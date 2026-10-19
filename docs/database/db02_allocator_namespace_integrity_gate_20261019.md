# DB-02 — Allocator namespace integrity and policy transition evidence gate

**Status:** PRODUCT DECISION REQUIRED; policy/allocator design ready for owner review, **not** implementation or activation approval.  
**2026-10-19**; branch `db/db-02-roll-policy-design`, preceding HEAD `613b6cc1ffd73fc1b46a02c13a13de82a8bb90ef`; reviewed `main e526de3fd4668483623ef52cccc34d38d893c249`; PRs [#101](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/101), [#100](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/100), [#102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102). This document is **DB-02-owned evidence only**. No shared SQL, tests, Foundation, Admissions, roll correction, existing placement or deployment files changed.

## 1. What was inspected and the final-definition caveat

Read `AGENTS.md` first, then DB-02 [design](db02_student_roll_policy_design_20261019.md) and [review](db02_student_roll_policy_review_20261019.md), [readiness #127](127_d1_roll_policy_p1_implementation_readiness_and_invariant_review.md)/[#154](154_d1_student_roll_policy_change_p1_contract_readiness.md), physical #27, constraint #30, locking #31, retention #34, permissions #08, command matrix #09, DB-01 PR #100 (RC gates still unsigned), and DB-03 PR #102 (Admissions SC gates still unsigned).

**Actual ordered SQL evidence:**

* `supabase/migrations/20260928000000_domain_package_01.sql.draft`, `app_private.d1_p1_route(text,uuid)`: selects exactly one active effective Foundation approval-policy version; `(p.campus_id IS NULL OR p.campus_id=p_campus_id)`; DIRECT returns `DIRECT`; APPROVAL requires active reviewer role and contiguous positive steps using `D1_REVIEWER_ROLE_SCOPE`. Importantly, `o.enabled` is mandatory and `o.requires_approval` must be false. With `p_campus_id=NULL`, **only School/global NULL-Campus policy versions can match**. With policy operation disabled, **no route currently resolves**.
* `...effect25_19_enrollment_place_school_anchor.sql.draft`: `d1_enrollment_place_lock_school(uuid)` locks `school_profiles` `FOR UPDATE`; `d1_enrollment_place_prelock_roll(uuid,date)` re-reads stored Section/Offering ancestry *after* School lock, requires exactly one policy whose half-open interval covers effective placement date, locks policy, then corresponding NULL persistent or Offering-specific academic allocator. A missing pool or policy fails closed.
* `...effect35_15_enrollment_place_allocator_server_version.sql.draft`: last identified `CREATE OR REPLACE FUNCTION app_private.d1_enrollment_place_allocate_roll(uuid,uuid,uuid,uuid,uuid,date)`. It selects policy by placement date, chooses most recent **unsuperseded same-Student** persistent origin, rejects later unsuperseded same-Student allocations for backdated placement, and for new persistent numbers starts at `GREATEST(alloc.next_value,pol.start_value)`. Its collision `WHILE EXISTS` scans other Students across persistent revisions **but filters out any allocation having a successor**. Academic branch scans same policy revision and all Sections of the Class Offering for overlapping candidate intervals. It updates only `next_value`, letting the M-row trigger own `row_version/updated_at`.
* `...effect26_03_enrollment_move_effect.sql.draft`, `d1_enrollment_move_effect(...)`: closes source Roll and Enrollment, creates successor Enrollment and calls `d1_enrollment_place_allocate_roll(...)`. This fragment alone is **not** proof that all final MOVE entry-point prelocks acquire School/policy/allocator before Student; inspect final wrappers/overrides and observed-lock tests before activation.
* `app_private.roll_policy_revisions`: immutable school+sequential revision, mode/start/date/reason/predecessor and one-way half-open close, no HE `row_version` or `command_receipt_id`. `roll_allocator_states`: per revision and nullable Offering, with distinct partial unique predicates. `roll_allocations`: immutable Student/Enrollment/policy/numeric/history/origin/supersedes; policy switches do not rewrite it.
* Structural suite `38_student_roll_policy_retained_history_defensive_invariants.sql` demonstrates owner-fixture HE constraints, not protected change. Suite `65_remaining_student_commands_fail_closed.sql` protects disabled command/permission. Existing placement/move/end acceptance is **not** a policy-transition collision test.

**Evidence boundary:** these inspected sources identify the latest allocator definition available by exact path and the base P1 resolver. A full automated ordered-function-resolution manifest, final defensive trigger body and running two-session PostgreSQL reproducer were **not executed** in this design-only task. Therefore conclusions distinguish demonstrated SQL selection predicates from end-to-end accepted database integrity.

## 2. Task A — historical numeric ownership: real mismatch versus proved failure

### Confirmed source-level mismatch

The frozen concurrency contract [#31](31_domain_package_01_concurrency_and_locking.md) describes **School-wide persistent numeric ownership across all PERSISTENT_STUDENT policy revisions**, not merely numbers in currently open unsuperseded heads. DB-01 PR #100 independently proposes reserving historical corrections; its RC-02/RC-05 approvals are pending.

In `d1_enrollment_place_allocate_roll`, the *origin lookup* condition
`NOT EXISTS (SELECT 1 FROM roll_allocations x WHERE x.student_id=p_student AND x.supersedes_id=r.id)`
is appropriate when selecting the same Student's latest corrected head rather than an obsolete predecessor.

But the *other-Student collision check* separately uses
`NOT EXISTS (SELECT 1 FROM roll_allocations x WHERE x.supersedes_id=r.id)`.
That can remove **a different Student's historically assigned numeric value** from the candidate set when the historical allocation was corrected. This is an actual **selection-logic conflict with the documented non-reuse invariant**, not a merely speculative code pattern.

### Concrete scenario

Assume a duly initialized persistent revision with counter high-water 1001 for the example, and School S:

1. Student A was assigned numeric **1001** in historical allocation `a1`.
2. In a separate future approved DB-01 correction (not currently enabled), Student A's `a1` is ended and successor `a2` contains **1002**, with `a2.supersedes_id=a1.id`.
3. A later persistent policy revision creates a **new** counter pool with `next_value=1001`, and Student B is first placed. The allocator examines `candidate=1001`.
4. The other-Student candidate scan sees `a1` but excludes it because `a2` supersedes `a1`; `a2.numeric_value=1002` is different. Thus this **function's WHILE loop does not reject 1001** and it attempts insertion for B.
5. **Not proved from the inspected function alone:** the final `d1_guard_crossrow`/other structural trigger might reject this INSERT; if it does, the end-user result is failed placement rather than committed duplicate, but the allocator still did not safely skip to the next unowned number. If trigger also uses only unsuperseded heads, a permanent ownership violation becomes possible after an approved correction and counter reset. The corresponding mutator is currently disabled, so this is **latent**, not a demonstrated live exploit.

### Two policy alternatives — owner decision RP-03

**A. Permanent historical ownership (recommended if #31 remains authoritative):** when allocating a number to a *different* Student under persistent mode, scan **all retained persistent allocations of School S** for numeric equality, ignoring supersession/end flags for ownership; keep same-Student current origin selection limited to latest applicable unsuperseded head. New revision counter starts at at least configured start and skips all historical other-Student numeric claims under School lock; optionally derive a monotone high-water from all prior committed persistent allocators with overflow checks, but **never use `MAX()+1` as a concurrent allocation substitute**. A manual DB-01 correction must reserve its successor number and leave the original owner claim reserved. Adopt this only after explicit owner sign-off and DB-01 alignment. Test A: A 1001→1002, B requests automatic assignment with new counter 1001 => **not** 1001; B cannot obtain 1001. Check guard and algorithm agree.

**B. Reuse after corrected-away history (not recommended without explicit new privacy/business decision):** freeze a narrower ownership policy where only eligible latest allocation heads reserve numbers and historical displays are distinguished by contextual effective intervals. That intentionally relaxes #31, may permit different Students sharing a *formerly issued permanent number*, and requires a new approved decision/ADR, joined correction/display/reprint rules, corresponding trigger checks and rigorous equality/overlap rules. Do not merely remove the source invariant or accept the current filter as approval. Test B: precisely specified reuse window and history visibility, duplicate display rules, and incompatible persistent claims fail as frozen.

**Current guarantee:** by the actual inspected allocation function, an unsuperseded other-Student persistent claim is skipped and the historical `roll_allocations` record is not intentionally changed by policy selection. A superseded different-Student historic claim **is not skipped by this candidate loop**. **There is no accepted authenticated DB-01 correction path yet**, and no demonstrated successful duplicate COMMIT. Must inspect final defensive trigger and reproduce in disposable local PostgreSQL before calling committed collision a confirmed defect.

**Overflow/availability:** candidate increment and `candidate+1` require explicit near-bigint-max validation. Policy mode/revision counter uniqueness does not itself prove numeric uniqueness across revisions.

## 3. Task B — precise policy transition matrix (proposed, not frozen)

Notation: `PS` = persistent Student; `AC` = academic context; `H(S)` = all historic persistent numeric claims across revisions of School S (recommended reservation set); `C(R,O)` = policy revision R plus Class Offering O. New revision always creates a **new pool**; old `roll_allocations` never change. Replacement boundary `t` is exclusive on old and inclusive on new.

| Transition | Policy/history action | New allocator initialization and high-water | Numeric/collision and pending placement treatment |
|---|---|---|---|
| 1 No policy → PS | `INIT` revision 1 only if never initialized, from approved server date | One `(r1,NULL)` pool, counter at configured start, advance/skip all `H(S)` if unusual retained history exists (normally none) | New Student receives unowned persistent value; existing Student origin reuse if valid; lack of initialization causes placement deny. |
| 2 No policy → AC | `INIT` revision 1 | One `(r1,O)` pool for each eligible Offering **or** lazy pool create while School locked (choice must freeze; current prelock *requires an existing pool*) | Check same R+O across all Sections; independent Offering counters valid. |
| 3 PS → PS | Close rN at t, add rN+1, same mode | New `(rN+1,NULL)`, starting at configured new minimum, with monotone prior high-water recommended and full `H(S)` skip | Carry existing Student's latest accepted persistent numeric through revision; distinct Student cannot reclaim former A number. |
| 4 PS → AC | Close PS at t, add AC successor | AC `(rN+1,O)` pools start at new AC start for every eligible Offering | Earlier PS allocations stay referenced to PS revision, not rewritten. At new placement in AC choose C(R,O); number may equal historic PS number because namespace differs. |
| 5 AC → PS | Close AC at t, add PS successor | New persistent NULL pool, start + School-wide historical persistent ownership/reserved counter high-water | Whether a Student who had PS number before the intervening AC period **must** regain that same numeric is RP-03 owner gate; current function selects latest unsuperseded PS allocation regardless of intervening AC, if no incompatible future PS allocation. |
| 6 AC → AC | Close old AC at t, add new AC revision (even same mode) | Entirely new per-(revision,Offering) pools; optional inherited high-water is **not required** by currently frozen AC namespace | Same numeric may repeat between distinct revisions/Offerings by design; no repeat within one active (revision,Offering) interval for different Students. |
| 7 END | One-way close exact active open head; no successor | Do not delete/recycle any pool/counter; no new pool | Policy lookup returns 0 in gap; placement denies. Whether END is allowed if it strands future accepted placement is RP-02 owner gate (recommend deny conflicting END). |
| 8 REPLACE vs placement | School lock serializes, then exact effective policy selection after wait | Create successor pool(s) atomically with replacement *before* releasing School lock | If placement wins first with future-effective date, later replace cannot silently alter its accepted policy; deny incompatible replacement. If replace wins, placement sees new policy and pool. |
| 9 PS → AC → PS | Two adjacent retained boundaries r1→r2→r3 | New persistent revision 3 pool, not old r1 counter; initialize respecting all retained PS owners and previous high-water | Same Student PS carry-forward is possible from r1 via latest unsuperseded PS lineage, subject to frozen RP-03 policy; intervening AC numbers do not become school-wide PS ownership. |
| 10 Committed future enrollment crosses boundary | Historical Enrollment/Roll remains assigned to exact original policy revision; placement time must select unique applicable policy | No retroactive correction/renumbering of committed allocation as part of policy change | Pre-scheduled rN+1 must be validated against any existing future accepted Enrollment; deny replacement/END that would leave a policy/roll mismatch, unless separately approved coordinated migration exists. |

**Mandatory date semantics:** `effective_from <= placement_date < effective_until` (unless NULL); no "today's current policy" shortcut when placement effective date differs. An Enrollment active across a boundary does **not** automatically acquire a new roll; the original effective allocation/history remains retained unless a separately approved Enrollment operation changes placement and allocates as of its accepted effective date. A policy change must not split, rewrite or silently replace that allocation.

**Important implementation dependency:** the final `d1_enrollment_place_prelock_roll` requires an existing correct pool and returns `D1_ENROLLMENT_PLACE_ROLL_ALLOCATOR_MISSING` otherwise. A DB-02 policy command that writes only revisions without provisioning required allocator rows will make subsequent placements fail. Lazy provisioning cannot be assumed without a reviewed DB-03 prelock change.

## 4. Task C — School-wide P1 authorization and evidence readiness

**Frozen:** `student.roll_policy.change` and `student.roll_policy.approve` are distinct non-family-safe `ALL / DIRECT` school permissions. FOUNDATION complete grant+role+assignment+scope chain, verified current Principal, independent reviewer Person, configured reviewer role/step and live `D1_REVIEWER_ROLE_SCOPE` are mandatory. Foundation authorization administration uses global lock `(71001,1)` EXCLUSIVE; candidate D1 command SHARED. `student.roll_policy.view` is read only.

**Observed actual resolver behavior:** `app_private.d1_p1_route(text,uuid)` includes the roll policy operation in its allowlist. It filters active, effective `approval_policy_versions` on `(p.campus_id IS NULL OR p.campus_id=p_campus_id)`, and requires **exactly one**; it accepts only enabled operation contracts with `NOT o.requires_approval`. For School target call `p_campus_id=NULL`, only NULL-Campus global policies match. This establishes a **viable no-fabricated-Campus candidate**; it does **not** authorize execution today because operation remains disabled and no public protected command exists. If School has both Campus policies and one global policy, NULL input naturally excludes Campus-specific ones. Owner must freeze that the School target always routes via NULL and that a global version is required; do not substitute first Campus.

**DIRECT candidate:** fixed typed operation and complete live ALL authority, School+source/policy/allocator locks, one effect transaction and receipt/audit/approved event. Missing, ambiguous or disabled policy denies.

**APPROVAL candidate:** submit immutable typed old policy ID/revision/mode/start/from/until snapshot plus new action/mode/start/date/reason and validated key; independent reviewer with exact `student.roll_policy.approve`, configured active role, correct step, matching live ALL authority, distinct Person. Final APPROVE never applies. Separate `request.apply` rechecks source head, effective date, route/policy version, requester and reviewer authority, counter/commitment state. Deterministic stale => bounded `APPROVED → INVALIDATED`, rejected apply receipt, no domain mutation or application/outbox; transient SQL failure rolls back and remains APPROVED. Checked participant read must only include explicitly approved typed old/new details, no raw workflow JSON/private free-text reason to unrelated readers.

**Receipts/evidence unresolved:** HE policy revision has **no** receipt FK. Proposed result binding via Foundation receipt fixed kind and immutable policy revision ID + exact old/new revision/interval evidence, backed by a fixed application guard. Required exact literal `result_kind`, broad audit field allowlist, event code, and restricted reason disclosure are **RP-06 owner decisions**. The older physical design #27 mentions `student.roll_policy_changed`, but later #127/#154 and matrix #09 intentionally leave event unspecified. **Do not register, emit or silently assume this event.**

## 5. Task D — owner-ready RP-01…RP-07 decision matrix

All recommendations below are **NOT frozen**, including an explicit policy choice to permanently reserve historically superseded numeric claims.

| Gate | Recommended answer with exact existing evidence | Alternative / risk / dependency / required implementation and acceptance |
|---|---|---|
| **RP-01** source/actions | INIT only for no retained revision, REPLACE and END require exact open current School policy ID+revision+immutable mode/start/from/until snapshot; server issues successor +1; no fabricated HE version. HE constraints in #27/#30/#127. | Bootstrap-only INIT, disallow END, or permit scheduling. New fixed typed RPC and school/snapshot checks required; test concurrent same-source updates and no-op. |
| **RP-02** time | Today-only server date; REPLACE contiguous at t, no backdates/future revision scheduling for first release; reject same-day closure and unsafe future commitments/END gaps. `effective_from`, one-way `effective_until` and current as-of allocator in #127/`effect25_19`. | Scheduled future policies require additional planner/resolver, future commitment revalidation, conflict/priority and historical correction rules; risk zero-length/reassignment. Test boundaries t−1/t and future accepted placements. |
| **RP-03** ownership | Distinguish same-Student latest *usable* origin from School-wide **all retained** PS ownership for different-Student collision; reserve historic corrected-away numbers, seed revision-specific persistent counter without resetting safety; PS reentry carries latest approved PS Student number, AC counters per R+O. #31 conflicts with `effect35_15` candidate predicate. | Permit reuse only after explicit ADR changing permanent identity semantics; risk duplicate Student-facing roll in history. Requires DB-03 allocator/defensive-trigger consistency and DB-01 correction agreement; test A1001→1002, B1001, PS→AC→PS, counter rollback/overflow. |
| **RP-04** School P1 | Call existing `d1_p1_route('student.roll_policy.change', NULL)` only after activation, require single effective NULL-Campus global version and ALL change/review grants; no fabricated Campus. Exact resolver filters confirmed in master draft. | New explicit School policy selector if Foundation global semantics prove unsuitable; risk wrong campus-derived route. Requires Foundation owner review, policy version binding/rechecking; test NULL vs campus and absent/ambiguous routes. |
| **RP-05** participants | DIRECT or submit→review→separate apply based on exact P1 route; requester/reviewer different People and live ALL grants; signed typed source/target snapshot and bounded checked participant read; stale deterministic invalidation. #127/#154 + Foundation P1 pattern. | Single-phase or generic JSON patch violates reviewed workflow and privacy; exact review projection and result/error codes remain owner gate. Test revocation-first/apply-first, self-review, route drift. |
| **RP-06** evidence | Owner chooses event literal and receipt `result_kind` before any command; immutable policy ID/revision result proof without adding `command_receipt_id` to HE table; minimal typed audit and private reason. Later command matrix leaves event blank. | Using illustrative #27 name without sign-off is prohibited; risk incompatible consumers and untraceable application. Requires event registry/receipt approval; test replay/no duplicate, data minimization, application FK/proof. |
| **RP-07** concurrency | Global SHARED auth→receipt/principal→School→policy→allocators→Student/academic/child; revalidate after lock waits; exact replay rechecks current grant and retained immutable result, not current head. Existing #31, `effect25_19`, `effect35_15`. | Lazy optimistic selection or inverse MOVE/END locks may deadlock or reuse numbers; needs DB-03 final call-graph proof. Test two-session REPLACE/REPLACE, REPLACE/END, place at t, revoked grants, rollback, response loss. |

## 6. Task E — DB-01 / DB-03 / Admissions read-only dependency handoff

| Boundary | DB-01 (#100) must satisfy | DB-03 (#102) / D1 placement owner must satisfy |
|---|---|---|
| Effective policy | Correction keeps source allocation's immutable policy; never retroactively substitutes current School policy. RC-01/03 remain pending. | New Enrollment uses exactly one School policy effective at Enrollment date, not today; future boundary must be rechecked after School lock. |
| Namespace | Correction selects School-wide persistent or exact academic revision+Offering from immutable source; no client-supplied scope. | New persistent revision pool is School-safe even if source counter low; AC per revision+Offering; no unprovisioned pool at placement time. |
| Ownership | RC-02/05 must explicitly agree whether corrected-away PS values remain reserved. Recommended permanent ownership across all retained PS revisions. | Auto allocator must use **all historically owned other-Student PS numbers** if approved, not only unsuperseded heads; update final trigger accordingly. |
| Correction lineage | Manual correction `supersedes_id` is predecessor; `origin_allocation_id` is distinct persistent carry origin; do not conflate or rewrite. | Carry forward latest legitimate unsuperseded same-Student PS claim, including after AC interlude if RP-03 approved; preserve origin/Policy ID on existing allocations. |
| Lock order | School→policy→allocator→Student before correction/affected academic histories, never inverse; recheck under lock. | Place/MOVE/END/Admissions handoff must share School→policy→allocator prefix and check policy/capacity after waits. Final MOVE wrapper must be audited for Student→allocator inversion. |
| Initial admission | DB-01 never invents Admissions clearance/number issuance. | DB-03 SC-04/05/06 handoff must create accepted Student/PRIMARY placement+roll atomically using approved policy pool; unavailable policy fails closed. No rollout until Admissions decisions frozen. |
| Replay | Old correction receipt valid as retained history after legitimate MOVE/END but current disclosure authorization still required. | No duplicate Enrollment or roll issuance on retry; policy cutover/revocation cannot become replay authority; receipt result binding uses immutable IDs. |
| Open decisions | RC-01…RC-08 not approved by DB-02. | SC-01…SC-07 not approved by DB-02; future-dated placement and cross-domain locking require separate sign-off. |

**Dependency requirement:** get DB-01 RC-02/RC-05 and DB-03 SC-04/SC-06 owners to accept or explicitly challenge RP-03 and the shared lock order. No other branch may be edited in this PR.

## 7. Exact proposed tests (no tests executed here)

| Test | Result required after approval |
|---|---|
| OWN-01 | Seed Student A PS 1001 then approved correction to 1002; new Student B automatic candidate starts 1001; **under permanent reservation recommendation**, allocator skips 1001 or fails without committing it; confirm final trigger. |
| OWN-02 | Repeat OWN-01 across PS r1→AC r2→PS r3; Student A reentry carries approved latest PS head; B never receives historically owned A number. |
| OWN-03 | Rebuild counter low despite prior high-water; School anchor/other-Student scan prevents duplicate and never decrements historical counters. |
| OWN-04 | AC same R/Offering two Sections collide during interval overlap; different Offering or policy revision allows namespace reuse. |
| TIME-01 | INIT both modes, policy REPLACE t−1/t/t+1, END and open gap; policy as-of selection exact; no rewriting old allocations. |
| TIME-02 | Future effective Enrollment accepted before attempted REPLACE; replacement denies if it would reinterpret committed placement, no silent reallocation. |
| TIME-03 | Pre-created vs lazy academic allocator: with current prelock, missing pool rejects; after approved provisioning, first placement succeeds. |
| P1-01 | School-global policy `campus_id IS NULL` selected by `d1_p1_route(code,NULL)`; no Campus policy fallback; no route while operation disabled. |
| P1-02 | DIRECT vs APPROVAL route; independent reviewer/different Person; approved request has no effect before explicit apply. |
| P1-03 | Grant revoke first → INVALIDATED without policy mutation; apply first → one commit followed by revoke; never self-review. |
| P1-04 | Source revision/route/allocator stale between review and apply → bounded INVALIDATED; unexpected infrastructure exception rolls back. |
| P1-05 | Same-key success after later legitimate policy change returns retained result only if live authority; no duplicate counter/evidence/outbox. |
| CON-01 | Two PostgreSQL sessions REPLACE same head under real School row-lock contention; one successor only. |
| CON-02 | Two-session REPLACE vs PLACE at boundary t, both arrival orders; no allocation refers to incompatible effective policy. |
| CON-03 | Two-session REPLACE PS→AC or AC→PS vs MOVE, test complete prelock ordering and absence of deadlock. |
| CON-04 | Two-session policy apply vs Foundation EXCLUSIVE revoke and reviewer authority; check deterministic loser outcomes. |
| CON-05 | Rollback injected between counter pool provisioning/policy close/successor; all effects vanish, waiting placement observes old policy. |

Use `SET ROLE authenticated` on fixed RPC tests, transaction-local owner fixtures only for prerequisites, `SET CONSTRAINTS ALL IMMEDIATE` then ROLLBACK, real observed locks/barriers rather than sleep-only evidence. Rerun suites #37 (checked read), #38 (owner HE), #61/62/63 (place/end/move), #65 (disabled operation until separate activation), full relevant D1/220 Foundation regressions, all 34 forced RLS relations. Neither source nor test modifications are included in DB-02 design PR.

## 8. Implementation sequence and stop condition

1. Owner explicitly freezes each RP-01…RP-07, including **whether historic corrected-away persistent values may ever be reassigned**, END/scheduling, School-global route and selected event/result names.
2. DB-01 and DB-03 confirm shared historical ownership, as-of policy semantics and School→policy→allocator→Student lock prefix; D1 integrator audits **final ordered SQL overrides and cross-row trigger** plus genuinely reproducible no-reuse/lock tests.
3. Separately authorize DB-02-only new additive SQL draft and narrow executor/checked-reader P1 functions; do **not** modify or activate existing central Migration 10 or Foundation files in DB-02 branch. DB-03 owner/integrator separately fixes placement allocator historical-ownership predicate if owner chooses permanent reservation.
4. Independently validate and fix isolated schema, grants/RLS, typed receipts, approval/invalidations, event selection, rollback and true two-session races. Full incremental acceptance must pass on exact candidate SHA.
5. Separate activation approval/PR may then consider enabling `student.roll_policy.change`, updating the fail-closed test, and integrating Migration 10 later. No hosted Supabase changes as a consequence of this design.

**Outcome:** `DB-02 POLICY AND ALLOCATOR DESIGN READY FOR OWNER REVIEW`; **PRODUCT DECISION REQUIRED** for RP-01…RP-07 and DB-01/DB-03 cross-domain compatibility. **No confirmed committed duplicate**, no new SQL or test execution, no activation.
