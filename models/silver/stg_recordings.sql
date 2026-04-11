{{
    config(
        unique_key = 'recording_sk',
        on_schema_change = 'sync_all_columns'
    )
}}

with source as (

    select * from {{ source('bronze', 'raw_recordings') }}

),

deduped as (

    select
        *,
        row_number() over (
            partition by RAW_ID
            order by     try_to_timestamp_ntz(ENDED_AT) desc nulls last,
                         _LOADED_AT desc
        ) as _row_num

    from source
    where RAW_ID is not null

),

typed as (

    select
        {{ riverside_sk(['RAW_ID']) }}              as recording_sk,
        RAW_ID                                      as recording_nk,
        {{ riverside_sk(['STUDIO_ID']) }}           as studio_sk,
        {{ riverside_sk(['HOST_USER_ID']) }}        as host_user_sk,
        nullif(trim(SESSION_TITLE), '')             as session_title,
        try_to_timestamp_ntz(STARTED_AT)            as started_at,
        try_to_timestamp_ntz(ENDED_AT)              as ended_at,

        -- Prefer source duration; fallback to computed
        coalesce(
            try_to_number(DURATION_SECONDS),
            datediff(
                'second',
                try_to_timestamp_ntz(STARTED_AT),
                try_to_timestamp_ntz(ENDED_AT)
            )
        )                                           as duration_seconds,

        round(
            coalesce(
                try_to_number(DURATION_SECONDS),
                datediff(
                    'second',
                    try_to_timestamp_ntz(STARTED_AT),
                    try_to_timestamp_ntz(ENDED_AT)
                )
            ) / 60.0, 2
        )                                           as duration_minutes,

        try_to_number(PARTICIPANT_COUNT)            as participant_count,
        lower(coalesce(RECORDING_TYPE, 'unknown'))  as recording_type,
        lower(coalesce(STATUS, 'unknown'))          as status,
        try_to_decimal(STORAGE_MB, 10, 2)          as storage_mb,

        -- Date key for fact-dim joins
        to_number(
            to_char(try_to_date(STARTED_AT), 'YYYYMMDD')
        )                                           as date_key,

        _LOADED_AT                                  as bronze_loaded_at,
        current_timestamp()                         as silver_loaded_at

    from deduped
    where _row_num = 1
      and STATUS = 'completed'   -- only completed sessions reach Silver

)

select * from typed

{% if is_incremental() %}
    where silver_loaded_at > (select max(silver_loaded_at) from {{ this }})
{% endif %}
