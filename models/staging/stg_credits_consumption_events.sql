{{
    config(
        materialized='view'
    )
}}

select
    id as event_id,
    "workspaceId"::text as workspace_id,
    "creditsCost" as credit_cost,
    "createdAt" as consumed_at
from {{ source('arcads_product', 'CreditsConsumptionEvents') }}