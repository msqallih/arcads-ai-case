{{
    config(
        materialized='view'
    )
}}

select
    id as payment_history_id,
    "stripeSubscriptionHistoryId" as subscription_history_id,
    type as payment_type,
    date::date as payment_date,
    currency,
    "currencyAmount" as currency_amount,
    "eurAmount" as eur_amount,
    credits,
    "additionalCredits" as additional_credits,
    "refundedAmount" as refunded_amount,
    "eurRefundedAmount" as eur_refunded_amount
from {{ source('arcads_product', 'StripePaymentHistories') }}
