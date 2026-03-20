-- Plan-Level Analysis for 30% Discount Test
-- Detailed breakdown by plan type and billing interval

WITH workspace_ab_tests AS (
    SELECT
        "workspaceId" as workspace_id,
        feature as ab_test_name,
        cohort,
        "createdAt" as assigned_at
    FROM "WorkspacesABTests"
    WHERE feature = 'PAYWALL_FIRST_MONTH_30_PERCENT_DISCOUNT'
),

subscription_histories AS (
    SELECT
        id as subscription_history_id,
        "workspaceId"::uuid as workspace_id,
        plan as plan_name,
        interval as billing_interval,
        "startDate" as start_date,
        "endDate" as end_date,
        ROW_NUMBER() OVER (PARTITION BY "workspaceId" ORDER BY "startDate", "createdAt") as rn
    FROM "StripeSubscriptionHistories"
),

first_subscriptions AS (
    SELECT *
    FROM subscription_histories
    WHERE rn = 1
        AND start_date >= '2026-01-28 14:00:00'::timestamp
        AND start_date <= '2026-02-10 10:00:00'::timestamp
),

payment_histories AS (
    SELECT
        ph.id as payment_id,
        ph."stripeSubscriptionHistoryId" as subscription_history_id,
        ph.date as payment_date,
        ph."eurAmount" as amount_eur
    FROM "StripePaymentHistories" ph
    WHERE ph.type = 'plan'
),

first_payments AS (
    SELECT
        ph.subscription_history_id,
        ph.amount_eur as first_payment_amount,
        ph.payment_date
    FROM payment_histories ph
    INNER JOIN (
        SELECT subscription_history_id, MIN(payment_date) as min_date
        FROM payment_histories
        GROUP BY subscription_history_id
    ) first ON ph.subscription_history_id = first.subscription_history_id 
        AND ph.payment_date = first.min_date
),

combined_data AS (
    SELECT
        wat.cohort,
        fs.plan_name,
        fs.billing_interval,
        fp.first_payment_amount
    FROM workspace_ab_tests wat
    INNER JOIN first_subscriptions fs ON wat.workspace_id = fs.workspace_id
    INNER JOIN first_payments fp ON fs.subscription_history_id = fp.subscription_history_id
)

SELECT
    cohort,
    plan_name,
    billing_interval,
    COUNT(*) as conversions,
    ROUND(AVG(first_payment_amount), 2) as avg_first_payment,
    ROUND(MIN(first_payment_amount), 2) as min_payment,
    ROUND(MAX(first_payment_amount), 2) as max_payment,
    ROUND(SUM(first_payment_amount), 2) as total_revenue
FROM combined_data
GROUP BY cohort, plan_name, billing_interval
ORDER BY cohort, plan_name, billing_interval;
