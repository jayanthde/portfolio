-- BLOCK-severity reconciliation: session purchase_count must sum back to the
-- raw purchase-event count. Returns rows => FAIL. This is the test that catches
-- systematic errors (dedupe/timezone/sessionization) that leave everything else green.
with sess as (
    select coalesce(sum(purchase_count), 0) as n from {{ ref('fct_user_sessions') }}
),
raw_purchases as (
    select count(*) as n from {{ ref('stg_app_events__events') }}
    where event_type = 'purchase'
)
select sess.n as sessions_n, raw_purchases.n as raw_n
from sess, raw_purchases
where sess.n <> raw_purchases.n
