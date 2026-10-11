# D1 Effect 30 — P1 stale explicit primary replacement after a competing approved END

Date: 2026-10-11
Verdict: **PASS — exact-source disposable PostgreSQL acceptance with observed two-session lock contention. Full D1 remains OPEN.**

## Source and CI

- Previously accepted `main`: `1714cbcd5f7d4f56cd7f27528286e5fe02ae19b2`.
- Verified candidate [PR #25](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/25) exact tested head: `63ecee2ba6bd6aefdb33edbba53dda7737d8bbc2`. Merged without rewriting its code into `main` at `12623f87632067749a1893f7ae181f50175f334a`.
- [D1 disposable runtime #207](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38115539322) **PASS** on that exact head: **837/837** D1 business assertions over 20 suites, **220/220** post-D1 Foundation assertions, **31/31** Python runner unit tests, and **12/12** true two-session races with observed PostgreSQL lock waits.
- [Foundation #399](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38115539272) **PASS**: all nine frozen migration/test files and **220/220** Foundation assertions.
- The exact-head disposable run applied **202 non-executable .sql.draft fragments** locally; checked **34/34 forced-RLS D1 relations**, **540** final SQL functions (522 SECURITY DEFINER), verified five Auth fixtures, denied private-function client EXECUTE, and passed both SQL lint levels.
- Alternative [PR #24](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/24) tested a materially overlapping stale-alternative race and itself passed D1 #205 and Foundation #397; it was **closed unmerged as superseded** rather than merging duplicate fixture and runner registrations.

## What this race proves

The disposable fixture starts after the preceding eleven accepted races. Student B still has an open selected-primary Family B relationship. An independent, initially eligible Family A FATHER relationship is created as a potential explicit replacement; no Family child-portal entitlement is added.

A verified requester uses the fixed typed command to **SUBMIT** two distinct P1 END intentions, preserving their separate Family/Student version context and idempotency keys:

1. END the unselected candidate in Family A at `CURRENT_DATE-2`.
2. END the currently selected primary in Family B at `CURRENT_DATE-1`, explicitly selecting the still-eligible Family A candidate as replacement.

Two different currently authorized Person/Principal identities independently approve the requests. APPROVE does **not** modify business records. Two genuinely separate authenticated PostgreSQL sessions then APPLY: the first commits the candidate END, while the second visibly waits on a real not-granted PostgreSQL advisory/transaction/tuple lock.

After the first commits, the chosen candidate cannot cover the second operation's later effective date. Under the same live, locked revalidation, the second approved request **INVALIDATES** (rather than silently choosing a different primary or modifying history). The runner verifies:

- Candidate END: `EXECUTED`, request version **5**, retained candidate with exclusive `CURRENT_DATE-2` end and end metadata.
- Primary END: `INVALIDATED`, request version **5**, no relationship result and no additional successful application/event.
- Previously selected Family B source remains open, with the same open primary-context identifier and no new primary-context successor.
- No child access is created. Student A's previously accepted history is unchanged.
- Cumulative Effect30 race evidence: **6 EXECUTED + 6 INVALIDATED**, **6** successful approval applications and relationship success events, **12** immutable reviews, **36** typed command receipts.
- Cumulative real lock-observed races: **12** (3 Employee create, 3 FAMILY Principal membership, 6 Family relationship).

The new Python harness enforces bounded worker inputs, distinct typed reasons/idempotency keys, two separate authentic sessions, observed granted/waiting locks before first commit, exact request result shapes and full post-race history/evidence counts. Missing contention, unapproved/early-exiting workers, or wrong data fail the test.

## Scope, freeze and remaining work

Exactly three local-only test/harness files entered `main`:

- `supabase/tests/domain/fixtures/family_replacement_stale_race_setup.sql`
- `tools/supabase/domain_concurrency_ci.py`
- `tools/supabase/tests/test_domain_acceptance_ci.py`

No executable migration, schema/permission grant, D1 SQL draft fragment, Flutter code, frozen Foundation migration/test, or remotely deployed Supabase project changed. The D1C2A **twelve-race acceptance checkpoint is frozen** at the tested PR source and merge SHA above. This is not a freeze of all Domain Package 01 or authorization to release Migration 10.

**Still OPEN:** additional permission/policy and replacement cases, Family checked portal reads and field disclosure, populated upgrades, Admissions/Finance, remaining D1 operation acceptance, production deployment and Migration 10 activation. Migration 10 remains **202 non-executable `.sql.draft` fragments**.

**Checkpoint:** `D1_EFFECT30_P1_REPLACEMENT_STALE_RACE_PASS — 837/837 BUSINESS — 220/220 FOUNDATION — 31/31 UNIT — 12/12 OBSERVED-LOCK RACES — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.
