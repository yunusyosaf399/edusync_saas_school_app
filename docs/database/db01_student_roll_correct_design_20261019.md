# DB-01 — student.roll.correct: bounded P1 product/design proposal

**Status: PRODUCT DECISION REQUIRED — NOT FROZEN, NOT IMPLEMENTED, NOT ENABLED.**
**Audit date:** 2026-10-19. **Base `main`:** `14fcfa5ba0d97e41264297338b702b23a4d40dbf`.
**Exclusive ownership:** this new DB-01 design document; no shared D1 SQL, roll-policy, Admissions, Foundation, fixture, or tracker modifications.
**Operation:** `student.roll.correct`; existing review permission `student.roll.approve`; existing event `enrollment.roll_corrected`.

## 1. Source of truth and audit findings

Read `AGENTS.md` first, then the master requirements, `DECISIONS_AND_INVARIANTS.md`, database guardrails, security workflow/audit, [readiness #153](153_d1_student_roll_correct_p1_contract_readiness.md), [physical catalog #27](27_domain_package_01_physical_catalog.md), [constraints #30](30_domain_package_01_constraint_matrix.md), [locks #31](31_domain_package_01_concurrency_and_locking.md), [indexes #32](32_domain_package_01_index_review.md), [retention #34](34_domain_package_01_query_retention_offline_review.md), [permissions #08](../security/08_domain_permission_disclosure_catalog.md), and [commands #09](../security/09_domain_checked_reads_and_commands.md).

* `student.roll.correct` is a registered **disabled** P1 operation; its change permission is disabled. No accepted authenticated correction RPC/receipt/APPROVAL operation exists. [Suite #65](../../supabase/tests/domain/65_remaining_student_commands_fail_closed.sql) (38 assertions) deliberately verifies that it stays disabled and that `authenticated` cannot DML/read private roll rows. A catalog entry is not operational authority.
* `app_private.roll_allocations` is the HE truth: `id, enrollment_id, student_id, policy_revision_id, numeric_value, effective_from, effective_until, origin_allocation_id, supersedes_id, correction_reason`, with server `created_at/created_by/ended_at/ended_by`. No HE row-version, no allocation-row `command_receipt_id`, no mutable display string. `enrollments` is PRIMARY placement history and `students.row_version` is a mutable Student projection token. This distinction matters: never fabricate a version field on roll history.
* `roll_policy_revisions` has `PERSISTENT_STUDENT` and `ACADEMIC_CONTEXT` modes; `roll_allocator_states` identifies a pool by policy revision and optional `class_offering_id` (NULL for persistent). It is **not** a generic integer allocator. `roll_allocations` has no physical school ID; derive School and academic ancestry through Enrollment/Offering and immutable policy.
* Existing authenticated `app.d1_place_student_enrollment` creates Enrollment plus server-chosen Roll (accepted suite #61); `app.d1_move_student_enrollment` closes the source Enrollment/Roll, adds successor Enrollment/Roll and carries persistent number (suite #63); `app.d1_end_student_enrollment` closes source Enrollment and Roll at the same exclusive bound (suite #62). Suites #61, #62, #63 accept bounded P0/P1 paths, **not** correction or correction-specific concurrent contention.
* The frozen physical/defensive contract retains old numeric history; cross-Student collision is checked under serialized ancestry/allocator context rather than a current-only unique index. Persistent Student numbers are checked against other Students **across all persistent policy revisions of the School**, independent of effective overlap. Academic-context numbers are checked against other Students in **the same policy revision + Class Offering** when intervals overlap. `I12` (`enrollment_id,effective_from DESC`), `I13` (`student_id,effective_from DESC`), and `I14` (`policy_revision_id,numeric_value,effective_from DESC`) already serve the scans. No new index assumed.
* Final placement allocator (`effect25_23` and later server-owned version correction) uses latest unsuperseded same-Student persistent allocation for carry-forward. Move (`effect26_03`) and END (`effect27_02`) expect precisely one current open Roll associated with an active source. The `effect30_32` cross-row guard validates origin as an earlier same-Student persistent row; when correction has `supersedes_id`, it also rejects unreconciled future divergent persistent allocations. DB-01 must **not** weaken that guard. The original `.sql.draft` is not an executable deployment.

**No audited source freezes RC-01–RC-08.** All recommendations below are proposals for explicit owner sign-off, not existing accepted product decisions.

## 2. RC-01 through RC-08 decision register (owner approval requested)

| Gate | Exact recommended default for first protected correction | Not authorized without approval |
|---|---|---|
| **RC-01: source / stale token** | Target an exact, currently effective, open ACTIVE PRIMARY `enrollment_id` and exact unsuperseded open `source_roll_allocation_id` for that Student. Require `student_id`, `expected_student_row_version`, `expected_enrollment_section_offering_id`, `expected_enrollment_effective_from`, `expected_source_roll_effective_from`, `expected_policy_revision_id` and `expected_old_numeric_value`; source must be unique and uncorrected. Revalidate after locks; source UUID is not guessed from the displayed roll number. | Closed/historical Enrollment edits, source auto-discovery by number, inferred HE version, bypass on a stale/changed source. |
| **RC-02: requested number / namespace** | Authorized staff explicitly requests a **numeric bigint** `proposed_numeric_value` (not auto-selected). Server derives the immutable source policy/mode and namespace: persistent = School-wide across persistent policy revisions; academic = source policy revision plus source Class Offering (all its Sections). Require integer `>= 0` and **recommend** `>= source_policy.start_value`; no formatted input, caller-chosen policy or namespace. Use existing allocator row as serialization/high-water anchor; if manual number is >= `next_value`, advance to number+1 (overflow denies); if below high-water, allow only after full uniqueness/interval check. | Automatic next-number selection, school-wide academic-context uniqueness, changing mode or policy as part of correction, and unstated number range rules. |
| **RC-03: correction date** | **Current-date-only** as first supported form: server `CURRENT_DATE` becomes successor `effective_from` and source exclusive `effective_until`. Require `source.effective_from < CURRENT_DATE`, Enrollment interval covering today, source policy effective today, and no future dated descendant or conflicting allocation. Same-day source start would produce a zero-length source interval: **deny**, not rewrite. No arbitrary supplied backdated/future effective date. | Retroactive correction of issued history, scheduled future correction, end of already-closed history, implicit edit to past reports. |
| **RC-04: retained lineage** | New row has a new UUID, identical Student/Enrollment/policy, `supersedes_id = source.id` and `origin_allocation_id = source.origin_allocation_id` (NULL stays NULL when source was an original persistent allocation). End only source one-way at correction date, then append successor with private nonblank correction reason. `origin_allocation_id` is persistent carry-forward ancestry, **not** the correction predecessor; subsequent MOVE/placement should use the new latest unsuperseded allocation as carried origin. In academic mode origin remains NULL. | Rewriting source numeric/ID/origin, treating origin as supersedes, hard delete, automatic repair of other historical Enrollment rows. |
| **RC-05: no-op / collision** | Require `proposed_numeric_value <> source.numeric_value`; reason-only changes deny. Reject any other Student owning requested number in the persistent School namespace (including past retained persistent allocations), or an effective interval collision in academic policy+Class Offering. Do **not** renumber anyone else. Recheck all candidates after serialized locks; rejected request makes no domain mutation. | Force takeover, silent shifting/renumbering of other Students, acceptance on a mere display-label change. |
| **RC-06: live scope / P1** | `student.roll.correct` uses frozen non-family-safe **ACS = ALL / matching CAMPUS / exact CLASS / exact SECTION** against stored source Enrollment ancestry. Resolve one unambiguous enabled P1 `DIRECT` or `APPROVAL` route for source Campus using existing policy resolution; missing, conflicting, disabled, or stale route denies. In APPROVAL, exact `student.roll.approve`, configured reviewer step and `D1_REVIEWER_ROLE_SCOPE` plus different *Person* are mandatory; all authority is live at review and apply. | FAMILY/Student-self/teacher-role default authority, role name shortcut, generic Principal bypass, auto-apply at final approval. |
| **RC-07: typed evidence / replay** | Canonical hashed intent binds all RC-01 identity/snapshot fields, proposed numeric, server-date boundary, source namespace/policy, nonblank correction reason and operation/receipt protocol. Fixed typed result: source and successor allocation UUID, Student/Enrollment UUID, effective date, source policy/mode, result kind **proposed** `D1_STUDENT_ROLL_CORRECT`; no arbitrary request JSON or client actor. One successful receipt + minimal audit + one `enrollment.roll_corrected` event atomically. Broad event has IDs/action/date/correlation only, no reason/contact/unnecessary old/new number. | New generic receipt engine, new audit/outbox namespace, storage of sensitive private reason in broad payloads, claim that this result kind is already frozen. |
| **RC-08: move/end/races/replay** | Only currently ACTIVE **open latest Enrollment** can be corrected; if later/future Enrollment or a later persistent-roll segment requires reconciliation, deny. SOURCE lock and Student lock serialize correction against MOVE/END. A losing command observes stale source and denies; source cannot end twice or have two successors. Exact successful replay must use retained receipt/source/successor evidence even after a later legitimate correction/MOVE/END, but **must recheck current participant/target authority**, not mutate. | Reopening ended Enrollment, automatic later-history rewrite, unconditional replay based on old authority, last-write-wins. |

**Approval must be explicit for each RC gate.** RC-02 minimum number, RC-03 same-day restriction, RC-04 origin carry semantics, RC-06 route resolution and RC-08 replay disclosure remain materially product/security-sensitive. An owner may reject any recommendation; stop before executable SQL.

## 3. Proposed exact command shape (not a deployed RPC)

Single typed, direct/submit *business* envelope; server derives all ancestry and current policy; `p_idempotency_key` is caller opaque with Foundation namespace binding.

`
student.roll.correct intent v1:
  student_id: uuid
  expected_student_row_version: bigint > 0
  enrollment_id: uuid
  expected_enrollment_section_offering_id: uuid
  expected_enrollment_effective_from: date
  source_roll_allocation_id: uuid
  expected_source_roll_effective_from: date
  expected_policy_revision_id: uuid
  expected_old_numeric_value: bigint
  proposed_numeric_value: bigint
  correction_reason: trimmed nonblank private text
  idempotency_key: fixed validated opaque token
`

The server must compute/verify: verified current Principal, School, Enrollment ancestry and source `placement_state`, policy/mode/start_value/effective coverage, Class Offering namespace, source `origin_allocation_id`/`supersedes_id`/`effective_until`, server business date, allocator ID/high-water, route version/effective selection, complete grant/scope, and any workflow request/reviewer/step context. Do not trust caller-supplied School/Campus/role/actor/mode/allocator/effective date. Stable snapshot facts and action value must participate in the canonical intent/hash. Private reason is in the hashed intent but not broad evidence. `students.row_version` need not increment merely because a child roll history row was appended; the exact source row/snapshot plus Student lock and retained receipt guard prevent stale correction.

For approval, retain this immutable typed envelope in a protected request-bound representation; bind source number, policy and Class/Section context at submission, and recheck all against live state at apply. Final reviewer approval **only changes request state to APPROVED**; a separate `request.apply` transaction performs the effect. The eventual typed checked request read must expose a deliberately reviewed field allowlist to the original currently authorized requester or currently eligible independent reviewer; do not expose raw request JSON or private reason to unreviewed consumers.

## 4. Entities, constraints, temporal reconstruction, and integrity

**Existing only:** `app_private.students`, `enrollments`, `roll_allocations`, `roll_policy_revisions`, `roll_allocator_states`, `school_profiles`, `academic_classes`, `app.campuses`, `app.academic_years`, `class_offerings`, `section_offerings`; and Foundation `principals`, complete grants, operation-policy/review steps, `command_receipts`, `approval_requests`/`approval_applications`, audit and outbox. DB-01 proposes **no new table, Foundation engine, permission code, scope kind, index or new physical namespace**.

**Logical references:**
- `roll_allocations.enrollment_id` → `enrollments.id` and composite (`enrollment_id, student_id`) → (`enrollments.id, student_id`).
- `roll_allocations.policy_revision_id` → immutable `roll_policy_revisions.id`; derive policy School.
- `roll_allocations.origin_allocation_id` → earlier same-Student persistent carry-forward allocation; `supersedes_id` → exact earlier same-Student correction predecessor. They have distinct purposes and may both be populated.
- Enrollment Section → Class Offering → Class/Campus/Year determines academic namespace; Section does not create an independent numeric namespace.
- New correction interval `[CURRENT_DATE, source_enrollment.effective_until)` (in baseline, source Enrollment is open, so to infinity), source interval becomes `[source.effective_from,CURRENT_DATE)`; no overlap, no gap, no zero-length interval, exactly one current roll for the Enrollment.
- Persistent correction must not invalidate later Student allocations; reject if such a later accepted history cannot be reconciled without affecting another operation. Review after corrections of same Enrollment: last **unsuperseded** successor becomes the next eligible source.

**Defensive side:** retain current HE immutability, one-way end-marker, and cross-row checks. In implementation phase compare the *final assembled* trigger/function definitions: appended draft fragments override earlier definitions. Any needed rule refinement is a separately reviewed dependency, not permission to edit shared D1 fragments in DB-01.

## 5. Permissions, RLS, approvals, audit and offline boundaries

Use only existing `schoolos_student_executor` for the narrow domain effect, `schoolos_workflow_executor` for P1 submit/review/apply, `schoolos_read_executor` for a bounded read, existing `schoolos_authz_reader` for evaluator inputs, and `schoolos_evidence_writer` for evidence. Function owners and exact EXECUTE edges must follow existing patterns after independent SQL review; no executor membership chain, schema-owner runtime mutation, direct `authenticated` base table DML, service-role override, or broad READ. Existing D1 tables remain ENABLE/FORCE RLS.

P1 DIRECT: live change permission and one valid DIRECT route; one transaction closes/appends and returns receipt. P1 APPROVAL: separately live requester change permission; independent reviewer has current `student.roll.approve` + configured role/step + matching affected Enrollment scope; request → reviews → APPROVED (no mutation) → explicit apply. Reviewer cannot be requester through a different Principal tied to the same Person. At apply, recheck requester and reviewer live grants, current source, route, policy/allocator, requested value collision and date. Deterministic stale state → `APPROVED → INVALIDATED` plus rejected `request.apply` receipt and no `approval_applications`/success event; transient SQL/deadlock/network failure rolls back, leaving APPROVED retryable. A successful approval application must be bound to exact request + successful typed `request.apply` receipt + exact result/lineage.

Minimize `enrollment.roll_corrected` payload and audit to safe IDs, date/action/correlation, with reason retained in restricted Roll history/approved request; no national IDs, contact info, reason text, sensitive profile or arbitrary values. Read history only via the separately granted `student.roll_history.view` checked surface; mutation permission does not imply historical read/export. Offline can queue only typed intent and snapshot, never offline numeric reservation; synchronize by idempotency and current authorization, reject conflicts rather than last-write-wins.

## 6. Cross-domain dependency matrix / blockers

| Dependency | DB-01 usage | Ownership and activation boundary |
|---|---|---|
| D1 Student + PRIMARY Enrollment (#25/26/27) | Genuine authenticated source, lock compatibility, move/end replay | **Read-only** reference; do not edit placement/move/end SQL or tests. |
| D1 Roll policy/allocator (#08/#09/#10) | Source policy/mode, exact namespace, serialized collision/high-water | **Read-only** reference; roll-policy-change RP-01…RP-07 unresolved; no policy replacement implementation. |
| Foundation identity/authz/receipts/P1 | Live grant/scope, shared auth lock, idempotency, independent review, audit/outbox | Reuse; no duplicated engine, grants, RLS or Foundation migrations. |
| D1 academic ancestry/campus | Derive School/Campus/Class/Section and namespace from stored Enrollment | Existing checked projection and lock helpers; no speculative cross-domain write. |
| Admissions/student.create | Not needed for already accepted test Student/placement fixture | Remains disabled; no synthetic Admissions handoff. |
| Student/family access, finance, transport, photo | No roll correction side effects | Out of ownership; no file/document/payment or FAMILY grant changes. |

**Dependency warning:** some original move/end function bodies acquire Student locks in their context, and placement allocator work is performed later in the effect; check the final assembled prelock wrappers and actual PostgreSQL observed-lock graph before implementing roll correction. The proposed `School → policy → allocator → Student → academic ancestry → child history` order is normative, but a contradictory installed writer must be corrected by its own owner before rollout. Do **not** conceal a lock inversion with an advisory lock invented solely for DB-01.

## 7. Allowed migration order after sign-off (planning only)

1. Owner signs all RC-01…RC-08, including allocator high-water behavior and replay disclosure.
2. Design-review the final concatenated D1 SQL/trigger/ACL/receipt shapes and the existing enrollment MOVE/END/PLACE prelock order; issue a cross-owner integration dependency if a contradiction is found.
3. In a **separate authorized implementation workstream**, add only reviewed new DB-01-specific `.sql.draft` fragments in migration order: private fixed-purpose source/namespace verifier → scoped P1 route + policy bindings → typed locked correction effect and result verifier → DIRECT receipt/evidence → submit/review/explicit apply + checked request read → narrow ACL/owner/grants and structural defense if required. Existing disabled operation stays disabled until independent acceptance gate.
4. Add separately owned rollback-only genuine-authenticated DIRECT and P1 APPROVAL pgTAP suites, negative security cases and observed-lock races. Existing #65 fails closed until an explicit replacement gate is approved; do not edit it in this DB-01 design branch.
5. Exact-head static + disposable local migration + Foundation regression + operation-specific acceptance + genuine two-session race review. Only then request an independent activation authorization; **never** apply Migration 10, remotely deploy, or freeze D1 from this document.

**Gate conclusion: PRODUCT DECISION REQUIRED.** This is a bounded technical recommendation, not approval to enable `student.roll.correct`.
