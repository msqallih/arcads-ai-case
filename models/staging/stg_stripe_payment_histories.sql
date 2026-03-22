{{
    config(
        materialized='view'
    )
}}

select
    id as payment_id,
    "stripeSubscriptionHistoryId" as subscription_history_id,
    "eurAmount" as eur_amount,
    "eurRefundedAmount" as eur_refunded_amount,
    date as payment_date,
    type as payment_type,
    case when "eurRefundedAmount" > 0 then true else false end as is_refunded
from {{ source('arcads_product', 'StripePaymentHistories') }}