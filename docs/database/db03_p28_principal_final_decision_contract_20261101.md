# DB-03 P28 — Principal final-decision typed contract (2026-11-01)

**Status: source-only, private, explicitly blocked.** No Principal can yet commit APPROVE, RETURN or REJECT through this candidate. It is not the final Admissions decision operation, and does not enable D1 `student.create`. P28 is stacked on accepted P27 / DB03 #203, not on main or on DB01/DB02 G02 #168.

## What is implemented

The private schema-owner-only `app_private.db03_principal_final_decision_contract(application,expected_version,forward,decision,reason_private)` accepts the *type* of an intended final action: `APPROVE`, `RETURN`, or `REJECT`. It rejects unsupported actions, absent/stale-form versions and missing/blank or control-character reasons. It reads the P27 source preflight and compares the caller's expected application version and selected Forward identity against currently observed values.

For an existing DRAFT application its diagnostic JSON reports `expected_version_matches`, `forward_reference_matches` and `review_inputs_observed` as observations only. **None of these is a grant, authorization token, current forwarded document hash, or commitment to apply a decision.** All results explicitly fix `principal_final_authority_verified=false`, `current_forward_snapshot_verified=false`, `assessment_and_skip_outcomes_verified=false`, `atomic_student_handoff_available=false`, `can_apply=false`, `can_create_student=false`, status `BLOCKED_PENDING_ATOMIC_FINAL_COMMAND`. Unknown/null applications produce no decision result.

The function is `SECURITY INVOKER`, restricted to the internal schema owner. It creates no operation, table, receipt, state transition, public RPC, grant to an authenticated user, migration or hosted deployment. Existing DB03 stage/outcome, Finance denial boundary, and D1 `student.create` fail-closed status remain unchanged.

## Required protected decision contract before enabling actions

- **Authentication and roles:** Principal-only live school leadership role assignment **and a distinct final-admission operation permission** with exact current Campus/School scope; neither possession of a label nor `admission.document.approve` is enough. Reauthorize after all School/app/authority locks, including on receipt replay.
- **Eligibility:** read the exact latest application revision, actual current Forward record and document hash, independently approved original document bytes, verified canonical Person, approved grade/campus/academic year/section with capacity, published intake/assessment stages, and latest immutable SKIPPED/MARKED_PAID/UNPAID fee disposition receipt. `FAILED` test cannot be bypassed; independently approved test-skip must be a separate current source.
- **APPROVE:** must be atomic with final Admissions acceptance, one-time handoff consumption, D1 Person/Student ID/admission number, initial Enrollment/Roll under DB01/DB02 lock order, retained private original file lineage, typed receipt/audit/outbox. Any failure rolls back all effects. The D1 command must not accept a fabricated boolean or an admin-created handoff token. APPROVE remains blocked until this is installed and accepted jointly with DB01/DB02.
- **RETURN / REJECT:** future protected operations must record retained, reasoned, append-only history; distinguish `RETURN` (correctable, no new application) from final `REJECT` with current authority, no partial approval and no Student creation. Neither is implemented by P28.
- **Finance:** `UNPAID` alone may be forwarded and approved under the owner decision; `MARKED_PAID` is *not* Finance settlement. Actual separately required payment clearance may only originate from the Finance authority.
- **Concurrency and replay:** current principal authority revocation, document quarantine/withdrawal, policy or fee disposition replacement, two competing final decisions and School roll-policy REPLACE must be tested with observed database lock waits, exact-key replay, changed-payload conflicts, and no double Student/number/roll/handoff.

## Acceptance included now

- Exactly one new `.sql.draft` internal function, zero side-effecting SQL or permission changes.
- Exact DB03 disposable candidate validator; one injected failed-install transaction and confirmation of absence followed by successful install.
- **20 rollback-only pgTAP assertions**: role ACL/SECURITY INVOKER, unavailable/unknown application, denied unsupported action, denied empty reason and expected version, source binding, no forged final handoff or Student creation.
- Preserve existing P27 (18/18) and Forward (12/12) tests, auth/data/document race coverage, all unrelated workstreams.
- Keep PR Draft until exact-HEAD DB03 disposable CI and D1 static pass; no merging the new SQL to the unmerged DB01/DB02 draft or activating it in production.

**Next real DB03 implementation increment:** obtain a dedicated Principal final-decision operation authority contract and design an authenticated lock/receipt-backed RETURN/REJECT path, with APPROVE *still* blocked pending coordinated D1 atomic handoff. Do not present this private typed validator as working school admissions approval.
