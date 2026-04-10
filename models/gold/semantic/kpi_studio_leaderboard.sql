{{
    config(
        materialized = 'view',
        tags = ['gold', 'semantic', 'kpi']
    )
}}

/*
  KPI: Studio performance leaderboard
  Answers: Which studios are the most active by sessions, storage, and recency?
*/

with studios as (

    select * from {{ ref('dim_studio') }}

),

fact as (

    select * from {{ ref('fact_recording') }}

),

studio_metrics as (

    select
        f.studio_sk,
        count(distinct f.recording_sk)                          as total_sessions,
        sum(f.duration_minutes)                                 as total_minutes,
        round(avg(f.duration_minutes), 1)                       as avg_session_minutes,
        sum(f.storage_mb)                                       as total_storage_mb,
        max(f.started_at)                                       as last_session_at

    from fact f
    group by 1

),

final as (

    select
        st.studio_sk,
        st.studio_nk,
        st.studio_name,
        st.owner_email,
        st.owner_name,
        st.owner_plan_tier,
        st.country_code,

        coalesce(m.total_sessions, 0)                           as total_sessions,
        coalesce(m.total_minutes, 0)                            as total_minutes,
        m.avg_session_minutes,
        coalesce(m.total_storage_mb, 0)                         as total_storage_mb,
        round(coalesce(m.total_storage_mb, 0) / 1024, 2)       as total_storage_gb,
        m.last_session_at,

        rank() over (order by coalesce(m.total_sessions, 0) desc)   as rank_by_sessions,
        rank() over (order by coalesce(m.total_storage_mb, 0) desc) as rank_by_storage

    from studios st
    left join studio_metrics m on st.studio_sk = m.studio_sk

)

select * from final
