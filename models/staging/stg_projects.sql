{{
    config(
        materialized='view'
    )
}}

select
    id,
    name,
    "folderId" as folder_id
from {{ source('arcads_product', 'Projects') }}