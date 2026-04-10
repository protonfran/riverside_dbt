{{
    config(
        materialized = 'view',
        tags = ['gold', 'semantic', 'kpi']
    )
}}

/*
  KPI: Churned users (last 90 days)
  Answers: Who cancelled recently, what plan did they have, and how much MRR did we lose?
*/

with subscriptions as (

    select * from {{ ref('stg_subscriptions') }}

),

users as (

    select * from {{ ref('dim_user') }}

),

engagement as (

    select * from {{ ref('kpi_user_engagement') }}

),

final as (

    select
        u.user_sk,
        u.email,
        u.display_name,
        u.plan_tier,
        u.country_code,

        s.plan_type                                         as churned_plan,
        s.mrr_usd_normalised                               as lost_mrr_usd,
        s.end_date                                         as churn_date,
        s.cancellation_reason,
        datediff('day', s.end_date, current_date())         as days_since_churn,

        coalesce(e.lifetime_sessions, 0)                    as lifetime_sessions,
        coalesce(e.total_minutes_recorded, 0)               as total_minutes_recorded,
        e.engagement_tier                                   as pre_churn_engagement_tier

    from subscriptions s
    join users      u on s.user_sk = u.user_sk
    left join engagement e on u.user_sk = e.user_sk
    where s.is_active        = false
      and s.end_date         >= dateadd('day', -90, current_date())
      and s.cancellation_reason is not null

)

select * from final
