{{
    config(
        materialized='table'
    )
}}

-- Identify first subscription for each workspace with AB test information
with workspaces_ab_tests as (
    select * from {{ ref('stg_workspaces_ab_tests') }}
),

subscription_histories as (
    select * from {{ ref('stg_stripe_subscription_histories') }}
),

payment_histories as (
    select * from {{ ref('stg_stripe_payment_histories') }}
),

plans as (
    select * from {{ ref('stg_plans') }}
),

-- Get first subscription per workspace
first_subscriptions as (
    select
        sh.workspace_id,
        sh.subscription_history_id,
        sh.plan,
        sh.billing_interval,
        sh.billing_interval_count,
        sh.start_date,
        sh.end_date,
        row_number() over (partition by sh.workspace_id order by sh.start_date) as rn
    from subscription_histories sh
),

first_sub_only as (
    select
        workspace_id,
        subscription_history_id,
        plan,
        billing_interval,
        billing_interval_count,
        start_date,
        end_date,
        start_date as first_subscription_at
    from first_subscriptions
    where rn = 1
),

-- Get first payment for each first subscription
first_payments as (
    select
        ph.subscription_history_id,
        ph.eur_amount as first_payment_amount,
        ph.payment_date as first_payment_date,
        ph.payment_type,
        row_number() over (partition by ph.subscription_history_id order by ph.payment_date) as rn
    from payment_histories ph
    where ph.payment_type = 'plan'
),

first_payment_only as (
    select
        subscription_history_id,
        first_payment_amount,
        first_payment_date
    from first_payments
    where rn = 1
),

-- Join everything together
final as (
    select
        fs.workspace_id,
        wat.workspace_ab_test_id,
        wat.ab_test_name,
        wat.cohort,
        wat.assigned_at as ab_test_assigned_at,
        fs.subscription_history_id,
        fs.plan as plan_id,
        fs.plan as plan_name,
        p.plan_type,
        p.plan_credits,
        p.is_pro,
        fs.billing_interval,
        fs.billing_interval_count,
        fs.start_date as subscription_start_date,
        fs.first_subscription_at,
        fp.first_payment_amount,
        fp.first_payment_date,
        -- Calculate if subscription happened during AB test period
        -- 10% Discount Test: January 1-10, 2026
        -- 30% Discount Test: January 28 (3 PM Paris) to February 10 (10 AM Paris), 2026
        case
            when wat.ab_test_name = 'PAYWALL_FIRST_MONTH_DISCOUNT'
                and fs.start_date >= '2026-01-01'::timestamp
                and fs.start_date <= '2026-01-10 23:59:59'::timestamp
            then true
            when wat.ab_test_name = 'PAYWALL_FIRST_MONTH_30_PERCENT_DISCOUNT' 
                and fs.start_date >= '2026-01-28 15:00:00'::timestamp 
                and fs.start_date <= '2026-02-10 10:00:00'::timestamp
            then true
            else false
        end as is_during_test_period
    from first_sub_only fs
    left join workspaces_ab_tests wat on fs.workspace_id = wat.workspace_id
    left join first_payment_only fp on fs.subscription_history_id = fp.subscription_history_id
    left join plans p on fs.plan = p.plan_type
)

select * from final
