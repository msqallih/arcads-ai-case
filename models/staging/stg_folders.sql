{{
    config(
        materialized='view'
    )
}}

select
    id as folder_id,
    name as folder_name,
    "productId" as product_id
from {{ source('arcads_product', 'Folders') }}