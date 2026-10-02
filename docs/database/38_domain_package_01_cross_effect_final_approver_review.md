# Cross-effect final-approver participant correction review

Status: corrected candidate; final exact-SHA CI required before affected approval workflows are re-frozen.

Discovered while independently auditing effect 18/36 after base candidate `ba835599b82c7f65b0db05825a0dc85f2dabe9fb` passed Actions #42.

## Finding

The reusable approval design permits ordered sequential stages with one effective decision per stage and does not require a different reviewer Person for every stage. Existing private participant helpers scanned an actor's decided reviews without deterministic final-step precedence and returned `DECIDED_REVIEWER` immediately on the first currently-authorized decided row. Therefore an actor who legitimately approved both an earlier stage and the final stage could be misclassified if PostgreSQL returned the earlier row first.

Simple example: an HR Director is eligible for stages 1 and 2. They approve stage 1 and later approve stage 2. They are the final approver, but an unordered scan could see the stage-1 row first and deny their explicit apply call.

A second nuance was found after the first correction was pushed: operation-specific `reviews_live` helpers intentionally require request state `APPROVED`. They are correct for deciding whether a domain mutation may occur, but they cannot be the participant-classification test for idempotent replay after the request is already `EXECUTED` or `INVALIDATED`.

## Final correction

Continuation `20260928000000_domain_package_01_effect18_09_final_approver_participant_correction.sql.draft` preserves each operation's legacy participant logic behind a private renamed `_v0` helper and removes direct workflow/read EXECUTE from those legacy helpers.

Continuation `20260928000000_domain_package_01_effect18_11_final_approver_terminal_replay.sql.draft` supplies the final classification rule:

1. call the legacy participant and proceed only if the result is exactly `DECIDED_REVIEWER`; NULL and every other classification return unchanged;
2. resolve the actor's immutable APPROVE on the maximum request step and that step's configured reviewer-role ID;
3. require the final step state, fixed resolver and assignment reason to match the frozen sequential-review contract; and
4. recheck that exact final reviewer role using the operation's existing current review permission/scope resolver.

Only then is the actor classified `FINAL_APPROVER`.

This direct role/scope test is valid in both the initial `APPROVED` state and terminal `EXECUTED`/`INVALIDATED` replay states. The apply routines still separately run their full `reviews_live` / approved-evidence validation before any mutation, so the replay correction does not weaken the mutation gate.

Affected already-implemented workflows:
- Student/Employee Profile approval path;
- Employee State;
- Employee Job Assignment;
- Employee Campus Affiliation;
- Teacher Capability;
- Class Teacher Assignment;
- Subject Teacher Assignment;
- Employee Restricted Identity.

Operation-specific final-role rechecks preserve each frozen context: Profile kind/campus, Employee target, Campus source+destination, Capability action/end boundary, Class Section, Subject Section+Subject, and Identity Employee context.

## Scope and freeze impact

This is a deterministic workflow-classification correction, not a product-semantics change. It does not change the 97-permission / 322-alternative / 36-operation catalog, domain mutation rules, lock order, reviewer Person separation, or approval state machine. Previously frozen D1 approval effects remain logically unchanged but their trusted implementation baseline must be revalidated at the final correction SHA before proceeding to the next new effect.

Migration 10 remains non-executable; D1C2 and remote/staging execution remain unauthorized.
