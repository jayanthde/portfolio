{{ config(materialized='view') }}

select
    user_id,
    plan_tier,
    cast(is_active as boolean) as is_active,
    region,
    cast(updated_at as timestamp) as updated_at
from {{ source('app_events', 'raw_app_users') }}
