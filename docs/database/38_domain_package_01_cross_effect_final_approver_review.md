# Cross-effect final-approver participant correction review

Status: correction candidate; post-correction CI required before any affected workflow is re-frozen.

Discovered while independently auditing effect 18/36 after base candidate `ba835599b82c7f65b0db05825a0dc85f2dabe9fb` passed Actions #42.

## Finding

The reusable approval design permits ordered sequential stages with one effective decision per stage and does not require a different reviewer Person for every stage. Existing private participant helpers scanned an actor's decided reviews without deterministic final-step precedence and returned `DECIDED_REVIEWER` immediately on the first currently-authorized decided row. Therefore an actor who legitimately approved both an earlier stage and the final stage could be misclassified if PostgreSQL returned the earlier row first.

Simple example: an HR Director is eligible for stages 1 and 2. They approve stage 1 and later approve stage 2. They are the final approver, but an unordered scan could see the stage-1 row first and deny their explicit apply call.

## Correction

Continuation `20260928000000_domain_package_01_effect18_09_final_approver_participant_correction.sql.draft` preserves each operation's existing participant and current-authority logic behind a private renamed helper. A new wrapper changes only the ambiguous `DECIDED_REVIEWER` case:

1. require an immutable APPROVE by that actor on the maximum step number;
2. require the final step itself to be APPROVED with the fixed `D1_REVIEWER_ROLE_SCOPE` resolver/assignment reason; and
3. require the operation's existing full `reviews_live` / `review_evidence_live` check to remain true.

Only then is the actor classified `FINAL_APPROVER`. Otherwise the legacy classification is returned unchanged.

Affected already-implemented workflows:
- Student/Employee Profile approval path;
- Employee State;
- Employee Job Assignment;
- Employee Campus Affiliation;
- Teacher Capability;
- Class Teacher Assignment;
- Subject Teacher Assignment;
- Employee Restricted Identity.

The renamed legacy helpers have workflow/read EXECUTE revoked. The new wrappers retain the original internal grants. There is no new authenticated RPC, permission, scope alternative, reviewer role, policy mode or operation contract.

## Scope and freeze impact

This is a deterministic workflow-classification correction, not a product-semantics change. It does not change the 97-permission / 322-alternative / 36-operation catalog, domain mutation rules, lock order, reviewer Person separation, or approval state machine. Previously frozen D1 approval effects remain logically the same but their trusted implementation baseline must be revalidated at the correction SHA before proceeding to the next new effect.

Migration 10 remains non-executable; D1C2 and remote/staging execution remain unauthorized.
