-- User Engagement Analysis for 30% Discount Test
-- Analyzing content generation costs and activity patterns

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
        "workspaceId"::uuid as workspace_id,
        "startDate" as start_date,
        ROW_NUMBER() OVER (PARTITION BY "workspaceId" ORDER BY "startDate") as rn
    FROM "StripeSubscriptionHistories"
),

first_subscriptions AS (
    SELECT workspace_id
    FROM subscription_histories
    WHERE rn = 1
        AND start_date >= '2026-01-28 14:00:00'::timestamp
        AND start_date <= '2026-02-10 10:00:00'::timestamp
),

-- Sum generation costs and count events
cost_totals AS (
    SELECT
        "workspaceId" as workspace_id,
        SUM(value) as total_cost,
        COUNT(*) as generation_count
    FROM "Costs"
    GROUP BY "workspaceId"
),

-- Credit consumption
credit_events AS (
    SELECT
        "workspaceId" as workspace_id,
        SUM(CASE WHEN "creditsCost" > 0 THEN "creditsCost" ELSE 0 END) as credits_consumed,
        SUM(CASE WHEN "creditsCost" < 0 THEN ABS("creditsCost") ELSE 0 END) as credits_refunded,
        SUM(generations) as total_generations_tracked,
        COUNT(*) as credit_event_count
    FROM "CreditsConsumptionEvents"
    GROUP BY "workspaceId"
),

-- Get workspace current state
workspace_state AS (
    SELECT
        id as workspace_id,
        "totalCredits" as total_credits,
        "usedCredits" as used_credits
    FROM "Workspaces"
),

combined_engagement AS (
    SELECT
        wat.cohort,
        CASE WHEN fs.workspace_id IS NOT NULL THEN 1 ELSE 0 END as converted,
        COALESCE(ct.generation_count, 0) as cost_tracked_generations,
        COALESCE(ce.total_generations_tracked, 0) as credit_tracked_generations,
        COALESCE(ct.total_cost, 0) as generation_cost,
        COALESCE(ce.credits_consumed, 0) as credits_used,
        COALESCE(ce.credits_refunded, 0) as credits_refunded,
        COALESCE(ws.total_credits, 0) as total_credits_allocated,
        COALESCE(ws.used_credits, 0) as credits_currently_used,
        CASE WHEN COALESCE(ct.generation_count, 0) > 0 OR COALESCE(ce.total_generations_tracked, 0) > 0 THEN 1 ELSE 0 END as has_generated
    FROM workspace_ab_tests wat
    LEFT JOIN first_subscriptions fs ON wat.workspace_id = fs.workspace_id
    LEFT JOIN cost_totals ct ON wat.workspace_id = ct.workspace_id
    LEFT JOIN credit_events ce ON wat.workspace_id = ce.workspace_id
    LEFT JOIN workspace_state ws ON wat.workspace_id = ws.workspace_id
)

SELECT
    cohort,
    converted,
    COUNT(*) as workspace_count,
    
    -- Generation metrics
    SUM(has_generated) as workspaces_with_activity,
    ROUND(SUM(has_generated)::numeric / COUNT(*)::numeric * 100, 2) as pct_with_activity,
    
    ROUND(AVG(cost_tracked_generations), 2) as avg_cost_tracked_gens,
    ROUND(AVG(credit_tracked_generations), 2) as avg_credit_tracked_gens,
    ROUND(AVG(CASE WHEN has_generated = 1 THEN cost_tracked_generations ELSE NULL END), 2) as avg_cost_gens_if_active,
    
    SUM(cost_tracked_generations) as total_cost_tracked_gens,
    SUM(credit_tracked_generations) as total_credit_tracked_gens,
    
    -- Cost metrics
    ROUND(AVG(generation_cost), 4) as avg_cost_per_workspace,
    ROUND(SUM(generation_cost), 2) as total_generation_cost,
    
    -- Credit metrics
    ROUND(AVG(credits_used), 2) as avg_credits_consumed,
    ROUND(AVG(credits_refunded), 2) as avg_credits_refunded,
    ROUND(AVG(total_credits_allocated)::numeric, 2) as avg_credits_allocated,
    ROUND(AVG(credits_currently_used)::numeric, 2) as avg_credits_in_use
    
FROM combined_engagement
GROUP BY cohort, converted
ORDER BY cohort, converted;
