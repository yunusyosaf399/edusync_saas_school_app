# DB03 P32 — Terminal REJECT and corrected RETURN across existing Admissions commands

**Status: inactive SQL candidate; no accepted Principal decision operation or Student creation.**
Base: draft DB03 #203 at `0389554093b8bf053e8a8c06d7a08c4fcef04011`; D1/DB01/DB02 integration PR #168 is not modified.

## Concrete gap fixed

P29/P31 created an immutable Principal RETURN/REJECT history and a private lifecycle projection, but earlier working Admissions commands were unaware of these decisions. Because `admission_applications.state` still allows only `DRAFT` and `WITHDRAWN`, those earlier commands could otherwise treat a rejected application as a usable draft. An old Forward record could also remain selectable after a Principal RETURN.

P32 provides **database-backed lifecycle enforcement**, without pretending that the final-decision writer exists:

- A private fixed-owner `db03_principal_not_rejected` fence and a row-trigger deny **application UPDATE** after terminal REJECT. Additional BEFORE INSERT triggers reject new records for 15 core Admissions mutation sources: intake transitions/grace, document intake/upload/link/Forward/review/clearance, original identity resolution, destination, admin fee declaration, assessment/stage outcome, and applicant Person checks/creation. The triggers deliberately **do not block Finance settlement or reversal ledgers**, immutable private file retention, or read-only evidence access after rejection.
- A private current-Forward function ignores a forwarded record once that particular Forward has an immutable Principal decision (RETURN or REJECT). The older `db03_document_is_forwarded` and `db03_document_target_open` functions are replaced **with the same signatures and existing owner**, so all existing callers acquire the new decision fence. The prior parent scope checks remain.
- A `db03_principal_resubmission_ready` predicate requires that after a RETURN the application row version actually advance beyond the returned version. The existing protected `app.forward_admission_to_principal` rechecks this before creating another Forward. **Simply clicking Forward again without a changed version is rejected.** Editing through an existing authorized mutation advances its row version. The next Forward must be a new revision.
- The established private administrator document queue now reports REJECTED and RETURNED_FOR_CORRECTION based on the Principal decision-history projection; `can_forward` requires the same corrected-version predicate. The Principal queue includes only the **latest, undecided, document-current** Forward. The server returns no private decision reason to these queue readers.

This is more than a diagnostic projection: when a future authorized Principal RETURN/REJECT writer inserts the matching immutable decision event, the existing mutation/forward entrypoints will honor it. A REJECT cannot be bypassed by an older DRAFT-state check or a new intake history INSERT. RETURN invalidates the previously forwarded review and requires an amended application before resubmission.

## Boundaries / outstanding safeguards

P32 **does not seed** the dedicated `admission.final.decide` permission, does not change P29's **no-writer** restriction, and adds no public final-decision RPC, Principal accepted event, final authorization token, APRROVE record, or Student ID/Enrollment/Roll operation. Until the protected RETURN/REJECT handler, typed receipt/audit/outbox and live Auth/lock/replay/race tests exist, no real Principal decisions can be applied. P32 also does not claim that every possible Finance/payment or publication effect is denied: it scopes rejection barriers to the enumerated Admissions mutations. Existing Finance reversals and archive access must remain possible.

P32's legacy command overrides are **isolated in its own later draft fragment**; the original DB03 source files are untouched. All previous source validators and database tests remain intact. Future code should keep the existing wrapper signatures/operation checks and must not defeat these fences.

The core owner sequence remains administrator DRAFT → all required documents attached → Forward → separate Principal review → final decision. The future RETURN/REJECT command needs exact current Principal role/permission, current forwarded snapshot/document authority, an immutable decision row plus receipt/audit/outbox in one transaction, same-key replay and changed-intent conflicts, and reauthorization after School/Application locks. APPROVE cannot be split from canonical Person/Student ID/admission number/PRIMARY Enrollment/Roll/document lineage atomic handoff; those cross-owner SC gates remain blocked.

## P32 isolated acceptance

1. Exactly one inactive source `.sql.draft` with five private helper/guard functions, five compatible existing function replacements, fixed-owner 16 terminal mutation triggers, no new final-decision writer grant.
2. A source-scope validator, injected failed-install rehearsal (no P32 functions left after rollback), successful disposable install and 28 rollback-only pgTAP assertions covering ACL, parent mutation guards, selected source INSERT fences, current Forward and corrected Return logic, queue integration and absence of a final RPC.
3. No hosted environment, executable migration, role seed, production activation, or merge to main. The full DB03 disposable candidate runtime and D1 static checks must pass on the exact proposed PR head. **Structural acceptance does not substitute for real Auth success/race testing of a future positive Principal command.**

**Next engineering task:** introduce a protected, dedicated Principal final-action handler for RETURN/REJECT, with a source-verified append-only receipt/audit/outbox and live Auth/lock/replay/rollback tests. Keep APPROVE disabled until DB03+D1 atomic handoff acceptance.
