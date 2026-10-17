# Student Profile P1 — independent source-gap assessment after SP owner approval

Date: 2026-10-17. Source: frozen `main` `21abb1fdf8e2e4d66b7f8ca3f43710660c415238` plus documentation-only PR #78. **Static/source review only**, not a new runtime SQL acceptance claim. Owner intent approval is frozen separately in [#173](173_d1_student_profile_p1_owner_approved_contract.md), secure history choice in [ADR-005](../decisions/ADR-005-student-profile-restricted-history.md).

## Verified gaps against installed *draft* SQL

1. D1 `app_private.students` has six nullable PROFILE columns and `row_version`; `app_private.student_identity_details` and `app_private.student_special_details` are distinct histories. D1 base remains 34 relations.
2. `app.d1_change_student_profile(uuid,uuid,date,text,text,text,text,uuid,bigint,text)` currently builds a six-key complete payload, passes it to `app_private.d1_profile_direct`, and has **no reason argument**. It therefore cannot satisfy approved SP-04/08's mandatory private purpose reason for DIRECT. Do not silently invent a reason.
3. `app.d1_submit_student_profile_update` currently builds the same complete payload. `app_private.d1_profile_payload_valid` requires all six keys; `app_private.d1_profile_effect` writes all six Student columns from those keys. This does **not** preserve UNCHANGED versus CLEAR. No-op and normalization must be reviewed, not assumed from existing tests.
4. Existing photo references use `profile_photo_file_id` and file-purpose guards; SP-03 requires separate entitlement/ownership testing before all-purpose acceptance. Existing test suites largely exercise `previous_school` and selected P1 routes; green concurrency cannot prove all field semantics.
5. No existing dedicated `app_private.student_profile_revisions` relation was identified in frozen base draft. Broad `audit_events`/`outbox_events` remain redacted and are not a substitute for SP-08 B secure old/new values.
6. Existing PRs #71–#77 passed incremental local-only authenticated P1 DIRECT, APPROVAL, negative, policy/scope, and real concurrency acceptance. Their frozen exclusions explicitly **do not** mark `student.profile.update` accepted. Last PR #77 local runtime recorded **74 business suites, 3,124 assertions**, Foundation **220** and disabled operation baseline; those tests must be preserved.

## Required dependency order, without skipping security gates

1. **Freeze owner semantics** (this PR): SP-01…SP-07 and SP-08 B as separate recorded decision; do not change past readiness snapshots or increment accepted count.
2. **Physical history design/DDL review** (future distinct branch/gate): choose purpose-restricted atomic old/new storage and authorize an additive migration, narrow role privileges and RLS. Existing 34 D1 relations remain unchanged.
3. **Typed Student-only RPC correction**: explicit per-field UNCHANGED/SET/CLEAR; independently typed server value validation and file entitlement; nonblank private DIRECT reason; preserve Employee Profile behavior and review/apply security.
4. **Positive/negative/race acceptance**: successful authorized Student new/current history, per-field clearing and unchanged, approval/revocation/route switches, dynamic historical replay, observed two-session contention, version and payload minimization.
5. **Exact SHA review and freeze**: three expected GitHub workflows (D1 local runtime, Foundation, D1 draft static) all SUCCESS; independent security and retention audit; only then count 32/35 and subsequently plan Roll Correction.

## This PR's actual effect and exclusions

**Documentation-only**: new approved contract, new ADR selecting **requirement** for restricted history, and this source-gap audit. No `.sql.draft` modification, no added table, no tests altered, no policy/grant/RLS change, no manifest increase, no remote actions. D1 remains **31/35 accepted**, Migration 10 **inactive**, four Student protected commands still **not fully accepted**, Issue #67 remains open. Exact-SHA CI on a future SQL candidate has *not* been run in this document gate.
