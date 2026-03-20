{{
    config(
        materialized='table'
    )
}}

-- Calculate workspace-level metrics for revenue and engagement
with workspaces as (
    select * from {{ ref('stg_workspaces') }}
),

payment_histories as (
    select * from {{ ref('stg_stripe_payment_histories') }}
),

credits_events as (
    select * from {{ ref('stg_credits_consumption_events') }}
),

videos as (
    select * from {{ ref('stg_videos') }}
),

video_assets as (
    select * from {{ ref('stg_video_assets') }}
),

costs as (
    select * from {{ ref('stg_costs') }}
),

-- Aggregate payments per workspace
workspace_payments as (
    select
        workspace_id,
        count(*) as total_payments,
        sum(case when payment_type = 'plan' then amount else 0 end) as total_plan_revenue,
        sum(case when payment_type = 'additional credits' then amount else 0 end) as total_additional_credits_revenue,
        sum(amount) as total_revenue,
        min(payment_date) as first_payment_date,
        max(payment_date) as last_payment_date
    from payment_histories
    where payment_status = 'succeeded'
    group by workspace_id
),

-- Aggregate credits consumption per workspace
workspace_credits as (
    select
        workspace_id,
        sum(case when credits > 0 then credits else 0 end) as total_credits_consumed,
        sum(case when credits < 0 then abs(credits) else 0 end) as total_credits_refunded,
        count(*) as total_credit_events
    from credits_events
    group by workspace_id
),

-- Aggregate generations per workspace
workspace_generations as (
    select
        workspace_id,
        count(*) as total_videos_v1
    from videos
    group by workspace_id
),

workspace_assets as (
    select
        workspace_id,
        count(*) as total_assets,
        count(distinct asset_type) as distinct_asset_types
    from video_assets
    group by workspace_id
),

-- Aggregate costs per workspace
workspace_costs as (
    select
        workspace_id,
        sum(cost) as total_generation_cost,
        count(*) as total_cost_records
    from costs
    group by workspace_id
),

-- Combine all metrics
final as (
    select
        w.workspace_id,
        w.user_id,
        w.plan,
        w.created_at as workspace_created_at,
        
        -- Payment metrics
        coalesce(wp.total_payments, 0) as total_payments,
        coalesce(wp.total_plan_revenue, 0) as total_plan_revenue,
        coalesce(wp.total_additional_credits_revenue, 0) as total_additional_credits_revenue,
        coalesce(wp.total_revenue, 0) as total_revenue,
        wp.first_payment_date,
        wp.last_payment_date,
        
        -- Credit metrics
        coalesce(wc.total_credits_consumed, 0) as total_credits_consumed,
        coalesce(wc.total_credits_refunded, 0) as total_credits_refunded,
        coalesce(wc.total_credit_events, 0) as total_credit_events,
        
        -- Generation metrics
        coalesce(wg.total_videos_v1, 0) as total_videos_v1,
        coalesce(wa.total_assets, 0) as total_assets,
        coalesce(wa.distinct_asset_types, 0) as distinct_asset_types,
        coalesce(wg.total_videos_v1, 0) + coalesce(wa.total_assets, 0) as total_generations,
        
        -- Cost metrics
        coalesce(wco.total_generation_cost, 0) as total_generation_cost,
        
        -- Engagement flags
        case when coalesce(wp.total_revenue, 0) > 0 then true else false end as has_revenue,
        case when coalesce(wc.total_credits_consumed, 0) > 0 then true else false end as has_consumed_credits,
        case when coalesce(wg.total_videos_v1, 0) + coalesce(wa.total_assets, 0) > 0 then true else false end as has_generated_content
        
    from workspaces w
    left join workspace_payments wp on w.workspace_id = wp.workspace_id
    left join workspace_credits wc on w.workspace_id = wc.workspace_id
    left join workspace_generations wg on w.workspace_id = wg.workspace_id
    left join workspace_assets wa on w.workspace_id = wa.workspace_id
    left join workspace_costs wco on w.workspace_id = wco.workspace_id
)

select * from final
