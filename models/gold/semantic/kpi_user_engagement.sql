{{
    config(
        materialized = 'view',
        tags = ['gold', 'semantic', 'kpi']
    )
}}

/*
  KPI: User engagement
  Answers: How active is each user? Who is a power user vs dormant?
*/

with users as (

    select * from {{ ref('dim_user') }}

),

studios as (

    select * from {{ ref('dim_studio') }}

),

fact as (

    select * from {{ ref('fact_recording') }}

),

user_sessions as (

    select
        f.host_user_sk                                          as user_sk,
        count(distinct f.recording_sk)                          as lifetime_sessions,
        count(distinct f.recording_sk)
            filter (where f.started_at >= dateadd('day', -30, current_date()))
                                                                as sessions_l30d,
        round(sum(f.duration_minutes), 1)                       as total_minutes_recorded,
        round(avg(f.participant_count), 1)                      as avg_participants_per_session,
        max(f.started_at)                                       as last_session_at

    from fact f
    group by 1

),

final as (

    select
        u.user_sk,
        u.user_nk,
        u.email,
        u.display_name,
        u.plan_tier,
        u.plan_type,
        u.country_code,
        u.current_mrr_usd,

        coalesce(s.lifetime_sessions, 0)                        as lifetime_sessions,
        coalesce(s.sessions_l30d, 0)                            as sessions_l30d,
        coalesce(s.total_minutes_recorded, 0)                   as total_minutes_recorded,
        s.avg_participants_per_session,
        s.last_session_at,
        datediff('day', s.last_session_at, current_date())      as days_since_last_session,

        case
            when coalesce(s.sessions_l30d, 0) >= 10 then 'Power User'
            when coalesce(s.sessions_l30d, 0) between 3 and 9 then 'Active'
            when coalesce(s.sessions_l30d, 0) between 1 and 2 then 'Casual'
            else 'Dormant'
        end                                                     as engagement_tier

    from users u
    left join user_sessions s on u.user_sk = s.user_sk

)

select * from final
