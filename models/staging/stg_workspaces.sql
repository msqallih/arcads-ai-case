{{
    config(
        materialized='view'
    )
}}

select
    id::text as workspace_id,
    "userId" as user_id,
    plan,
    "stripeEndCurrentPeriod" as stripe_end_current_period,
    "totalCredits" as total_credits,
    "usedCredits" as used_credits
from {{ source('arcads_product', 'Workspaces') }}