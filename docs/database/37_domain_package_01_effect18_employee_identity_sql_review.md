# Effect 18 implementation review

Status: corrected implementation candidate, pending final exact-SHA CI and freeze.

Operation: `employee.identity.correct` (effect 18/36).

Approved semantics implemented:
- mandatory P2 submit -> review -> explicit apply;
- first identity snapshot allowed;
- server apply-time accepted effective instant;
- reviewed CLEAR appends a null/null successor and keeps history;
- exact no-op denied;
- current open lineage head only;
- ALL or current CAMPUS EA authority; no OWN/self resolver mutation path;
- reviewer needs `employee.identity.approve`, configured reviewer role, live scope, and requester/reviewer Person separation;
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
9. `20260928000000_domain_package_01_effect18_09_final_approver_participant_correction.sql.draft`
10. `20260928000000_domain_package_01_effect18_10_employee_identity_event_aggregate.sql.draft`
11. `20260928000000_domain_package_01_effect18_11_final_approver_terminal_replay.sql.draft`

Static audit corrections:
- review-receipt replay no longer depends on the predecessor still being open after a later apply;
- stored source UUID/timestamp facts must parse before participant/read/review/apply use;
- receipt result summaries have exact safe schemas;
- successful approval application evidence is bound to the request, apply receipt, predecessor closure, successor lineage, requested values and accepted instant;
- policy resolution verifies the frozen operation still has `requires_approval=true`;
- an actor who legitimately decided multiple sequential stages can no longer be misclassified by unordered review-row retrieval;
- continuation 09 fixed the initial APPROVED apply path; continuation 11 closes the terminal-replay edge by resolving the immutable final-step reviewer role and rechecking that operation's exact current review permission/scope directly, so EXECUTED/INVALIDATED apply receipt replay remains current-authority-gated without depending on request state APPROVED;
- every terminal-replay wrapper first requires the legacy participant result to be exactly `DECIDED_REVIEWER` using null-safe `IS DISTINCT FROM`, so a NULL/unavailable participant can never fall through to an upgrade;
- `employee.identity_corrected` follows the retained-history event pattern: aggregate kind `EMPLOYEE_IDENTITY`, aggregate ref = the newly created identity snapshot, aggregate version `1`; the parent Employee remains the protected target/concurrency anchor and stays in the safe payload.

CI evidence:
- Base effect-18 candidate `ba835599b82c7f65b0db05825a0dc85f2dabe9fb` passed Actions run #42 (`36998795115`): 121/121 tooling tests, frozen Foundation source/config gates, lint and 220/220 Foundation assertions.
- Cross-effect correction candidate `abdc16a5931115425fb52c9bdb8393cc052efcfe` triggered run #43, but the terminal-replay nuance was discovered after that push. Therefore neither #42 nor #43 can be the final freeze gate.
- The commit containing continuation 11 must receive its own exact-SHA PASS before freeze.

Migration 10 remains non-executable. No D1C2 or remote execution is authorized.
