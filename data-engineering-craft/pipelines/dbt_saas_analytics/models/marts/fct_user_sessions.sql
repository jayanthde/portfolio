-- CANONICAL FACT. Grain: one row per session_key.
-- Incremental on INGEST time (received_at) + 3-day lookback + merge => idempotent,
-- late-data-safe. DuckDB uses the delete+insert strategy for incremental merges.
{{ config(
    materialized='incremental',
    unique_key='session_key',
    incremental_strategy='delete+insert',
    on_schema_change='append_new_columns'
) }}

with sessionized as (
    select * from {{ ref('int_sessionized_events') }}

    {% if is_incremental() %}
    -- Filter on received_at (monotonic), NOT event_timestamp (client, can be late).
    -- 3-day lookback re-reads recent rows; unique_key makes reprocessing idempotent.
    where received_at >= (
        select coalesce(max(received_at), timestamp '1900-01-01') - interval 3 day
        from {{ this }}
    )
    {% endif %}
),

aggregated as (
    select
        session_key,
        actor_id,
        cast(min(event_timestamp) as date)                        as session_date,
        min(event_timestamp)                                      as session_start_ts,
        max(event_timestamp)                                      as session_end_ts,
        count(*)                                                  as event_count,
        count(*) filter (where event_type = 'page_view')          as page_view_count,
        count(*) filter (where event_type = 'feature_used')       as feature_used_count,
        count(*) filter (where event_type = 'purchase')           as purchase_count,
        sum(revenue_usd)                                          as revenue_usd,
        date_diff('second', min(event_timestamp), max(event_timestamp)) as session_duration_seconds,
        max(received_at)                                          as received_at
    from sessionized
    group by session_key, actor_id
)

select * from aggregated
