# DB03 P44 — application-specific policy and numbering-profile snapshot storage

**6 November 2026. Inactive source proposal with disposable database tests only.**

## Problem

P43 can render an Admission number when given trusted formatting inputs. It cannot decide which policy or numbering profile belongs to an application. The existing S3/S5 Admissions draft deliberately keeps `admission_applications.policy_version_id` NULL, and no protected policy-selection command exists. The eventual Principal APPROVE transaction must not guess a profile from whichever School policy happens to be newest, or accept a profile ID supplied by a client.

## Added

- Private append-only `admission_application_policy_snapshots` history with exact Application, School, Academic Year, policy version, APPLICATION numbering profile and ADMISSION numbering profile.
- Composite School/Year and Policy/Profile foreign keys prevent attaching an application from another year/school or numbering profiles that are not the selected policy's own.
- Revision and same-application predecessor keys preserve a record of later corrections; a 32-byte published configuration hash, Stage epoch, Application version, immutable creation principal and typed command receipt are required.
- Forced RLS, no direct client/service/worker grants, unconditional row-mutation and TRUNCATE blockers. **No writer has been enabled.**
- 22 rollback-only pgTAP structural/safety assertions; failure-injection rollback and full DB03 regression acceptance.

## Example

Ahmad applies in School A, Academic Year 2026. That school's **published** policy names Application numbering profile `APP-2026` and permanent Admission numbering profile `CHAR-2026`. The snapshot storage can retain that exact policy/profile relationship. An attempt to substitute a profile not named by the policy, or attach School B's policy, will violate the database foreign keys.

## Important boundaries before activation

This is storage, **not a working policy assignment**. Later a School-authorized command must select a published immutable policy, verify its effective interval/format and same School/Year, snapshot its hash and appropriate stage/identity/destination state, and create the command receipt, audit and outbox in one transaction. The existing `admission_applications.policy_version_id` projection still remains NULL under the S5 guard; the design must reconcile that field explicitly before positive submission/approval (no bypass of S3/S5 triggers).

A policy may later be retired without invalidating retained historical evidence. Therefore these FKs deliberately enforce lineage, not mutable policy publication state: the future trusted writer must verify `PUBLISHED` at binding time and the consumer revalidate the accepted policy contract when appropriate.

The older S10/SC-03 Finance-clearance gate must also be reconciled with the owner's newer decision that an administrative `UNPAID` declaration can proceed to Principal approval. No Finance or D1 code changes are included.

Next bind this source to P38/P42 Student handoff, then implement one authenticated Principal APPROVE -> Admission number allocation -> D1 Student/first status/PRIMARY Section enrollment/roll/receipt transaction with replay/race/rollback acceptance. Source-only; no hosted Supabase, `main`, or active Student mutation.
