{{
    config(
        materialized='view'
    )
}}

select
    id as video_asset_id,
    type as asset_type,
    "productId" as product_id,
    status
from {{ source('arcads_product', 'VideoAssets') }}
