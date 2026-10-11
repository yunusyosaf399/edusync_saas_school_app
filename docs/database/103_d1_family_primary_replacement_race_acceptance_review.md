# D1 Effect 30 — P1 explicit other-Family primary replacement versus competing CORRECT

Date: 2026-10-11  
Verdict: **PASS — exact-source real two-session observed-lock disposable local acceptance; full D1 OPEN.**  
PR: [#23](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/23)

## Exact CI checkpoint

- Trusted previously accepted main: `d2f51b1dc7315726b12ca19348f88a0e6f294e04`; exact tested pull-request head `cd2e1ac9c54bafff903d005cd11a8b6553a30797`; merged at `ace36a8f1801b428e8f93e7c14fe077e753fb818`, whose second parent is the tested source.
- [D1 runtime #202, attempt 2](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38112787162) **PASS**: **837/837** business assertions, twenty suites; **220/220** post-D1 Foundation regressions; **29/29** Python tooling unit tests; **11/11** observed-lock real two-session races. Explicit marker: `D1_FAMILY_PRIMARY_REPLACEMENT_RACE_PASS Effect30 P1 END explicit other-Family selected-primary replacement wins over independently approved CORRECT; observed_lock_wait=true; one EXECUTED/one INVALIDATED; exact retained replacement lineage`.
- [Foundation #394, attempt 2](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38112787174) **PASS**: nine frozen migrations and nine tests, **220/220** assertions.
- Both first attempts failed during environment startup (`supabase start (exit 1)`) **before database SQL assertions**. Retried the exact same commit with no SQL, security or source changes; both attempts 2 completed successfully.
- Exact-head disposable runtime assembled/applied 202 **non-executable SQL draft fragments**, checked 34/34 forced-RLS domain tables, 540 final functions (522 SECURITY DEFINER), no client/private-helper execution and both SQL lint levels. The change is test/harness-only, so independently path-filtered static D1 gate did not run; earlier accepted [static #115](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38055482552) covers unchanged SQL, and #202 directly checks its assembled catalog and lint.

## Intent, approvals and immutable ancestry

The fixture runs **after the ten previously accepted races**, including the full end and cross-action history for Student A. It uses the existing separate **Student B**, existing ACTIVE Family A, a different synthetic ACTIVE Family B, and **two valid, simultaneously selectable** current relationship bases — Family A's selected primary GUARDIAN and Family B's independent MOTHER. Only the fixture-only historical source and primary display facts are seeded, not workflow states. The primary context initially points to Family A's guardian relationship; no child entitlement is implicit.

The verified staff requester uses typed `app.d1_submit_family_relationship_change` twice with the same Student, source relationship, Family, optimistic Student/Family versions and `CURRENT_DATE-6` exclusive end date. The first **END** has the explicit **other-Family replacement relationship UUID**, exactly as required by frozen Effect30 preflight when another selectable primary relationship exists. The second **CORRECT** proposes new guardian display facts without a replacement. Requests carry separate reasons and canonical typed idempotency keys. Two different verified Person/Principal/Auth reviewers use current configured `family.access.approve` permission and role/scope to independently approve one request each. Neither APPROVE applies any business mutation.

## Two real PostgreSQL sessions and verified terminal results

Two separately named authenticated `app.d1_apply_family_relationship_change(request_id,4,key)` workers apply the independently approved competing intents. Worker one holds its transaction open after applying END while named-worker class-71001 PostgreSQL advisory lock is held. The runner verifies that worker two's `application_name` has a **not-granted advisory, transactionid or tuple lock**, and fails closed on missing contention, unexpected worker exits, unapproved requests or wrong terminal result. This is not two sequential APPLY calls or proof based on a background lock.

- The **END** request commits `EXECUTED` version 5 with original source relationship identity. Original Family A source remains a historical row with `effective_until=CURRENT_DATE-6` and populated end metadata; the exact old selected primary context retains the same exclusive end.
- A **single open successor primary context** points to the separately retained, open other-Family relationship in ACTIVE Family B, has the exact accepted effective boundary and `supersedes_id` to the old primary context. No duplicate or incorrectly guessed primary context exists.
- The independently approved **CORRECT** request commits `INVALIDATED` version 5 with no returned relationship; no new relationship successor is inserted from its proposed display facts.
- Family B's replacement relationship stays unmodified and open, and no Student B child-specific Family access is created. The previously accepted Student A historical count (four relationship rows, three primary contexts) remains untouched.
- Across all five Effect30 races at this point: **5 EXECUTED, 5 INVALIDATED, 5 approval applications, 5 relationship success events, 10 immutable reviews, 30 typed receipts**. Across the full D1 runner: **11** verified real two-session observed-lock races (3 Employee, 3 Family membership, 5 Family relationship).

## Scope, changed files and remaining gates

Test-only delta is three files: `supabase/tests/domain/fixtures/family_primary_replacement_race_setup.sql`, `tools/supabase/domain_concurrency_ci.py`, and `tools/supabase/tests/test_domain_acceptance_ci.py`. Two new unit tests reject unowned/invalid worker cases and ensure independent END versus CORRECT idempotency keys.

This acceptance is **local-only incremental D1C2A**, not proof of all selected-primary cross-Family scenarios. Opposite-winner concurrency, replacement losing live eligibility during APPLY, broader scope/policy cases, checked Family portal projections, populated upgrade and Admissions/Finance remain OPEN. **Migration 10 is still `.sql.draft`, never activated or deployed to hosted Supabase; full D1 acceptance remains OPEN.**

**Checkpoint: `D1_EFFECT30_P1_EXPLICIT_PRIMARY_REPLACEMENT_RACE_PASS — 837/837 BUSINESS — 220/220 FOUNDATION — 11/11 OBSERVED-LOCK RACES — 29/29 UNIT — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.**
