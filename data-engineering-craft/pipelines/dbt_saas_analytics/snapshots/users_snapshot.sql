{% snapshot users_snapshot %}
{{
  config(
    target_schema='snapshots',
    unique_key='user_id',
    strategy='check',
    check_cols=['plan_tier', 'is_active', 'region']
  )
}}
select user_id, plan_tier, is_active, region, updated_at
from {{ ref('stg_app_events__users') }}
{% endsnapshot %}
