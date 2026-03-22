{{
    config(
        materialized='view'
    )
}}

select
    id,
    "workspaceId"::text as workspace_id
from {{ source('arcads_product', 'Products') }}