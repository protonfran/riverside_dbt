{{
    config(
        materialized = 'table',
        tags = ['gold', 'dim']
    )
}}

/*
  DIM_STUDIO  —  SCD Type 1
  Joins to DIM_USER (Gold-to-Gold ref) to denormalise owner info.
*/

with studios as (

    select * from {{ ref('stg_studios') }}

),

users as (

    select * from {{ ref('dim_user') }}

),

final as (

    select
        st.studio_sk,
        st.studio_nk,
        st.studio_name,
        st.plan_type,

        -- Owner attributes (denormalised)
        u.email                                     as owner_email,
        u.display_name                              as owner_name,
        u.plan_tier                                 as owner_plan_tier,
        u.country_code,

        st.created_at,
        st.updated_at,
        current_timestamp()                         as dwh_updated_at

    from studios st
    left join users u
           on st.user_sk = u.user_sk

)

select * from final
