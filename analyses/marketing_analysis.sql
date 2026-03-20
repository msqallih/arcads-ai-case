-- Marketing Performance Analysis for A/B Tests
-- Analyzes Meta advertising data during the two paywall discount tests

WITH stg_meta_ads AS (
    SELECT
        "Date"::date as ad_date,
        "Spend (€)"::numeric as spend_eur,
        "Purchases"::integer as purchases,
        "Sign Ups"::integer as sign_ups,
        "Impressions"::integer as impressions,
        "Link Clicks"::integer as link_clicks,
        "CPC (€)"::numeric as cpc_eur,
        "CPM (€)"::numeric as cpm_eur,
        "ROAS"::numeric as roas,
        CASE 
            WHEN "Sign Ups"::integer > 0 
            THEN ("Purchases"::numeric / "Sign Ups"::numeric) * 100
            ELSE 0
        END as conversion_rate_percent
    FROM meta_ads
),

test_period_metrics AS (
    SELECT 
        CASE 
            WHEN ad_date BETWEEN '2026-01-01' AND '2026-01-10' THEN '10% Discount Test'
            WHEN ad_date BETWEEN '2026-01-28' AND '2026-02-10' THEN '30% Discount Test'
            ELSE 'Baseline'
        END as test_period,
        
        -- Date range
        MIN(ad_date) as start_date,
        MAX(ad_date) as end_date,
        COUNT(*) as days,
        
        -- Spend metrics
        SUM(spend_eur) as total_spend,
        AVG(spend_eur) as avg_daily_spend,
        
        -- Volume metrics
        SUM(impressions) as total_impressions,
        SUM(link_clicks) as total_link_clicks,
        SUM(sign_ups) as total_sign_ups,
        SUM(purchases) as total_purchases,
        
        -- Efficiency metrics
        AVG(cpc_eur) as avg_cpc,
        AVG(cpm_eur) as avg_cpm,
        AVG(roas) as avg_roas,
        AVG(conversion_rate_percent) as avg_conversion_rate,
        
        -- Cost metrics
        SUM(spend_eur) / NULLIF(SUM(sign_ups), 0) as cost_per_signup,
        SUM(spend_eur) / NULLIF(SUM(purchases), 0) as cost_per_purchase
        
    FROM stg_meta_ads
    GROUP BY 1
),

final AS (
    SELECT
        test_period,
        start_date,
        end_date,
        days,
        
        -- Spend
        ROUND(total_spend, 2) as total_spend_eur,
        ROUND(avg_daily_spend, 2) as avg_daily_spend_eur,
        
        -- Volume
        total_impressions,
        total_link_clicks,
        total_sign_ups,
        total_purchases,
        
        -- Efficiency
        ROUND(avg_cpc, 2) as avg_cpc_eur,
        ROUND(avg_cpm, 2) as avg_cpm_eur,
        ROUND(avg_roas, 2) as avg_roas,
        ROUND(avg_conversion_rate, 2) as avg_conversion_rate_pct,
        
        -- Costs
        ROUND(cost_per_signup, 2) as cost_per_signup_eur,
        ROUND(cost_per_purchase, 2) as cost_per_purchase_eur,
        
        -- Calculate lift vs baseline
        ROUND(
            (avg_conversion_rate - LAG(avg_conversion_rate) OVER (ORDER BY test_period)) / 
            NULLIF(LAG(avg_conversion_rate) OVER (ORDER BY test_period), 0) * 100, 
            2
        ) as conversion_rate_lift_vs_baseline_pct
        
    FROM test_period_metrics
)

SELECT * FROM final
ORDER BY test_period;
