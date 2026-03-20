{{
    config(
        materialized='view'
    )
}}

select
    id as credit_event_id,
    "workspaceId" as workspace_id,
    "userId" as user_id,
    feature as credit_event_feature,
    "occurredAt"::date as occured_at,
    generations,
    "creditsCost" as credit_cost
from {{ source('arcads_product', 'CreditsConsumptionEvents') }}
