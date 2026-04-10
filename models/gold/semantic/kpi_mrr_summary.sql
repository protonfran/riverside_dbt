{{
    config(
        materialized = 'view',
        tags = ['gold', 'semantic', 'kpi']
    )
}}

/*
  KPI: MRR & ARR summary
  Answers: What is our monthly and annual recurring revenue by segment?
*/

with users as (

    select * from {{ ref('dim_user') }}

),

final as (

    select
        plan_type,
        active_billing_cycle                        as billing_cycle,
        plan_tier,
        country_code,

        count(distinct user_sk)                     as paying_users,
        sum(current_mrr_usd)                        as total_mrr_usd,
        round(avg(current_mrr_usd), 2)              as arpu_usd,
        sum(current_mrr_usd) * 12                   as arr_usd_estimate

    from users
    where plan_status    = 'active'
      and current_mrr_usd > 0
    group by 1, 2, 3, 4

)

select * from final
