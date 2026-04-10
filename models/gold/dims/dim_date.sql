{{
    config(
        materialized = 'table',
        tags = ['gold', 'dim']
    )
}}

/*
  DIM_DATE — pass-through from the dim_date seed.
  The seed lives in seeds/dim_date.csv and is loaded via `dbt seed`.
  This model exposes it under the gold schema alongside the other dims
  so fact tables can use {{ ref('dim_date') }} uniformly.
*/

select * from {{ ref('dim_date') }}
