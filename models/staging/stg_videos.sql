{{
    config(
        materialized='view'
    )
}}

select
    id as video_id,
   "scriptId" as script_id,
    "videoStatus" as video_status
from {{ source('arcads_product', 'Videos') }}
