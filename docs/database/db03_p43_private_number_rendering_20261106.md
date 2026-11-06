# DB03 P43 — canonical permanent Admission-number rendering contract

**6 November 2026. Inactive DB03 proposal; no number issuance or Student mutation.**

## Why this is a prerequisite

The P41 series/immutable allocation ledger and the P42 same-application handoff FK are ready, but an actual Principal-approved Student must use a **single deterministic format** derived from the School's published profile, start of Academic Year and next locked Series value.

Example: profile prefix `CHAR`, separator `-`, `FULL_YEAR` session, Academic Year beginning in 2026, four numeric digits and serial value 1 yields `CHAR-2026-0001`.

A format mismatch could produce a duplicate number or a non-replayable Student creation receipt.

## Added

- `app_private.db03_render_admission_number(prefix, separator, session_format, year_starts_on, digits, start_value, numeric_value)`: private, immutable and `SECURITY INVOKER`; no database reads/writes.
- Supports `FULL_YEAR` and `TWO_DIGIT_YEAR`; 1–8 numeric digits; zero padding; optional empty prefix/separator; Unicode prefix.
- Rejects invalid/null/infinite inputs, outside-range values, counter overflow, ambiguous surrounding prefix whitespace, separator whitespace/control characters and overlong components.
- 31 transaction-rollback pgTAP assertions for formatting, boundary cases, lack of client/worker grants, failure paths and absence of an approval or public issue endpoint.
- Injected failed-DDL-install/rollback evidence and inclusion in combined disposable DB03 CI.

## Crucial scope boundaries

**P43 does not issue, reserve, mutate, or display an assigned Admission number.** It only calculates a canonical string from typed inputs, exclusively for a later trusted issuer. The future issuer must itself select a `PUBLISHED` ADMISSION-number profile from a current, immutable, School-scoped policy binding, derive year from the locked `app.academic_years.starts_on`, lock the matching P41 series and handle uniqueness/races/receipt replay before writing the allocation. The profile and year **cannot** be selected from client strings.

D1's `student.create` remains disabled by the frozen Effect36 contract. Application policy-version binding is a separate unresolved dependency: the current S3/S5 app draft intentionally leaves `policy_version_id` NULL, so that must be implemented under a separate reviewed source before the positive Principal APPROVE transaction. Older S10/SC-03 Finance clearance wording must also be reconciled with the owner's newer rule that an UNPAID administrative admission-fee declaration can still proceed to Principal approval.

The School Student ID, Admission number and Roll number are separate. No hosted Supabase change, main merge, production mutation or enrollment occurs.
