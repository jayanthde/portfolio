-- Built ON TOP of fct_user_sessions (NOT raw) — proves the layering/conformed-dim payoff.
-- Grain: one row per actor per ISO week.  is_engaged := active_days >= 3.
{{ config(materialized='table') }}

with sessions as (
    select * from {{ ref('fct_user_sessions') }}
)

select
    actor_id,
    date_trunc('week', session_date)                 as week_start,
    count(*)                                          as session_count,
    count(distinct session_date)                      as active_days,
    sum(event_count)                                  as event_count,
    sum(revenue_usd)                                  as revenue_usd,
    (count(distinct session_date) >= 3)               as is_engaged
from sessions
group by actor_id, date_trunc('week', session_date)
