-- Singular test: no active subscription should have negative or zero MRR
-- unless it's a free plan (mrr_usd_normalised = 0 is valid for free tier).

select
    subscription_sk,
    user_sk,
    plan_type,
    mrr_usd_normalised
from {{ ref('stg_subscriptions') }}
where is_active            = true
  and plan_type           != 'free'
  and mrr_usd_normalised  <= 0
