# D1 Effect 30 — P1 competing Family relationship END/CORRECT cross-action races

Date: 2026-10-11  
Verdict: **PASS — exact-source real observed-lock two-session local-only incremental acceptance. Full D1 OPEN.**  
PR: [#22](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/22)

## Exact source identity and CI verification

- Accepted main parent: `1bfed16dcc553bce44b17ee76658d91d78f29473`; **exact tested PR head:** `5d2b512ad9c9051658e748289bf6795b57fe7d7b`; merged at `c26e2f169d6720f83908fb0b8d73bd9869b819c0`, whose second parent is the exact tested PR head.
- [D1 disposable runtime #199](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38106491380) **PASS**: `D1_FAMILY_RELATIONSHIP_CROSS_ACTION_A_RACE_PASS` and `D1_FAMILY_RELATIONSHIP_CROSS_ACTION_B_RACE_PASS`; each explicitly reports a two-session observed lock wait and one EXECUTED / one INVALIDATED terminal outcome, with retained primary history. Total **10/10** genuine two-session races, **837/837 business assertions in twenty suites**, **220/220 post-D1 Foundation regressions**, **27/27 runner unit tests**.
- [Foundation #391](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38106491551) **PASS**: frozen nine migrations/test files, **220/220**.
- Exact-head disposable D1 runtime assembled/applied **202 non-executable SQL draft fragments**, verified **34/34 forced-RLS D1 tables, 540 final functions (522 SECURITY DEFINER), zero client/private-helper execution**, and both local SQL lint levels PASS. Only two Python test/harness files changed; path-filtered standalone static D1 workflow did not run on this head, while unchanged SQL fragments passed [static #115](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38055482552) plus exact-head runtime assembly/catalog/lint.

## Frozen conflict semantics and sequential race fixtures

The prior accepted competing CORRECT race has already built one current selected-primary corrected guardian successor linked to a retained original relationship. This test reuses that **real retained open successor** and corresponding open selected primary display context. No synthetic approval records are inserted, no schema-owner direct workflow mutation and no fabricated new source/Family/Student are used. Distinct verified requester and reviewers use authenticated typed Effect30 `family.relationship.change` P1 SUBMIT, two APPROVEs by two separate Persons/Auth users under the configured reviewer role/scope, and two APPLYs per phase with different request IDs/idempotency keys.

**Phase A — CORRECT beats END:** Two independently valid APPROVED intents target that exact open source and the same `CURRENT_DATE` effective boundary. CORRECT's APPLY wins in the first PostgreSQL session; END's APPLY competes and becomes INVALIDATED version5. The source closes once at `CURRENT_DATE` and a single new open relationship is appended with `supersedes_id` to the source and the winning correction's exact display/Student/Family/adult Person facts. The old selected primary context closes at the same boundary and a single open successor context points to the winning replacement.

**Phase B — END beats CORRECT:** Two new independently approved requests target **the open Phase A successor** at `CURRENT_DATE+1`. END's APPLY wins and ends that source and its current selected primary context exactly at the future exclusive date, while CORRECT's APPLY becomes INVALIDATED version5. END returns the original retained source identity, with **no new relationship and no new selected primary context**, because no alternative same-Student relationship remains eligible at that future boundary.

**True contention is mandatory in each direction:** Workers are independently authenticated PostgreSQL processes with unique `application_name`. The harness requires the first named worker to hold a granted class-71001 advisory lock and the second named worker to show a not-granted advisory, transactionid or tuple lock *before the first commits*. Missing lock, premature worker completion, wrong terminal state or version, or incomplete historical evidence fail the gate. Sequential command execution or another session's unrelated lock cannot satisfy the check.

## Retained effects and invariants

The test inspects exact `family_relationships` and `student_primary_family_contexts` exclusive interval boundaries and `supersedes_id` links. Across the prior Effect30 same-action END/CORRECT races plus these two cross-action races, there are exactly **4 EXECUTED and 4 INVALIDATED**, **4 successful applications**, **4 relationship success outbox events**, **8 retained review decisions**, **24 typed receipts**, **4 retained relationship rows**, **3 primary contexts** and **zero Student child entitlements**. Specifically, Phase A creates one legitimate relationship/primary successor; Phase B's competing CORRECT creates no loser successor, and the final selected primary relationship/context close without an incorrectly guessed replacement. The underlying P1 policy, locked ancestry, optimistic versions and deferred guards are not bypassed or weakened.

Two new Python unit tests assert the permitted phase/action pairs, safe test-owned UUID-only inputs, authenticated transaction SQL, distinct request keys and worker identities.

## Scope / next release gates

Exactly `tools/supabase/domain_concurrency_ci.py` and `tools/supabase/tests/test_domain_acceptance_ci.py` changed. These are disposable local D1C2A acceptance tests, **not** full Effect30/Families authorization proof, production migration verification or a general release-readiness signal. More complex selected-primary END with explicit alternative replacement under concurrent APPLY, Family checked portal projections, populated upgrade, Admissions/Finance, wider policy-scope coverage and full D1 remain OPEN. **Migration 10 remains `.sql.draft` and no hosted Supabase database was changed.**

**Checkpoint: `D1_EFFECT30_P1_CROSS_ACTION_RACES_PASS — 837/837 BUSINESS — 220/220 FOUNDATION — 10/10 OBSERVED-LOCK RACES — 27/27 UNIT — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.**
