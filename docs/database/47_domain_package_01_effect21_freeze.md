# D1C1B Effect 21 — Student Restricted Identity Freeze

**Status: FROZEN**

## Operation

- Effect: **21/36**
- Operation: `student.identity.correct`
- Required review permission: `student.identity.approve`
- Approval class: **P2 REQUIRED_REVIEW**
- Relation: `app_private.student_identity_details`
- Event: `student.identity_corrected`

## Trusted implementation

Trusted runtime implementation SHA:

`08a5c2c6912170738f1ded9e809e01d8dc8d6150`

The two commits after that SHA and before this freeze are review-documentation only. No runtime SQL changed after the exact-SHA CI run.

## Frozen product/domain decisions

1. `student.identity.correct` is CORRECT-only. It requires an existing current restricted-identity snapshot; absence of a current snapshot is rejected rather than treated as initial creation.
2. Correction atomically closes the current snapshot at server apply-time and inserts one successor at the same instant with `supersedes_id` bound to the predecessor.
3. P2 review is mandatory; no DIRECT route is permitted. Requester/reviewer Person separation is enforced.
4. Apply rechecks current requester authority, reviewer authority, policy, target/version and source snapshot. Deterministic stale failures invalidate the approved request; malformed stored payload remains rollback-class failure.
5. Student authorization uses the frozen ACS target model derived from stored PRIMARY placement ancestry; placement itself grants no authority.
6. Exact factual no-op correction is rejected; reason-only changes cannot create a successor.
7. Raw national identity, birth-certificate values/file metadata, private address, guardian identity/contact and arbitrary reason are excluded from broad receipt/audit/outbox evidence.
8. Birth-certificate linkage remains typed to `BIRTH_CERTIFICATE`; referenced file must exist and be `AVAILABLE`. The relationship grants no upload/download authority.
9. Terminal successful/rejected apply replay returns durable retained result after current participant authority recheck and does not repeat mutation/evidence.
10. Foundation authorization lock `(71001,1)` is SHARED before Student/history locks; successful outbox aggregate is the retained `STUDENT_IDENTITY` snapshot at version 1.

## CI evidence

GitHub Actions workflow: **Foundation database (local stack)**

- Run: **#53**
- Run ID: `37096183204`
- Exact checked-out SHA: `08a5c2c6912170738f1ded9e809e01d8dc8d6150`
- Conclusion: **SUCCESS**
- Tooling unit tests: **121/121**
- Foundation source guard: `FOUNDATION_SOURCE_PASS 9 migrations + 9 tests`
- Local config: `LOCAL_CONFIG_PASS`
- Supabase CLI pin: **2.98.2**
- Docker/Linux gate: PASS
- Local reset: nine frozen migrations, no seed
- Auth fixtures: **5/5**
- Lint error/warning gates: PASS
- pgTAP: **220/220** across tests 01–09
- Local stack stopped cleanly

The GitHub Actions Node.js deprecation warning is runner/action tooling noise and not a project test failure.

## Independent audit result

The implementation was independently reviewed before and after CI. Pre-freeze hardening corrected reviewer-role/scope coupling, deterministic birth-certificate validation, final-approver terminal replay and retained-history outbox aggregation. The final post-CI comparison confirms that `08a5c2c6... -> 029bc286...` contains only the database/security review documents; no runtime SQL changed after the successful exact-SHA run.

## Boundary

This freeze is source/static + Foundation-regression evidence only. Migration 10 remains non-executable `.sql.draft`. The Effect-21 draft was **not executed by PostgreSQL in CI**, and D1C2 / remote or staging application remains unauthorized.

Frozen manifest vocabulary remains **97 permissions / 322 scope alternatives / 36 operation contracts**.
