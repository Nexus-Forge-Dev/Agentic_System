# Async Workers & Queues Testing Checklist
# .agents/skills/qa-pro-max/checklists/workers-queues.md
#
# Used by: sdet, qa-automation-engineer, backend-architect
# Activated by: /e2e, /health

---

## JOB IDEMPOTENCY

```
□ Enqueue same job twice (same idempotency key):
    → Executes ONCE only
    → No duplicate DB records created
    → No duplicate emails/notifications sent
    → No duplicate third-party API calls
□ Job fails mid-execution:
    → Retry picks up from correct checkpoint (not restart from scratch)
    → No partial execution artifact left in DB
    → Idempotency key prevents double-write on retry
□ After max retries exhausted:
    → Job moves to dead-letter queue (DLQ)
    → NOT silently dropped
    → DLQ entry contains: original payload, failure reason, retry count, timestamps
□ Dead-letter queue rate: < 1% of total enqueued jobs under normal load
□ Job IDs: unique, deterministic for idempotency key generation
```

---

## RETRY BEHAVIOR

```
□ Transient error (network timeout, DB connection drop):
    → Job retries automatically
    → Retry uses exponential backoff (not linear — prevents thundering herd)
    → Backoff caps at maximum interval (e.g., 30 minutes — not infinite growth)
□ Permanent error (invalid data, business rule violation):
    → Job fails immediately
    → Does NOT retry (would always fail — wasteful)
    → Moved to DLQ with error classification
□ Retry backoff formula verified:
    Attempt 1: immediate or short delay
    Attempt 2: delay × 2
    Attempt 3: delay × 4
    ... capped at max delay
□ Final retry failure:
    → Alert or metric emitted (Prometheus counter or Sentry event)
    → NOT silent — observable in monitoring
□ Retry count visible in job metadata (for debugging)
```

---

## QUEUE SATURATION UNDER STRESS

```
□ Enqueue 10x normal job volume simultaneously:
    → Queue depth peaks and then drains (not unbounded growth)
    → Processing completes within acceptable time window
    → No job loss (all enqueued jobs eventually processed or DLQ'd)
□ Worker concurrency limit respected:
    → No more than N workers processing simultaneously (N = configured limit)
    → Under spike: backpressure queues excess, does not spawn unlimited workers
□ Consumer group rebalance under stress:
    → No job duplication during rebalance
    → No job loss during rebalance
□ Queue depth metric: observable and alertable throughout test
□ Memory stability: worker process memory stable during sustained load
```

---

## POISON PILL HANDLING

```
□ Malformed job payload (missing fields, wrong types):
    → Rejected at consumer (parse error caught)
    → Error logged with job ID and payload
    → Worker continues processing other jobs (no crash loop)
    → Moved to DLQ
□ Job that consistently crashes the worker process:
    → Detected after N crashes (configurable threshold)
    → Isolated and moved to DLQ
    → Worker restarts and processes next job
    → Alert emitted
□ Worker crash under load:
    → Queue state preserved after crash (jobs not lost)
    → On worker restart: resumes processing without duplication
    → No jobs marked as "in progress" indefinitely after crash (stall detection)
□ Job timeout:
    → Jobs running beyond max duration are killed
    → Killed job returned to queue or DLQ (not silently abandoned)
    → Timeout duration configured per job type, not globally
```

---

## EMAIL / NOTIFICATION DELIVERY

```
□ Email job enqueued → verified in mock SMTP (e.g. MailHog, Mailpit in local/CI env)
□ Email job failed → retry scheduled, user NOT notified until job succeeds
□ Duplicate email prevention:
    → Idempotency key on email job
    → Sending same email twice → second attempt is no-op
    → User receives exactly one email
□ Email delivery confirmed via mock SMTP receipt:
    → NOT just "job status = completed"
    → Assert: to, from, subject, and key body content
□ Email template rendering tested separately:
    → Snapshot test on rendered HTML
    → No broken variable interpolation (undefined values in template)
□ Notification channels:
    → Push notifications: verified via mock provider
    → SMS: verified via mock provider (never real SMS in tests)
    → Webhooks: verified via mock endpoint with request capture
```

---

## SCHEDULED JOBS (CRON)

```
□ Cron expression validated (correct schedule, no off-by-one in timezone)
□ Cron job tested with simulated trigger (not waiting for wall-clock time)
□ Cron job idempotent: running twice in same window produces same result
□ Cron job overlap protection:
    → If previous run still active when next fires: skip or queue (not double-run)
    → Overlap behavior documented and tested
□ Cron job failure:
    → Error logged and alerted (not silently swallowed)
    → Next scheduled run not affected by previous failure
```

---

## ANTI-PATTERNS (HARD BLOCKS)

```
❌ Never assert job completion by checking HTTP response alone — verify DB side effect
❌ Never test workers with real external email/SMS/payment APIs
❌ Never assume "job queued" = "job executed" — assert the side effect, not the enqueue
❌ Never allow unbounded queue growth in load tests — catch and fail the test
❌ Never set retry count to unlimited — always cap with DLQ fallback
❌ Never test cron timing by waiting for wall-clock time — use simulated trigger
❌ Never ignore DLQ entries in health checks — DLQ growth is a production incident
```
