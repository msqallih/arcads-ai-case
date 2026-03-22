{{
    config(
        materialized='view'
    )
}}

select
    type as plan_type,
    credits as plan_credits,
    "isPro" as is_pro
from {{ source('arcads_product', 'Plans') }}