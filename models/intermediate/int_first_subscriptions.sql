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
        sh.plan_id,
        sh.billing_interval,
        sh.start_date,
        sh.end_date,
        sh.created_at,
        row_number() over (partition by sh.workspace_id order by sh.start_date, sh.created_at) as rn
    from subscription_histories sh
),

first_sub_only as (
    select
        workspace_id,
        subscription_history_id,
        plan_id,
        billing_interval,
        start_date,
        end_date,
        created_at as first_subscription_at
    from first_subscriptions
    where rn = 1
),

-- Get first payment for each first subscription
first_payments as (
    select
        ph.workspace_id,
        ph.subscription_history_id,
        ph.amount as first_payment_amount,
        ph.payment_date as first_payment_date,
        ph.payment_type,
        row_number() over (partition by ph.workspace_id order by ph.payment_date, ph.created_at) as rn
    from payment_histories ph
    where ph.payment_type = 'plan'
),

first_payment_only as (
    select
        workspace_id,
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
        wat.ab_test_name,
        wat.cohort,
        wat.created_at as ab_test_assigned_at,
        fs.subscription_history_id,
        fs.plan_id,
        p.plan_name,
        p.plan_type,
        fs.billing_interval,
        fs.start_date as subscription_start_date,
        fs.first_subscription_at,
        fp.first_payment_amount,
        fp.first_payment_date,
        -- Calculate if subscription happened during AB test period
        case
            when wat.ab_test_name = 'PAYWALL_FIRST_MONTH_30_PERCENT_DISCOUNT' 
                and fs.start_date >= '2026-01-28 14:00:00'::timestamp 
                and fs.start_date <= '2026-02-10 10:00:00'::timestamp
            then true
            when wat.ab_test_name = 'PAYWALL_FIRST_MONTH_DISCOUNT'
                and fs.start_date >= '2026-01-01 00:00:00'::timestamp
                and fs.start_date <= '2026-01-10 23:59:59'::timestamp
            then true
            else false
        end as is_during_test_period
    from first_sub_only fs
    left join workspaces_ab_tests wat on fs.workspace_id = wat.workspace_id
    left join first_payment_only fp on fs.workspace_id = fp.workspace_id 
        and fs.subscription_history_id = fp.subscription_history_id
    left join plans p on fs.plan_id = p.plan_id
)

select * from final
