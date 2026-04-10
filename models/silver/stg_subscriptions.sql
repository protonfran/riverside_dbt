{{
    config(
        unique_key = 'subscription_sk',
        on_schema_change = 'sync_all_columns'
    )
}}

with source as (

    select * from {{ source('bronze', 'raw_subscriptions') }}

),

deduped as (

    select
        *,
        row_number() over (
            partition by RAW_ID
            order by     try_to_date(END_DATE) desc nulls last,
                         _LOADED_AT desc
        ) as _row_num

    from source
    where RAW_ID is not null

),

renamed as (

    select
        {{ riverside_sk(['RAW_ID']) }}              as subscription_sk,
        RAW_ID                                      as subscription_nk,
        {{ riverside_sk(['USER_ID']) }}             as user_sk,
        lower(coalesce(PLAN_TYPE, 'unknown'))        as plan_type,
        lower(coalesce(BILLING_CYCLE, 'unknown'))    as billing_cycle,
        try_to_decimal(MRR_USD, 10, 2)             as mrr_usd,

        -- Normalise annual billing to monthly equivalent
        case
            when lower(BILLING_CYCLE) = 'annual'
            then round(try_to_decimal(MRR_USD, 10, 2) / 12, 2)
            else try_to_decimal(MRR_USD, 10, 2)
        end                                         as mrr_usd_normalised,

        try_to_date(START_DATE)                     as start_date,
        try_to_date(END_DATE)                       as end_date,
        nullif(trim(CANCELLATION_REASON), '')       as cancellation_reason,

        case
            when END_DATE is null
              or try_to_date(END_DATE) >= current_date()
            then true
            else false
        end                                         as is_active,

        _LOADED_AT                                  as bronze_loaded_at,
        current_timestamp()                         as silver_loaded_at

    from deduped
    where _row_num = 1

)

select * from renamed

{% if is_incremental() %}
    where silver_loaded_at > (select max(silver_loaded_at) from {{ this }})
{% endif %}
