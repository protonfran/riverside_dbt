{{
    config(
        materialized = 'table',
        tags = ['gold', 'dim']
    )
}}

/*
  DIM_USER  —  SCD Type 1
  Full table rebuild on each dbt run.
  Any attribute change in Silver overwrites the Gold row (no history kept).
  If Type 2 history is needed later, add a snapshot on stg_users instead.
*/

with users as (

    select * from {{ ref('stg_users') }}

),

active_subscriptions as (

    -- Latest active subscription per user
    select *
    from (
        select
            *,
            row_number() over (
                partition by user_sk
                order by     start_date desc
            ) as _row_num
        from {{ ref('stg_subscriptions') }}
        where is_active = true
    )
    where _row_num = 1

),

final as (

    select
        u.user_sk,
        u.user_nk,
        u.email,
        u.display_name,
        u.plan_type,
        u.plan_status,
        u.country_code,

        -- Enriched tier attribute
        case u.plan_type
            when 'enterprise' then 'Tier 1'
            when 'business'   then 'Tier 2'
            when 'pro'        then 'Tier 3'
            when 'standard'   then 'Tier 4'
            else                   'Free'
        end                                         as plan_tier,

        u.created_at,
        u.updated_at,

        -- Active subscription details (denormalised for BI convenience)
        s.plan_type                                 as active_plan_type,
        s.mrr_usd_normalised                        as current_mrr_usd,
        s.billing_cycle                             as active_billing_cycle,

        current_timestamp()                         as dwh_updated_at

    from users u
    left join active_subscriptions s
           on u.user_sk = s.user_sk

)

select * from final
