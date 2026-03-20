{{
    config(
        materialized='view'
    )
}}

select
    id as user_id,
    email,
    "firstName" as first_name,
    "lastName" as last_name,
    "createdAt"::date as created_at,
    "updatedAt"::date as updated_at
from {{ source('arcads_product', 'Users') }}
