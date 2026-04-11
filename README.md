# Riverside.fm — dbt Project

Transforms raw Bronze data (loaded by Snowpipe) through Silver and Gold layers
into a business-ready semantic layer for analytics and BI tools.

---

## Project structure

```
riverside_dbt/
├── dbt_project.yml              # Project config, materialisation strategy per layer
├── profiles.yml                 # Snowflake connection profiles (dev / prod)
├── packages.yml                 # dbt-utils, dbt-expectations
├── generate_dim_date.py         # One-time script to generate seeds/dim_date.csv
│
├── seeds/
│   ├── schema.yml
│   └── dim_date.csv             # 4018-row date spine (2020–2030)
│
├── models/
│   ├── sources.yml              # Bronze source declarations + freshness thresholds
│   │
│   ├── silver/                  # Incremental models — dedup, cast, surrogate keys
│   │   ├── stg_users.sql
│   │   ├── stg_studios.sql
│   │   ├── stg_recordings.sql
│   │   ├── stg_participants.sql
│   │   ├── stg_subscriptions.sql
│   │   └── schema.yml
│   │
│   └── gold/
│       ├── dims/                # Full-table rebuilds — SCD Type 1
│       │   ├── dim_user.sql
│       │   ├── dim_studio.sql
│       │   ├── dim_date.sql     # Pass-through from seed
│       │   └── schema.yml
│       │
│       ├── facts/               # Incremental fact tables
│       │   ├── fact_recording.sql
│       │   └── schema.yml
│       │
│       └── semantic/            # Views — KPI layer for BI tools
│           ├── kpi_monthly_recording_activity.sql
│           ├── kpi_user_engagement.sql
│           ├── kpi_mrr_summary.sql
│           ├── kpi_churned_users.sql
│           ├── kpi_studio_leaderboard.sql
│           └── schema.yml
│
├── tests/                       # Singular (custom) tests
│   ├── assert_no_negative_duration.sql
│   ├── assert_no_orphaned_recordings.sql
│   └── assert_no_zero_paid_mrr.sql
│
└── macros/
    └── riverside_sk.sql         # Surrogate key wrapper around dbt_utils
```

---

## Lineage

```
Bronze sources  (Snowpipe → RAW_* tables)
      │
      │  {{ source('bronze', 'raw_*') }}
      ▼
Silver models   (incremental, merge strategy)
  stg_users  stg_studios  stg_recordings  stg_participants  stg_subscriptions
      │
      │  {{ ref('stg_*') }}
      ▼
Gold dims       (full table rebuild — SCD Type 1)
  dim_user   dim_studio   dim_date (from seed)
      │
      │  {{ ref('dim_*') }}
      ▼
Gold fact       (incremental, merge strategy)
  fact_recording
      │
      │  {{ ref('fact_recording') }}  +  {{ ref('dim_*') }}
      ▼
Gold semantic   (views — zero storage cost)
  kpi_monthly_recording_activity
  kpi_user_engagement
  kpi_mrr_summary
  kpi_churned_users
  kpi_studio_leaderboard
```

---

## First-time setup

```bash
# 1. Install dbt Snowflake adapter
pip install dbt-snowflake

# 2. Install dbt packages
dbt deps

# 3. Set environment variables
export SNOWFLAKE_ACCOUNT="yourorg-youraccount"
export SNOWFLAKE_USER="your_user"
export SNOWFLAKE_PASSWORD="your_password"

# 4. Verify connection
dbt debug

# 5. Load the date spine seed
dbt seed

# 6. First full build
dbt build          # runs seed + models + tests in DAG order
```

---

## Day-to-day commands

```bash
# Run all models
dbt run

# Run a specific layer only
dbt run --select silver
dbt run --select gold

# Run a single model and all its upstream dependencies
dbt run --select +fact_recording

# Run tests only
dbt test

# Run tests for a specific model
dbt test --select stg_recordings

# Check source freshness (will warn/error if Snowpipe has stalled)
dbt source freshness

# Generate and serve docs locally
dbt docs generate
dbt docs serve

# Full build: seed + run + test (use in CI)
dbt build
```

---

## Materialisation strategy

| Layer    | Strategy      | Reason |
|----------|---------------|--------|
| Silver   | `incremental` | Append-heavy; merge on surrogate key avoids full scans |
| Gold dims | `table`      | Small-to-medium; full rebuild ensures SCD Type 1 correctness |
| Gold fact | `incremental` | Large and append-heavy; merge on `recording_sk` |
| Semantic  | `view`        | No storage cost; always reflects latest Gold data |
| Seed      | CSV load      | Static reference data; version-controlled in Git |

---

## SCD Type 1 behaviour

Dimension models (`dim_user`, `dim_studio`) are materialised as full tables.
On every dbt run they are completely rebuilt from Silver. This means:

- Attribute changes (e.g. a user upgrades from `pro` → `business`) are
  overwritten in place — no history is kept.
- If you need history, add a **dbt snapshot** on `stg_users`:

```bash
# snapshots/snap_users.sql
{% snapshot snap_users %}
{{
    config(
        target_schema = 'snapshots',
        unique_key    = 'user_sk',
        strategy      = 'timestamp',
        updated_at    = 'updated_at',
    )
}}
select * from {{ ref('stg_users') }}
{% endsnapshot %}
```

Then run: `dbt snapshot`

---

## Environment variables required

| Variable             | Description                          |
|----------------------|--------------------------------------|
| `SNOWFLAKE_ACCOUNT`  | e.g. `myorg-myaccount`               |
| `SNOWFLAKE_USER`     | Snowflake username                   |
| `SNOWFLAKE_PASSWORD` | Snowflake password                   |

For CI (GitHub Actions, dbt Cloud, etc.) store these as secrets and inject
them at runtime. Never commit credentials to `profiles.yml`.
