# D1 Effect 30 — Family relationship P1 cross-campus reviewer scope acceptance

Date: 2026-10-10  
Verdict: **PASS — exact-source, disposable local D1 incremental acceptance. Full D1 OPEN.**  
PR: [#18](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/18)

## Source and validated workflows

- Prior accepted main: `15b502eb8e14665ffac412077dc8abf224b619d5`. Exact PR head tested: `bd10ffe49ccbf3b27c5d48dd4ca19a81def33022`. Merge commit: `92cf2c4e4ff9c38510c752f35815ed63046968bb`, with exact tested head as second parent.
- [D1 local runtime #180](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38055482547): **PASS**, cross-campus suite `19_family_relationship_p1_cross_campus_scope.sql` **34/34**, business tests **793/793 in 19 suites**, post-D1 Foundation **220/220**, unit tests **21/21**, **six real observed-lock two-session races** (three Employee; three Family shared-Principal membership P1 ADD/END/CORRECT). All SQL lint levels PASS.
- [Foundation #376](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38055482580): **PASS**, frozen nine migrations/nine tests, **220/220 Foundation assertions**.
- [D1 static #115](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38055482552): **PASS**, 202 non-executable draft fragments; 34 domain relations; 97 permissions, 322 scope alternatives, 36 operations; 540 final functions (522 SECURITY DEFINER), signature-shape drift zero.
- D1 local runtime assembled/applied 202 draft SQL fragments **only in its disposable local database**, verified 34/34 forced-RLS domain tables, 540 final functions (522 SECURITY DEFINER) and no private helper EXECUTE for authenticated, anon or service_role. No hosted deployment or production migration activation.

## Business acceptance — matching interval-effective Student context

The frozen `family.relationship.change` P1 reviewer contract requires configured reviewer role **and current `family.access.approve` authority** at the affected Student's interval-effective primary enrollment. Accepted direct scope alternatives are **ALL** or an actual matching **CAMPUS**, **CLASS** or **SECTION**; a previously retained reviewer assignment is not enough. A requester and reviewer remain distinct verified Persons.

Suite19 creates, within one rollback-only transaction, two active Campuses, one Academic Year and Academic Class, one Class Offering/Section Offering for each Campus, two Student PRIMARY enrollments, a matching initial capacity revision for each offering, a persistent roll policy/allocator and two distinct roll allocations spanning both enrollments. The assertions check:

- Actual PRIMARY enrollment ancestry resolves Student A to Campus A and Student B to Campus B. Under `ALL` the exact configured reviewer is valid for both and materializes as selected reviewer on two separate pending P1 submissions.
- After live `ALL` revocation with **Campus A** scope granted, the same reviewer still has the role/assignment but is **not** a current Campus B candidate. The reviewer cannot read protected B reason or approve B, and the denied attempt creates no review record, while approval for matching Student A succeeds.
- After Campus A is revoked and **Class B** granted, Class B permission authorizes B and rejects A, without campus fallback. Revoking Class B and granting **Section B** likewise authorizes B and rejects A, restores B checked-read and permits B approval.
- Neither approval creates a Family relationship. Only the verified requester explicitly applying the approved B request creates one B relationship and retained application evidence. The A request remains approved but unapplied; no Student child-access grant arises.
- Every test fixture row is rolled back; before pgTAP finish, `SET CONSTRAINTS ALL IMMEDIATE` executes all actual deferred capacity-fact, revision-projection and roll-coverage checks rather than bypassing them.

## Ancillary shared-trigger hardening exposed by real enrollment fixture

Two original generic triggers had latent shape/identifier errors that earlier suites, which did not build real enrollment/Class/Section ancestry, never exercised:

1. `effect30_31_enrollment_history_guard.sql.draft`: generic `d1_guard_effective_history()` dereferenced `NEW.supersedes_id` for `enrollments`, whose actual lineage field is `predecessor_id`. The one changed conditional tests `(pg_catalog.to_jsonb(NEW)->>'supersedes_id') IS NOT NULL`. For tables with a genuine non-null `supersedes_id`, all retained predecessor, ancestry, timestamp and head-consumption checks execute unchanged.
2. `effect30_32_crossrow_campus_local_rename.sql.draft`: `d1_guard_crossrow()` used `campus_id` for both a PL/pgSQL local variable and a SQL column, making `co.campus_id=campus_id` ambiguous. Rename only the local variable to `locked_campus_id` and all of its references; do not change SQL column names, equalities or rejected-state checks.

Both corrections are append-only `.sql.draft` continuations; their original frozen Migration 10 base source is unchanged. The functions' signatures, owners, SECURITY DEFINER pinned search paths, trigger linkage, role ACLs, matching rules, locking and privacy semantics are preserved.

## Change boundary and remaining work

Exactly four PR files relative to `main`: two append-only non-executable SQL draft continuations, rollback-only 34-assertion suite19 and one test-runner registration. Neither client privileges nor frozen Foundation migrations were modified. The PR is **accepted only for local incremental D1C2A**; full D1 acceptance, Family checked portal projections, Admissions/Finance, populated upgrade and hosted application remain OPEN.

**Checkpoint: `D1_EFFECT30_P1_CROSS_CAMPUS_SCOPE_PASS — 793/793 BUSINESS — 220/220 FOUNDATION — 6/6 RACES — 202 DRAFT FRAGMENTS — STATIC PASS — FULL D1 OPEN`.**
