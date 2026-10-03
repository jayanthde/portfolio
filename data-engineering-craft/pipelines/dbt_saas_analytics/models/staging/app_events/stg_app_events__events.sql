-- Staging = 1:1 with the source: rename, cast, DEDUPE, coalesce identity.
-- No joins, no business logic. This is the clean interface the rest of the repo trusts.
{{ config(materialized='view') }}

with source as (
    select * from {{ source('app_events', 'raw_app_events') }}
),

deduped as (
    -- at-least-once delivery => duplicate event_ids are normal. Keep earliest-received.
    select
        *,
        row_number() over (partition by event_id order by received_at) as _rn
    from source
    where event_id is not null
)

select
    event_id,
    event_type,
    coalesce(user_id, anonymous_id)                       as actor_id,
    user_id,
    anonymous_id,
    cast(event_timestamp as timestamp)                    as event_timestamp,
    cast(received_at     as timestamp)                    as received_at,
    coalesce(json_extract_string(properties, '$.plan_tier'), 'unknown') as plan_tier_at_event,
    coalesce(cast(json_extract_string(properties, '$.revenue') as decimal(18,2)), 0) as revenue_usd
from deduped
where _rn = 1
