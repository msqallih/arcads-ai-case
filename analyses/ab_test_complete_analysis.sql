-- Complete AB test analysis (for read only purposes, not materialized)
-- This query includes all logic from staging → intermediate → marts → analysis

-- Staging layer: source data transformations

WITH stg_workspaces AS (
    SELECT
        id::text AS workspace_id,
        "userId" AS user_id,
        plan, -- selected plan
        "stripeEndCurrentPeriod" AS stripe_end_current_period, -- stripe subscription end of current period (1 month later if the user a selected a monthly plan)
        "totalCredits" AS total_credits, -- plan's credits (10 for a Starter, 20 for a Basic)
        "usedCredits" AS used_credits
    FROM "Workspaces"
),

stg_workspaces_ab_tests AS (
    SELECT
        id as workspace_ab_test_id,
        "workspaceId"::text as workspace_id,
        feature as ab_test_name,
        cohort,
        "createdAt" as assigned_at
    FROM "WorkspacesABTests"
    WHERE (
        -- Test 1: 10% Discount - January 1-10, 2026 (10 days as per assignment)
        (feature = 'PAYWALL_FIRST_MONTH_DISCOUNT'
         AND "createdAt" >= '2026-01-01 00:00:00'::timestamp
         AND "createdAt" <= '2026-01-10 23:59:59'::timestamp)
        OR
        -- Test 2: 30% Discount - January 28 (3 PM) to February 10 (10 AM), 2026
        (feature = 'PAYWALL_FIRST_MONTH_30_PERCENT_DISCOUNT'
         AND "createdAt" >= '2026-01-28 15:00:00'::timestamp
         AND "createdAt" <= '2026-02-10 10:00:00'::timestamp)
    )
),

stg_plans AS (
    SELECT
        type AS plan_type,
        credits AS plan_credits,
        "isPro" AS is_pro
    FROM "Plans"
),

stg_stripe_subscription_histories AS (
    SELECT
        id AS subscription_history_id,
        "workspaceId"::text AS workspace_id,
        plan,
        "startDate" AS start_date,
        "endDate" AS end_date,
        interval AS billing_interval,
        "intervalCount" AS billing_interval_count,
        "createdAt" AS created_at
    FROM "StripeSubscriptionHistories"
),

stg_stripe_payment_histories AS (
    SELECT
        id AS payment_id,
        "stripeSubscriptionHistoryId" AS subscription_history_id,
        "eurAmount" AS eur_amount,
        "eurRefundedAmount" AS eur_refunded_amount,
        date AS payment_date,
        type AS payment_type,
        CASE WHEN "eurRefundedAmount" > 0 THEN true ELSE false END AS is_refunded
    FROM "StripePaymentHistories"
),

stg_credits_consumption_events AS (
    SELECT
        id AS event_id,
        "workspaceId"::text AS workspace_id,
        "creditsCost" AS credit_cost,
        "createdAt" AS consumed_at
    FROM "CreditsConsumptionEvents"
),

stg_videos AS (
    SELECT
        id AS video_id,
        "scriptId" AS script_id,
        "videoStatus" AS video_status
    FROM "Videos"
),

stg_video_assets AS (
    SELECT
        id AS video_asset_id,
        type AS asset_type,
        status,
        "productId" AS product_id
    FROM "VideoAssets"
),

stg_costs AS (
    SELECT
        id AS cost_id,
        type,
        "entityId" AS entity_id,
        "workspaceId"::text AS workspace_id,
        value
    FROM "Costs"
),

stg_products AS (
    SELECT
        id,
        "workspaceId"::text AS workspace_id
    FROM "Products"
),

stg_folders AS (
    SELECT
        id AS folder_id,
        name AS folder_name,
        "productId" AS product_id
    FROM "Folders"
),

stg_projects AS (
    SELECT
        id,
        name,
        "folderId" AS folder_id
    FROM "Projects"
),

stg_scripts AS (
    SELECT
        id,
        name,
        "projectId" AS project_id
    FROM "Scripts"
),

-- Meta Ads data for CAC calculation
stg_meta_ads AS (
    SELECT
        "Date" as ad_date,
        "Spend (€)" as spend_eur,
        "Purchases" as purchases,
        "Sign Ups" as sign_ups,
        "Cost per Sign Up (€)" as cost_per_sign_up_eur,
        "Cost per Purchase (€)" as cost_per_purchase_eur
    FROM meta_ads
),

-- Intermediate layer: business logic transformations

-- Calculate test period boundaries for each AB test
-- Define exact test periods based on actual test dates
test_periods AS (
    SELECT 
        'PAYWALL_FIRST_MONTH_DISCOUNT' AS ab_test_name,
        '2026-01-01'::timestamp AS test_start_date,
        '2026-01-10'::timestamp AS test_end_date,
        10 AS test_duration_days
    UNION ALL
    SELECT 
        'PAYWALL_FIRST_MONTH_30_PERCENT_DISCOUNT' AS ab_test_name,
        '2026-01-28 15:00:00'::timestamp AS test_start_date,  -- 3:00 PM Paris time
        '2026-02-10 10:00:00'::timestamp AS test_end_date,    -- 10:00 AM Paris time
        14 AS test_duration_days
),

-- Calculate CAC from Meta Ads data
-- We'll aggregate by test period to get average CAC during each test
cac_by_period AS (
    SELECT
        tp.ab_test_name,
        tp.test_start_date,
        tp.test_end_date,
        tp.test_duration_days,
        SUM(ma.spend_eur) AS total_ad_spend,
        SUM(ma.sign_ups) AS total_sign_ups,
        SUM(ma.purchases) AS total_purchases,
        -- CAC = Total Spend / Total Sign Ups
        CASE 
            WHEN SUM(ma.sign_ups) > 0 
            THEN SUM(ma.spend_eur) / SUM(ma.sign_ups)
            ELSE 0 
        END AS cac_per_signup,
        -- Cost per Purchase from ads
        CASE 
            WHEN SUM(ma.purchases) > 0 
            THEN SUM(ma.spend_eur) / SUM(ma.purchases)
            ELSE 0 
        END AS cac_per_purchase
    FROM test_periods tp
    LEFT JOIN stg_meta_ads ma 
        ON ma.ad_date BETWEEN tp.test_start_date AND tp.test_end_date
    GROUP BY tp.ab_test_name, tp.test_start_date, tp.test_end_date, tp.test_duration_days
),

-- int_first_subscriptions logic
first_subscriptions_base AS (
    SELECT
        sh.workspace_id,
        sh.subscription_history_id,
        sh.plan,
        sh.billing_interval,
        sh.billing_interval_count,
        sh.start_date,
        sh.end_date,
        sh.start_date AS first_subscription_at,
        ROW_NUMBER() OVER (PARTITION BY sh.workspace_id ORDER BY sh.start_date) AS rn
    FROM stg_stripe_subscription_histories sh
),

first_sub_only AS (
    SELECT *
    FROM first_subscriptions_base
    WHERE rn = 1
),

-- Track ALL subscriptions for churn analysis
all_subscriptions AS (
    SELECT
        sh.workspace_id,
        sh.subscription_history_id,
        sh.plan,
        sh.billing_interval,
        sh.start_date,
        sh.end_date,
        ROW_NUMBER() OVER (PARTITION BY sh.workspace_id ORDER BY sh.start_date) AS subscription_number,
        COUNT(*) OVER (PARTITION BY sh.workspace_id) AS total_subscription_count
    FROM stg_stripe_subscription_histories sh
),

-- Identify churned workspaces (those who had a subscription but it ended)
churn_analysis AS (
    SELECT
        workspace_id,
        MAX(end_date) AS last_subscription_end_date,
        MIN(start_date) AS first_subscription_start_date,
        COUNT(*) AS total_subscriptions,
        -- Churned if last subscription ended and no active subscription
        CASE 
            WHEN MAX(end_date) < CURRENT_DATE THEN TRUE
            ELSE FALSE
        END AS is_churned,
        -- Churned after first month discount
        CASE 
            WHEN COUNT(*) = 1 AND MAX(end_date) < CURRENT_DATE THEN TRUE
            ELSE FALSE
        END AS churned_after_first_subscription,
        -- Calculate lifetime in days (extract days from interval)
        EXTRACT(DAY FROM (MAX(end_date) - MIN(start_date)))::integer AS subscription_lifetime_days
    FROM all_subscriptions
    GROUP BY workspace_id
),

first_payments_base AS (
    SELECT
        ph.subscription_history_id,
        ph.eur_amount AS first_payment_amount,
        ph.payment_date AS first_payment_date,
        ROW_NUMBER() OVER (PARTITION BY ph.subscription_history_id ORDER BY ph.payment_date) AS rn
    FROM stg_stripe_payment_histories ph
    WHERE ph.payment_type = 'plan'
),

first_payment_only AS (
    SELECT
        subscription_history_id,
        first_payment_amount,
        first_payment_date
    FROM first_payments_base
    WHERE rn = 1
),

int_first_subscriptions AS (
    SELECT
        fs.workspace_id,
        fs.subscription_history_id,
        fs.plan AS plan_id,
        fs.plan AS plan_name,
        pl.plan_type,
        fs.billing_interval,
        fs.start_date AS subscription_start_date,
        fs.first_subscription_at,
        fp.first_payment_amount,
        fp.first_payment_date
    FROM first_sub_only fs
    LEFT JOIN stg_plans pl ON fs.plan = pl.plan_type
    LEFT JOIN first_payment_only fp ON fs.subscription_history_id = fp.subscription_history_id
),

-- int_workspace_metrics logic
-- First, we need to calculate revenue ONLY for payments made during/after AB test assignment
-- This requires joining with AB test data first
workspace_ab_test_payments AS (
    SELECT
        wat.workspace_id,
        wat.ab_test_name,
        wat.assigned_at,
        ph.payment_date,
        ph.payment_type,
        ph.eur_amount,
        ph.eur_refunded_amount,
        ph.is_refunded
    FROM stg_workspaces_ab_tests wat
    INNER JOIN stg_stripe_subscription_histories sh ON wat.workspace_id = sh.workspace_id
    INNER JOIN stg_stripe_payment_histories ph ON sh.subscription_history_id = ph.subscription_history_id
    -- CRITICAL: Only count payments made during or after AB test assignment
    WHERE ph.payment_date >= wat.assigned_at
),

payment_aggregations AS (
    SELECT
        workspace_id,
        COUNT(*) AS total_payments,
        SUM(CASE WHEN payment_type = 'plan' THEN eur_amount ELSE 0 END) AS total_plan_revenue,
        SUM(CASE WHEN payment_type = 'additional_credits' THEN eur_amount ELSE 0 END) AS total_additional_credits_revenue,
        -- Total revenue = payments - refunds (only for payments after AB test assignment)
        SUM(eur_amount) - SUM(CASE WHEN is_refunded THEN eur_refunded_amount ELSE 0 END) AS total_revenue,
        SUM(CASE WHEN is_refunded THEN eur_refunded_amount ELSE 0 END) AS total_refunded,
        MIN(payment_date) AS first_payment_date,
        MAX(payment_date) AS last_payment_date
    FROM workspace_ab_test_payments
    GROUP BY workspace_id
),

credit_aggregations AS (
    SELECT
        workspace_id,
        SUM(credit_cost) AS total_credits_consumed
    FROM stg_credits_consumption_events
    GROUP BY workspace_id
),

-- Video and asset aggregations (joined through products)
video_aggregations AS (
    SELECT
        p.workspace_id,
        COUNT(DISTINCT v.video_id) AS total_videos_v1,
        COUNT(DISTINCT va.video_asset_id) AS total_assets
    FROM stg_products p
    LEFT JOIN stg_folders f ON p.id = f.product_id
    LEFT JOIN stg_projects proj ON f.folder_id = proj.folder_id
    LEFT JOIN stg_scripts s ON proj.id = s.project_id
    LEFT JOIN stg_videos v ON s.id = v.script_id
    LEFT JOIN stg_video_assets va ON p.id = va.product_id
    GROUP BY p.workspace_id
),

-- Use credits consumed as a proxy for generation activity
-- Actual generation costs can be calculated from credits * cost_per_credit if needed
int_workspace_metrics AS (
    SELECT
        w.workspace_id,
        w.user_id,
        w.plan,
        COALESCE(pa.total_plan_revenue, 0) AS total_plan_revenue,
        COALESCE(pa.total_additional_credits_revenue, 0) AS total_additional_credits_revenue,
        COALESCE(pa.total_revenue, 0) AS total_revenue,
        pa.first_payment_date,
        pa.last_payment_date,
        COALESCE(ca.total_credits_consumed, 0) AS total_credits_consumed,
        COALESCE(pa.total_refunded, 0) AS total_credits_refunded,
        COALESCE(va.total_videos_v1, 0) AS total_videos_v1,
        COALESCE(va.total_assets, 0) AS total_assets,
        COALESCE(va.total_videos_v1, 0) + COALESCE(va.total_assets, 0) AS total_generations,
        -- Use credits consumed as proxy for cost (can multiply by avg cost per credit if known)
        COALESCE(ca.total_credits_consumed, 0) * 0.01 AS total_generation_cost,
        CASE WHEN pa.total_revenue > 0 THEN true ELSE false END AS has_revenue,
        CASE WHEN ca.total_credits_consumed > 0 THEN true ELSE false END AS has_consumed_credits,
        CASE WHEN ca.total_credits_consumed > 0 THEN true ELSE false END AS has_generated_content,
        COALESCE(pa.total_payments, 0) AS total_payments
    FROM stg_workspaces w
    LEFT JOIN payment_aggregations pa ON w.workspace_id = pa.workspace_id
    LEFT JOIN credit_aggregations ca ON w.workspace_id = ca.workspace_id
    LEFT JOIN video_aggregations va ON w.workspace_id = va.workspace_id
),

-- Marts layer: fct_ab_test_paywall logic

fct_ab_test_paywall AS (
    SELECT
        fs.workspace_id,
        fs.ab_test_name,
        fs.cohort,
        fs.ab_test_assigned_at,
        fs.subscription_history_id,
        fs.plan_id,
        fs.plan_name,
        fs.plan_type,
        fs.billing_interval,
        fs.subscription_start_date,
        fs.first_subscription_at,
        fs.first_payment_amount,
        fs.first_payment_date,
        fs.is_during_test_period,
        
        -- Add workspace metrics
        wm.total_revenue,
        wm.total_plan_revenue,
        wm.total_additional_credits_revenue,
        wm.total_payments,
        wm.last_payment_date,
        wm.total_credits_consumed,
        wm.total_credits_refunded,
        wm.total_videos_v1,
        wm.total_assets,
        wm.total_generations,
        wm.total_generation_cost,
        wm.has_revenue,
        wm.has_consumed_credits,
        wm.has_generated_content,
        
        -- Add churn metrics
        ca.is_churned,
        ca.churned_after_first_subscription,
        ca.total_subscriptions,
        ca.subscription_lifetime_days,
        ca.last_subscription_end_date,
        
        -- Add CAC metrics
        cac.cac_per_signup,
        cac.cac_per_purchase,
        cac.test_duration_days,
        
        -- Calculate profit with CAC
        wm.total_revenue - wm.total_generation_cost - COALESCE(cac.cac_per_signup, 0) AS profit_with_cac,
        
        -- Days since test assignment
        CURRENT_DATE - fs.ab_test_assigned_at::date AS days_since_test_assignment
        
    FROM (
        SELECT
            wat.workspace_id,
            wat.ab_test_name,
            wat.cohort,
            wat.assigned_at AS ab_test_assigned_at,
            ifs.subscription_history_id,
            ifs.plan_id,
            ifs.plan_name,
            ifs.plan_type,
            ifs.billing_interval,
            ifs.subscription_start_date,
            ifs.first_subscription_at,
            ifs.first_payment_amount,
            ifs.first_payment_date,
            CASE 
                -- 10% Discount Test: January 1-10, 2026
                WHEN wat.ab_test_name = 'PAYWALL_FIRST_MONTH_DISCOUNT'
                    AND ifs.first_subscription_at >= '2026-01-01'::timestamp
                    AND ifs.first_subscription_at <= '2026-01-10 23:59:59'::timestamp
                THEN true
                -- 30% Discount Test: January 28 (3 PM) to February 10 (10 AM), 2026
                WHEN wat.ab_test_name = 'PAYWALL_FIRST_MONTH_30_PERCENT_DISCOUNT'
                    AND ifs.first_subscription_at >= '2026-01-28 15:00:00'::timestamp
                    AND ifs.first_subscription_at <= '2026-02-10 10:00:00'::timestamp
                THEN true
                ELSE false 
            END AS is_during_test_period
        FROM stg_workspaces_ab_tests wat
        LEFT JOIN int_first_subscriptions ifs ON wat.workspace_id = ifs.workspace_id
    ) fs
    LEFT JOIN int_workspace_metrics wm ON fs.workspace_id = wm.workspace_id
    LEFT JOIN churn_analysis ca ON fs.workspace_id = ca.workspace_id
    LEFT JOIN cac_by_period cac ON fs.ab_test_name = cac.ab_test_name
),

-- Analysis layer: final AB test comparison

test_metrics AS (
    SELECT
        ab_test_name,
        cohort,
        
        -- Test duration normalization factor
        MAX(test_duration_days) AS test_duration_days,
        
        -- Basic counts
        COUNT(DISTINCT workspace_id) AS total_workspaces,
        COUNT(DISTINCT CASE WHEN subscription_history_id IS NOT NULL THEN workspace_id END) AS converted_workspaces,
        
        -- Conversion rate
        ROUND(
            100.0 * COUNT(DISTINCT CASE WHEN subscription_history_id IS NOT NULL THEN workspace_id END) / 
            NULLIF(COUNT(DISTINCT workspace_id), 0), 
            2
        ) AS conversion_rate_percent,
        
        -- Revenue metrics
        SUM(total_revenue) AS total_revenue,
        SUM(total_plan_revenue) AS total_plan_revenue,
        SUM(total_additional_credits_revenue) AS total_additional_credits_revenue,
        ROUND(AVG(CASE WHEN total_revenue > 0 THEN total_revenue END), 2) AS avg_revenue_per_paying_customer,
        ROUND(SUM(total_revenue) / NULLIF(COUNT(DISTINCT workspace_id), 0), 2) AS revenue_per_workspace,
        
        -- First payment metrics
        ROUND(AVG(first_payment_amount), 2) AS avg_first_payment,
        
        -- Generation metrics
        SUM(total_generations) AS total_generations,
        SUM(total_credits_consumed) AS total_credits_consumed,
        ROUND(AVG(CASE WHEN has_generated_content THEN total_generations END), 2) AS avg_generations_per_active_user,
        
        -- Cost metrics
        SUM(total_generation_cost) AS total_generation_cost,
        
        -- CAC metrics (average across all workspaces in cohort)
        AVG(cac_per_signup) AS avg_cac_per_signup,
        AVG(cac_per_purchase) AS avg_cac_per_purchase,
        SUM(cac_per_signup) AS total_cac_cost,
        
        -- Meta Ads spend (total spend during test period)
        MAX(COALESCE((SELECT total_ad_spend FROM cac_by_period WHERE cac_by_period.ab_test_name = fct_ab_test_paywall.ab_test_name), 0)) AS total_meta_ads_spend,
        
        -- Profit metrics WITH CAC
        SUM(total_revenue - total_generation_cost - COALESCE(cac_per_signup, 0)) AS total_profit_with_cac,
        ROUND(
            AVG(CASE WHEN has_revenue THEN total_revenue - total_generation_cost - COALESCE(cac_per_signup, 0) END), 
            2
        ) AS avg_profit_per_paying_customer_with_cac,
        ROUND(
            SUM(total_revenue - total_generation_cost - COALESCE(cac_per_signup, 0)) / NULLIF(COUNT(DISTINCT workspace_id), 0), 
            2
        ) AS profit_per_workspace_with_cac,
        
        -- Churn metrics
        COUNT(DISTINCT CASE WHEN is_churned THEN workspace_id END) AS churned_workspaces,
        COUNT(DISTINCT CASE WHEN churned_after_first_subscription THEN workspace_id END) AS churned_after_first_month,
        ROUND(
            100.0 * COUNT(DISTINCT CASE WHEN is_churned THEN workspace_id END) / 
            NULLIF(COUNT(DISTINCT CASE WHEN subscription_history_id IS NOT NULL THEN workspace_id END), 0),
            2
        ) AS churn_rate_percent,
        ROUND(
            100.0 * COUNT(DISTINCT CASE WHEN churned_after_first_subscription THEN workspace_id END) / 
            NULLIF(COUNT(DISTINCT CASE WHEN subscription_history_id IS NOT NULL THEN workspace_id END), 0),
            2
        ) AS first_month_churn_rate_percent,
        
        -- Average subscription lifetime
        ROUND(AVG(CASE WHEN subscription_history_id IS NOT NULL THEN subscription_lifetime_days END), 1) AS avg_subscription_lifetime_days
        
    FROM fct_ab_test_paywall
    GROUP BY ab_test_name, cohort
),

-- Calculate lift metrics by comparing Cohort B vs Cohort A
test_comparison AS (
    SELECT
        ab_test_name,
        
        -- Conversion lift
        conversion_rate_percent - LAG(conversion_rate_percent) OVER (PARTITION BY ab_test_name ORDER BY cohort) AS conversion_lift_pct,
        
        -- Revenue lift
        ROUND(
            100.0 * (revenue_per_workspace - LAG(revenue_per_workspace) OVER (PARTITION BY ab_test_name ORDER BY cohort)) / 
            NULLIF(LAG(revenue_per_workspace) OVER (PARTITION BY ab_test_name ORDER BY cohort), 0),
            2
        ) AS revenue_lift_percent,
        
        -- Profit lift (with CAC included)
        ROUND(
            100.0 * (profit_per_workspace_with_cac - LAG(profit_per_workspace_with_cac) OVER (PARTITION BY ab_test_name ORDER BY cohort)) / 
            NULLIF(LAG(profit_per_workspace_with_cac) OVER (PARTITION BY ab_test_name ORDER BY cohort), 0),
            2
        ) AS profit_lift_percent
        
    FROM test_metrics
)

-- Final output with key metrics: CAC, LTV, Conversion, Churn
SELECT
    tm.ab_test_name,
    tm.cohort,
    tm.test_duration_days,
    
    -- Volume & Conversion
    tm.total_workspaces,
    tm.converted_workspaces,
    tm.conversion_rate_percent,
    
    -- Revenue & LTV
    ROUND(tm.total_revenue, 2) AS total_revenue,
    ROUND(tm.avg_first_payment, 2) AS avg_first_payment,
    ROUND(tm.revenue_per_workspace, 2) AS ltv_per_workspace,  -- Total revenue from ALL payments (to date)
    
    -- CAC (Customer Acquisition Cost)
    ROUND(tm.avg_cac_per_signup, 2) AS cac_per_signup,
    ROUND(tm.total_cac_cost, 2) AS total_cac_cost,
    ROUND(tm.total_meta_ads_spend, 2) AS total_meta_ads_spend,
    
    -- Profit (Revenue - Generation Costs - CAC)
    ROUND(tm.total_profit_with_cac, 2) AS total_profit,
    ROUND(tm.profit_per_workspace_with_cac, 2) AS profit_per_workspace,
    
    -- LTV/CAC Ratio (key metric for unit economics)
    -- Note: This is LTV to date, not projected lifetime value
    ROUND(
        tm.revenue_per_workspace / NULLIF(tm.avg_cac_per_signup, 0),
        2
    ) AS ltv_to_cac_ratio,
    
    -- Churn & Retention
    tm.churned_workspaces,
    tm.churned_after_first_month,
    ROUND(tm.churn_rate_percent, 2) AS churn_rate_percent,
    ROUND(tm.first_month_churn_rate_percent, 2) AS first_month_churn_rate_percent,
    ROUND(tm.avg_subscription_lifetime_days, 1) AS avg_subscription_lifetime_days,
    
    -- Engagement
    tm.total_generations,
    ROUND(tm.avg_generations_per_active_user, 1) AS avg_generations_per_active_user,
    
    -- Lift Metrics (Cohort B vs Cohort A)
    ROUND(tc.conversion_lift_pct, 2) AS conversion_lift_pct,
    ROUND(tc.revenue_lift_percent, 2) AS ltv_lift_percent,
    ROUND(tc.profit_lift_percent, 2) AS profit_lift_percent
    
FROM test_metrics tm
LEFT JOIN test_comparison tc ON tm.ab_test_name = tc.ab_test_name
ORDER BY tm.ab_test_name, tm.cohort
