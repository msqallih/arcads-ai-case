{{
    config(
        materialized='table'
    )
}}

-- Calculate workspace-level metrics for revenue and engagement
-- IMPORTANT: Only count payments made during or after AB test assignment
with workspaces as (
    select * from {{ ref('stg_workspaces') }}
),

workspaces_ab_tests as (
    select * from {{ ref('stg_workspaces_ab_tests') }}
),

subscription_histories as (
    select * from {{ ref('stg_stripe_subscription_histories') }}
),

payment_histories as (
    select * from {{ ref('stg_stripe_payment_histories') }}
),

credits_events as (
    select * from {{ ref('stg_credits_consumption_events') }}
),

costs as (
    select * from {{ ref('stg_costs') }}
),

videos as (
    select * from {{ ref('stg_videos') }}
),

video_assets as (
    select * from {{ ref('stg_video_assets') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

folders as (
    select * from {{ ref('stg_folders') }}
),

projects as (
    select * from {{ ref('stg_projects') }}
),

scripts as (
    select * from {{ ref('stg_scripts') }}
),

-- Get payments made during or after AB test assignment
workspace_ab_test_payments as (
    select
        wat.workspace_id,
        wat.ab_test_name,
        wat.assigned_at,
        ph.payment_date,
        ph.payment_type,
        ph.eur_amount,
        ph.eur_refunded_amount,
        ph.is_refunded
    from workspaces_ab_tests wat
    inner join subscription_histories sh on wat.workspace_id = sh.workspace_id
    inner join payment_histories ph on sh.subscription_history_id = ph.subscription_history_id
    -- CRITICAL: Only count payments made during or after AB test assignment
    where ph.payment_date >= wat.assigned_at
),

-- Aggregate payments per workspace
payment_aggregations as (
    select
        workspace_id,
        count(*) as total_payments,
        sum(case when payment_type = 'plan' then eur_amount else 0 end) as total_plan_revenue,
        sum(case when payment_type = 'additional_credits' then eur_amount else 0 end) as total_additional_credits_revenue,
        -- Total revenue = payments - refunds (only for payments after AB test assignment)
        sum(eur_amount) - sum(case when is_refunded then eur_refunded_amount else 0 end) as total_revenue,
        sum(case when is_refunded then eur_refunded_amount else 0 end) as total_refunded,
        min(payment_date) as first_payment_date,
        max(payment_date) as last_payment_date
    from workspace_ab_test_payments
    group by workspace_id
),

-- Aggregate credits consumption per workspace
credit_aggregations as (
    select
        workspace_id,
        sum(credit_cost) as total_credits_consumed
    from credits_events
    group by workspace_id
),

-- Aggregate actual generation costs from Costs table
cost_aggregations as (
    select
        workspace_id,
        sum(value) as total_generation_cost
    from costs
    group by workspace_id
),

-- Video and asset aggregations (joined through products)
video_aggregations as (
    select
        p.workspace_id,
        count(distinct v.video_id) as total_videos_v1,
        count(distinct va.video_asset_id) as total_assets
    from products p
    left join folders f on p.id = f.product_id
    left join projects proj on f.folder_id = proj.folder_id
    left join scripts s on proj.id = s.project_id
    left join videos v on s.id = v.script_id
    left join video_assets va on p.id = va.product_id
    group by p.workspace_id
),

-- Combine all metrics
final as (
    select
        w.workspace_id,
        w.user_id,
        w.plan,
        coalesce(pa.total_plan_revenue, 0) as total_plan_revenue,
        coalesce(pa.total_additional_credits_revenue, 0) as total_additional_credits_revenue,
        coalesce(pa.total_revenue, 0) as total_revenue,
        pa.first_payment_date,
        pa.last_payment_date,
        coalesce(ca.total_credits_consumed, 0) as total_credits_consumed,
        coalesce(pa.total_refunded, 0) as total_credits_refunded,
        coalesce(va.total_videos_v1, 0) as total_videos_v1,
        coalesce(va.total_assets, 0) as total_assets,
        coalesce(va.total_videos_v1, 0) + coalesce(va.total_assets, 0) as total_generations,
        -- Actual generation costs from Costs table
        coalesce(costa.total_generation_cost, 0) as total_generation_cost,
        case when pa.total_revenue > 0 then true else false end as has_revenue,
        case when ca.total_credits_consumed > 0 then true else false end as has_consumed_credits,
        case when ca.total_credits_consumed > 0 or va.total_videos_v1 > 0 or va.total_assets > 0 then true else false end as has_generated_content,
        coalesce(pa.total_payments, 0) as total_payments
    from workspaces w
    left join payment_aggregations pa on w.workspace_id = pa.workspace_id
    left join credit_aggregations ca on w.workspace_id = ca.workspace_id
    left join cost_aggregations costa on w.workspace_id = costa.workspace_id
    left join video_aggregations va on w.workspace_id = va.workspace_id
)

select * from final
