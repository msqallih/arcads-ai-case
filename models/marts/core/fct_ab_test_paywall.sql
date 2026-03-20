{{
    config(
        materialized='table'
    )
}}

-- Fact table for AB test analysis - focused on the paywall tests
with first_subscriptions as (
    select * from {{ ref('int_first_subscriptions') }}
),

workspace_metrics as (
    select * from {{ ref('int_workspace_metrics') }}
),

workspaces as (
    select * from {{ ref('stg_workspaces') }}
),

-- Filter for the two paywall AB tests we're analyzing
paywall_tests as (
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
        wm.total_generations,
        wm.total_generation_cost,
        wm.has_revenue,
        wm.has_consumed_credits,
        wm.has_generated_content,
        
        -- Add current workspace state
        w.plan as current_plan,
        w.stripe_end_current_period as current_period_end,
        
        -- Calculate key metrics
        case 
            when fs.first_payment_date is not null then true 
            else false 
        end as converted_to_paid,
        
        case
            when wm.total_payments > 1 then true
            else false
        end as has_renewed,
        
        -- Calculate LTV (total revenue)
        coalesce(wm.total_revenue, 0) as lifetime_value,
        
        -- Calculate profit (revenue - costs)
        coalesce(wm.total_revenue, 0) - coalesce(wm.total_generation_cost, 0) as profit,
        
        -- Days from assignment to first payment
        case 
            when fs.first_payment_date is not null 
            then extract(day from (fs.first_payment_date - fs.ab_test_assigned_at))
            else null
        end as days_to_conversion,
        
        -- Identify test periods
        case
            when fs.ab_test_name = 'PAYWALL_FIRST_MONTH_30_PERCENT_DISCOUNT' then '30% Discount Test'
            when fs.ab_test_name = 'PAYWALL_FIRST_MONTH_DISCOUNT' then '10% Discount Test'
            else 'Other'
        end as test_label
        
    from first_subscriptions fs
    left join workspace_metrics wm on fs.workspace_id = wm.workspace_id
    left join workspaces w on fs.workspace_id = w.workspace_id
    where fs.ab_test_name in (
        'PAYWALL_FIRST_MONTH_30_PERCENT_DISCOUNT',
        'PAYWALL_FIRST_MONTH_DISCOUNT'
    )
)

select * from paywall_tests
