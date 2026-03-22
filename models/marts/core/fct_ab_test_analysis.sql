{{
    config(
        materialized='table'
    )
}}

-- Analysis of AB test results with key metrics: CAC, LTV, Conversion, Churn
with fct_ab_test_paywall as (
    select * from {{ ref('fct_ab_test_paywall') }}
),

-- Calculate metrics by test and cohort
test_metrics as (
    select
        ab_test_name,
        cohort,
        
        -- Test duration normalization factor
        max(test_duration_days) as test_duration_days,
        
        -- Basic counts
        count(distinct workspace_id) as total_workspaces,
        count(distinct case when subscription_history_id is not null then workspace_id end) as converted_workspaces,
        
        -- Conversion rate
        round(
            100.0 * count(distinct case when subscription_history_id is not null then workspace_id end) / 
            nullif(count(distinct workspace_id), 0), 
            2
        ) as conversion_rate_percent,
        
        -- Revenue metrics
        sum(total_revenue) as total_revenue,
        sum(total_plan_revenue) as total_plan_revenue,
        sum(total_additional_credits_revenue) as total_additional_credits_revenue,
        round(avg(case when total_revenue > 0 then total_revenue end), 2) as avg_revenue_per_paying_customer,
        round(sum(total_revenue) / nullif(count(distinct workspace_id), 0), 2) as revenue_per_workspace,
        
        -- First payment metrics
        round(avg(first_payment_amount), 2) as avg_first_payment,
        
        -- Generation metrics
        sum(total_generations) as total_generations,
        sum(total_credits_consumed) as total_credits_consumed,
        round(avg(case when has_generated_content then total_generations end), 2) as avg_generations_per_active_user,
        
        -- Cost metrics
        sum(total_generation_cost) as total_generation_cost,
        
        -- CAC metrics (average across all workspaces in cohort)
        avg(cac_per_signup) as avg_cac_per_signup,
        avg(cac_per_purchase) as avg_cac_per_purchase,
        sum(cac_per_signup) as total_cac_cost,
        
        -- Meta Ads spend (total spend during test period)
        max(coalesce((select total_ad_spend from {{ ref('stg_meta_ads') }} ma 
                      join (select distinct ab_test_name, test_duration_days from {{ ref('fct_ab_test_paywall') }}) tp 
                      on true 
                      where tp.ab_test_name = fct_ab_test_paywall.ab_test_name limit 1), 0)) as total_meta_ads_spend,
        
        -- Profit metrics WITH CAC
        sum(total_revenue - total_generation_cost - coalesce(cac_per_signup, 0)) as total_profit_with_cac,
        round(
            avg(case when has_revenue then total_revenue - total_generation_cost - coalesce(cac_per_signup, 0) end), 
            2
        ) as avg_profit_per_paying_customer_with_cac,
        round(
            sum(total_revenue - total_generation_cost - coalesce(cac_per_signup, 0)) / nullif(count(distinct workspace_id), 0), 
            2
        ) as profit_per_workspace_with_cac,
        
        -- Churn metrics
        count(distinct case when is_churned then workspace_id end) as churned_workspaces,
        count(distinct case when churned_after_first_subscription then workspace_id end) as churned_after_first_month,
        round(
            100.0 * count(distinct case when is_churned then workspace_id end) / 
            nullif(count(distinct case when subscription_history_id is not null then workspace_id end), 0),
            2
        ) as churn_rate_percent,
        round(
            100.0 * count(distinct case when churned_after_first_subscription then workspace_id end) / 
            nullif(count(distinct case when subscription_history_id is not null then workspace_id end), 0),
            2
        ) as first_month_churn_rate_percent,
        
        -- Average subscription lifetime
        round(avg(case when subscription_history_id is not null then subscription_lifetime_days end), 1) as avg_subscription_lifetime_days
        
    from fct_ab_test_paywall
    group by ab_test_name, cohort
),

-- Calculate lift metrics by comparing Cohort B vs Cohort A
test_comparison as (
    select
        ab_test_name,
        
        -- Conversion lift
        conversion_rate_percent - lag(conversion_rate_percent) over (partition by ab_test_name order by cohort) as conversion_lift_pct,
        
        -- Revenue lift
        round(
            100.0 * (revenue_per_workspace - lag(revenue_per_workspace) over (partition by ab_test_name order by cohort)) / 
            nullif(lag(revenue_per_workspace) over (partition by ab_test_name order by cohort), 0),
            2
        ) as revenue_lift_percent,
        
        -- Profit lift (with CAC included)
        round(
            100.0 * (profit_per_workspace_with_cac - lag(profit_per_workspace_with_cac) over (partition by ab_test_name order by cohort)) / 
            nullif(lag(profit_per_workspace_with_cac) over (partition by ab_test_name order by cohort), 0),
            2
        ) as profit_lift_percent
        
    from test_metrics
)

-- Final output with key metrics: CAC, LTV, Conversion, Churn
select
    tm.ab_test_name,
    tm.cohort,
    tm.test_duration_days,
    
    -- Volume & Conversion
    tm.total_workspaces,
    tm.converted_workspaces,
    tm.conversion_rate_percent,
    
    -- Revenue & LTV
    round(tm.total_revenue, 2) as total_revenue,
    round(tm.avg_first_payment, 2) as avg_first_payment,
    round(tm.revenue_per_workspace, 2) as ltv_per_workspace,
    
    -- CAC (Customer Acquisition Cost)
    round(tm.avg_cac_per_signup, 2) as cac_per_signup,
    round(tm.total_cac_cost, 2) as total_cac_cost,
    round(tm.total_meta_ads_spend, 2) as total_meta_ads_spend,
    
    -- Profit (Revenue - Generation Costs - CAC)
    round(tm.total_profit_with_cac, 2) as total_profit,
    round(tm.profit_per_workspace_with_cac, 2) as profit_per_workspace,
    
    -- LTV/CAC Ratio (key metric for unit economics)
    round(
        tm.revenue_per_workspace / nullif(tm.avg_cac_per_signup, 0),
        2
    ) as ltv_to_cac_ratio,
    
    -- Churn & Retention
    tm.churned_workspaces,
    tm.churned_after_first_month,
    round(tm.churn_rate_percent, 2) as churn_rate_percent,
    round(tm.first_month_churn_rate_percent, 2) as first_month_churn_rate_percent,
    round(tm.avg_subscription_lifetime_days, 1) as avg_subscription_lifetime_days,
    
    -- Engagement
    tm.total_generations,
    round(tm.avg_generations_per_active_user, 1) as avg_generations_per_active_user,
    
    -- Lift Metrics (Cohort B vs Cohort A)
    round(tc.conversion_lift_pct, 2) as conversion_lift_pct,
    round(tc.revenue_lift_percent, 2) as ltv_lift_percent,
    round(tc.profit_lift_percent, 2) as profit_lift_percent
    
from test_metrics tm
left join test_comparison tc on tm.ab_test_name = tc.ab_test_name
order by tm.ab_test_name, tm.cohort
