{{
    config(
        materialized='view'
    )
}}

select
    id,
    name,
    "projectId" as project_id
from {{ source('arcads_product', 'Scripts') }}