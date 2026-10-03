-- Canonical conformed dimension. Built on the SCD2 snapshot so a fact can be
-- attributed to the plan a user was on AT event time (not their plan today).
{{ config(materialized='table') }}

with scd as (
    select * from {{ ref('users_snapshot') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['user_id', 'dbt_valid_from']) }} as user_key,
    user_id,                               -- business key
    plan_tier,
    is_active,
    region,
    dbt_valid_from  as valid_from,
    dbt_valid_to    as valid_to,
    (dbt_valid_to is null) as is_current
from scd
