# DB03 initial examiner assessment command (inactive draft)

This proposal adds one protected, worker-only `db03_record_initial_assessment` command over the private source in 22. It records an explicit `PASSED` or `FAILED` decision for one required published `ADMISSION_TEST` or `INTERVIEW` stage. Optional score and maximum must be supplied together; there is no automatic pass threshold. The assessment date comes from the School time zone. The private reason and score stay out of audit/outbox summaries.

The issuer requires a current real Auth token, active individual Principal binding, enabled operation contract, live matching permission and Campus grant, and a DRAFT application at the expected version. The command takes the same application row lock for competing decisions; a stage accepts one immutable initial result. Exact retries return the receipt after authority revalidation. A changed retry or second decision fails. Receipt, source, audit, and outbox insert in one transaction.

No permission or operation is seeded for customers. The disposable fixture creates the required stages and a scoped grant to exercise real Auth and concurrent decisions. There is no retake, correction, `ADMIN_TEST_SKIP`, stage outcome, Finance clearance, final admission, or Student creation in this change. A future skip command must use this same application lock and explicitly reject a prior failed test. Principal final admission remains a separate gate.

Validation: `python3 tools/db03/schema_candidate_ci.py --source-only`; the disposable DB03 GitHub CI additionally rehearses rollback, runs eight pgTAP checks, and exercises the document fixture with real Auth. The source is `.sql.draft` and has no deployment or migration registration.
