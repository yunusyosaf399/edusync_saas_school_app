# PR #104 — Student Photo provider-neutral mock delivery and recovery CI freeze

Date: 2026-10-19. **ACCEPTED: disposable local two-store metadata-provider recovery rehearsal only. NOT a production file upload, File AVAILABLE, Photo SET, external object-store recovery, or hosted D1 migration.**

## Exact provenance and repository acceptance

- Frozen start: `e526de3fd4668483623ef52cccc34d38d893c249`, [PR #99 freeze](217_student_photo_native_pg_lost_ack_receipt_outbox_ci_merge_freeze.md).
- [PR #104](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/104) was accepted from exact CI-tested head **`36a5d28e2412f21df54f4da033c9179006e6c6ff`**. Earlier head `84a8f19dfdb66b1f0e7b82a854fed9f068a6e61a` had a passing Foundation run but failing D1, and is **not** accepted.
- Original D1 failure: `D1_PHOTO_NATIVE_PG_PROVIDER_FINAL_EVENT_DUPLICATION`. The mock provider had passed the tested flow through actual P1 Enrollment END and VOID/reconciliation, but the final assertion erroneously counted **all** queued PostgreSQL events, including two retained PR #99 fixture events. Corrected `_outbox_count(psycopg, student)` now joins `photo_pg_trial.ack_receipts` by event ID and filters on the exact fresh Student UUID. A source regression test requires the filter, preserving real Student and Foundation guards. The correction modifies only test measurement; no authorization or shared domain SQL semantics changed.
- Premerge security and collision gate: `main` still at the prior freeze; PR open/draft/mergeable, exact expected head/base; four reviewed files only; no new public app tables, ALTER ... DISABLE RLS, public grants, direct Enrollment mutation or SQL migrations; checks passed on exact head. PR marked ready then GitHub SHA-guarded merged successfully at **`cda176fb0938db83920fc81d11039227ecae8673`**. Independently checked `main` equals merge SHA, PR closed/merged at matching SHA and the only merged file differences are:
  1. `docs/database/218_student_photo_provider_neutral_delivery_recovery_candidate.md`;
  2. `tools/supabase/domain_photo_provider_neutral_recovery_ci.py`;
  3. `tools/supabase/domain_student_photo_real_pg_handoff_ci.py`;
  4. `tools/supabase/tests/test_domain_photo_provider_neutral_recovery_ci.py`.

## Concurrent DB-01 through DB-04 workstream conflict audit

Read `AGENTS.md`, compared PRs **#100**, **#101**, **#102**, **#103** and checked full file paths against PR #104 before merge. The four other PRs were **open and unmerged**, and each changed only distinct `docs/database/db01_*`, `db02_*`, `db03_*` or `db04_*` documents. Intersections against PR #104's four changed files: **zero**. No changes were made to those four PRs, their branches, their docs, their owner-decision checklists, D1 enrollment placement/campus-transfer/end functions, Foundation authorization, active migrations, allocator or Admissions code.

Shared **conceptual dependency** remains: the Student Photo local trial uses accepted P0 Student placement and protected P1 Enrollment END, which any future DB-01/DB-02 roll allocator or DB-03 Student Creation code might touch after independent product sign-off. That future implementation must re-run current photo regression markers and reconcile common Student lock ordering. This freeze does **not** approve any DB-01...04 design decisions or pre-authorize future concurrent SQL modifications. DB-02's branch may require updating its base when it is independently reviewed. PR #104's merge does not resolve those tasks.

## Two corrected exact-head workflow results

1. [Foundation local stack #39226951190](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39226951190): **completed SUCCESS**, `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed`, **299 Python tests**.
2. [D1 Migration 10 local runtime #39226951200](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39226951200): **completed SUCCESS**, `D1_BUSINESS_PASS 3124 assertions`, **139 Python tests**, all eight previous Student Photo PR #94–99 integration markers, both new **`D1_STUDENT_PHOTO_PROVIDER_NEUTRAL_DELIVERY_PASS`** and **`D1_STUDENT_PHOTO_PROVIDER_NEUTRAL_COMPENSATION_PASS`**, and final `D1C2A_PASS`. Migration 10 remains a non-executable `.sql.draft`.

## Precisely what was accepted

This local-only test creates one synthetic new Student under a verified **test Principal** and places it through the genuine accepted P0 public application command, creating authentic PRIMARY Enrollment and Roll (no direct row insertion). It uses the approved native PostgreSQL intent/receipt/outbox fixture from PR #99 and an **independently committed, durable SQLite metadata-only mock provider**. A hashed, domain-separated key binds an event UUID, token digest and bounded action, not an exposed bearer. A trusted no-login local worker reads only pending PostgreSQL events under `FOR UPDATE SKIP LOCKED`, rechecks current Student PRIMARY/Campus/photo-profile Principal authorization, and cross-checks the exact receipt/token state before provider acceptance.

The successful exact-head runtime verified five outcomes: denial before provider acceptance; mock SQLite acceptance **committed** before a lost provider reply with PostgreSQL transaction still pending and then safely retried by deterministic idempotency key; two independent PostgreSQL workers competing for one pending event with one claim; PostgreSQL acknowledgment lost **after** delivery commit, plus forced duplicate scheduling without a second mock-provider record; and pending mock-provider acceptance followed by genuine protected P1 Enrollment END, after which normal delivery denies and a privileged disposable-only reconciler idempotently marks metadata **VOIDED** and records **CANCELLED** even if the VOID acknowledgment was lost. Native photo token remains a historically CONSUMED trial value and is never made File AVAILABLE or applied to Student Photo.

**School example:** A mock provider accepts a student's photo-intent metadata, but its reply disappears. Retrying the same event reaches the existing metadata rather than creating a duplicate. If a genuine protected Enrollment END occurs before final processing, local recovery marks the mock metadata cancelled. No actual image is stored.

## Hard nonactivation and next boundaries

- **No media bytes, HTTP provider, Supabase Storage, cloud object identity, file availability/ownership, real student Photo SET, provider deletion guarantee, image sanitation, SHA-256 verified bytes, actual school-scoped file.upload entitlement, subscription/module/purpose check, production identity/secret custody, signed provider receipt, multi-host worker restart or hosted deployment.** SQLite `VOIDED` does not represent physical erasure, and `DELIVERED` is only queue processing.
- Lost opaque ISSUE bearer response still requires separate contract; no real external exactly-once effect guarantee was established.
- Next isolated design gate: actual provider interface contract for server-side authenticated write/HEAD/delete, deterministic idempotency, signed receipt, content-hash/object-provenance checks, network retry/reconcile budget and cleanup/alerts; **do not activate** until verified with the Product Owner.
- **31/35 protected operations accepted** unchanged. #67 Photo SET **DENY**, #68 Roll Correction, #69 Roll Policy Change and #70 Admissions handoff unaccepted. D1 Migration 10 remains `.sql.draft`. DB-01...04 proposals are independent and unapproved. Real Student Photo uploads remain disabled.
