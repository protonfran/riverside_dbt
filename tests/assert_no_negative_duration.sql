-- Singular test: no recording should have a negative duration.
-- This catches edge cases where ENDED_AT < STARTED_AT due to bad source data.

select
    recording_sk,
    recording_nk,
    duration_seconds
from {{ ref('fact_recording') }}
where duration_seconds < 0
