{{
    config(
        unique_key = 'participant_sk',
        on_schema_change = 'sync_all_columns'
    )
}}

with source as (

    select * from {{ source('bronze', 'raw_participants') }}

),

deduped as (

    select
        *,
        row_number() over (
            partition by RAW_ID
            order by     _LOADED_AT desc
        ) as _row_num

    from source
    where RAW_ID is not null

),

renamed as (

    select
        {{ riverside_sk(['RAW_ID']) }}              as participant_sk,
        RAW_ID                                      as participant_nk,
        {{ riverside_sk(['RECORDING_ID']) }}        as recording_sk,

        -- Registered users get a surrogate key; anonymous guests get NULL
        case
            when USER_ID is not null
            then {{ riverside_sk(['USER_ID']) }}
            else null
        end                                         as user_sk,

        lower(nullif(trim(GUEST_EMAIL), ''))        as guest_email,
        lower(coalesce(ROLE, 'guest'))              as participant_role,
        try_to_timestamp_ntz(JOINED_AT)             as joined_at,
        try_to_timestamp_ntz(LEFT_AT)               as left_at,

        datediff(
            'second',
            try_to_timestamp_ntz(JOINED_AT),
            try_to_timestamp_ntz(LEFT_AT)
        )                                           as session_duration_seconds,

        _LOADED_AT                                  as bronze_loaded_at,
        current_timestamp()                         as silver_loaded_at

    from deduped
    where _row_num = 1

)

select * from renamed

{% if is_incremental() %}
    where silver_loaded_at > (select max(silver_loaded_at) from {{ this }})
{% endif %}
