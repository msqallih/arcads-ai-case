{{
    config(
        materialized='table'
    )
}}

-- Analysis of AB test results comparing 10% vs 30% discount
with ab_test_data as (
    select * from {{ ref('fct_ab_test_paywall') }}
),

-- Calculate metrics by test and cohort
test_metrics as (
    select
        test_label,
        ab_test_name,
        cohort,
        
        -- Sample size
        count(*) as total_workspaces,
        
        -- Conversion metrics
        sum(case when converted_to_paid then 1 else 0 end) as conversions,
        sum(case when converted_to_paid then 1 else 0 end)::numeric / count(*)::numeric as conversion_rate,
        
        -- Revenue metrics
        sum(first_payment_amount) as total_first_payment_revenue,
        avg(first_payment_amount) as avg_first_payment_amount,
        sum(lifetime_value) as total_lifetime_value,
        avg(lifetime_value) as avg_lifetime_value,
        
        -- Profit metrics
        sum(profit) as total_profit,
        avg(profit) as avg_profit_per_workspace,
        
        -- Plan distribution
        sum(case when plan_name = 'STARTER' and billing_interval = 'month' then 1 else 0 end) as starter_monthly,
        sum(case when plan_name = 'BASIC' and billing_interval = 'month' then 1 else 0 end) as creator_monthly,
        sum(case when plan_name = 'PRO' and billing_interval = 'month' then 1 else 0 end) as pro_monthly,
        sum(case when billing_interval = 'year' then 1 else 0 end) as yearly_plans,
        
        -- Engagement metrics
        sum(case when has_generated_content then 1 else 0 end) as workspaces_with_content,
        sum(total_generations) as total_content_generated,
        avg(total_generations) as avg_generations_per_workspace,
        
        -- Retention metrics
        sum(case when has_renewed then 1 else 0 end) as renewed_subscriptions,
        sum(case when has_renewed then 1 else 0 end)::numeric / 
            nullif(sum(case when converted_to_paid then 1 else 0 end), 0)::numeric as renewal_rate,
        
        -- Time to conversion
        avg(days_to_conversion) as avg_days_to_conversion,
        
        -- Additional revenue
        sum(total_additional_credits_revenue) as total_additional_credits_revenue,
        avg(total_additional_credits_revenue) as avg_additional_credits_revenue
        
    from ab_test_data
    where is_during_test_period = true
    group by test_label, ab_test_name, cohort
),

-- Calculate lift for each test
test_comparison as (
    select
        test_label,
        
        -- Control (Cohort A) metrics
        max(case when cohort = 'A' then total_workspaces else 0 end) as control_sample_size,
        max(case when cohort = 'A' then conversion_rate else 0 end) as control_conversion_rate,
        max(case when cohort = 'A' then avg_lifetime_value else 0 end) as control_avg_ltv,
        max(case when cohort = 'A' then avg_profit_per_workspace else 0 end) as control_avg_profit,
        
        -- Variant (Cohort B) metrics
        max(case when cohort = 'B' then total_workspaces else 0 end) as variant_sample_size,
        max(case when cohort = 'B' then conversion_rate else 0 end) as variant_conversion_rate,
        max(case when cohort = 'B' then avg_lifetime_value else 0 end) as variant_avg_ltv,
        max(case when cohort = 'B' then avg_profit_per_workspace else 0 end) as variant_avg_profit,
        
        -- Calculate lifts
        (max(case when cohort = 'B' then conversion_rate else 0 end) - 
         max(case when cohort = 'A' then conversion_rate else 0 end)) / 
         nullif(max(case when cohort = 'A' then conversion_rate else 0 end), 0) * 100 as conversion_rate_lift_percent,
        
        (max(case when cohort = 'B' then avg_lifetime_value else 0 end) - 
         max(case when cohort = 'A' then avg_lifetime_value else 0 end)) / 
         nullif(max(case when cohort = 'A' then avg_lifetime_value else 0 end), 0) * 100 as ltv_lift_percent,
        
        (max(case when cohort = 'B' then avg_profit_per_workspace else 0 end) - 
         max(case when cohort = 'A' then avg_profit_per_workspace else 0 end)) / 
         nullif(max(case when cohort = 'A' then avg_profit_per_workspace else 0 end), 0) * 100 as profit_lift_percent
        
    from test_metrics
    group by test_label
),

-- Combine detailed metrics with comparison
final as (
    select
        tm.*,
        tc.control_sample_size,
        tc.control_conversion_rate,
        tc.control_avg_ltv,
        tc.control_avg_profit,
        tc.variant_sample_size,
        tc.variant_conversion_rate,
        tc.variant_avg_ltv,
        tc.variant_avg_profit,
        tc.conversion_rate_lift_percent,
        tc.ltv_lift_percent,
        tc.profit_lift_percent
    from test_metrics tm
    left join test_comparison tc on tm.test_label = tc.test_label
    order by tm.test_label, tm.cohort
)

select * from final
