{{
    config(
        materialized='view'
    )
}}

select
    id as workspace_id,
    "userId" as user_id,
    plan,
    "stripeEndCurrentPeriod"::date as stripe_end_current_period,
    "totalCredits" as total_credits,
    "usedCredits" as used_credits
from {{ source('arcads_product', 'Workspaces') }}