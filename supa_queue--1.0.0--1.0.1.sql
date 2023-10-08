CREATE OR REPLACE FUNCTION public.retry_failed_jobs()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'net', 'vault'
AS $function$
DECLARE
    r RECORD;
    request_id BIGINT;
    api_key TEXT;
    base_url TEXT;
    response_result net._http_response_result;
BEGIN
    RAISE NOTICE 'Retrying failed jobs';

    -- Get the API key
    SELECT decrypted_secret
    INTO api_key
    FROM vault.decrypted_secrets
    WHERE name = 'service_role';

    FOR r IN (
            SELECT * FROM job_queue
            WHERE (status = 'failed' AND retry_count < retry_limit)
              OR (status = 'processing' AND created_at < current_timestamp - INTERVAL '10 minutes')
            FOR UPDATE SKIP LOCKED
        ) LOOP
            RAISE NOTICE 'Retrying job_id: %', r.job_id;

        UPDATE job_queue
        SET retry_count = retry_count + 1
        WHERE job_id = r.job_id;

        SELECT decrypted_secret
        INTO base_url
        FROM vault.decrypted_secrets
        WHERE name = 'consumer_function';
        -- Call the request_wrapper to process the job
        request_id := request_wrapper(
            method := r.http_verb,
            -- Edge function call (like AWS lambda)
            url := base_url || COALESCE(r.url_path, ''),
            body := COALESCE(r.payload::jsonb, '{}'::jsonb),
            headers := jsonb_build_object('Authorization', 'Bearer ' || api_key, 'Content-Type', 'application/json')
        );
        INSERT INTO current_jobs (request_id, job_id)
        VALUES (request_id, r.job_id);
    END LOOP;
END;
$function$;