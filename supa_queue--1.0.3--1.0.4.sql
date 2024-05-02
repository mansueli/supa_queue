CREATE OR REPLACE FUNCTION process_current_jobs()

RETURNS VOID

SECURITY DEFINER

SET search_path = public, extensions, net, vault

AS $$

DECLARE

    current_job RECORD;

    response_result RECORD;

BEGIN

    FOR current_job IN SELECT * FROM current_jobs

    FOR UPDATE SKIP LOCKED

    LOOP

        RAISE NOTICE 'Processing job_id: %, request_id: %', current_job.job_id, current_job.request_id;



        SELECT

            status,

            (response).status_code AS status_code,

            (response).body AS body

        INTO response_result

        FROM net._http_collect_response(current_job.request_id);



        IF response_result.status = 'SUCCESS' AND response_result.status_code BETWEEN 200 AND 299 THEN

            RAISE NOTICE 'Job completed (job_id: %)', current_job.job_id;



            UPDATE job_queue

            SET status = 'complete',

                content = response_result.body::TEXT

            WHERE job_id = current_job.job_id;



            DELETE FROM current_jobs

            WHERE request_id = current_job.request_id;

        ELSIF response_result.status = 'ERROR' THEN

            RAISE NOTICE 'Job failed (job_id: %)', current_job.job_id;



            UPDATE job_queue

            SET status = 'failed',

                retry_count = retry_count + 1

            WHERE job_id = current_job.job_id;



            DELETE FROM current_jobs

            WHERE request_id = current_job.request_id;

        ELSE

            RAISE NOTICE 'Job still in progress or not found (job_id: %)', current_job.job_id;



            -- Check if the number of retries has exceeded the retry limit

            SELECT retry_count, retry_limit INTO retry_count, retry_limit

            FROM job_queue

            WHERE job_id = current_job.job_id;



            IF retry_count >= retry_limit THEN

                RAISE NOTICE 'Job failed due to exceeding retry limit (job_id: %)', current_job.job_id;



                UPDATE job_queue

                SET status = 'failed'

                WHERE job_id = current_job.job_id;



                DELETE FROM current_jobs

                WHERE request_id = current_job.request_id;

            END IF;

        END IF;

    END LOOP;

END;

$$ LANGUAGE plpgsql;