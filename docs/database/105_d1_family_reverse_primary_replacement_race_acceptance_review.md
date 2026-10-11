# D1 Effect 30 — P1 reverse primary replacement race: primary switch wins before candidate END

Date: 2026-10-11
Verdict: **PASS — exact-merge-ref disposable PostgreSQL acceptance with observed two-session lock contention. Full D1 remains OPEN.**

## Reviewed source and CI

- Accepted previous `main`: `aa8d56ad0f097b32e1f23f5819c26a3e96de2c02`.
- [PR #26](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/26) exact source head: `6c34a4a520a67ea2fa3f7b67033651bc40da7ad8`, merged with the expected SHA into `main` as `b6ac7e199a884f650ca09fc08d1064a3ace0b603`. The merge-ref GitHub Actions checkout is `104882969d55b3b4cda019093cbeef8385e8bf4d`, merging the same PR source into the same accepted base. The CI-tested merge tree is the accepted merge tree.
- [D1 disposable runtime #214](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38121289173): **PASS**, **33/33** runner unit tests, **837/837** business TAP assertions over **20 suites**, **220/220** post-D1 Foundation assertions and **13/13** true two-session concurrency races (three Employee create, three Family membership and seven Family relationship).
- [Foundation #404](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38121289229): **PASS**, **189/189** tooling unit tests, frozen nine migrations and nine test files, **220/220** Foundation TAP assertions.
- Runtime #214 applied **202 non-executable Migration 10 `.sql.draft` fragments** only in a disposable local PostgreSQL stack; **34/34** domain relations enforced RLS, **540** final SQL functions (522 SECURITY DEFINER), five test Auth identities, no direct authenticated/anon/service_role private helper EXECUTE, both lint levels PASS. Disposable stack stopped at end.

## Domain case and assertion evidence

This is the **reverse winner** of [the accepted stale-replacement race](104_d1_family_primary_replacement_stale_candidate_race_acceptance_review.md). The previously selected Family B primary relationship of Student B is still open. The fixture creates an eligible different-Family A **GUARDIAN** replacement relationship and a distinct still-eligible Family A **MOTHER** basis, with no child-portal access. The MOTHER ensures that, after selection of the GUARDIAN as primary, a subsequent END of the GUARDIAN at the later date requires a valid explicit alternative, rather than silently choosing or clearing the primary.

An authenticated requester SUBMITs two different typed P1 END requests before either applies:

1. END the currently selected Family B primary at `CURRENT_DATE+1` **with the explicit Family A GUARDIAN relationship as replacement**.
2. END the initially unselected Family A GUARDIAN at `CURRENT_DATE+2`, **with no designated primary replacement**.

Each goes through a distinct real Person/Principal reviewer who independently APPROVEs; there is no synthetic pre-approved row or direct mutation. Two separately authenticated PostgreSQL workers APPLY, with first-worker granted and second-worker waiting database lock observed *before* the first transaction commits. The **primary switch commits first** and the competing candidate END must revalidate the dependency on the now-selected primary.

D1 runtime #214 logs `D1_FAMILY_REPLACEMENT_REVERSE_RACE_PASS`. Its exact evidence requires:

- Primary-switch END `EXECUTED`, request version **5**. Former Family B relationship and selected primary context retain exclusive end date `CURRENT_DATE+1`.
- Exactly one current primary-context successor selects the exact Family A GUARDIAN starting `CURRENT_DATE+1` and supersedes the previous context.
- Competing stale GUARDIAN END `INVALIDATED`, version **5**, no new relationship mutation or success application/event.
- Family A GUARDIAN remains open, Family A MOTHER remains open, and no child access is introduced. Previously accepted Student A records remain unchanged.
- Cumulative Effect 30 two-session outcomes: **7 EXECUTED + 7 INVALIDATED**, **7** successful approval applications and outbox success events, **14** genuine P1 approval reviews and **42** typed receipts.
- Cumulative observed-lock D1C2A races: **13** (three Employee create, three Family membership and seven Family relationship).

The bounded runner checks worker SQL intent and keys, requires observed lock waiting, validates exact row outcomes and retained history, and fails on missing contention/changed evidence. Two new Python tests validate strict worker positions, real authenticated role setup, first-winner hold and distinct typed action keys.

## Scope, freeze and remaining release boundary

Exactly **three local-only acceptance files** changed:

- `supabase/tests/domain/fixtures/family_replacement_reverse_race_setup.sql`
- `tools/supabase/domain_concurrency_ci.py`
- `tools/supabase/tests/test_domain_acceptance_ci.py`

No D1 SQL draft, frozen Foundation migration/test, executable hosted migration, application code, RLS/permission grant or remote Supabase database changed. The **13-race disposable-local D1C2A acceptance checkpoint is accepted and frozen at the above source and merge commit**, not full Domain Package D1 acceptance or authorization to activate Migration 10.

**Still OPEN:** other security/approval permutations, full Family checked portal reads and disclosure, populated upgrades, Admissions and Finance, other D1 command operation acceptance and hosted activation. Migration 10 remains **202 unactivated `.sql.draft` fragments**.

**Checkpoint:** `D1_EFFECT30_P1_REVERSE_REPLACEMENT_RACE_PASS — 837/837 BUSINESS — 220/220 FOUNDATION — 33/33 D1 UNIT — 13/13 OBSERVED-LOCK RACES — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.
