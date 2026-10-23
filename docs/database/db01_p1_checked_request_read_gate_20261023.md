# DB01-05 — Checked Roll-correction P1 request viewing

**Acceptance:** Disposable engineering PASS on source SHA `cba4c7e54f2e558d5f6ae2c546213d2dd2f25d2b`, 2026-10-23. Not a security review signoff or a release/merge authorization.

## Purpose

Allow an authenticated user to inspect one `student.roll.correct` P1 approval request without granting direct table access, while preserving current grant/scope checks and separating Roll-number disclosure from request participation.

The new read-only RPC is `app.d1_read_student_roll_correction_request(request_id uuid)`, returning exactly: `request_id`, `request_version`, `request_state`, `student_id`, `source_section_offering_id`, `expected_student_version`, nullable `source_numeric_value`, nullable `proposed_numeric_value`, `request_reason` and `participant_kind`. No raw JSON, reviewer identities, command receipts, audit objects or outbox data are disclosed.

## Who can see a request?

The verified server Principal is resolved from the current authenticated session, under the Foundation shared authorization lock and current-Principal lock. A missing Principal, malformed snapshot, unrelated request ID or disabled grant returns no rows.

- **REQUESTER:** exact request-submitting Principal with current `student.roll.correct` scope for the stored source Section.
- **REVIEWER:** different Person, exact current unwithdrawn review assignment on one or more configured P1 steps and current `student.roll.approve` grant scoped to the same Section and required reviewer Role. Historic review alone does not authorize viewing.
- **AUTHORIZED_ADMIN:** different Person with **both** current Section-scoped `student.roll.correct` and independent current `student.roll_history.view` for the target Student. A Role label by itself is not sufficient.

The numeric columns remain NULL unless the separate live `student.roll_history.view` check succeeds; no fallback to the request's historic source effective date is accepted for numeric disclosure.

## Least privilege

`effect41_14_db01_checked_request_read.sql.draft` adds one private participant helper and one authenticated-only typed public RPC. Only `schoolos_read_executor` can call the private helper; the client cannot SELECT workflow evidence tables or EXECUTE private routines. The trusted reader/authorization roles receive selected columns and `student.roll.correct`-only FORCE RLS policies, not global private-table SELECT. The SQL does not enable catalog permissions, deploy migrations, write requests or update Roll allocations.

## Verified real PostgreSQL

| Check | Result |
| --- | --- |
| D1 static | [#39890730674](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39890730674) SUCCESS |
| Foundation | [#39890730520](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39890730520) SUCCESS |
| D1 PostgreSQL runtime | [#39890730526](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39890730526) SUCCESS |
| Full P1 suite | `92_db01_roll_correct_p1_apply.sql 85/85` |
| Complete domain acceptance | `D1_BUSINESS_PASS 3658 assertions` |
| Protected inventory | 34/34 FORCE RLS, 569 functions / 551 definers / 162 app / 407 private, no client private EXECUTE |

**Boundary:** PR #141 remains DRAFT/unmerged; Migration 10 files remain `.sql.draft`. DB01-06 and later integration/security/release tasks are separate and not deemed passed.
