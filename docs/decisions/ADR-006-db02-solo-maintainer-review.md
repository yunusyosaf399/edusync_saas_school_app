# ADR-006: DB02 solo-maintainer development review

- **Status:** Accepted (review policy only; code-version acceptance remains separate)
- **Date:** 2026-10-26
- **Owner:** Younas Khan / `yunusyosaf399`
- **References:** DB02 issue #69 P03/G03; review issue #131; PR #168
- **Supersedes:** The mandatory non-author development-review mechanism in DB02 P03/G03 and issue #131, for this sole-maintainer project. Historical review records remain intact.

## Context and owner decision

The owner confirmed that the repository is private and developed by the owner alone. The proposed replacement for P03/G03 was documented technical/security review, passing automated database/security checks, and the owner's explicit acceptance of the reviewed version. Deployment would require separate approval, and the result would be recorded as owner acceptance rather than independent review. The owner replied **“Okay do it”**, approving this policy change in the 26 October 2026 conversation.

That approval selects the review mechanism. It does not retrospectively accept a technical review that had not yet been presented, approve a particular implementation commit, merge a PR, or authorize database activation.

## Decision

For DB02 development acceptance:

1. P03 is satisfied by this accepted policy and identification of the sole maintainer `yunusyosaf399` as the eventual owner decision-maker. A second GitHub contributor is not required for this mechanism.
2. A technical/security review must record the exact implementation commit, scope, inspected source and evidence, findings/dispositions and remaining limitations. The implementation assistant may perform it, with its involvement and lack of independence explicitly stated.
3. Automated database/security proof must apply to the exact implementation source. Documentation-only follow-ups may reference prior exact-code CI when the composed SQL/registry digest still matches. Source changes require new appropriate tests and acceptance; old evidence does not approve changed code.
4. G03 requires the owner's explicit acceptance of the reviewed implementation commit after the report is available, including the recorded DB01/Enrollment and Academic/DB02 compatibility behavior. Until then its status is AWAITING_OWNER_ACCEPTANCE.
5. Owner acceptance is recorded with the owner identity, exact reviewed SHA, actual instruction/date and scope. No fabricated GitHub APPROVED review or independent reviewer is created. The review issue can then close under this policy.
6. G04 approved integration/merge, G05 final accepted-contract freeze and G06 executable migration/hosted activation remain separate gates. A review-policy or code-review acceptance does not authorize deployment.

## Scope and preserved requirements

This decision governs DB02 software-development review gates P03/G03 only. It does not change School application authorization, RLS, grants, immutable evidence/history, Financial safeguards, or the runtime rule requiring a different Person for configured independent business approvals. It does not change DB01-11's separate acceptance record, installed DB03/DB04 handoff requirements, or hosted release policy.

The owner can later nominate an external reviewer and record additional assurance. The absence of a second assessor is a known limitation of this solo-maintainer process; it is not described as independent approval.

## Alternatives

Waiting indefinitely for a non-author reviewer prevents this sole-maintainer project from satisfying its development gates. Recording a self-authored GitHub approval as independent would be inaccurate. The selected process retains explicit evidence and owner accountability while describing the review truthfully.

## Validation and migration impact

No SQL, executable migration, permission, runtime business approval or deployed database is changed. Validate the policy links and decision fields, retain exact-code CI/source digest, present the technical review, and keep G03 pending until the owner accepts that version. No schema, offline or storage migration is required.
