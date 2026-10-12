# D1 Family portal — current emergency-contact checked read and live revocation

Date: 2026-10-12
Verdict: **PASS — exact-source disposable local PostgreSQL business acceptance; full Domain Package D1 remains OPEN.**

## Verified GitHub source, merge and independent workflows

- Previously frozen and documented `main`: `6e7c299632f9b2175f1963a850e455617d098940`.
- [PR #35](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/35) **MERGED** as `03d6973258f7f30d5c061d32c7b3998f590e4cec` from exact accepted source head `297a69c81548cff9feb95bd709750f629983c269`.
- Both successful GitHub Actions checked out PR merge ref `7d568009b533a8feab1ea9ccc329f99e8b5cae02`, which merged that exact head into the same previously accepted main.
- [D1 Migration 10 disposable local runtime #274](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38209684226): **PASS**, `D1C2A_PASS`, **1,435/1,435** business pgTAP assertions across **29** suites, including `29_family_portal_emergency_contact_current_checked_read.sql` **77/77**; **220/220** post-D1 frozen Foundation regressions; **42/42** D1 Python tooling unit tests; and unchanged **13/13** real two-session PostgreSQL observed-lock races (3 Employee creation, 3 Family Principal Membership, 7 Family Relationship). Error/warning SQL lint PASS.
- [Foundation database local stack #449](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38209684285): **PASS**, **198/198** Python tooling unit tests, frozen **nine** migrations/**nine** SQL files, **220/220** Foundation pgTAP assertions, clean local reset and error/warning SQL lint.
- The D1 harness assembled **202 inactive Migration 10 `.sql.draft` fragments** and parsed/applied them **locally in a disposable PostgreSQL stack only**. Its catalog probe reported **34/34** force-RLS D1 tables, **540** functions (**522** SECURITY DEFINER), and no private helper EXECUTE for `authenticated`, `anon` or `service_role`. **No hosted Supabase, real school data, executable Migration 10 migration, or production API was changed.**

## Frozen contract and precisely accepted 77-assertion scenario

The current emergency-contact checked RPC `app.d1_read_student_emergency_contacts(uuid)` exposes only **four typed fields**—`display_name`, `relationship`, `phone`, and `email`. It uses the distinct `student.emergency_contact.view` permission. An authenticated shared FAMILY Principal must possess a currently effective **family-only, family-safe** role grant and exact `OWN/D1_FAMILY_CHILD` scope, current FAMILY Principal and membership, a valid Family–Student relationship basis and an effective Student-specific child entitlement. Historic records require a different, staff-only `student.emergency_contact_history.view` privilege. Emergency-contact record/Person ID possession grants no FAMILY/guardian/pickup authority; no raw private table read is granted.

The rollback-only `BEGIN` / `ROLLBACK` SQL acceptance test covers:

1. A real authenticated FAMILY identity already connected to Student A through active shared-Principal Family membership, GUARDIAN relationship basis and a **real, separately staff-authorized child-access ADD**. Student A and unrelated Student B each have real, current PRIMARY enrollments and retained class/section/academic year, capacity and roll evidence; Student B has no FAMILY-child entitlement.
2. The schema-owner synthetic fixture creates **two current Student A contact records**, one with a supplied name (AUNT) and one linked to a real Person (GUARDIAN) whose fallback display comes from the private People record; **one ended Student A contact**, **one future Student A contact**, and an independent **current Student B contact**. These rows do not grant child access, relationship basis or new permissions. Valid ended metadata is retained.
3. With only the separately permitted FAMILY summary privilege, the actual authenticated FAMILY client reads its Student A summary but **zero emergency contacts or historic emergency contacts**.
4. Only after configuring a live `student.emergency_contact.view` family-only/family-safe grant and corresponding `OWN/D1_FAMILY_CHILD` scope can the FAMILY client see **exactly two currently effective Student A contact rows**. The actual four approved display values for named and Person-linked rows are checked. The expired and future-dated contacts do not appear. Student B, nonexistent UUIDs and NULL target return no rows.
5. Typed disclosure verification asserts **four keys per visible contact row**, **eight keys across two rows**, with **zero Person/contact row IDs, Student IDs, audit or interval dates, lineage/reason and private identity fields**. The current grant does not authorize history, Student PROFILE/ROSTER, Restricted Identity or Student Special; authenticated raw private emergency-contact and identity table SELECTs remain denied.
6. A savepoint-bound owner edit closes one current contact on the present business date. The current read immediately drops from two rows to one, without suppressing the unaffected contact; rolling back the savepoint restores the two-row current view without enabling history.
7. Separate rollback-bound tests revoke the **emergency-view role grant**, revoke its exact **assignment scope**, and end the **FAMILY shared-Principal membership**. Each alone removes the current emergency-contact projection immediately. Revoking only the emergency grant or scope preserves independently permitted Family summary. Savepoints restore the baseline independently.
8. An independent, authenticated and authorized staff actor performs a **real `app.d1_change_family_child_access(..., 'REVOKE', ...)`** on Student A, with effective end `CURRENT_DATE`. Even though the FAMILY identity, grants, membership, GUARDIAN basis, PRIMARY enrollment and all five emergency-contact history rows remain, Student A emergency-contact read immediately returns **zero**. Student B remains invisible, historic contact reads cannot bypass the revocation, and Family summary also denies. Original relationship, Family membership and contact history are retained; one genuine ADD and one REVOKE successful receipt/outbox event each and one closed historical child-entitlement interval remain. Anonymous EXECUTE of current checked-read RPC is denied.

All private emergency-contact fixture insertion and synthetic date/membership/grant changes are performed as the schema owner **within the rolled-back SQL test transaction**, not as the FAMILY client. The genuine child-entitlement ADD and REVOKE go through protected authenticated commands. Authenticated FAMILY reads use existing fixed-purpose `app` RPCs only.

## Exact bounded source change and remaining gates

Exactly three **acceptance-only** files changed:
- `supabase/tests/domain/29_family_portal_emergency_contact_current_checked_read.sql`: new **77/77** rollback-only assertions;
- `tools/supabase/domain_business_ci.py`: register **29th** domain suite and 77-assertion plan;
- `tools/supabase/tests/test_domain_acceptance_ci.py`: add one Python unit guard for current/historic separation, effective intervals, typed field ceiling, permission/membership/scope/child-entitlement revocations and no raw client reads.

**No production SQL, frozen Foundation contract, Migration 10 SQL draft, deployed grant/RLS rule, application code, external API or hosted Supabase resources were changed.** The **29-suite, 1,435-assertion disposable D1C2A business checkpoint is accepted and frozen** alongside the already accepted **13/13 observed-lock races**.

**Full D1 remains OPEN** for other Family portal current/history, emergency-contact and alternative-relationship-basis permutations, broader inter-Family isolation/role/scope matrices, other D1 operation acceptance, populated upgrade, Admissions/Finance and hosted Migration 10 activation. All **202** Migration 10 fragments remain inactive `.sql.draft`.

**Checkpoint marker:** `D1_FAMILY_EMERGENCY_CONTACT_CURRENT_CHECKED_READ_PASS — 1435/1435 BUSINESS — 220/220 FOUNDATION — 42/42 D1 UNIT — 13/13 OBSERVED-LOCK RACES — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.
