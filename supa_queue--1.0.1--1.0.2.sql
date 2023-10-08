-- Retry jobs each 10 minutes
SELECT cron.schedule(
    'retry_failed_jobs',
    '*/10 * * * *',
    $$ SELECT retry_failed_jobs(); $$
);
-- Schedule process jobs 3 times per minute:
SELECT cron.schedule(
    'process_tasks_subminute',
    '* * * * *',
    $$ SELECT process_tasks_subminute(); $$
);