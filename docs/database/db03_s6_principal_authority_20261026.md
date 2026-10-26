# DB03 S6 — principal-only identity authority and admission completion dependencies

Owner requirement: [principal approval sequence](db03_owner_decision_principal_admission_authority_20261026.md), including the later missing-document forwarding restriction. This supersedes generic staff identity-verifier eligibility. Inactive candidate only; no deployment or merge.

## Implemented restriction

The S4 original-document attestation and S5 candidate-check/Person-create authority routines now require `roles.code='PRINCIPAL'`, active non-family role, active authenticated individual, and the whole exact current operation/permission/assignment/scope chain. Foundation `guard_roles()` already makes role code immutable. A label named Principal has no effect. A principal assignment cannot borrow a grant carried by the administrator role. Deployment administrators must register the exact principal code through the existing trusted role catalog; there is no default role/permission activation or permission bypass.

Identity attestation retains applicable ALL/exact-CAMPUS scope; canonical Person search/creation remains ALL-only. Authorization is checked before private source inspection and during evidence/replay under the existing authorization fence. Current revocation, role retirement and expiry continue to deny. Neither a Person record nor original inspection submits the application, creates a Student, verifies uploaded bytes or grants family access.

The publication test fixture now creates the designated synthetic principal role with exact grants so retained S4/S5 positive paths exercise the new requirement. This is disposable test data, not bootstrap configuration. A new suite creates an independent administrator role with all exact permissions and the misleading label Principal; it tests that those grants cannot satisfy the principal requirement even for an actor holding both roles.

## Verification

Verified runtime source `5fa2acac284213443a5c84fa935de1450d4b25dc`, tree `fcdcbdfbbf248dccd78860d7a5fc6ecab86b9147`: [DB03 run 40371810484](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/40371810484) **SUCCESS**, 277/277 DB03 assertions, 220/220 frozen Foundation assertions and 24/24 genuine observed-lock schedules. [D1 static run 40371810523](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/40371810523) **SUCCESS**. All DDL rollback/guard-restoration and fixture rollback checks passed; the disposable stack stopped. An initial container-registry image-pull failure was recovered by the pinned harness; it was not a SQL/test failure. Local source validation, Python compilation and diff whitespace checks also pass. The later documentation-only successor records these results and the subsequently answered deadline/retention choices without changing tested code.

The added suite contains 27 assertions: administrator intake success; administrator denial for all three identity APIs; unchanged application/no denied-command receipts; label/code spoof resistance; same-chain grant requirements; retired role/revoked scope; successful principal identity and real Person creation; retained DRAFT state; current assignment required on all historical replays; no duplicate source/evidence; no client role writes.

Four new real PostgreSQL backend schedules cover principal-assignment revocation and principal-role retirement before S4 attestation and S5 creation. Each observes the blocking backend before committing revocation, then proves denied command and unchanged root/source. A fresh disposable catalog per additional schedule avoids reversing accepted revocations. Observed combined totals: 277 DB03 assertions, 220 frozen Foundation assertions, 24 observed-lock schedules. No frozen Foundation files/tests change.

## Full requested workflow: current status

| Requested behavior | Actual implementation status |
|---|---|
| Administrator prepares unresolved application | Existing protected draft-create command; no identity attestation granted by intake permission |
| Administrator records up to two months for missing certificates | Existing protected grant history with immutable first School-local calendar cap |
| Principal alone attests identity | S6 implementation above |
| Administrator attaches private certificates received in time | Not implemented: needs actual registered file-purpose/entitlement service and byte-validated private uploads |
| Missing required documents block forwarding to principal | Not implemented: no forwarding command or effective attachment roster exists; do not claim current DRAFT-only state is a finished queue |
| Principal independently verifies attached documents | Not implemented: file provenance, independent uploader/reviewer and current file-state evidence needed |
| Principal approval then submitted application and Student creation | Not implemented: requires complete document/stage source, mandatory Finance-authorizer clearance, D1 destination/number allocation and atomic single-use handoff |

The remaining rows are dependencies to implement, not owner permission requests. Their existing contracts must be composed; a fabricated AVAILABLE metadata row, caller `documents_complete`/`paid` flag, arbitrary approval UUID, direct Student INSERT or denial-only placeholder would not satisfy this task. Current checked repository sources contain no protected upload/finalization service, Finance clearance command or successful D1 `student.create` API. Relevant contracts: [P3 document boundary](db03_p3_document_verification_stage_outcome_readiness_20261020.md), [P6 Finance boundary](db03_p6_school_finance_clearance_readiness_20261021.md), [D1 handoff](155_d1_student_create_admissions_handoff_contract_readiness.md).

Required acceptance after those dependencies exist: missing birth/transfer certificate blocks forwarding; timely real attachment allows forwarding only; same-uploader principal cannot verify; invalid/quarantined/stale/replaced files invalidate approval eligibility; approval without all required evidence/Finance/destination denies; one accepted principal approval produces exactly one submitted application and real Student/status/PRIMARY enrollment/roll/ID/handoff effect atomically; competing approval/retry/revocation/file quarantine/Finance reversal schedules prove no duplicate or partial result. The owner subsequently selected rejection with retained history for certificates still missing after the deadline, and permanent retention of uploaded certificates, including rejected/withdrawn cases. See [exact selections](db03_owner_decisions_certificate_expiry_retention_20261026.json). These require the document/deadline worker and storage-retention integration; neither is implemented in this authority slice.
