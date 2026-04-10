{{
    config(
        unique_key = 'recording_sk',
        on_schema_change = 'sync_all_columns',
        tags = ['gold', 'fact']
    )
}}

/*
  FACT_RECORDING
  Grain: one row per completed recording session.
  All foreign keys are surrogate keys that join to Gold dims.
*/

with recordings as (

    select * from {{ ref('stg_recordings') }}

),

final as (

    select
        -- Keys
        r.recording_sk,
        r.studio_sk,
        r.host_user_sk,
        r.date_key,

        -- Degenerate dimensions
        r.recording_nk,
        r.session_title,
        r.recording_type,
        r.status,

        -- Measures
        r.duration_seconds,
        r.duration_minutes,
        r.participant_count,
        r.storage_mb,

        -- Derived bucketing (useful for BI slicing without SQL)
        case
            when r.duration_seconds >= 3600 then 'long'      -- 60 min+
            when r.duration_seconds >= 600  then 'medium'    -- 10–60 min
            else                                 'short'     -- < 10 min
        end                                                  as duration_bucket,

        -- Timestamps
        r.started_at,
        r.ended_at,
        r.silver_loaded_at,
        current_timestamp()                                  as gold_loaded_at

    from recordings r

)

select * from final

{% if is_incremental() %}
    where gold_loaded_at > (select max(gold_loaded_at) from {{ this }})
{% endif %}
