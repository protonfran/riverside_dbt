-- Singular test: every recording's studio_sk must exist in dim_studio.
-- Orphaned facts indicate a studio record that was deleted upstream
-- without a corresponding recording cleanup.

select
    f.recording_sk,
    f.studio_sk
from {{ ref('fact_recording') }} f
left join {{ ref('dim_studio') }} s
       on f.studio_sk = s.studio_sk
where s.studio_sk is null
