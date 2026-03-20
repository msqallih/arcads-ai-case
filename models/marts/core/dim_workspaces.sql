{{
    config(
        materialized='table'
    )
}}

-- Dimension table for workspaces
with workspaces as (
    select * from {{ ref('stg_workspaces') }}
),

users as (
    select * from {{ ref('stg_users') }}
),

workspace_metrics as (
    select * from {{ ref('int_workspace_metrics') }}
),

final as (
    select
        w.workspace_id,
        w.user_id,
        u.email as user_email,
        w.plan as current_plan,
        w.subscription_id,
        w.stripe_end_current_period,
        w.total_credits,
        w.used_credits,
        w.created_at as workspace_created_at,
        w.updated_at as workspace_updated_at,
        u.created_at as user_created_at,
        
        -- Metrics from int_workspace_metrics
        wm.total_revenue,
        wm.total_plan_revenue,
        wm.total_additional_credits_revenue,
        wm.total_payments,
        wm.first_payment_date,
        wm.last_payment_date,
        wm.total_credits_consumed,
        wm.total_generations,
        wm.total_generation_cost,
        wm.has_revenue,
        wm.has_consumed_credits,
        wm.has_generated_content
        
    from workspaces w
    left join users u on w.user_id = u.user_id
    left join workspace_metrics wm on w.workspace_id = wm.workspace_id
)

select * from final
