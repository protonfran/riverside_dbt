{{
    config(
        unique_key = 'user_sk',
        on_schema_change = 'sync_all_columns'
    )
}}

with source as (

    select * from {{ source('bronze', 'raw_users') }}

),

deduped as (

    select
        *,
        row_number() over (
            partition by RAW_ID
            order by     try_to_timestamp_ntz(UPDATED_AT) desc nulls last,
                         _LOADED_AT desc
        ) as _row_num

    from source
    where RAW_ID is not null

),

renamed as (

    select
        {{ riverside_sk(['RAW_ID']) }}              as user_sk,
        RAW_ID                                      as user_nk,
        lower(trim(EMAIL))                          as email,
        initcap(nullif(trim(DISPLAY_NAME), ''))     as display_name,
        lower(coalesce(PLAN_TYPE, 'unknown'))        as plan_type,
        lower(coalesce(PLAN_STATUS, 'unknown'))      as plan_status,
        upper(nullif(trim(COUNTRY_CODE), ''))        as country_code,
        try_to_timestamp_ntz(CREATED_AT)            as created_at,
        try_to_timestamp_ntz(UPDATED_AT)            as updated_at,
        _LOADED_AT                                  as bronze_loaded_at,
        current_timestamp()                         as silver_loaded_at

    from deduped
    where _row_num = 1

)

select * from renamed

{% if is_incremental() %}
    where silver_loaded_at > (select max(silver_loaded_at) from {{ this }})
{% endif %}
