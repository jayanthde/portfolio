-- The hard logic lives ONCE here (ephemeral), so marts stay readable and DRY.
-- Rule (a CONTRACT, see /docs): a new session starts when the gap between an
-- actor's consecutive events exceeds 30 minutes.
{{ config(materialized='ephemeral') }}

with events as (
    select * from {{ ref('stg_app_events__events') }}
),

flagged as (
    select
        *,
        date_diff(
            'minute',
            lag(event_timestamp) over (partition by actor_id order by event_timestamp),
            event_timestamp
        ) as mins_since_prev
    from events
),

sessionized as (
    select
        *,
        sum(case when mins_since_prev is null or mins_since_prev > 30 then 1 else 0 end)
            over (partition by actor_id order by event_timestamp
                  rows between unbounded preceding and current row) as session_seq
    from flagged
)

select
    {{ dbt_utils.generate_surrogate_key(['actor_id', 'session_seq']) }} as session_key,
    actor_id,
    event_type,
    event_timestamp,
    received_at,
    plan_tier_at_event,
    revenue_usd
from sessionized
