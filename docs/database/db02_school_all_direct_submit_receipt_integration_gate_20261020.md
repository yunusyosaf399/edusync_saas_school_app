# DB-02 — School ALL actor authorization and protected DIRECT/SUBMIT receipt integration gate

**Date:** 2026-10-20. **Status:** DB-02 private authorization increment implemented as a non-activating draft; protected DIRECT and SUBMIT commands are **BLOCKED** by a shared receipt allowlist and independent security review. PR #101; DB-01 #117 remains outside this branch.

## Verified source blocker (not a speculative product decision)

The final assembled D1 `app_private.d1_command_receipt_lookup(text,text,text,jsonb)`, last overridden in `supabase/migrations/20260928000000_domain_package_01_effect35_18_family_primary_context_receipt_intent_allowlist.sql.draft`, uses an explicit operation + phase + canonical JSON-array length whitelist. The complete function has no `student.roll_policy.change` branch. Consequently a well-formed future:

- DIRECT `(operation_code='student.roll_policy.change', command_kind=operation_code)`, or
- SUBMIT `(operation_code='student.roll_policy.change', command_kind='request.submit')`

**currently raises** `D1 receipt operation phase or shape unsupported` before its receipt is obtained. Writing a receipt directly, bypassing the typed digest, actor/idempotency locks or explicit operation whitelist is **prohibited**. The receipt guard is owned by `schoolos_evidence_writer` and is shared with other implemented operations. DB-02 does **not** overwrite it or edit frozen Foundation migration, shared CI deployment controls, or another workstream.

Engineering integration requirement: the shared receipt owner must approve a narrow **additive** final override or exact integrated change for the two Roll Policy phases and their frozen canonical intents; retain every existing allowed operation/phase, the verified current Principal, SHA-256/JCS intent digest, READ COMMITTED, SHARED Foundation auth lock, idempotency-key serialization, receipt replay checks and private EXECUTE grants. No wildcard code or generic JSON shape. A version/phase-by-phase integration review is needed before any new effect writes a SUCCESS receipt.

**Proposed canonical typed business envelope for review** (exact array length and field types to be frozen in the integration PR; not yet implemented): `[school_id, action(INIT|REPLACE), source_policy_id, expected_revision, expected_mode, expected_start_value, expected_effective_from, expected_effective_until, new_mode, new_start_value, nonblank_reason, selected_global_p1_version_id]`. The Foundation policy UUID must be **derived server-side** using `d1_roll_policy_p1_version`, never trusted as a client-selection authority. DIRECT and SUBMIT require distinct command_kind values and route checks. Idempotent replay must recheck current authority, School-source compatibility, global Foundation policy version and disclosure before any historical response. This array is an engineering proposal, not a claim that the existing allowlist accepts it.

## Completed DB-02-only safe increment

- `supabase/migrations/20260928000000_domain_package_01_effect45_01_db02_school_actor_all_authorization.sql.draft` adds a single private `app_private.d1_roll_policy_actor_all_authorized(p_school uuid,p_actor uuid) RETURNS boolean`.
- Owned by existing `schoolos_authz_reader`, fixed `search_path=pg_catalog,pg_temp`, `SECURITY DEFINER` using only previously granted internal permission/Principal/role/scope reads. New EXECUTE goes **only** to `schoolos_student_executor` and `schoolos_workflow_executor`; explicitly revoked from PUBLIC, anon, authenticated and service_role. No new role, grant to client, public RPC, table, RLS policy, D1 operation activation, history/evidence mutations or new event.
- Enforces `app_private.current_principal_id() = p_actor` rather than accepting caller-supplied Principal as proof. Requires nonnull School/actor, LIVE and individually bound Principal with Person identity, enabled `student.roll_policy.change` operation and non-family-safe permission, exact current role–grant–scope–permission links, enabled ALL/DIRECT scope with all campus/class/section/subject targets NULL, active nonfamily role, live assignment/grant/scope validity ranges and no revocation. Does not conflate independent `student.roll_policy.approve` with change authority.
- It does not select P1 policy, prove School existence or School lock itself: those are the separate previously accepted **effect44_01** global Foundation UUID selector and **effect43_01** locked School-date/source preflight. This helper does not acquire SHARED Foundation auth or command receipt locks; a future protected executor **MUST** take them first and recheck actor/current authorization after waits. A function-only call cannot authorize or perform a command.
- `supabase/tests/domain/85_db02_school_actor_all_authority.sql`: rollback-only **19** pgTAP assertions, including private EXECUTE boundary, disabled operation/permission/grant, verified actor positive School ALL, wrong Principal and null School, role/grant revocation, and unchanged Roll Policy/allocation history. Temporary fixture operation-enable is rolled back. It does not activate the live app operation.
- Business manifest and its tooling unit test append #85 **after** DB-02 suites #82 (10), #83 (18), #84 (20), leaving existing #1–80 intact. DB-01 #81 stays on its independently owned draft PR #117. Catalog inventory is pinned to **549 functions / 531 security definers / 392 private functions**; no new public app function or client-private EXECUTE is allowed.

## Source references and separate follow-on gates

| Gate | Existing verified source or owner | Next requirement |
|---|---|---|
| Foundation receipt typing | `effect35_18_family_primary_context_receipt_intent_allowlist.sql.draft` | Shared receipt owner admits exact Roll Policy DIRECT and SUBMIT shapes without removing any previously accepted shape |
| Foundation receipt + replay | `d1_command_receipt_lookup` and profile submit/direct patterns | Read-committed SHA/JCS idempotency, canonical principal binding and replay/source/disclosure proof |
| School P1 version | DB-02 `effect44_01` | Recheck immutable global UUID and route after any School/approval lock wait |
| Current actor's School scope | DB-02 `effect45_01` | Precede with Foundation SHARED auth and current Principal lock, recheck live ALL-scope change grant at APPLY |
| Typed School source | DB-02 `effect43_01` | School-local date, exact source/row lock, INIT or contiguous REPLACE only; no END or scheduling |
| Independent reviewer | DB-02 `effect42_01` | Different Person + configured current reviewer role and `student.roll_policy.approve`; eventually prove real SUBMIT→REVIEW→APPLY |
| DB-01 interface | DB-01 draft PR #117 and main's persisted history owner scanning | Do not rewrite correction/placement allocator or assume #81 was included in #85 runtime |
| Evidence codes | `docs/database/20261020_owner_choices_and_dependency_resolution.md` identifies `D1_STUDENT_ROLL_POLICY` and `student.roll_policy_changed` as **engineering selections** | Register and test exact receipt result/outbox evidence *after* integrated approval; no early event registration |
| External security | PR #101 independent-review request | A non-author reviewer records exact SHA approval or requested fixes; self-review and passing CI are not substitutes |

## Required implementation order after shared integration authority

1. Shared receipt owner adds and independently reviews explicit Roll Policy DIRECT/SUBMIT phase whitelist and locked typed canonical intent; acceptance rejects other phases/lengths and preserves all previous operations.
2. DB-02 implements private typed command entry/pipeline using SHARED auth + receipt prefix, current bound actor School ALL, trusted School/local date and exact Foundation policy UUID. **DIRECT may return SUCCESS only after an atomic policy + allocator effect and evidence writes**; it cannot merely report a successful preflight. SUBMIT may return only a receipt-bound Foundation request with independent reviewers and approved lifecycle transitions.
3. Run authenticated route selection, current-authority revocation, replay, stale policy-version/source, unsafe END/future dates, origin/retained numbers and two genuine PostgreSQL sessions for School REPLACE versus Enrollment placement and grant revocation.
4. Independent review, then separately owner-approved activation and deployment; no merge/production effect is authorized by any passing synthetic fixture.

**Stop condition:** without narrow shared receipt integration ownership and independent review signoff, implementing an externally callable DIRECT/SUBMIT command or bypassing receipt typing would violate the existing protected-command contract.
