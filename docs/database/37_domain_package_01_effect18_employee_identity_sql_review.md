# Effect 18 implementation review

Status: implementation candidate, pending CI and freeze.

Operation: `employee.identity.correct` (effect 18/36).

Approved semantics implemented:
- mandatory P2 submit -> review -> explicit apply;
- first identity snapshot allowed;
- server apply-time accepted effective instant;
- reviewed CLEAR appends a null/null successor and keeps history;
- exact no-op denied;
- current open lineage head only;
- ALL or current CAMPUS EA authority; no self-mutation path;
- reviewer needs `employee.identity.approve`, configured reviewer role, live scope, and Person separation;
- multi-campus policy selection resolves campus-over-school precedence for each current campus and denies unless all resolutions converge to one policy-version ID;
- Employee -> identity-history locking after Foundation authorization/idempotency/principal locks;
- deterministic stale policy/authority/history invalidates without mutation;
- success emits `employee.identity_corrected` with safe metadata only;
- catalog remains 97 permissions / 322 alternatives / 36 operations.

Ordered static `.sql.draft` package:
1. `20260928000000_domain_package_01_effect18_01_employee_identity.sql.draft`
2. `20260928000000_domain_package_01_effect18_02_employee_identity.sql.draft`
3. `20260928000000_domain_package_01_effect18_03_employee_identity.sql.draft`
4. `20260928000000_domain_package_01_effect18_04_employee_identity_application_guard.sql.draft`
5. `20260928000000_domain_package_01_effect18_05_employee_identity_receipt_hardening.sql.draft`
6. `20260928000000_domain_package_01_effect18_06_employee_identity_review_replay.sql.draft`
7. `20260928000000_domain_package_01_effect18_07_employee_identity_payload_parse.sql.draft`
8. `20260928000000_domain_package_01_effect18_08_employee_identity_p2_contract.sql.draft`

Pre-push static audit corrections:
- review-receipt replay no longer depends on the predecessor still being open after a later apply;
- stored source UUID/timestamp facts must parse before participant/read/review/apply use;
- receipt result summaries have exact safe schemas;
- successful approval application evidence is bound to the request, apply receipt, predecessor closure, successor lineage, requested values and accepted instant;
- policy resolution verifies the frozen operation still has `requires_approval=true`.

Migration 10 remains non-executable. No D1C2 or remote execution is authorized.
