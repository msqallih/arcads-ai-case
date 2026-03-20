{{
    config(
        materialized='view'
    )
}}

select
    id as cost_id,
    type,
    "entityId" as entity_id,
    "workspaceId" as workspace_id,
    value
from {{ source('arcads_product', 'Costs') }}
