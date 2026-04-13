{{ config(materialized='table') }}

with base_dates as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2020-01-01' as date)",
        end_date="cast('2030-01-01' as date)"
    ) }}
),

final as (
    select 
        cast(date_day as date) as date_day
    from base_dates
)

select *
from final
-- Optional but recommended: limit to a practical range for performance
where date_day >= dateadd(year, -6, current_date)
  and date_day <= dateadd(year, 2, current_date)