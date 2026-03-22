{{
    config(
        materialized='view'
    )
}}

select
    id as video_asset_id,
    type as asset_type,
    status,
    "productId" as product_id
from {{ source('arcads_product', 'VideoAssets') }}