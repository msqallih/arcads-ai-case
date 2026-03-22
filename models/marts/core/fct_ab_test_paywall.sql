{{
    config(
        materialized='table'
    )
}}

-- Fact table for AB test analysis - focused on the paywall tests
with workspaces_ab_tests as (
    select * from {{ ref('stg_workspaces_ab_tests') }}
),

first_subscriptions as (
    select * from {{ ref('int_first_subscriptions') }}
),

workspace_metrics as (
    select * from {{ ref('int_workspace_metrics') }}
),

-- Track ALL subscriptions for churn analysis
subscription_histories as (
    select * from {{ ref('stg_stripe_subscription_histories') }}
),

all_subscriptions as (
    select
        sh.workspace_id,
        sh.subscription_history_id,
        sh.plan,
        sh.billing_interval,
        sh.start_date,
        sh.end_date,
        row_number() over (partition by sh.workspace_id order by sh.start_date) as subscription_number,
        count(*) over (partition by sh.workspace_id) as total_subscription_count
    from subscription_histories sh
),

-- Identify churned workspaces (those who had a subscription but it ended)
churn_analysis as (
    select
        workspace_id,
        max(end_date) as last_subscription_end_date,
        min(start_date) as first_subscription_start_date,
        count(*) as total_subscriptions,
        -- Churned if last subscription ended and no active subscription
        case 
            when max(end_date) < current_date then true
            else false
        end as is_churned,
        -- Churned after first month discount
        case 
            when count(*) = 1 and max(end_date) < current_date then true
            else false
        end as churned_after_first_subscription,
        -- Calculate lifetime in days (extract days from interval)
        extract(day from (max(end_date) - min(start_date)))::integer as subscription_lifetime_days
    from all_subscriptions
    group by workspace_id
),

-- Define exact test periods based on actual test dates
test_periods as (
    select 
        'PAYWALL_FIRST_MONTH_DISCOUNT' as ab_test_name,
        '2026-01-01'::timestamp as test_start_date,
        '2026-01-10'::timestamp as test_end_date,
        10 as test_duration_days
    union all
    select 
        'PAYWALL_FIRST_MONTH_30_PERCENT_DISCOUNT' as ab_test_name,
        '2026-01-28 15:00:00'::timestamp as test_start_date,
        '2026-02-10 10:00:00'::timestamp as test_end_date,
        14 as test_duration_days
),

-- Calculate CAC from Meta Ads data
meta_ads as (
    select * from {{ ref('stg_meta_ads') }}
),

cac_by_period as (
    select
        tp.ab_test_name,
        tp.test_start_date,
        tp.test_end_date,
        tp.test_duration_days,
        sum(ma.spend_eur) as total_ad_spend,
        sum(ma.sign_ups) as total_sign_ups,
        sum(ma.purchases) as total_purchases,
        -- CAC = Total Spend / Total Sign Ups
        case 
            when sum(ma.sign_ups) > 0 
            then sum(ma.spend_eur) / sum(ma.sign_ups)
            else 0 
        end as cac_per_signup,
        -- Cost per Purchase from ads
        case 
            when sum(ma.purchases) > 0 
            then sum(ma.spend_eur) / sum(ma.purchases)
            else 0 
        end as cac_per_purchase
    from test_periods tp
    left join meta_ads ma 
        on ma.ad_date between tp.test_start_date and tp.test_end_date
    group by tp.ab_test_name, tp.test_start_date, tp.test_end_date, tp.test_duration_days
),

-- Main fact table
fct_ab_test_paywall as (
    select
        fs.workspace_id,
        fs.ab_test_name,
        fs.cohort,
        fs.ab_test_assigned_at,
        fs.subscription_history_id,
        fs.plan_id,
        fs.plan_name,
        fs.plan_type,
        fs.billing_interval,
        fs.subscription_start_date,
        fs.first_subscription_at,
        fs.first_payment_amount,
        fs.first_payment_date,
        fs.is_during_test_period,
        
        -- Add workspace metrics
        wm.total_revenue,
        wm.total_plan_revenue,
        wm.total_additional_credits_revenue,
        wm.total_payments,
        wm.last_payment_date,
        wm.total_credits_consumed,
        wm.total_credits_refunded,
        wm.total_videos_v1,
        wm.total_assets,
        wm.total_generations,
        wm.total_generation_cost,
        wm.has_revenue,
        wm.has_consumed_credits,
        wm.has_generated_content,
        
        -- Add churn metrics
        ca.is_churned,
        ca.churned_after_first_subscription,
        ca.total_subscriptions,
        ca.subscription_lifetime_days,
        ca.last_subscription_end_date,
        
        -- Add CAC metrics
        cac.cac_per_signup,
        cac.cac_per_purchase,
        cac.test_duration_days,
        
        -- Calculate profit with CAC
        wm.total_revenue - wm.total_generation_cost - coalesce(cac.cac_per_signup, 0) as profit_with_cac,
        
        -- Days since test assignment
        current_date - fs.ab_test_assigned_at::date as days_since_test_assignment
        
    from (
        select
            wat.workspace_id,
            wat.ab_test_name,
            wat.cohort,
            wat.assigned_at as ab_test_assigned_at,
            ifs.subscription_history_id,
            ifs.plan_id,
            ifs.plan_name,
            ifs.plan_type,
            ifs.billing_interval,
            ifs.subscription_start_date,
            ifs.first_subscription_at,
            ifs.first_payment_amount,
            ifs.first_payment_date,
            case 
                -- 10% Discount Test: January 1-10, 2026
                when wat.ab_test_name = 'PAYWALL_FIRST_MONTH_DISCOUNT'
                    and ifs.first_subscription_at >= '2026-01-01'::timestamp
                    and ifs.first_subscription_at <= '2026-01-10 23:59:59'::timestamp
                then true
                -- 30% Discount Test: January 28 (3 PM) to February 10 (10 AM), 2026
                when wat.ab_test_name = 'PAYWALL_FIRST_MONTH_30_PERCENT_DISCOUNT'
                    and ifs.first_subscription_at >= '2026-01-28 15:00:00'::timestamp
                    and ifs.first_subscription_at <= '2026-02-10 10:00:00'::timestamp
                then true
                else false 
            end as is_during_test_period
        from workspaces_ab_tests wat
        left join first_subscriptions ifs on wat.workspace_id = ifs.workspace_id
    ) fs
    left join workspace_metrics wm on fs.workspace_id = wm.workspace_id
    left join churn_analysis ca on fs.workspace_id = ca.workspace_id
    left join cac_by_period cac on fs.ab_test_name = cac.ab_test_name
)

select * from fct_ab_test_paywall
