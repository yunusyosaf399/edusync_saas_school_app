# D1 Family portal — current checked-read permission, disclosure and live revocation

Date: 2026-10-12
Verdict: **PASS — exact-source disposable local PostgreSQL acceptance only. Full D1 still OPEN.**

## Exact source and independently verified workflows

- Prior frozen `main`: `db1a6f1ce1ee04120c964cd7465af56e27ef3d1c`.
- [PR #33](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/33) merged as `6ef3bbeb39a016b1f86fcc006e9de433fb7d2a37` from exact corrected source head `832dbda4fe7e2a996fc2bb75f6f43cf54fce9a11`. The two passing workflows checked out PR merge ref `ae0186560744c020792c81f4648f51751c3e2cdf`, merging that exact head into the accepted prior base.
- Initial D1 #260 and Foundation #439 **FAILED during Python unit preflight only**: a tooling test incorrectly expected 69 assertions for frozen suite #23 (actual 65) and 65 for new suite #27 (actual 69). No PostgreSQL runtime acceptance ran during those failures. Corrected by a **unit-only fix** `832dbda4fe7e2a996fc2bb75f6f43cf54fce9a11`; neither SQL suite or production logic was altered.
- [D1 disposable runtime #262](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38198831723) **PASS**: **1,291/1,291** business pgTAP assertions across **27** suites, new `27_family_portal_checked_current_read_revocation.sql` **69/69**, **220/220** post-D1 Foundation regressions, **40/40** D1 tooling unit tests, unchanged **13/13** observed-lock two-session PostgreSQL race cases, both SQL lint levels PASS and final `D1C2A_PASS`.
- [Foundation local stack #441](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38198831688) **PASS**: nine frozen migrations/nine SQL suites, **220/220** Foundation pgTAP assertions, **196/196** Python tooling tests, local reset and both SQL lint passes.
- D1 runtime assembled **202** non-executable Migration 10 `.sql.draft` fragments and applied them **only in a disposable local database**; verified **34/34** forced-RLS tables and **540** final functions (**522** SECURITY DEFINER), without client-role private helper EXECUTE. No production migration, hosted Supabase operation or real school data changed.

## Precisely accepted current Family portal read boundary

The existing fixed-purpose `app.d1_read_family_summary_for_student(uuid)` and `app.d1_read_family_relationships_for_student(uuid)` expose **typed current views**, not raw private domain tables. The frozen FAMILY resolver `OWN/D1_FAMILY_CHILD` requires a verified current shared FAMILY Principal and Auth binding, current Family Principal membership, an effective family-to-Student child entitlement, an effective approved relationship basis, and a separately enabled, currently live family-safe grant and matching OWN scope.

The 69-assertion `BEGIN/ROLLBACK` pgTAP suite uses real authenticated-family JWT context, separate real staff child-access **ADD** and **REVOKE** domain commands, and owner-only synthetic fixture setup. It confirms:
1. A valid FAMILY login can see Student A's exactly authorized linked Family summary; other Student B, unknown and NULL IDs return no rows. The Family summary has **exactly four typed fields** (Family ID/label, Student ID/display), excluding internal, restricted and sensitive Student data.
2. `family.summary.view` grants no `family.relationship.view`, Family relationship history, Student roster/profile, restricted identity or Student special disclosure by itself. Authentic `authenticated` raw SELECT on private Student, Family relationship and child-access tables remains denied.
3. Adding a separate enabled family-safe **`family.relationship.view`** grant with matching OWN/D1_FAMILY_CHILD assignment exposes Student A's current relationship kind/adult display only, **three typed fields**, and never raw Person ID, contact, audit, lineage or history. Other Student B is still denied; historical relationship/admin/membership views are separately gated.
4. Revoking **only** the relationship-view grant causes current relationship display to disappear without suppressing still-permitted Family summary (savepoint rollback restores the grant). Ending shared Family membership alone suppresses both current views despite preserved historical relationship and child entitlement (savepoint rollback restores legitimate access).
5. A real separately authorized staff **`family.child_access.change` REVOKE**, closing the Student A child entitlement effective `CURRENT_DATE`, immediately denies both current Family reads, including attempts to use historical relationship surfaces. Original relationship evidence, membership and active Principal remain retained, with exactly one ADD receipt/event and one REVOKE receipt/event and one closed historical entitlement rather than deletion. Anonymous EXECUTE of checked read is denied.

Every client-side read goes through typed `app` RPCs under `SET ROLE authenticated`, not a private table SELECT. This is the **current Family summary/relationship** disclosure checkpoint, not an enrolled Student ROSTER/PROFILE, restricted identity, special fields, historical search or full portal acceptance.

## Bounded change and remaining gates

Exactly three test-only source paths changed:
- `supabase/tests/domain/27_family_portal_checked_current_read_revocation.sql` — new 69-assertion current-read, revoked-permission and revoked-entitlement acceptance suite;
- `tools/supabase/domain_business_ci.py` — explicit suite #27 registration;
- `tools/supabase/tests/test_domain_acceptance_ci.py` — new static/ACL guard and corrected suite #23/#27 test expectations.

No Foundation migration, active D1 migration, Migration 10 draft, RLS/grant deployment, Flutter app, UI, API or hosted database changed. **The 27-suite, 1,291-assertion business acceptance checkpoint is accepted and frozen**, with prior **13/13** observed-lock races still accepted.

**Full D1 remains OPEN** for Student ROSTER/PROFILE Family checked-read permission/field-ceiling tests, other Family-history and disclosure combinations, populated upgrade/reconciliation, other D1 business operations, Admissions/Finance, and hosted Migration 10 activation. All **202** fragments remain inactive `.sql.draft`.

**Marker:** `D1_FAMILY_PORTAL_CURRENT_READ_REVOKE_PASS — 1291/1291 BUSINESS — 220/220 FOUNDATION — 40/40 D1 UNIT — 13/13 OBSERVED-LOCK RACES — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.
