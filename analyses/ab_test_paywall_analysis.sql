-- AB Test Analysis: Paywall First Month Discount (10% vs 30%)
-- This analysis compares the performance of two AB tests:
-- 1. PAYWALL_FIRST_MONTH_DISCOUNT (10% discount) - Jan 1-10, 2026
-- 2. PAYWALL_FIRST_MONTH_30_PERCENT_DISCOUNT (30% discount) - Jan 28 - Feb 10, 2026

WITH workspace_ab_tests AS (
    SELECT
        "workspaceId" as workspace_id,
        feature as ab_test_name,
        cohort,
        "createdAt" as assigned_at
    FROM "WorkspacesABTests"
    WHERE feature IN ('PAYWALL_FIRST_MONTH_DISCOUNT', 'PAYWALL_FIRST_MONTH_30_PERCENT_DISCOUNT')
),

subscription_histories AS (
    SELECT
        id as subscription_history_id,
        "workspaceId"::uuid as workspace_id,
        plan as plan_name,
        interval as billing_interval,
        "intervalCount" as interval_count,
        "startDate" as start_date,
        "endDate" as end_date,
        "createdAt" as created_at,
        ROW_NUMBER() OVER (PARTITION BY "workspaceId" ORDER BY "startDate", "createdAt") as rn
    FROM "StripeSubscriptionHistories"
),

first_subscriptions AS (
    SELECT *
    FROM subscription_histories
    WHERE rn = 1
),

payment_histories AS (
    SELECT
        id as payment_id,
        "stripeSubscriptionHistoryId" as subscription_history_id,
        type as payment_type,
        date as payment_date,
        "eurAmount" as amount_eur,
        credits,
        "additionalCredits" as additional_credits,
        ROW_NUMBER() OVER (PARTITION BY "stripeSubscriptionHistoryId" ORDER BY date) as payment_rn
    FROM "StripePaymentHistories"
),

first_payments AS (
    SELECT
        ph.subscription_history_id,
        ph.amount_eur as first_payment_amount,
        ph.payment_date as first_payment_date
    FROM payment_histories ph
    WHERE ph.payment_rn = 1 AND ph.payment_type = 'plan'
),

plans AS (
    SELECT
        type as plan_type,
        credits as plan_credits,
        "isPro" as is_pro
    FROM "Plans"
),

-- Aggregate all payments per workspace for LTV calculation
workspace_payments AS (
    SELECT
        sh."workspaceId"::uuid as workspace_id,
        COUNT(DISTINCT ph.id) as total_payments,
        SUM(CASE WHEN ph.type = 'plan' THEN ph."eurAmount" ELSE 0 END) as total_plan_revenue,
        SUM(ph."eurAmount") as total_revenue
    FROM "StripePaymentHistories" ph
    JOIN "StripeSubscriptionHistories" sh ON ph."stripeSubscriptionHistoryId" = sh.id
    GROUP BY sh."workspaceId"
),

-- Aggregate generation costs
generation_costs AS (
    SELECT
        "workspaceId" as workspace_id,
        SUM(value) as total_cost
    FROM "Costs"
    GROUP BY "workspaceId"
),

-- Combine all data
workspace_data AS (
    SELECT
        wat.workspace_id,
        wat.ab_test_name,
        wat.cohort,
        wat.assigned_at,
        
        -- Subscription info
        fs.plan_name,
        fs.billing_interval,
        fs.start_date as subscription_start_date,
        
        -- Payment info
        fp.first_payment_amount,
        fp.first_payment_date,
        
        -- Revenue metrics
        COALESCE(wp.total_payments, 0) as total_payments,
        COALESCE(wp.total_revenue, 0) as lifetime_value,
        COALESCE(wp.total_plan_revenue, 0) as total_plan_revenue,
        
        -- Cost metrics
        COALESCE(gc.total_cost, 0) as total_generation_cost,
        COALESCE(wp.total_revenue, 0) - COALESCE(gc.total_cost, 0) as profit,
        
        -- Conversion flags
        CASE WHEN fp.first_payment_date IS NOT NULL THEN 1 ELSE 0 END as converted,
        CASE WHEN wp.total_payments > 1 THEN 1 ELSE 0 END as has_renewed,
        
        -- Test period flags
        CASE
            WHEN wat.ab_test_name = 'PAYWALL_FIRST_MONTH_30_PERCENT_DISCOUNT'
                AND fs.start_date >= '2026-01-28 14:00:00'::timestamp
                AND fs.start_date <= '2026-02-10 10:00:00'::timestamp
            THEN 1
            WHEN wat.ab_test_name = 'PAYWALL_FIRST_MONTH_DISCOUNT'
                AND fs.start_date >= '2026-01-01 00:00:00'::timestamp
                AND fs.start_date <= '2026-01-10 23:59:59'::timestamp
            THEN 1
            ELSE 0
        END as is_during_test_period,
        
        -- Days to conversion
        CASE
            WHEN fp.first_payment_date IS NOT NULL
            THEN EXTRACT(DAY FROM (fp.first_payment_date - wat.assigned_at))
            ELSE NULL
        END as days_to_conversion,
        
        -- Test label
        CASE
            WHEN wat.ab_test_name = 'PAYWALL_FIRST_MONTH_30_PERCENT_DISCOUNT' THEN '30% Discount Test'
            WHEN wat.ab_test_name = 'PAYWALL_FIRST_MONTH_DISCOUNT' THEN '10% Discount Test'
            ELSE 'Other'
        END as test_label
        
    FROM workspace_ab_tests wat
    LEFT JOIN first_subscriptions fs ON wat.workspace_id = fs.workspace_id
    LEFT JOIN first_payments fp ON fs.subscription_history_id = fp.subscription_history_id
    LEFT JOIN plans p ON fs.plan_name = p.plan_type
    LEFT JOIN workspace_payments wp ON wat.workspace_id = wp.workspace_id
    LEFT JOIN generation_costs gc ON wat.workspace_id = gc.workspace_id
),

-- Calculate metrics by test and cohort
test_metrics AS (
    SELECT
        test_label,
        ab_test_name,
        cohort,
        
        -- Sample size
        COUNT(*) as total_workspaces,
        
        -- Only count conversions during test period
        SUM(CASE WHEN is_during_test_period = 1 AND converted = 1 THEN 1 ELSE 0 END) as conversions_during_test,
        SUM(CASE WHEN is_during_test_period = 1 AND converted = 1 THEN 1 ELSE 0 END)::numeric / 
            COUNT(*)::numeric as conversion_rate,
        
        -- All conversions (including after test)
        SUM(converted) as total_conversions,
        
        -- Revenue metrics (for those who converted during test)
        SUM(CASE WHEN is_during_test_period = 1 AND converted = 1 THEN first_payment_amount ELSE 0 END) as total_first_payment_revenue,
        AVG(CASE WHEN is_during_test_period = 1 AND converted = 1 THEN first_payment_amount ELSE NULL END) as avg_first_payment,
        
        -- LTV metrics (includes all revenue, even after test)
        SUM(lifetime_value) as total_ltv,
        AVG(lifetime_value) as avg_ltv_per_workspace,
        AVG(CASE WHEN converted = 1 THEN lifetime_value ELSE NULL END) as avg_ltv_per_converted,
        
        -- Profit metrics
        SUM(profit) as total_profit,
        AVG(profit) as avg_profit_per_workspace,
        
        -- Plan distribution (for conversions during test)
        SUM(CASE WHEN is_during_test_period = 1 AND plan_name = 'STARTER' AND billing_interval = 'month' THEN 1 ELSE 0 END) as starter_monthly,
        SUM(CASE WHEN is_during_test_period = 1 AND plan_name = 'BASIC' AND billing_interval = 'month' THEN 1 ELSE 0 END) as creator_monthly,
        SUM(CASE WHEN is_during_test_period = 1 AND plan_name = 'PRO' AND billing_interval = 'month' THEN 1 ELSE 0 END) as pro_monthly,
        SUM(CASE WHEN is_during_test_period = 1 AND billing_interval = 'year' THEN 1 ELSE 0 END) as yearly_plans,
        
        -- Retention
        SUM(has_renewed) as renewed_count,
        SUM(has_renewed)::numeric / NULLIF(SUM(converted), 0)::numeric as renewal_rate,
        
        -- Time to conversion
        AVG(CASE WHEN is_during_test_period = 1 AND converted = 1 THEN days_to_conversion ELSE NULL END) as avg_days_to_conversion
        
    FROM workspace_data
    GROUP BY test_label, ab_test_name, cohort
)

-- Final output with lift calculations
SELECT
    test_label,
    cohort,
    total_workspaces,
    conversions_during_test,
    ROUND(conversion_rate * 100, 2) as conversion_rate_percent,
    ROUND(avg_first_payment, 2) as avg_first_payment,
    ROUND(avg_ltv_per_workspace, 2) as avg_ltv_per_workspace,
    ROUND(avg_ltv_per_converted, 2) as avg_ltv_per_converted,
    ROUND(avg_profit_per_workspace, 2) as avg_profit_per_workspace,
    starter_monthly,
    creator_monthly,
    pro_monthly,
    yearly_plans,
    renewed_count,
    ROUND(renewal_rate * 100, 2) as renewal_rate_percent,
    ROUND(avg_days_to_conversion, 1) as avg_days_to_conversion,
    
    -- Calculate lifts (B vs A)
    ROUND((conversion_rate - LAG(conversion_rate) OVER (PARTITION BY test_label ORDER BY cohort)) / 
        NULLIF(LAG(conversion_rate) OVER (PARTITION BY test_label ORDER BY cohort), 0) * 100, 2) as conversion_lift_percent,
    
    ROUND((avg_ltv_per_workspace - LAG(avg_ltv_per_workspace) OVER (PARTITION BY test_label ORDER BY cohort)) / 
        NULLIF(LAG(avg_ltv_per_workspace) OVER (PARTITION BY test_label ORDER BY cohort), 0) * 100, 2) as ltv_lift_percent,
    
    ROUND((avg_profit_per_workspace - LAG(avg_profit_per_workspace) OVER (PARTITION BY test_label ORDER BY cohort)) / 
        NULLIF(LAG(avg_profit_per_workspace) OVER (PARTITION BY test_label ORDER BY cohort), 0) * 100, 2) as profit_lift_percent

FROM test_metrics
ORDER BY test_label, cohort;
