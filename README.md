# supa_queue Extension for Postgres

## Overview

The `supa_queue` extension is a simple but robust message queue system designed to work seamlessly with Postgres. It allows you to manage and process asynchronous jobs efficiently within your Postgres database.
You can read the blog post explaining this system here: [Building a Queue System with Supabase and PostgreSQL](https://blog.mansueli.com/building-a-queue-system-with-supabase-and-postgresql)

## Features

- Simple message queue system.
- Support for various HTTP methods (GET, POST, DELETE).
- Retry mechanism for failed jobs.
- Concurrent processing using multiple workers.
- Integration with external services via HTTP requests.
- Flexible scheduling with `pg_cron` for optimal job management.

## Installation

To install the `supa_queue` extension, follow these steps:

1. Make sure you have Postgres installed and running.

1. Install the required extensions `pg_cron` and `pg_net` if not already installed.

1. Install [DB.DEV](https://database.dev/installer):
```sql
create extension if not exists http with schema extensions;
create extension if not exists pg_tle;
select pgtle.uninstall_extension_if_exists('supabase-dbdev');
drop extension if exists "supabase-dbdev";
select
    pgtle.install_extension(
        'supabase-dbdev',
        resp.contents ->> 'version',
        'PostgreSQL package manager',
        resp.contents ->> 'sql'
    )
from http(
    (
        'GET',
        'https://api.database.dev/rest/v1/'
        || 'package_versions?select=sql,version'
        || '&package_name=eq.supabase-dbdev'
        || '&order=version.desc'
        || '&limit=1',
        array[
            ('apiKey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhtdXB0cHBsZnZpaWZyYndtbXR2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE2ODAxMDczNzIsImV4cCI6MTk5NTY4MzM3Mn0.z2CN0mvO2No8wSi46Gw59DFGCTJrzM0AQKsu_5k134s')::http_header
        ],
        null,
        null
    )
) x,
lateral (
    select
        ((row_to_json(x) -> 'content') #>> '{}')::json -> 0
) resp(contents);
create extension "supabase-dbdev";
select dbdev.install('supabase-dbdev');
drop extension if exists "supabase-dbdev";
create extension "supabase-dbdev";
```

1. Install supa_queue with the following code:

```sql
select dbdev.install('mansueli-supa_queue');
create extension "mansueli-supa_queue"
    version '1.0.3';
```

You can also install it in a different `schema` with:

```sql
create schema supa_queue;
select dbdev.install('mansueli-supa_queue');
create extension "mansueli-supa_queue"
    schema supa_queue
    version '1.0.3';
```

## Usage

### Inserting Jobs

To add a job to the queue, insert a new record into the `job_queue` table. Specify the HTTP verb (GET, POST, DELETE), payload, and other relevant information. The job will be processed asynchronously.

```sql
INSERT INTO job_queue (http_verb, payload, url_path) VALUES ('GET', '{"key": "value"}', '/api/resource');
```

### Processing Jobs

Jobs are processed automatically using the provided functions. The `process_job()` trigger function processes newly inserted jobs. The `process_current_jobs_if_unlocked()` function assigns jobs to available workers for execution.

### Retrying Failed Jobs

Failed jobs are automatically retried with the `retry_failed_jobs()` function, increasing job reliability. Jobs with a status of 'failed' and within the retry limit will be retried.

## Configuration

You can configure various aspects of the `supa_queue` extension by modifying the provided SQL functions and cron schedules to suit your specific use case.

Note that you'll need to set these values in Vault:

 - `service_role` key you can get this in the [dashboard](https://supabase.com/dashboard/project/_/settings/api).
 - `consumer_function` this is the URL of the Edge Function that will consume the tasks.
## License

This extension is provided under the [license](https://github.com/mansueli/supa_queue/blob/master/LICENSE) included in the repository.

## Contributing

If you'd like to contribute to this project or report issues, please visit the [GitHub repository](https://github.com/mansueli/supa_queue) for more information.
