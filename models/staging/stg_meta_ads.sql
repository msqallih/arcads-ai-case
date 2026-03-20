{{
    config(
        materialized='view'
    )
}}

select
    "Date"::date as ad_date,
    "Spend (€)"::numeric as spend_eur,
    "Purchases"::integer as purchases,
    "ROAS"::numeric as roas,
    "Cost per Purchase (€)"::numeric as cost_per_purchase_eur,
    "Purchase Value (€)"::numeric as purchase_value_eur,
    "Sign Ups"::integer as sign_ups,
    "Cost per Sign Up (€)"::numeric as cost_per_sign_up_eur,
    "Link Clicks"::integer as link_clicks,
    "CPC (€)"::numeric as cpc_eur,
    "CPM (€)"::numeric as cpm_eur,
    "Impressions"::integer as impressions,
    
    -- Calculate CTR (Click-Through Rate)
    case 
        when "Impressions"::integer > 0 
        then ("Link Clicks"::numeric / "Impressions"::numeric) * 100
        else 0
    end as ctr_percent,
    
    -- Calculate conversion rate (Purchases / Sign Ups)
    case 
        when "Sign Ups"::integer > 0 
        then ("Purchases"::numeric / "Sign Ups"::numeric) * 100
        else 0
    end as conversion_rate_percent
    
from {{ ref('meta_ads') }}
