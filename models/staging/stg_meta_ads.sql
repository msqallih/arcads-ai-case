{{
    config(
        materialized='view'
    )
}}

select
    "Date" as ad_date,
    "Spend (€)" as spend_eur,
    "Purchases" as purchases,
    "Sign Ups" as sign_ups,
    "Cost per Sign Up (€)" as cost_per_sign_up_eur,
    "Cost per Purchase (€)" as cost_per_purchase_eur
from {{ ref('meta_ads') }}