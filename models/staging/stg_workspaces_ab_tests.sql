{{
    config(
        materialized='view'
    )
}}

select
    id as workspace_ab_test_id,
    "workspaceId" as workspace_id,
    feature as ab_test_name,
    cohort
from {{ source('arcads_product', 'WorkspacesABTests') }}
