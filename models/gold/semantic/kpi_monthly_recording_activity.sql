{{
    config(
        materialized = 'view',
        tags = ['gold', 'semantic', 'kpi']
    )
}}

/*
  KPI: Monthly recording activity
  Answers: How many sessions, hosts, and storage consumed per month?
*/

with fact as (

    select * from {{ ref('fact_recording') }}

),

dates as (

    select * from {{ ref('dim_date') }}

),

final as (

    select
        d.year,
        d.month_num,
        d.month_name,
        d.year_month,
        f.recording_type,

        count(distinct f.recording_sk)              as total_sessions,
        count(distinct f.host_user_sk)              as unique_hosts,
        count(distinct f.studio_sk)                 as active_studios,
        sum(f.participant_count)                    as total_participants,
        round(avg(f.duration_minutes), 1)           as avg_duration_minutes,
        round(median(f.duration_minutes), 1)        as median_duration_minutes,
        sum(f.storage_mb)                           as total_storage_mb,
        round(sum(f.storage_mb) / 1024, 2)         as total_storage_gb

    from fact f
    join dates d on f.date_key = d.date_key
    group by 1, 2, 3, 4, 5

)

select * from final
