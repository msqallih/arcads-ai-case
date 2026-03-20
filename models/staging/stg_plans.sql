{{
    config(
        materialized='view'
    )
}}

select
    type as plan_type,
    "isPro" as is_pro,
    credits as plan_credits
from {{ source('arcads_product', 'Plans') }}
