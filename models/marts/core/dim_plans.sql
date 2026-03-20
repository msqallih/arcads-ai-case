{{
    config(
        materialized='table'
    )
}}

-- Dimension table for plans
with plans as (
    select * from {{ ref('stg_plans') }}
),

final as (
    select
        plan_id,
        plan_name,
        plan_type,
        is_pro,
        plan_credits,
        plan_price,
        plan_interval,
        
        -- Add calculated fields
        case 
            when plan_name = 'BASIC' then 'CREATOR'
            else plan_name
        end as plan_display_name,
        
        case
            when plan_interval = 'month' then plan_price
            when plan_interval = 'year' then plan_price / 12.0
            else null
        end as monthly_equivalent_price
        
    from plans
)

select * from final
