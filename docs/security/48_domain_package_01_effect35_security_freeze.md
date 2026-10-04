# D1C1B Effect 35/36 — Employee Designation Security Freeze

**Status: FROZEN.**

Trusted runtime SHA: `97e6eb7d8329475861fd3b4c0f7fc5f7e7c175c7`.

Exact-SHA GitHub Actions run #208 (`37186906366`) completed successfully on that SHA.

## Frozen security contract

`employee.designation.change` is P0 DIRECT only and requires exact current non-family-safe `employee.designation.manage` with ALL/DIRECT scope against the locked School.

No CAMPUS, OWN/FAMILY, Employee-membership, Designation/job-assignment, Department, label, title or role-name shortcut grants authority. FAMILY cannot satisfy the staff permission and SYSTEM is not an ordinary business caller.

Fresh live authorization is evaluated after target locks and before replay or mutation.

## Frozen mutation boundary

The command may only:

- CREATE one ACTIVE Designation with server UUID, stable School/code identity and nonblank label;
- UPDATE label only on the exact ACTIVE expected-version Designation;
- ARCHIVE the exact ACTIVE expected-version Designation one-way with server archive evidence.

There is no DELETE or reactivation path. `school_id` and `code` are immutable and code uniqueness remains retained after archive.

Archiving a Designation does not rewrite Employee job assignments, change Employee state, alter payroll terms, provision roles/grants, affect campus affiliation or create Teaching authority. Archived Designations are rejected by separately protected job-assignment ADD/CORRECT paths as new destinations.

## Frozen evidence boundary

Successful receipts use `D1_DESIGNATION` with exact `{row_version,state}` summary. Broad audit is `employee.designation.change` / `DESIGNATION` with only `{action,state,row_version}` details. Designation code/label and unrelated HR data are excluded. No Designation outbox event is emitted.

Effect-35 continuation 01 adds schema-owner trigger guards for exact receipt/audit binding. The trigger functions revoke PUBLIC, anon, authenticated and service_role EXECUTE and create no new client/executor entry point.

The receipt append-time current-row binding does not make replay dependent on the result remaining current; successful historical replay still rechecks present authority and returns retained result evidence without inserting a new receipt.

## Validation/freeze boundary

Run #208 (`37186906366`) on exact runtime SHA `97e6eb7d8329475861fd3b4c0f7fc5f7e7c175c7` passed exact checkout, 121/121 tooling tests, frozen 9-migration/9-test integrity, Supabase CLI 2.98.2, 5/5 Auth fixtures, lint gates and 220/220 Foundation TAP assertions.

The Effect-35 runtime delta from Effect-34 freeze tip `0e5535cb80157c4947e315b39791d76a0001e630` is exactly:

`supabase/migrations/20260928000000_domain_package_01_effect35_01_designation_evidence_guard.sql.draft`

Migration 10 remains `.sql.draft` and unexecuted; the exact-SHA CI gate did not parse or deploy it. Foundation migrations 1–9 and the frozen **97 permissions / 322 permission-scope alternatives / 36 operation contracts** manifest remain unchanged. D1C2, managed/staging application, worker activation and Effect 36 implementation are not authorized by this freeze.

**`DOMAIN PACKAGE D1C1B EFFECT 35/36 SECURITY FROZEN — EMPLOYEE.DESIGNATION.CHANGE ACCEPTED`**
