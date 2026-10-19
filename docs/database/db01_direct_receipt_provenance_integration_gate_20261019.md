# DB-01 — Second D1 function-inventory gate: immutable DIRECT receipt provenance

**Prepared:** 2026-10-19. **Status: NON-ACTIVATING IMPLEMENTATION SUBMITTED, NOT INDEPENDENTLY APPROVED OR DEPLOYED.**
Documentation owner [PR #100](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/100). SQL implementation and tests [stacked draft PR #111](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/111), **base** [draft PR #109](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/109), with independently requested integration owner approval in [issue #110](https://github.com/yunusyosaf399/edusync_saas_school_app/issues/110). Neither PR is merged; `student.roll.correct` remains registered disabled.

**Product:** DB-01 RC-01…RC-08 were owner-approved in [contract v1](db01_student_roll_correct_owner_approved_contract_20261019.md); **DB-02 RP-02/03/07, School-local T-B reconciliation and shared MOVE source prelock are NOT approved** by this document. No hosted Supabase action, executable migration, public RPC, staff permission activation or merge.

## 1. Last verified baseline

- Stacked PR #109 head `7e2ac543a34ac42a08ed7a1c4096ebae6a15516b`: the private retained R0→R1 row-pair verifier is internally executable but not client-executable. Three exact-head workflows passed, including D1 local runtime, **suite #77 30/30**, 3,196 total domain assertions, 232 draft SQL fragments assembled and applied, and frozen runtime catalog **543 functions, 525 SECURITY DEFINER, 157 app functions, 386 app_private functions, authenticated_private=0, anon=0, service_role=0**. That is not a protected correction.
- Foundation receipt `app_private.command_receipts` actually stores `principal_id,operation_id,command_kind,idempotency_key,canonical_payload_hash,canonicalization_version,expected_target_version,request_id,expected_request_version,state,result_kind,result_ref,result_summary,created_by`. Unique `(principal_id,operation_id,idempotency_key)` does **not** guarantee only one successful receipt claims one corrected Roll UUID.
- Foundation `audit_events` and `outbox_events` actually link `command_receipt_id`, `correlation_id`; outbox unique `(command_receipt_id,event_ordinal)` does **not** alone enforce one event total.
- Owner-approved correction success returns `result_ref = corrected Roll UUID`, selected result kind `D1_STUDENT_ROLL_CORRECT`, and one `enrollment.roll_corrected` outbox event. Original expected caller intent is hashed under approved canonical protocol; hash must **never include a volatile replay date**.

## 2. New exact helper and trust boundary

**New internal SQL function** in `effect38_03_db01_direct_receipt_provenance.sql.draft`:

```sql
app_private.d1_roll_correct_direct_receipt_matches_exact(
  p_receipt uuid, p_actor uuid, p_key text, p_expected_hash bytea,
  p_student uuid, p_enrollment uuid, p_source_roll uuid, p_successor_roll uuid
) RETURNS boolean
```

**Owner and ACL (revised after observed runtime privilege failure):** `schoolos_schema_owner` (the only existing role allowed to read both retained Foundation receipt and outbox evidence under FORCE RLS), `SECURITY DEFINER SET search_path=pg_catalog,pg_temp`; no PUBLIC/anon/authenticated/service_role effective EXECUTE; narrowly callable only by trusted Student and workflow executors. The underlying `schoolos_student_executor`-owned retained Roll-pair verifier receives a narrow EXECUTE grant to `schoolos_schema_owner`; **no general table SELECT grants to student/evidence executors**. Does not expose an `app` RPC, issue a receipt, create a Roll, audit or outbox, update evidence, read via client or enable a permission.

**Verified only in DIRECT mode:** operation `student.roll.correct`, contract version 1, `command_kind='student.roll.correct'`, stored receipt `state='SUCCEEDED'`, `result_kind='D1_STUDENT_ROLL_CORRECT'`, no approval `request_id`/version, original individual Principal/created_by/idempotency key/32-byte hash, stored target Student version matching the strict result summary, result_ref new Roll. Calls existing #109 canonical 12-key retained row-pair verifier to prove the actual R0→R1 state after later lawful history changes.

**Distinct cross-evidence checks:** precisely one successful correction receipt for this corrected Roll within the original operation; one audit and one outbox row for original receipt; event ordinal 1 and schema version 1; audit matches original Principal, Student, source kind API, success and `student.roll.correct` event; outbox `enrollment.roll_corrected` refers to original Enrollment; audit/outbox correlation IDs match; neither broad event payload nor audit details carries top-level numeric or correction-reason fields.

**What this helper does NOT prove:** It does not authenticate its caller, enforce today's individual Student/Section history-view permission, recompute `p_expected_hash` from independently verified caller input, prove original correction reason equality to the input intent, or validate APPROVAL request/reviewer/application evidence. A future authenticated protected wrapper **must** reconstruct the entire canonical source intent and hash before invoking this internal helper and independently authorize historical disclosure. Do not expose this function directly to clients. The synthetic regression receipt is not an authenticated command success and cannot prove original actor authorization.

**APPROVAL APPLY excluded intentionally:** a success receipt with `command_kind='request.apply'` or non-null request ID must fail this DIRECT verifier. Future separately catalog-gated `approval_applications` guard has to bind the approved request's exact old_snapshot, requested numeric/reason, independently reviewed step evidence, applied target version, receipt, and corrected Roll. Do not accept an APPLY result using only the DIRECT verifier.

## 3. Catalog delta and isolation

| Runtime catalog metric | PR #109 exact baseline | New PR #111 expected |
|---|---:|---:|
| Total D1 functions | 543 | **544** |
| SECURITY DEFINER | 525 | **526** |
| Private functions | 386 | **387** |
| Public app functions | 157 | **157** |
| Authenticated app EXECUTE | 157 | **157** |
| Authenticated private EXECUTE | 0 | **0** |
| Anonymous/service_role EXECUTE | 0/0 | **0/0** |
| Domain tables / FORCE RLS | 34/34 | **34/34** |

The staged integration PR modifies only one DB-01 SQL draft, one DB-01 rollback-only test suite, `tools/supabase/domain_business_ci.py` registration, the **three** strict `EXPECTED_RUNTIME_METRICS` totals in `tools/supabase/domain_local_ci.py`, and matching assertions in `tools/supabase/tests/test_domain_local_ci.py`. It never weakens the drift failure condition or FINAL function guard and never grants new client access. Independently review that exact combined diff; issue #110 approval is separate from issue #108's first helper.

## 4. Negative and positive acceptance claims

Suite `78_db01_direct_receipt_provenance_private_acl.sql` uses the established real authenticated **P0 Enrollment placement** seed, adds a **privileged synthetic** R0→R1 correction history plus synthetic DIRECT receipt/audit/outbox evidence, and rolls the entire disposable local transaction back. Its 18 test cases probe no receipt, missing audit/outbox, a fully linked synthetic record, wrong digest/key/Principal/Student/Roll identities, replay without mutation, actual PostgreSQL effective client EXECUTE denial, disabled operation and unchanged retained rows. The test must never be reported as a successful authenticated correction, DIRECT command acceptance or School-local date proof.

**CI/debugging chronology:** Initial PR #111 head `fced078ce1d977654f6b33abef161d93b53b8856` failed D1 runtime because `schoolos_student_executor` lacked `SELECT` on Foundation `command_receipts`. The intermediate `schoolos_evidence_writer`-owned revision likewise lacked `SELECT` on `outbox_events`. Both deficiencies correctly reflected the frozen privilege boundary; broad table SELECT grants were **not** added. The verifier was changed to the existing schema-owner execution pattern, explicit narrow predecessor-proof delegation added, and the test suite expanded to **24** actual owner/ACL/negative assertions. The first schema-owner runtime executed **24 tests with 23 PASS**; remaining failure was a pgTAP dollar-quoted psql variable (`42601`) rather than the expected authenticated `42501`, corrected at `7836270c9772a658ba14c6205e0ae078a67f95a3`. **This final exact-head CI must be rechecked; no 24/24 PASS is claimed until the GitHub D1 log confirms it.** Keep PR draft until independent integration/security owner approval and source+receipt acceptance.

## 5. Next gate after this receipt component

If #111 passes runtime and integration owner separately accepts its strict catalog and ACL delta, the next implementation task is the **APPROVAL APPLY request/application/receipt provenance guard**, only after approved DB-02 policy compatibility and cross-Enrollment lock contracts are reconciled. The full protected DIRECT and reviewed APPLY mutation workflows still require School-local effective-date agreement, independent reviewer/actor permissions, concurrency, real current-disclosure checks, accepted P1 authorization and activation planning.

**Release status: product contract approved for DB-01; second internal receipt verifier proposed; runtime acceptance pending; independent integration signoff pending; protected Student Roll Correction NOT IMPLEMENTED.**
