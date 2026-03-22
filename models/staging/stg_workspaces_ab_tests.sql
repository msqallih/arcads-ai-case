{{
    config(
        materialized='view'
    )
}}

select
    id as workspace_ab_test_id,
    "workspaceId"::text as workspace_id,
    feature as ab_test_name,
    cohort,
    "createdAt" as assigned_at
from {{ source('arcads_product', 'WorkspacesABTests') }}
where (
    -- Test 1: 10% Discount - January 1-10, 2026
    (feature = 'PAYWALL_FIRST_MONTH_DISCOUNT'
     and "createdAt" >= '2026-01-01 00:00:00'::timestamp
     and "createdAt" <= '2026-01-10 23:59:59'::timestamp)
    or
    -- Test 2: 30% Discount - January 28 (3 PM) to February 10 (10 AM), 2026
    (feature = 'PAYWALL_FIRST_MONTH_30_PERCENT_DISCOUNT'
     and "createdAt" >= '2026-01-28 15:00:00'::timestamp
     and "createdAt" <= '2026-02-10 10:00:00'::timestamp)
)