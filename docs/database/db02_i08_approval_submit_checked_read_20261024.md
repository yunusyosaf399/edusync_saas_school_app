# DB-02 I08 — independently reviewed Roll Policy request SUBMIT (inactive draft)

**Scope:** School-wide approval-route `request.submit` and checked PENDING request participant read. **Status:** draft source/acceptance; no hosted Supabase deployment or protected operation activation.

**Stacked baseline:** I07 draft PR #152, exact locally green head `51d2d1355401b807bf6d83e6d0aee0b3214f2224`. Retain earlier I06 evidence proof unchanged for DIRECT.

## Protected commands

`app.d1_submit_student_roll_policy_change(school_id,action,source_policy_id,expected_source_revision,expected_source_mode,expected_source_start_value,expected_source_effective_from,new_mode,new_start_value,private_reason,idempotency_key)` returns `(request_id UUID,request_version BIGINT)`. Same fixed 11 typed command inputs as DIRECT; INIT or REPLACE only. Owner `schoolos_workflow_executor` (NOLOGIN); `SECURITY DEFINER`, fixed `search_path=pg_catalog,pg_temp`; only `authenticated` granted EXECUTE.

`app.d1_read_student_roll_policy_request(request_id)` returns an allowlisted 11-column typed row only for a current School ALL requester or currently assigned/open/eligible independent reviewer. It never returns arbitrary request payload, raw reason, actor grants, reviewer enumeration, receipt/hash or raw approval rows. Revocation returns zero rows. Client `anon` and `service_role` have no new function EXECUTE.

The Student-owned `d1_roll_policy_submit_context` checks a server-selected global NULL-Campus APPROVAL P1 **UUID**, currently verified Principal and School ALL authorization, shared Foundation auth lock, receipt/idempotency lock, School/source/allocator locked preflight, trusted School-local date and unmodified selected P1 after the wait. It calls the unchanged 12-element typed shared receipt allowlist (`request.submit` already approved). A matching prior SUBMIT may be discovered only under current authority, then verified from saved Foundation history before replay. Same key with changed reason/proposal conflicts. There is no direct policy effect on submission.

### Private Foundation evidence

A successful new submission atomically:
1. Stores a frozen `approval_requests` row bound to `student.roll_policy.change`, immutable requester/school/P1 UUID, source identity and trusted School business date. Private reason exists only in `approval_requests.reason` and canonical receipt hash, not broad evidence.
2. Transitions `DRAFT -> SUBMITTED -> PENDING`; creates all frozen template steps, opens first, assigns currently eligible **different-Person** reviewer candidates using existing `d1_review_candidates`. No independent reviewer => entire request transaction aborts.
3. Inserts **one** receipt `request.submit / D1_STUDENT_ROLL_POLICY_REQUEST`, result_ref=request ID, exact two-key `{"request_version":3,"state":"PENDING"}` summary, **one** minimized audit event with phase SUBMIT, and three linked Foundation approval transitions.
4. Validates matching retained request, P1/source/proposal, receipt/hash, step/reviewer evidence, transitions, audit and absence of policy-change outbox events before exposing the request ID. Replay rechecks immutable history, not today's active policy head.

The request has **no policy revision/pool effect** and emits **no `student.roll_policy_changed` outbox event**. APPROVED is still not applied; I09/I10/I11 implement independent reviewer decision, application, and reviewed REVIEW/APPLY receipt shapes separately.

**Security boundary:** private evidence helpers stay owned by `schoolos_evidence_writer`; private typed context by Student executor. Narrow NOLOGIN-only grants, operation-scoped RLS, no raw client table access, no broad wildcard receipt phases. CI permissions and exact catalog counts are frozen in runner tests.

## Verification

Rollback-only pgTAP `96_db02_approval_submit_read.sql` covers disabled operation, missing P1, School ALL denied, independent reviewer assignment, PENDING/receipt/audit/transition proof, zero Roll Policy/pool/outbox changes, idempotent SUBMIT replay, private reason confidentiality, requester/reviewer typed reads and reviewer grant revocation. Complete once **all three exact-head** D1 static, Foundation local, and D1 disposable runtime workflows pass; otherwise keep I08 open. Independent security signoff remains issue #131.

**Deployment gates**: PR remains draft/unmerged; no hosted migration, no live enablement, no API release, no role activation outside disposable test transactions, no review/apply command or cross-workstream schema change.
