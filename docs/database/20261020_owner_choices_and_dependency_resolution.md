# Owner choices and blocking-work reconciliation — 20 October 2026

## Actual conversation decisions

The product owner instructed: “Okay what requirs complete it and let complete all remaining jobs that have blocked the other work”. Asked two concrete product questions, the owner selected:

1. **Today-only changes (Recommended):** “Create or replace a policy using the School’s local date; preserve all historical numbers, defer closing/scheduling, and use school-wide direct or independent approval.”
2. **Require clearance (Recommended):** “Block final admission until Finance confirms clearance or an explicitly approved waiver; never trust a screenshot alone.”

These are actual product selections, not inferred from passing CI. They supersede the corresponding unresolved recommendations in DB-02 #101 and DB-03 #102. Prior records remain historical; no earlier author, approval date or reviewer identity is rewritten.

## Decision mapping and engineering interpretation

| Gate | Resolved behavior | Remaining engineering proof |
|---|---|---|
| RP-01 | INIT + REPLACE only; END/RESUME deferred | Exact retained source and immutable revision linkage |
| RP-02 | Trusted School-local current apply date; no backdate or scheduling; no second replacement producing an empty DATE interval | Shared server-date implementation; reject incompatible committed future placements |
| RP-03 | Retain all historical persistent numeric ownership | Retained-owner scan already fixed in #106; high-water and eager academic-pool provisioning still need policy-change implementation |
| RP-04 | School-wide DIRECT or APPROVAL routing | Exact single global NULL-Campus policy UUID selection and stale recheck |
| RP-05 | Independent review before separately authorized APPLY | Existing current role/permission/scope and different-Person rules remain mandatory |
| RP-06 | Evidence naming is an implementation detail delegated by the instruction to complete blocking work | Implementation selects `D1_STUDENT_ROLL_POLICY` and `student.roll_policy_changed`; these are **engineering selections**, not literal codes spoken by the owner. Register and test exact safe evidence before success/activation |
| RP-07 | Preserve the established Foundation auth/receipt → School → sorted policies → sorted allocator pools → Student/academics → retained history lock order | Exact current-source replay and real opposing-arrival tests for new commands |
| SC-03 business rule | Cleared Finance evidence or an approved waiver is mandatory; screenshot alone is insufficient | Finance-owned verifier/reversal fence and actual Admissions-produced handoff are not yet implemented |

The owner did not individually sign the remaining Admissions SC-01/02/04/05/06/07 physical/interface choices. Existing approved requirements and conservative technical implementation can be developed under the current assignment, but a successful end-to-end Admissions acceptance must not be invented from the clearance answer.

## Engineering increment in this branch

1. One private Academic-owned `d1_roll_business_date(uuid)` resolver reads the existing School timezone with a new **SELECT(timezone)-only** internal column grant. It validates the zone against `pg_timezone_names`, captures the real server clock once, and has no client clock/date/zone parameter or fallback. No additional table or public function is added. Mutators call after their existing School/roll lock prefix; the helper deliberately does not acquire School late during checked reads.
2. The final current roll-policy read materializes current authorization before computing one School date, preserving unauthorized empty results. Existing placement re-enrollment and END current-source comparisons use that resolver, preserving all other mutation/evidence bodies. Explicit historical/future placement/MOVE/END input dates retain their existing contracts; this increment does not forbid already supported future initial placement or silently renumber anything.
3. Security review found the DB-01 application guard accepted **any positive** receipt expected-request version. The already-passing #116 suite #79 named version 1 despite the executed request being version 5 (approved predecessor 4). The new guard binds `expected_request_version = executed_request.row_version - 1`, following the frozen server version trigger. The fixture now uses the actual predecessor and a regression rejects the old mismatched receipt. Original Effect38 source and frozen Foundation files remain untouched.

## Exact validation and security boundaries

Expected composed inventory: **243 drafts, 546 functions / 528 definers / 157 app / 389 private**, 34 FORCE-RLS relations, unchanged 97 permissions / 322 scope alternatives / 36 operations and zero client-private/anon/service-role EXECUTE. The single new function has Academic ownership and named internal Student/Workflow/Read EXECUTE only; the existing DB-01 trigger is replaced without new privileges. Strict catalog guards remain enabled.

Local tooling: **349 tests pass**, including source-preservation and exact ACL checks. Suite #79 becomes 13 assertions and new suite #80 adds 24 timezone/current-policy/negative-ACL cases, making **80 suites / 3,257 business assertions**. Two additional observed School-row waits test committed/rolled-back timezone updates, Student remaining unlocked upstream and reverse School conflicts; all timezone fixture changes are restored. Exact-head full runtime, Foundation and static evidence must be checked on the PR after submission.

## Honest remaining gates

- #116 demonstrated the composed previous stacks pass, but did not merge them or provide independent security approval. This branch adds real date/security fixes; it does not retroactively sign off #108/#110/#112 or count the assistant's own review as an independent reviewer.
- Roll CORRECT and Roll Policy Change protected commands/checked history and their authenticated acceptance remain implementation work; the date helper does not implement those commands.
- Actual Admissions policy/stage/offer/handoff and Finance clearance/reversal implementation remain missing; the selected clearance rule does not fabricate them.
- Approved DB-01 Q-A requires genuinely separate business days for repeated correction acceptance. No test clock override or synthetic “protected” multi-day correction is introduced.
- Migration 10 remains non-executable `.sql.draft`; Foundation migrations 1–9 and tests 01–09 stay frozen. No hosted deployment or operation activation is authorized by these results.
