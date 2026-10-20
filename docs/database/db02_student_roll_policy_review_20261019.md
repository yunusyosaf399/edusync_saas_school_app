# DB-02 — roll-policy P1 review, dependency, migration and acceptance plan

**Status: PRODUCT DECISION REQUIRED / DESIGN ONLY.** Based on `main 14fcfa5ba0d97e41264297338b702b23a4d40dbf`, 2026-10-19. Companion: [DB-02 contract](db02_student_roll_policy_design_20261019.md). This is a planning/review document, **not** an executable migration, feature flag change, accepted P1 command, or independent runtime pass.

## A. Review outcome and source trace

| Source / current artifact | Evidenced behavior | Missing DB-02 contract |
|---|---|---|
| `AGENTS.md`, master spec, decisions, security/guardrails | School per Supabase project, school-wide config, historical protection, Foundation grants + P1 workflow, no client direct writes | No approval to introduce another RBAC/approval/receipt system |
| Readiness #154 and #127 | Seven RP gates unapproved; `student.roll_policy.change` disabled; ALL/DIRECT non-family-safe change/review permissions; event intentionally unselected | Exact typed INIT/REPLACE/END and school-target policy route |
| Physical #27 / constraints #30 | HE policy and allocations, M allocator; half-open history and revision lineage | Date eligibility, revision-source snapshot, cutover handling |
| Concurrency #31 / retention #34 | School→policy→allocator before Student/Offering; persistent school-wide ownership; academic exact revision+Offering | Fully ordered cross-operation waits/rollback/replay |
| Indexes #32 | U08/I10/PU01/PU02/I11/I12–I14 | Benchmark before proposing any additive index |
| Current-read review #126 / suite #37 | Bounded `app.d1_read_roll_policy` under `student.roll_policy.view` | No checked change participant/read API |
| Structural review #127 / suite #38 | 40 synthetic owner-fixture integrity checks for revision 1–4 and fail-closed operation | No authenticated P1 command acceptance |
| Current fail-closed suite #65 | Four student command/permission contracts disabled, private DML denied | Cannot enable policy in DB-02 design; enabling requires its own approved gate |
| Final placement `effect25_19`, `effect35_15`; existing move/end | School-anchored prelock, as-of allocation and revision-specific counters | Pre-created pools, future commitments, and historic persistent number retention across supersession |
| DB-01 PR #100 design (separate branch) | RC-01–RC-08 explicitly pending; proposed school-wide persistent number reservation | No DB-02 edits/approval of DB-01 correction semantics |
| PR #99 (separate branch) | Student Photo local-only trial | No overlap or reason to touch photo storage/worker |

**Critical not-a-PASS:** roll-policy physical fixture tests and the current checked read do not prove `student.roll_policy.change` P1 semantics. Foundation regression success does not make a disabled operation safe to activate. Document #27's illustrative event name conflicts with later #127/#154 and command matrix; RP-06 remains unselected.

## B. Decision sign-off sheet (product owner)

Record one of **APPROVE / REVISE / REJECT** for *each* gate. No entry below is signed.

| Gate | Specific question | Status |
|---|---|---|
| RP-01 | INIT only for empty history, REPLACE/END only exact open source head and expected immutable snapshot, revision+1 successor? | **PENDING** |
| RP-02 | Current-date-only first release; contiguous replacement, deny backdating/future scheduling and deny unsafe END gaps/future commitments? | **PENDING** |
| RP-03 | New per-revision counter pool(s), no historical reallocation, reserve school-wide persistent numeric ownership even when superseded, explicit persistent reentry behavior? | **PENDING** |
| RP-04 | One School target routed through a verified global/NULL-campus Foundation P1 policy rather than a fabricated Campus or first-matching Campus? | **PENDING** |
| RP-05 | Exact typed request/read/independent reviewer/apply, live ALL permission + configured reviewer role/step, no self-Person review, stale INVALIDATED? | **PENDING** |
| RP-06 | Select broad event code and fixed result kind/provenance/allowlist expressly; keep private reason out of general evidence and no invented HE receipt FK? | **PENDING** |
| RP-07 | School/policy/allocator shared lock prefix, same-day ordered winner, durable replay after subsequent legitimate change, revocation/rollback races? | **PENDING** |

## C. Proposed implementation dependency and migration order — NOT AUTHORIZED

0. Verify `main` SHA, branch/PR isolation, approved RP gates, DB-01/DB-03 namespace and lock ownership, final assembled function definitions (later `CREATE OR REPLACE` overrides earlier draft fragments), and no break to 34 D1 RLS relations/97 permissions/322 scopes/36 operations.
1. Write a **new, domain-owned, additive DB-02 SQL draft fragment** only after a separately granted SQL ownership slot and approved decisions. No edits to existing central `20260928000000_domain_package_01.sql.draft`, 197+ shared ordered fragments, frozen Foundation, global registration, CI or application manifests by this chat. An integrator must later assign the official migration inclusion/order.
2. Schema/defense: use existing `roll_policy_revisions`, `roll_allocator_states`, `roll_allocations`; validate exact current source, half-open predecessor/unique revision, interval, immutable/end markers and existing FK/trigger checks. No new base table assumed. Review whether existing RLS/column ACLs narrowly support the fixed executor; escalate needed shared grants.
3. School-wide P1 resolver: verify explicit Foundation `d1_p1_route` school/NULL semantics against permission ALL/DIRECT; if unsupported STOP at upstream Foundation integration design (do not impersonate Campus). Define exact operation-specific fixed handlers and secure checked participant read (not the existing current policy read).
4. Locked effect: acquire Foundation SHARED auth → idempotency lock → Principal/workflow → School → policy rows → existing/new mode-specific allocator parents/rows → only needed Student/academic dependencies; re-read policy, route, active/future placements, cross-revision persistent owners and current authority after waits; deny conflicts. Initialize correct pool(s), close/append policy, write evidence atomically. No changes to retained allocations.
5. P1 transactions: DIRECT typed effect or APPROVAL submit, separate review, then explicit apply; APPROVED never applies on review. Deterministic stale failure yields INVALIDATED + bounded REJECTED apply receipt with no mutation/application/event; unexpected SQL infrastructure failures roll back and keep APPROVED for retry.
6. Evidence and final registration after RP-06: exact result kind, approved event code, allowlisted typed audit/outbox, receipt-to-retained-result proof and hash/replay; no broad request JSON, no raw sensitive reason; no duplicate engine.
7. Rollback-only authenticated pgTAP, RLS negative tests, genuine independent PostgreSQL session lock races; repeat existing current-read #37, physical #38, policy-disabled #65 **until separately approved activation**, place/move/end regressions #61–63, D1/Foundations static and disposable local validations. A new activation PR must explicitly replace/adjust #65 and register event/operation enabled only after all decisions and tests pass.
8. Separate independent SQL/security acceptance, populated upgrade/cutover review and activation authorization. Keep Migration 10 `.sql.draft` and do not apply to hosted Supabase or execute anything under this DB-02 design PR.

**Migration ordering dependency:** School/policy history/allocator and Foundation P1 are upstream; DB-03 enrollment place/move/end must share prelock handoff; DB-01 roll correction must agree on immutable policy and school-wide numeric ownership. Any changes to DB-01/03 files belong to their owners or a later coordinated integration PR.

## D. Proposed positive and negative acceptance cases

Each proposed case is **future work**, not an executed test. Every test must use fixed `SET ROLE authenticated` protected calls; owner fixtures only for setup, never to fabricate successful P1 effects. Use rollback-only SQL and force deferred constraints immediate before rollback.

| ID | Condition / expected result |
|---|---|
| RP-T01 | INIT empty School policy history creates revision=1, NULL predecessor, correct effective interval, one selected mode/counter, one receipt/audit; no Student created. |
| RP-T02 | INIT on School with any retained revision denies (including ended/scheduled predecessor); no duplicate seed/revision. |
| RP-T03 | Current-date REPLACE exact open head: one close, successor `revision + 1`, exact predecessor, half-open adjacency; old allocation rows byte-for-byte retained. |
| RP-T04 | END exact open head closes only policy; if gap blocks future placement, placement denies, no fallback to older revision. END with conflicting committed future placement rejects before close. |
| RP-T05 | Exact source ID/revision/mode/start/effective-from/expected NULL end mismatch, nonexistent School/head, already-ended/superseded source → deny, no evidence. |
| RP-T06 | Same-day source close violating positive length, invalid/new mode, NULL/negative/overflow start, blank reason, no-op REPLACE, illegal future/backdate → deny. |
| RP-T07 | Existing PERSISTENT Student retains original numeric across eligible persistent revisions; when switched to academic, old allocations still point to original policy. Returning to persistent follows expressly approved carry rule. |
| RP-T08 | New persistent revision's candidate never assigns a number historically owned by another Student across old persistent revisions, including corrected-away head (pending RP-03). |
| RP-T09 | Academic policy allocators are separate by exact policy+Class Offering; same number across distinct namespaces may coexist; collision across Sections of same Offering at overlapping times denies. |
| RP-T10 | Replacing policy with existing committed future-effective placement: fail closed or use the *explicitly approved* future-commitment strategy; never silently leave mismatched policy/roll. |
| RP-T11 | Counter creation/advancement and policy change rollback atomically on injected violation; no orphan revision or pool; server owns M-row version fields. |
| RP-T12 | Nonexistent/disabled P1 route, ambiguous/multiple policies, wrong/global route or forced Campus fallback → deny. DIRECT under APPROVAL and vice versa deny. |
| RP-T13 | No change permission, grant revoked, school/ALL mismatch, FAMILY actor, Student-own or role-label-only actor → deny. Separate view grant alone insufficient. |
| RP-T14 | Independent reviewer with current `student.roll_policy.approve`, `D1_REVIEWER_ROLE_SCOPE`, configured role/step accepts; final APPROVE only changes workflow state; later explicit apply performs one effect. |
| RP-T15 | Requester/reviewer same Person across two Principals, outdated reviewer assignment, wrong scope/step or revoked reviewer role denies; generic admin fallback absent. |
| RP-T16 | After APPROVED, changed source revision, route/policy, revoked requester/reviewer, allocator conflict or future placement → deterministic INVALIDATED/REJECTED apply receipt, no domain/application/event. |
| RP-T17 | Injected infrastructure/deadlock/SQL error rolls back and leaves APPROVED/retryable; never converted to accepted INVALIDATED automatically. |
| RP-T18 | Exact DIRECT and APPROVAL terminal idempotency replays retained receipt after later legitimate replacement/END if current authority permits; changed key intent/reason/source conflicts. No duplicate revision/event/counter. |
| RP-T19 | Audit/outbox include only approved selected code and typed IDs/intervals; no private reason/raw request JSON. If RP-06 event still unselected, no operation activation. |
| RP-T20 | Unauthorized authenticated/anon/private select or DML on policy, allocator or roll rows denied; read RPC returns only reviewed four current fields. |
| RP-T21 | Existing placement/move/end, checked policy read, synthetic HE invariants, Foundation permissions/220 baseline and 34 FORCE RLS regress without changes. |
| RP-T22 | Numeric threshold: counter `next_value` at/below start, near bigint max, duplicate preprovision attempt, and policy-shared timestamp cutover reject on overflow/ambiguity. |

**Estimated new plan:** 22 discrete acceptance scenarios (not a frozen pgTAP assertion count). The test owner determines final per-suite plan and test assertions after decisions and signatures freeze.

## E. Required genuine concurrency schedules

Two independent PostgreSQL sessions, real row/advisory lock contention observed with controlled barriers, bounded lock/statement timeouts, no artificial sleep-only claim. Capture locked target IDs, order, post-commit outcome and absence of duplicate artifacts. These are designs, not accepted races.

| Race | Session A | Session B | Observable contract |
|---|---|---|---|
| RP-C01 | REPLACE r1→r2 | REPLACE r1→r3 | School anchor serializes; exactly one new revision; loser stale/invalidated, never fork. |
| RP-C02 | REPLACE r1→r2 | END r1 | One writer wins; other rejects/invalidate without double close or gap rewriting. |
| RP-C03 | INIT empty School | INIT same School | One revision 1 and one correct allocator namespace; loser rejects/replays only if same key/actor intent. |
| RP-C04 | REPLACE policy at date t | Place Enrollment effective t | Deterministic policy selection after School lock; winner/loser outcome respects chosen cutover; no policy-mismatched allocation. |
| RP-C05 | REPLACE persistent→academic | Concurrent academic-placement into same Offering | No missing/stale pool, counter double issue or allocation under invalid policy interval. |
| RP-C06 | REPLACE academic→persistent | Concurrent placement and earlier persistent owner reuse | School-wide persistent number collision denied, even when counter restarts at new revision. |
| RP-C07 | APPROVED policy apply | Revoke requester/reviewer grant (EXCLUSIVE Foundation lock) | If revoke commits first, apply INVALIDATED; if apply wins, revoke occurs afterward. Never bypass current authority. |
| RP-C08 | APPROVED apply | Alter P1 route/policy or replace expected source | Apply rechecks exact route/source; stale approval INVALIDATED and no receipt marked successful. |
| RP-C09 | DIRECT commit then lose client response | Same-key retry after another legitimate policy revision | One successful history/evidence effect; authorized retry returns retained result, not second mutation. |
| RP-C10 | Policy change before transaction commit (forced abort) | Placement waiting for School lock | Rollback exposes old valid policy/counter only; waiting placement reselects after lock, no phantom r2. |
| RP-C11 | Policy replace | DB-01 manual numeric correction under School/policy/allocator locks | No inverse lock order, corrupted high-water or cross-revision persistent reuse; requires DB-01 implementation approval. |
| RP-C12 | Policy replace | DB-03 MOVE/END/placement | Complete School→policy→allocator→Student/Offering prefix proven; identify and correct any upstream Student→allocator inversion before activation. |

**Contested lock gate:** PR #100 explicitly flags potential MOVE/END lock inversion with allocator prefix. A runnable roll-policy mutator must not be enabled until the final integrated lock graph proves same ordered anchors across all participating commands.

## F. Acceptance, rollback and review evidence checklist

* Freeze each RP recommendation with owner signature/dated ADR, including selected event code. A design PR cannot satisfy this.
* Verify new file ownership and official integration ordering; run `git diff --check` or equivalent formatting validation without modifying shared fixtures. Check operation still disabled and no event/SQL/RLS changes on this design branch.
* At future implementation: static SQL parse/guards, pgTAP happy/negative, `SET CONSTRAINTS ALL IMMEDIATE`, full rollback, independent two-session tests; Foundation 1–9 + tests 01–09 unchanged; no hosted data.
* Gate independent reviewers on exact branch/commit, final definition order, privileges/RLS and log evidence. Failed/waiting runs are not acceptance. PR remains draft/not merged by this chat.

## G. Closure status

**PRODUCT DECISION REQUIRED.** No RP-01…RP-07 approval exists in the audited source; no protected operation implemented or enabled; no SQL migration, test modification, CI change, hosted Supabase action or merge has been performed. The companion DB-02 documents are intended solely for independent design review and owner decision recording.
