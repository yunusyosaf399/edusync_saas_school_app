# DB-01 — student.roll.correct independent design review, SQL plan and acceptance matrix

**Status: PRODUCT DECISION REQUIRED / DESIGN-ONLY CANDIDATE.** No live operation, runnable SQL, acceptance tests, or activation is delivered here.
**Reviewed source:** `main 14fcfa5ba0d97e41264297338b702b23a4d40dbf` (2026-10-19).
**Companion proposal:** [DB-01 contract](db01_student_roll_correct_design_20261019.md), read together with [readiness #153](153_d1_student_roll_correct_p1_contract_readiness.md).
**Boundary:** two newly created DB-01 documents only. This record is neither an independent executable-SQL audit nor a claim of passing correction-runtime assertions.

## A. Traceable current-state inventory

| Object/source | Audited fact | Open gap for student.roll.correct |
|---|---|---|
| `app_private.roll_allocations`; physical #27, constraints #30, draft `d1_10` | Immutable identity, one-way effective close, retained `numeric_value`, `supersedes_id`, `origin_allocation_id`, private `correction_reason`; no HE version or receipt FK; FORCE RLS | No protected corrected-row append command/result verifier/approved P1 API |
| `roll_policy_revisions` and `roll_allocator_states`; #27/#30/#31/#32 | Persistent School-wide versus academic per policy-revision/Class Offering; two partial allocator uniqueness keys; high-water counter | Proposed manual value policy, collision/time boundaries and counter advancement need owner approval |
| `students`, `enrollments`, Section/Offering/Year/Campus; #27/#30 | Active PRIMARY source, Student row version, Enrollment section ancestry and half-open history | Exact source snapshot contract and same-day eligibility need owner approval |
| `effect25_23` / later `effect35_15`, suite `61_student_enrollment_place_p0_initial_roll.sql`, acceptance #147 | Server-owned first roll; latest unsuperseded persistent lineage; authenticated P0 placement verified | No manual correction tests; do not assume allocator always acquires needed locks when invoked from other effects |
| `effect26_03`, suite `63_student_enrollment_move_p1_direct_section_history.sql`, acceptance #149 | Source Roll/Enrollment closed together; successor Enrollment/Roll; persistent roll carry-forward; Section move DIRECT | Not a correction; move-vs-correction observed-lock coverage missing |
| `effect27_02`, suite `62_student_enrollment_end_p1_direct_history.sql`, acceptance #148 | Exact current source Roll UUID/from date, one-way synchronized END, durable replay | End-vs-correction observed-lock coverage missing |
| `effect30_32_crossrow_campus_local_rename.sql.draft` | Roll origin is same-Student earlier persistent ancestry; future divergent persistent successors can reject; academic collision by stored policy+Class Offering/interval | Must exercise the **final assembled** trigger, not presume any single earlier fragment is final |
| `65_remaining_student_commands_fail_closed.sql`, readiness #151/#153, `156_d1_four_student_operation_decision_register.json` | Registered `student.roll.correct` operation/permission disabled and raw DML prohibited; 38 fail-closed assertions | Must stay unchanged until a separately accepted implementation replaces the disabled-state expectation |
| `08_domain_permission_disclosure_catalog.md` / `09_domain_checked_reads_and_commands.md` / retention #34 | Existing `student.roll.correct` / `student.roll.approve` (non-family-safe ACS), P1, selected `enrollment.roll_corrected` | No approved typed DIRECT/APPROVAL handler, review request read, fixed result kind or receipt binding |

Scope of review: read-only contract/accepted-test/source inspection. No independent runtime/PostgreSQL execution was performed for this design PR. Earlier suites' published passing numbers are **historical evidence for their own operations only**.

## B. Owner decision sign-off sheet

Mark one of `APPROVE`, `REVISE`, `REJECT` for **each** recommendation in the companion design, not one blanket implementation authorization.

| ID | Owner-facing question and recommended answer | Status |
|---|---|---|
| RC-01 | Correct **only** a named current open Roll attached to a named current ACTIVE PRIMARY Enrollment, bound to Student version + source IDs/dates/policy/old numeric? | **PENDING** |
| RC-02 | Staff explicitly chooses a valid numeric value; server derives persistent-vs-academic namespace and serializes allocator/high-water (including manual values below current high-water after collision check)? | **PENDING** |
| RC-03 | Start with **today-only** effective correction (source started before today); reject backdated, future and same-day zero-length source corrections? | **PENDING** |
| RC-04 | `supersedes_id=source.id`, `origin_allocation_id` inherited unchanged for persistent carry-forward, new UUID and separate nonblank private reason? | **PENDING** |
| RC-05 | Reject equal numeric/reason-only changes and collisions, without modifying another Student's allocated number? | **PENDING** |
| RC-06 | Require live ACS authorization and one exact P1 route for source Campus; APPROVAL reviewer is different Person with current review permission, configured role/step and `D1_REVIEWER_ROLE_SCOPE`? | **PENDING** |
| RC-07 | Use proposed fixed result `D1_STUDENT_ROLL_CORRECT`; receipt/approval binding, restricted reason and minimized `enrollment.roll_corrected` event; same-key hash includes entire intent? | **PENDING** |
| RC-08 | Only open latest Enrollment; reject dependencies requiring future-history reconciliation; reauthorize historical-success replay after a MOVE/END/later correction? | **PENDING** |

**No RC decision is represented as signed or frozen.** Source docs explicitly leave RC-01…RC-08 open. Owner approval is the prerequisite for further SQL work.

## C. Proposed validation/state machine (non-executable pseudocode)

1. **Before any D1 lock:** enforce `READ COMMITTED`, obtain Foundation transaction SHARED authorization lock `(71001,1)`, server Principal, fixed operation enabled/permission/route, receipt namespace advisory lock and canonical intent comparison. Replays first pass **current** authorization for exact target/participant; no stale JWT or cached scopes. The public command must not permit caller actor, role or resolver parameters.
2. **Preflight discovery before typed row locks:** fetch immutable source IDs/academic path/School/policy/allocator and optional related future history, without relying on stale scan as final authority. If dependency parents cannot be discovered before higher-rank locks, restart with complete set rather than acquire lower rank late.
3. **Global typed lock order:** `School (if needed) → roll policy rows → roll allocator rows (UUID order) → Student → Academic Class → Campus → Academic Year → Class Offering → Section Offering → child Enrollment/Roll history (stable order)`. Receipt/Principal/approval locks use their existing Foundation prefix. Re-read source, grants, route, policy and every relevant current/future allocation **after** waiting. Check effective-date policy coverage and source currentness.
4. **Fail closed:** stale Student/source/enrollment facts, non-ACTIVE Placement/Student, missing/ambiguous route, invalid new number, policy/namespace mismatch, zero-length history, existing competing next correction, later persistent dependents, or cross-Student collision must produce no success evidence.
5. **DIRECT effect:** update source `effective_until/ended_at/ended_by` exactly once under the HE guard; append new allocation with same Student/Enrollment/policy, correct `supersedes_id` and inherited origin; do not update source `numeric_value`, Enrollment row/version, unrelated allocation or School policy.
6. **Transaction evidence:** typed terminal `SUCCEEDED` receipt referencing immutable result shape; minimal audit and one selected outbox event. If in APPROVAL mode: independent review → `APPROVED` (no effect) → separate locked apply + successful `request.apply` receipt and exact same-domain result/application linkage. Deterministic stale after APPROVED → `INVALIDATED` with rejected apply receipt, no domain mutation/event/application; unexpected DB failure rolls back and remains retryable.
7. **Terminal replay:** compare operation, actor participation, canonical key+intent and retained exact predecessor/successor/result binding. Do **not** demand that the successful successor is still open; later legitimate correction, MOVE or END does not erase an earlier success. Recheck *current* permissible disclosure and deny if grant/participant scope is revoked. No duplicate closure, allocator advancement, receipt, audit or outbox event.

**Lock-risk prerequisite:** `effect26_02` and `effect27_02` have Student-locking context helpers, while `effect26_03` allocates successor Roll after taking source Student/history context. `effect25_19` introduces a School/policy/allocator prelock helper, but DB-01 has **not** proven from an integrated runtime lock graph that all final MOVE/END paths universally acquire lower-order allocator anchors first. Before correction is runnable, independently trace the final function call graph and demonstrate no Student→allocator versus allocator→Student inversion. Any fix belongs to the upstream owning task, not this design branch.

## D. Positive and negative acceptance matrix — implementation phase only

Each case requires **real `SET ROLE authenticated` protected RPCs** and a genuinely placed Enrollment+Roll created through accepted `app.d1_place_student_enrollment`. Privileged setup may create School, policy, scopes, Student/academic fixture parents, but **must not seed fake successful correction/Enrollment/Roll history**. Use transaction-local fixtures with `SET CONSTRAINTS ALL IMMEDIATE` and unconditional `ROLLBACK`.

| Group | Test ID | Condition / expected outcome |
|---|---|---|
| DIRECT success | R01 | Current ACTIVE PRIMARY Enrollment with retained source roll and complete ALL grant + effective DIRECT P1; custom available integer; one new Roll, source ends today, same Enrollment/Student/policy; no Student version bump or Enrollment mutation. |
| DIRECT success | R02 | Persistent School-wide number, then new legitimate Section MOVE later; new MOVE successor uses corrected number and accepted latest unsuperseded source origin. |
| DIRECT success | R03 | Academic-context number reused in *different* Class Offering is allowed; duplicate in same policy+Class Offering for overlapping other Student denies. |
| DIRECT success | R04 | Two corrections on successive dates (each after latest row's start); each successor points directly to former head via `supersedes_id`; origin remains persistent ancestry, no branch/fork. |
| Input/source reject | R05 | Wrong Student ID, wrong Enrollment ID, wrong Roll ID, wrong source effective-from, wrong Section, old numeric or policy ID; deny with zero mutation/evidence. |
| Input/source reject | R06 | Student expected version stale, Student no longer ACTIVE, Enrollment closed/not PRIMARY/not latest, Roll already ended/superseded/missing; deny. |
| Temporal reject | R07 | Attempt on source started today (zero-length), future-effective request, backdated date, outside Enrollment or policy interval, later conflicting persistent allocation; deny. |
| Numeric reject | R08 | Same numeric/reason-only change, NULL/noninteger/negative/under-minimum/overflow value, whitespace-only reason, collision persistent across policy revisions/Students; deny. |
| Numeric retain | R09 | Old persistent value remains in historical row; another Student cannot take it under persistent School-wide uniqueness, even after correction. |
| Numeric allocator | R10 | Manual number above `next_value` adjusts high-water once; later P0 allocation cannot issue same number; manually chosen free number below high-water never decreases counter; rollback leaves allocator unchanged. |
| Namespace policy | R11 | Other Student same academic numeric in different policy/Class Offering is not a collision when namespace differs; a conflicting overlap in same namespace denies. |
| Scope/role reject | R12 | No grant, expired/revoked grant, wrong Campus/Class/Section, OWN/ASSIGNED/FAMILY/student-self role, disabled command/permission; deny without disclosure. |
| P1 route | R13 | Missing policy, ambiguous or disabled route, wrong policy Campus, route changed after submit, or DIRECT call under APPROVAL-only policy; deny. |
| APPROVAL success | R14 | Valid submit/independent review/explicit apply; APPROVED alone makes no Roll row; apply one successor, receipt/application link, one event; requester/reviewer different People. |
| APPROVAL reject | R15 | Reviewer missing current `student.roll.approve`, lacks configured reviewer role/scope/step, same Person via another Principal, wrong Student ancestry; deny. |
| APPROVAL stale | R16 | After approval, revoke requester/reviewer permission, change P1 route, end/move source, change source number/lineage, or occupy requested value; expected bounded `INVALIDATED` + rejected apply receipt and zero mutation/application/event. |
| APPROVAL transient | R17 | Unexpected deadlock/lock timeout/SQL failure rolls back and retains APPROVED state for retriable apply; do not misclassify infrastructure failures as INVALIDATED. |
| Idempotency | R18 | Same exact DIRECT/submit/apply key+intent returns prior durable result and evidence counts unchanged; changed reason/number/target with same key conflicts. |
| Terminal history replay | R19 | After legitimate later correction/MOVE/END, replay first successful request returns identical *historical* source/successor IDs if the actor is still currently authorized; no requirement original row remain current. |
| Terminal security replay | R20 | Grant revoked or current target/participant context changed beyond actor's permitted scope; replay denies even if durable receipt exists. |
| RLS/ACL | R21 | `authenticated` cannot directly SELECT/INSERT/UPDATE/DELETE `roll_allocations`, `roll_allocator_states`, or private workflow/receipt details. No broad owner or service-role shortcut. |
| Evidence | R22 | Exactly one permitted `enrollment.roll_corrected`; raw correction reason and unnecessary numeric/identity values absent from broad audit/outbox; private checked-read projection bounded. |
| Regression | R23 | Existing #61 placement, #62 end, #63 move and #65 fail-closed baseline remain unchanged until a separately authorized activation/test replacement; Foundation 220 SQL regressions remain unchanged. |

Approval-mode tests must cover present-authorization rechecks on every request/reviewer/apply/replay path; current permission is not inferred from role label or from a historical reviewer assignment.

## E. Required real two-session PostgreSQL contention schedule

An actual race passes **only** when logs show concurrent independent backend sessions, a blocked lock wait or measured contention, both terminal outcomes, and immutable post-race history/receipt/event counts. Sequential calls are not a substitute.

| Race | Session A | Session B | Expected invariant |
|---|---|---|---|
| C01 correction/correction | Correct source X to N1 under School/allocator/Student locks; hold lock | Attempt X→N2 or same X→N1 under different idempotency key | One successor to X; loser stale source denies; no fork or duplicate outbox. |
| C02 correction/MOVE, correction first | Correct X and hold Student lock | Move same Enrollment source Section A→B | B waits; re-reads corrected open head; MOVE uses new current number once or safely denies if its expected source snapshot changed; no contradictory successor. |
| C03 MOVE/correction, move first | Move/close Enrollment and source Roll; hold lock | Correct now-ended source | B waits then denies stale/closed source; retained move history untouched. |
| C04 correction/END, correction first | Correct current Roll, hold lock | END same Enrollment with expected source Roll snapshot | END waits then either uses revalidated new current Roll with correct expected facts, or stale-denies; Enrollment/Roll end dates remain aligned. |
| C05 END/correction, end first | END closes Enrollment and Roll; hold lock | Correct old source | B waits then denies; no correction of ended Enrollment. |
| C06 correction/correction across Students | Propose same persistent School number, or same academic policy/Class Offering overlapping interval for two Students | Competing other Student proposes identical number | Serialized allocator/School anchor: at most one accepted conflicting claim; nonconflicting different academic namespace may coexist. |
| C07 approval/apply vs grant revoke | Approved request pending; apply holds shared Foundation authz lock | Revoke one required requester/reviewer grant using Foundation exclusive lock | Apply-first commits before revoke; revoke-first causes deterministic invalidation. No post-revoke new successful correction. |
| C08 approval/apply vs policy route flip | Apply approved DIRECT/APPROVAL-context intent | Change effective Foundation P1 route | Apply-first or route-change-first revalidation; stale approval cannot sneak through wrong route. |
| C09 correct/allocator P0 placement | Manually correct to available high numeric while holding allocator | Concurrent P0 placement using allocator | No duplicate numeric assignment; next_value reflects committed manual reservation and automatic allocation; rollback does not consume value. |
| C10 replay after later MOVE | Successfully correct; simulate client lost reply, then move | Retry original exact idempotency key | Historical exact result returned only after live authorization; no new correction/receipt/event. |

**Lock graph audit** (mandatory): inspect final assembled School/policy/allocator prelock positions in existing MOVE/END/PLACE wrappers, and use `pg_stat_activity`/`pg_locks` to establish the blocking backend/row/advisory lock. A deadlock indicates failed integration, not passing acceptance. If a move result helper itself silently reselects a source roll, ensure its immutable receipt/payload binding prevents double consumption.

## F. Acceptance and delivery sequence / stop boundary

| Gate | Work | Evidence required | Current status |
|---|---|---|---|
| DB-01-A | Source/readiness/RC-01…RC-08 design | This new design + independent review, links to source | **Prepared, not owner-approved** |
| DB-01-B | Owner freezes every RC decision | Explicit signed decision record, especially temporal, allocator, origin, reviewer, replay | **BLOCKED** |
| DB-01-C | Integration proof | Final assembled SQL dependency, lock/prelock graph, source guard and index compatibility | **NOT STARTED** |
| DB-01-D | SQL design reviewed then implemented on independent task branch | Typed SQL fragments only within separately assigned ownership; exact RPC signatures, roles, receipts | **NOT AUTHORIZED** |
| DB-01-E | Genuine protected tests/races | R01–R23 and C01–C10, exact-head CI, no Foundation regression | **NOT AUTHORIZED** |
| DB-01-F | Independent activation | Approved new operation enable/permission grant plus migration release decision | **NOT AUTHORIZED** |

**Explicit non-claims:** no new SQL; no runtime testing; no hosted Supabase; no D1 migration activation; no claim `student.roll.correct` is runnable; no change in accepted operation count, 97/322/36 manifests, Foundation 1–9, test #65 or the central acceptance tracker; no shared integration file touched.

**Final verdict: PRODUCT DECISION REQUIRED.** DB-01 stops here and requests explicit owner decisions RC-01 through RC-08 before implementation.
