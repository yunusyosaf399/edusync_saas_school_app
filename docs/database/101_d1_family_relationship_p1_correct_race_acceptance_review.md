# D1 Effect 30 — P1 Family relationship competing CORRECT and primary lineage race

Date: 2026-10-10  
Verdict: **PASS — exact-source real observed-lock two-session disposable local acceptance; full D1 OPEN.**  
PR: [#21](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/21)

## Exact source and CI results

- Prior accepted main `198ae6263127b25f2d955953b0bd0dee843e9fd9`; **tested PR head** `0a2a87e6148b8aa90206d55d4a96ef4aceec20d4`; merge `439be791e8c11c16f6e14b07cda1917df1ebb699`, whose second parent is the tested head. Exactly three local-only test/harness files were changed.
- [D1 local runtime #196](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38074292937): **PASS**, `D1_FAMILY_RELATIONSHIP_CORRECT_RACE_PASS` with `lock_wait_observed=true`, **one EXECUTED, one INVALIDATED, one retained relationship successor and one primary-context successor**. Overall **8/8** observed-lock real two-session races; **837/837 D1 business assertions in twenty suites**; **220/220 post-D1 Foundation regressions**; **25/25 runner unit tests**. Both SQL lint levels PASS. Disposable-only assembled/applied 202 non-executable draft fragments; 34/34 forced-RLS domain tables; 540 final functions (522 SECURITY DEFINER); private-helper client EXECUTE zero.
- [Foundation #388](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38074292935): **PASS**, nine frozen Foundation migrations/tests, 220/220 assertions.
- Test-only diff did not trigger path-filtered D1 static gate; same unchanged 202 draft fragments previously passed [D1 static #115](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38055482552), and this exact source passed the local D1 draft assembly, RLS, catalog and lint checks.

## Frozen request, review and mutation contract exercised

The earlier approved competing-END race ends its old source; the `CORRECT` race therefore seeds a **different retained, open and unsuperseded guardian relationship** for the same Student/Family, with a current **selected primary display context**. The fixture-only relationship and primary context use legitimate retained record guards in disposable local PostgreSQL; no business request is preapproved or raw user mutation substituted.

A verified requester independently SUBMITs **two P1 CORRECT proposals** on that same open source and effective boundary with **different corrected display facts** and different idempotency keys. Two reviewers with the configured `family.access.approve` permission and role/scope are **distinct verified Persons and Auth bindings**; each legitimately approves a different request. Both requests are independently valid before APPLY. Pre-race SQL confirms **two APPROVED requests, two immutable reviews, two different requested display values and two distinct reviewer Principals**.

Two real authenticated sessions call `app.d1_apply_family_relationship_change(request_id,4,key)`; one retains its transaction after returning the success result. The second is required to demonstrate a **not-granted PostgreSQL advisory/transaction/tuple lock** against its own unique `application_name`, while the first holds its own granted advisory lock. The test fails if the sessions merely execute sequentially or a background session supplies the apparent wait.

Observed result:
- **Winner** executes at request version 5 and returns a new relationship UUID distinct from source. Original source is retained and closes once at exclusive `CURRENT_DATE-1`, with `ended_by`/`ended_at`. Exactly one open `GUARDIAN` replacement has unchanged Student, Family and adult Person ancestry, carries the **first authorized correction facts**, and links via `supersedes_id` to original source.
- **Loser** commits `INVALIDATED` version 5 with no relationship UUID. The alternate approved display facts never become an appended successor.
- **Selected primary context** closes its old record at the same date and appends exactly one open context linked to the winning corrected relationship via `supersedes_id` of the original context; no extra current primary is created.
- **Whole Effect30 P1 race history (earlier END + new CORRECT)**: two `EXECUTED`, two `INVALIDATED`, four independently accepted review records, twelve typed receipts, precisely two approval applications, two successful relationship outbox events, and **zero** child-access entitlement rows.

## Failed-run diagnostics and correction scope

- [Runtime #192](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38073224170) failed during fixture setup with `D1 mutation requires a verified current principal`, because a fresh transaction did not inherit prior test JWT settings. Only the local fixture now restores the verified Foundation staff claims before protected synthetic writes.
- [Runtime #194](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38073612372) failed during fixture setup with `permission denied for schema auth`, because a restricted `schoolos_schema_owner` attempted to read `auth.users`. Only the local fixture now captures the second reviewer's fixture Auth UUID before switching roles, then reads the transaction-local setting. The frozen privilege denial remains enforced.
- The exact accepted run #196 demonstrates full successful contention after both setup corrections. No weakened guard, RLS/ACL change, new permission or hosted migration was needed.

## Changed files and release boundary

1. `supabase/tests/domain/fixtures/family_relationship_correct_race_setup.sql` — disposable retained source, selected primary history, two independently authenticated reviewers and real typed P1 requests/reviews.
2. `tools/supabase/domain_concurrency_ci.py` — worker isolation, waiting-lock observation, fail-closed complete lineage/evidence checks.
3. `tools/supabase/tests/test_domain_acceptance_ci.py` — two unit tests for worker input boundary and distinct idempotency keys.

This is **incremental D1C2A disposable acceptance only**, not proof for all concurrent P1 combinations or release readiness. Cross-action END/CORRECT, selected-primary END replacement under concurrent application, Family checked portal projections, populated upgrades, Admissions/Finance and full D1 remain OPEN. **Migration 10 remains `.sql.draft`, not deployed.**

**Checkpoint: `D1_EFFECT30_P1_CORRECT_RACE_PASS — 837/837 BUSINESS — 220/220 FOUNDATION — 8/8 RACES — 25/25 UNIT — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.**
