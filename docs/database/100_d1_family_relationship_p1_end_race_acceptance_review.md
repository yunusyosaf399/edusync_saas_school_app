# D1 Effect 30 — P1 competing Family relationship END observed-lock race acceptance

Date: 2026-10-10  
Verdict: **PASS — exact-source, real two-session disposable local race acceptance; full D1 OPEN.**  
PR: [#20](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/20)

## Source identity and exact runtime evidence

- Prior accepted main `d9445e326188bc8e2d438b95776ffc259c7228b8`; exact tested PR head `1a24b33cc0de36077b16f054d79a3df3aedfd32c`; merge commit `e273e19e73537acc2ad25e230e6de656aa9fcdaa` has tested head as its second parent.
- [D1 local runtime #187](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38071054072) **PASS**: new `D1_FAMILY_RELATIONSHIP_END_RACE_PASS` with `lock_wait_observed=true`, one `EXECUTED` / one `INVALIDATED`; total **7/7 actual observed-lock PostgreSQL two-session races**, including three Employee races and Family Principal Membership ADD/END/CORRECT three. **837/837 business assertions across 20 suites**, **220/220 post-D1 Foundation regressions**, **23/23 runner unit tests**, both SQL lint gates. Local application of 202 non-executable draft fragments: 34 forced-RLS tables; 540 final functions (522 SECURITY DEFINER); private helper exposure to client roles zero. Disposable stack stopped.
- [Foundation #382](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38071054074) **PASS**: nine frozen migrations/nine tests, 220/220 pgTAP assertions.
- PR files affect only test fixture and Python race harness/unit tests, so the D1 static workflow's path filter did not select this SHA. Accepted [D1 static #115](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38055482552) covers the unchanged 202 draft fragments; exact-head D1 runtime independently revalidates assembly, function/RLS catalog and lint.

## Race semantics verified

The fixture starts from the previously accepted disposable Family shared-Principal membership race's independent retained Family relationship basis, **one open Student A guardian relationship**, no selected primary context and no child entitlement. It adds a narrow `family.relationship.change` staff grant/scope and an independently configured P1 policy requiring a real reviewer role with `family.access.approve`. Two separate typed SUBMIT operations for the same source and effective date create two PENDING requests; an Auth-verified reviewer who is a different Person separately approves both. These approvals do not mutate the relationship.

Two real independently authenticated PostgreSQL session workers explicitly call `app.d1_apply_family_relationship_change(request_id,4,key)`. Each worker sets its own distinct `application_name`. The first session holds its transaction after returning successful APPLY; the second enters actual lock contention. The harness requires evidence of a granted advisory lock on that first worker and a **waiting** transaction/advisory/tuple lock on the specific second worker, rather than accepting an unrelated database lock or sequential execution.

After both workers commit, expected and observed results are:

- **Winner:** request `EXECUTED` version 5, returned original relationship UUID; the existing open source ends once at `CURRENT_DATE-3` with persisted `ended_at` and `ended_by`.
- **Loser:** request `INVALIDATED` version 5 and no relationship UUID. The stale approval is not allowed to overwrite the winner's ended source or produce a success event.
- **Retained evidence:** exactly two separately approved review records; exactly six typed command receipts (two SUBMIT, two APPROVE, two APPLY); precisely one completed approval application and one Family relationship success outbox event; one retained relationship row, no added replacement or deletion, no primary display-context row, no Family Student child access.

The runner fails closed on lost fixture source identity/versions, incomplete independent approvals, missing observed lock, wrong terminal states, duplicate receipts/applications/events or misplaced Student access. It also adds two small unit tests for approved test-owned worker intents and distinct keys.

## Acceptance boundary

Exactly three changed test-only files: `supabase/tests/domain/fixtures/family_relationship_end_race_setup.sql`, `tools/supabase/domain_concurrency_ci.py`, `tools/supabase/tests/test_domain_acceptance_ci.py`. No frozen Domain/Effect30 business SQL was modified or relaxed. The new observed-lock result is a separate genuine race, not a replacement for the six earlier races. Competing CORRECT, primary-context and cross-action race coverage, untested authorization permutations, broader D1, populated upgrade and hosted database remain OPEN. Migration 10 remains `.sql.draft`.

**Checkpoint: `D1_EFFECT30_P1_RELATIONSHIP_END_RACE_PASS — 837/837 BUSINESS — 220/220 FOUNDATION — 7/7 RACES — 23/23 UNIT — 202 SQL DRAFT FRAGMENTS — FULL D1 OPEN`.**
