# DB-02 I06 — evidence integration execution checklist (non-activating)

**Status:** implementation planning only; I06 remains OPEN in issue #69.  
**Baseline:** I05 draft PR #147 exact tested SHA `2553e10a1848762f9865038c3efcfdf12b53585a`.  
**Normative evidence contract:** `docs/database/db02_p02_receipt_event_privacy_contract_20261023.md` on P02 PR #142, commit `8ec27ceee49f356d4f1915b95e7d8f7e43b3e45e`. This contract is in a separate draft branch; reconcile explicitly, do not assume it was merged into I05.

## Verified handoff and stop conditions

I05's private Student-owned `app_private.d1_roll_policy_revision_transition` currently calls the command context, locked preflight, source closure/new revision INSERT and schema-owner allocator provisioning, then returns the new UUID. **It does not write a success receipt, audit or outbox event.** The current context intentionally rejects historical success replay. Therefore **do not enable the operation, expose an authenticated entry point, or treat I05 as an atomic protected command**.

I06 must compose the evidence writer **inside the same SQL transaction** as the I05 revision and pool writes; an exception anywhere must roll back source closure, new revision, all new pools, receipt, audit and outbox. Preserve the I01–I05 fixed signatures/ACLs unless an explicitly reviewed integration requires changing them. Do not introduce a client-callable private helper or a generic evidence writer grant.

## Implementation sequence

1. **Inspect exact source schema and shared writer before coding.** Read the latest I05 `effect51_01`, I01 context and PR #122 shared receipt writer, Foundation physical catalog F19/F20/F25/F26, and analogous existing enrollment/family evidence effects. Verify actual column names, constraints, ownership and function signatures. In particular, **roll_policy_revisions has no command_receipt_id FK**. Do not invent one.
2. **Implement fixed, private success-row verifier.** Accept only an actual terminal SUCCEEDED receipt for operation `student.roll_policy.change`, phase DIRECT (and APPLY only after I11 authorization), result kind `D1_STUDENT_ROLL_POLICY`, and result_ref equal to a persisted revision UUID. Compare the exact P02 **14-key** summary, revision ancestry/source closure, selected Foundation P1 UUID, School and actor, and exact set of revision allocator keys, not merely their count. Historical replay must validate its original historical revision, even after later replacements. Enforce uniqueness of success evidence and reject cross-actor/cross-School substitution.
3. **Compose one success evidence set.** Exactly one receipt, one private audit with operation event_type `student.roll_policy.change`, and one outbox event_type `student.roll_policy_changed` version 1, ordinal 1, aggregate_kind `ROLL_POLICY`, aggregate_ref = new revision UUID, aggregate_version = revision number, common correlation and real verified actor. Use the **six-key** safe outbox payload from P02. Use existing approved private writer boundary; do not widen generic event registration or Foundation permissions.
4. **Preserve reason confidentiality.** The nonblank reason belongs only in the immutable private policy revision and in authorized approval request storage where applicable; it participates in the canonical intent hash. Never copy it into receipt summary, audit reason/details/authority_evidence, outbox payload or public projection. Never include Student numeric Rolls or raw approval payload in evidence.
5. **Replay verification.** Same actor + same key + same canonical intent may return only after current authority/route and exact historical row/evidence verification. Same key with changed intent (including reason) must conflict. Replay must not write another revision, pool, receipt, audit or event. An infrastructure exception must not be recorded as a fictitious durable rejection.
6. **Limit scope.** I06 is private DIRECT evidence composition and verifier only; do not implement I07 authenticated endpoint, I08–I10 approval workflow or I11 REVIEW/APPLY shared receipt shapes by implication. P02's APPLY verifier requirements remain blocked on the actual approval-application schema and reviewed I11 phase shape.

## Required disposable acceptance before checking off I06

- New rollback-only pgTAP suite with successful INIT and REPLACE: persisted source/new revision, exact allocator key set, one typed 14-key receipt, one audit and one six-key outbox event, all correlated.
- Same-key exact replay (including after later legitimate replacement) and changed-intent key conflict; zero duplicate effect/evidence; wrong actor/School/result_ref/source/summary/event/ordinal must fail closed.
- Fail midway through evidence write and assert **zero committed** new policy, allocator, receipt, audit and outbox; old source closure also rolled back.
- Privacy canary and ACL/RLS: no raw reason/Student number in audit/outbox/summary; anon/authenticated/service_role/PUBLIC cannot execute private verifier/writer or read private evidence.
- Exact-head D1 static, Foundation local and disposable D1 runtime all green; update manifests to actual observed function/assertion counts, never guess. Record exact commit/run links in issue #69 **only after** verified success.

## External gates remain open

Independent non-author SQL/security review of the shared receipt writer and new schema-owner allocator writer is pending in issue #131. Academic lifecycle provisioning and DB-01/Enrollment integration, two-backend race suites, staged migration/release approval are separately tracked in issue #69. No merge, hosted Supabase SQL, production migration, permission activation or operation enable is authorized by this plan.
