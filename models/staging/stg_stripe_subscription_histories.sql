{{
    config(
        materialized='view'
    )
}}

select
    id as subscription_history_id,
    "workspaceId" as workspace_id,
    plan,
    "subscriptionId" as subscription_id,
    interval as billing_interval,
    "intervalCount" as billing_interval_count,
    "startDate"::date as start_date,
    "endDate"::date as end_date,
    "createdAt"::date as created_at
from {{ source('arcads_product', 'StripeSubscriptionHistories') }}
