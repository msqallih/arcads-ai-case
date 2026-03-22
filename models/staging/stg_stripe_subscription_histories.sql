{{
    config(
        materialized='view'
    )
}}

select
    id as subscription_history_id,
    "workspaceId"::text as workspace_id,
    plan,
    "startDate" as start_date,
    "endDate" as end_date,
    interval as billing_interval,
    "intervalCount" as billing_interval_count,
    "createdAt" as created_at
from {{ source('arcads_product', 'StripeSubscriptionHistories') }}