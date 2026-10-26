# DB03 S3 — opaque application drafts and retained certificate grace

**Implementation candidate, 26 October 2026.** This follows tested S2 publication and implements the next prerequisite for the owner's certificate workflow. It adds real private intake drafts, retained withdrawal transitions, and application-wide certificate grace history. All files remain non-executable proposals under `supabase/proposals/db03/04_*.sql.draft`; disposable CI is the only installation target. No hosted change, operation registration, production acceptance or merge is implied.

## Implemented boundary

An application draft can exist without a Person, as already selected in P2-D01. This slice deliberately stores only its UUID, School, intended Campus/Year and server metadata. It contains no applicant name, DOB, national ID, contacts, certificate bytes/URLs or unverified identity flag. States are DRAFT and WITHDRAWN only; Person and submitted-policy bindings must remain NULL. The separately approved unresolved-draft withdrawal retains the record rather than deleting it or fabricating a Person.

The real `admission_applications` parent is followed by `admission_application_transitions` and owner-requested additive entity #18, `admission_certificate_grace_history`. It is an early subset of the proposed application, not an alternate applicant truth table. Actual Foundation School/Campus/Year/Principal/receipt FKs are installed; same-School Year uses its existing composite key and Campus ancestry is checked by the protected command and trigger. Optional D1 Class/Section intent columns are deferred until composed D1 parents and their complete validation/lock contract are installed. No orphan UUID, shadow D1 parent or guessed identity-source adapter is introduced. No application number is issued before verified submission.

## Fixed commands and permissions

| Public command | Required exact permission/operation | Meaning |
|---|---|---|
| `app.create_admission_draft(campus_id uuid, academic_year_id uuid, key text)` | `admission.draft.create` | Create one unresolved opaque DRAFT and initial transition |
| `app.withdraw_admission_draft(application_id uuid, expected_version bigint, reason text, key text)` | `admission.draft.withdraw` | Retain an unresolved draft and append its withdrawal transition |
| `app.grant_admission_certificate_grace(application_id uuid, expected_version bigint, document_kind text, due_on date, reason text, key text)` | `admission.certificate.grace` | Append one certificate deadline decision, without completing or verifying anything |

Returns are application UUID and resulting version; grace also returns due date. The caller cannot supply an actor, grant anchor, state, revision, receipt or result. These engineering command names are not new product-owner selections. Only authenticated has public EXECUTE. NOLOGIN workflow owns the three fixed SECURITY DEFINER entries; a private SECURITY INVOKER implementation has a three-code allowlist and no client EXECUTE or arbitrary JSON dispatcher. Private auth and evidence functions retain their dedicated existing roles. All search paths are fixed.

Authority requires a real current Auth-linked active INDIVIDUAL, exact enabled non-family permission and operation/handler/contract version, a complete effective role/grant/assignment/scope chain and ALL/DIRECT or the exact CAMPUS/DIRECT scope. OWN/ASSIGNED are unsupported, not widened. `requires_approval=true` fails closed rather than bypassing configured review. No permission, role assignment or operation row is seeded. Administrator titles and uploader identity never substitute for permission. This uses the existing one-administrator operational rule; it does not weaken independent review for admission-test skips.

Lock order in this isolated candidate: S2 authorization SHARED fence → actor/operation/key advisory → School → Campus → Year → application. Current authorization is rechecked with the wall clock after waits, and new effects require an open School, ACTIVE Campus and PLANNED/ACTIVE Year. Root versions guard every grace/withdrawal amendment. This is not approval of the later complete D1/identity/Finance lock graph. Future writers and source adapters must integrate their actual locks before SUBMIT/READY is added.

## Original window and immutable history

Grace applies only to birth and school-leaving certificates. Both kinds share the first application-wide grant date, obtained from the trusted School-local clock; no supplied/backdated/future anchor exists. A NULL due date selects the original two-calendar-month maximum. A shorter date is allowed. Changes and additional missing kinds append consecutive application-wide revisions referencing the exact predecessor. They never reset the first date or exceed its cap. New decisions cannot use a past due date or an exhausted window. A regressed School calendar cannot rewind the history. These implement the explicitly recorded engineering calendar interpretation in the [certificate contract](db03_required_certificates_two_month_grace_20261026.md).

Reasons remain private bounded text in domain history. Granting school-leaving grace records a missing-document deadline; it does not establish a trusted transfer classification or exempt a first-time applicant. Transfer applicability must later come from authorized intake evidence, never a client checkbox. No document is marked uploaded, VERIFIED, PASSED or waived by a deadline decision.

The private `admission_certificate_grace_current` security-invoker view derives the latest revision for each application/kind. The due date is inclusive on the School-local date; afterward status is OVERDUE. Otherwise it is AWAITING_DOCUMENT, or WITHDRAWN after withdrawal. It is a missing-obligation projection, not a certificate verification view. It has no client raw access; later checked read APIs must retain normal action/scope checks. Overdue does not automatically delete/withdraw an application or create enrollment. A later verified-document integration must reconcile this projection against real certificate evidence.

All grace and transition rows are append-only. Raw writes, DELETE and TRUNCATE are denied, including ordinary schema-owner DML; only the fixed workflow route can create effects. Mutable application identity/destination metadata is frozen; only protected DRAFT amendments or withdrawal advance its server-owned row version. Stronger privileged DDL/restore remains an operator responsibility, as with the other proposals.

## Atomic receipts and replay

Each command atomically commits its root effect, one domain-history row, receipt, audit and outbox event. History receipt FKs are deferred within that transaction because the evidence writer seals the already-created typed effect. Final constraints must resolve before commit; no receiptless durable history is allowed.

Idempotency is actor + operation + key with canonicalization version 1. The fixed JCS intent array contains only controlled operation/kind, UUID/date/version strings and a SHA-256 digest of the private reason; spacing normalization cannot alter free-form content because none enters the array. Reason changes still conflict. Receipt result kind is `ADMISSION_DRAFT_EFFECT`, with exactly application ID, resulting application version, optional grace due date and history ID. Audit/outbox contain only application ID/version and history ID. They do not contain document kind, reason, identity, file details or signed access.

The evidence writer independently rechecks live action/scope authority, exact immutable history, original result, and matching audit/outbox before replay. Later grace revisions or withdrawal do not change an earlier successful response, reopen an application or duplicate history. Current revocation denies historical replay. Matching historical retries can return after destination archival, but new effects cannot; retained replay is not new operational eligibility.

## Validation and next work

The runner preserves 110 prior DB03 assertions and adds 50 intake cases: disabled defaults, raw/private ACL denial, exact Campus scope, open parents, configured review rejection, create/retry/conflicting intent, unresolved NULL shape, original shared cap, shorter/deadline changes and lineage, excessive/stale/invalid intent rejection, immutable history, atomic outbox-failure rollback, retained withdrawal and historical replay, private evidence, genuine School-local date rollover and current-authority replay denial. Synthetic School timezone changes are rollback-only fixtures; stored anchors are never rewritten. All 220 frozen Foundation assertions run after this candidate installs, except the baseline catalog assertions before additions.

Five new real backend schedules inspect `pg_blocking_pids` before releasing the blocker: same-key grace replay; different-key stale grace; withdrawal before grace; grace before withdrawal; and permission revocation before grace. Durable root/version/history/receipt outcomes are checked independently. The existing five publication races also run with S3 installed. SQL fixtures roll back; race rows exist only in a separately reset disposable database. Installation failure/rollback probes cover tables/view/public entries. Actual exact-head results are recorded in PR #102 after CI, not inferred from prepared tests.

**Still required for the full requested workflow:** canonical Person matching/verification source, actual application submission and number allocation, composed D1 class intent, administrator private upload/link/verification with real file purpose/entitlement and document-source locks, verified transfer classification, checked intake reads, final document/Finance/READY/Student handoff and release/upgrade acceptance. This slice cannot complete admission or enroll a student. It does implement the durable draft/grace prerequisite rather than accepting a placeholder verification boolean.

**Example:** a draft is opened on 26 October. The administrator grants birth-certificate time until 10 November. Later, leaving-certificate grace can extend only to the original 26 December limit. Both decisions remain in history. Until the real identity/document/Finance completion commands exist and succeed, the application remains unresolved and no enrollment is created.

Technical references checked: [PostgreSQL 17 constraints](https://www.postgresql.org/docs/17/ddl-constraints.html) and [Supabase grants and RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).
