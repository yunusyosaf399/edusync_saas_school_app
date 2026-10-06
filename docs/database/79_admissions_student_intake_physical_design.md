# Admissions and atomic student intake: physical design

Date: 2026-10-06. Status: proposed physical design; implementation and acceptance pending. This document does not enable student.create or certify Admissions complete.

## Requirements and boundary

Sources: master specification §§11–12,18,72.1,73.D and Q62–65; D1 Effect 36 dependency review. Admissions owns applications, configured stage revisions, recorded outcomes and a server-verifiable final handoff. D1 owns Person, Student, initial status and enrollment history. Finance owns charges, verified payments, allocations and reversals. Foundation owns principals, authorization, approvals, receipts, audit, outbox and private file identity.

An applicant exists independently of Student. An application references a resolved Person; uncertain identity remains a draft and cannot reach final acceptance. Submission snapshots an immutable published admission policy. Editing a later policy does not silently change existing applications.

Optional stages are configured as required or skipped in the published policy. A skipped stage still has a historical outcome and policy reference. No client-provided boolean, JSON document, role name or administrative override substitutes for a completed stage, approved decision, fee clearance or final handoff.

Family relationship, shared-family membership, child-access grants and account activation are subsequent independently authorized operations. Intake does not create any of those grants automatically.

## Common entity contract

Every entity below follows the repository entity template through its entity-specific fields and this common contract. IDs are UUID with server-generated gen_random_uuid(); timestamps are timestamptz; business dates are date. Every mutable projection has row_version bigint NOT NULL DEFAULT 1 CHECK(row_version > 0). Every row has created_at timestamptz NOT NULL DEFAULT clock_timestamp() and created_by uuid NOT NULL REFERENCES app_private.principals(id). Updates stamp updated_at and advance row_version.

All proposed tables are in app_private, with RLS enabled and forced. Clients, anon and service_role receive no direct table mutation or private helper execution. Narrow app command/read functions use explicit search_path, verified active principal, enabled deployment-owned operation, live permission/grant/assignment/scope and workflow checks. Admissions grants are independently registered; D1's 97-permission/36-operation catalog remains unchanged until a separately versioned registrar and explicit deployment activation exist. No broadening of existing D1 permissions is implied.

School, year, campus, class offering and section ancestry must match the existing Foundation/D1 keys. A scope grant on one campus does not authorize another application's destination. Application documents and assessment content require separate protected disclosure from operational status summaries. Family and Student roles have no application access based solely on a prospective family label or unactivated account.

Business commands have typed receipts with canonical intent, actor and resulting IDs/versions. Replays recheck present authority before returning retained original outcomes. Each accepted command writes audit and identifier-only outbox facts in the same transaction. Audit/outbox records do not contain applicant national identifiers, contact information, documents, test answers or signed URLs. Private file links resolve through Foundation file_objects, validated relationship and controlled purpose, not object URLs.

Protected histories are append-only. Ordinary application behavior cannot DELETE or TRUNCATE them. Draft correction is versioned; submitted facts require recorded correction/decision rather than silent overwrite. Withdrawal, rejection and cancellation retain allocated numbers and prior stages. No automatic deletion on school suspension. Retention durations remain a recorded policy decision; no invented numeric duration.

Offline caches are permission-scoped and encrypted. Offline clients may prepare drafts, but server acceptance, number allocation, approval, fee clearance, handoff issue and intake consumption require current online authorization. Client timestamps and last-write-wins cannot resolve critical conflicts.

Notifications use Foundation outbox and recipient authorization at delivery; forms, letters and cards use permanent identifiers and underlying data, rendered on demand. No rendered PDF is stored by default.

## Entity: admission_policy_versions

Purpose/source: immutable published configuration for one school's admission process.

Fields: id uuid PK; school_id uuid NOT NULL FK school_profiles; policy_key text NOT NULL; version integer NOT NULL CHECK >0; state text NOT NULL DEFAULT 'DRAFT' CHECK IN ('DRAFT','PUBLISHED','RETIRED'); effective_from timestamptz NULL; effective_until timestamptz NULL; published_at timestamptz NULL; published_by uuid NULL FK principals; fee_requirement text NOT NULL CHECK IN ('NOT_REQUIRED','REQUIRED'); numbering_profile_id uuid NOT NULL FK admission_numbering_profiles; common metadata.

Keys: UNIQUE(school_id,policy_key,version). Published effective ranges for one key cannot overlap. Exact FK numbering profile must belong to same school.

Lifecycle/history: DRAFT editable with optimistic version; publishing validates stages, numbering and reviewer contract and freezes content. RETIRED prevents new submission but preserves existing application interpretation. Required fee cannot be downgraded by editing a published version.

Indexes/queries: (school_id,policy_key,state,effective_from); select effective published policy at submission. No implicit newest-version fallback when publication is missing or ambiguous.

Permissions/workflow: admission.policy.manage for draft; admission.policy.publish with configured approval gate for publication. Unauthorized or wrong-school actor denied. Publishing cannot bypass required reviewer or finance dependencies.

Audit/events: admission.policy.created/published/retired. Storage: none. Future: new stage kinds require controlled deployment contract, not arbitrary executable configuration. Example query: SELECT id,version FROM app_private.admission_policy_versions WHERE school_id=$1 AND policy_key=$2 AND state='PUBLISHED' AND effective_from<=statement_timestamp() AND (effective_until IS NULL OR effective_until>statement_timestamp()).

## Entity: admission_policy_stages

Purpose/source: ordered immutable requirements within a policy revision.

Fields: id uuid PK; policy_version_id uuid NOT NULL FK policy_versions; ordinal integer NOT NULL CHECK >0; stage_kind text NOT NULL CHECK IN ('DOCUMENT_VERIFICATION','ADMISSION_TEST','INTERVIEW','APPROVAL','ADMISSION_FEE'); requirement text NOT NULL CHECK IN ('REQUIRED','SKIPPED'); label text NOT NULL; approval_policy_version_id uuid NULL FK Foundation approval_policy_versions; common metadata.

Keys: UNIQUE(policy_version_id,ordinal), UNIQUE(policy_version_id,stage_kind). Publish-time check ordinals contiguous and APPROVAL before fee/final acceptance. Reuse Foundation approval rules instead of a second review engine. Fee requirement and fee stage must agree. Optional APPROVAL skip is permitted only if published policy explicitly allows it; the final authorized acceptance command remains mandatory.

Lifecycle/history: immutable once parent published; stage outcome is always recorded even for configured skip. Index: (policy_version_id,ordinal). Permissions: inherit policy manage/publish, no unrelated campus configuration access. Audit: policy revision audit covers stage creation; no stage-only untracked edits. Storage: none. Future: assessment adapters produce typed results, not SQL supplied by school. Query: SELECT * FROM app_private.admission_policy_stages WHERE policy_version_id=$1 ORDER BY ordinal.

## Entity: admission_applications

Purpose/source: applicant process identity and current projection, independent of Student.

Fields: id uuid PK; school_id uuid NOT NULL; person_id uuid NOT NULL FK people; policy_version_id uuid NULL FK policy_versions (required on submission); application_number_allocation_id uuid NULL FK admission_number_allocations (required on submission); academic_year_id uuid NOT NULL FK academic_years; campus_id uuid NOT NULL FK campuses; class_offering_id uuid NOT NULL FK existing D1 offerings; section_id uuid NULL FK existing D1 sections; state text NOT NULL DEFAULT 'DRAFT' CHECK IN ('DRAFT','SUBMITTED','IN_PROGRESS','ACCEPTED','REJECTED','WITHDRAWN','CONSUMED'); submitted_at timestamptz NULL; accepted_at timestamptz NULL; final_handoff_id uuid NULL FK admission_handoffs, deferred for the acceptance transaction; common metadata.

Keys: UNIQUE(application_number_allocation_id). At most one nonterminal submitted/in-progress/accepted application for the same Person, school and academic year; a rejected/withdrawn historical attempt may be followed by a new numbered application. The existing Student Person uniqueness remains decisive at intake.

Constraints: destination ancestry and applicable policy school/year validated under locks. Submission requires active resolved Person, published policy, allocation and complete stage snapshot. ACCEPTED requires final unused handoff; CONSUMED requires consumed handoff and resulting Student link. Direct projection updates are protected by command-only trigger contract.

History: proposed destination corrections after submission are append-only and invalidate affected approval/stage/fee snapshots; former destination is retained. Row_version prevents stale amendment. Indexes: (school_id,campus_id,academic_year_id,state,id), (person_id,academic_year_id). Permissions: admission.application.create/view/amend/withdraw scoped to destination; export independently authorized. Applicant/student/family accounts cannot self-accept. Audit: application.created/submitted/amended/withdrawn/rejected/accepted/consumed. Files: through application_document_links. Query: SELECT id,state,row_version FROM app_private.admission_applications WHERE campus_id=$1 AND academic_year_id=$2 AND state=$3 ORDER BY created_at,id LIMIT $4.

## Entity: admission_stage_outcomes

Purpose/source: append-only outcome history per application and snapshotted stage.

Fields: id uuid PK; application_id uuid NOT NULL FK applications; policy_stage_id uuid NOT NULL FK policy_stages; revision integer NOT NULL CHECK >0; outcome text NOT NULL CHECK IN ('PENDING','PASSED','FAILED','SKIPPED','INVALIDATED'); reason text NULL (required for failure/invalidation); approval_application_id uuid NULL FK Foundation approval_applications; assessment_id uuid NULL FK admission_assessments; fee_clearance_id uuid NULL FK admission_fee_clearances; supersedes_id uuid NULL FK same table; recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(); common creation metadata.

Keys: UNIQUE(application_id,policy_stage_id,revision), UNIQUE(supersedes_id) when nonnull. Enforce same application and stage in revision chain. No cyclic/backward revision references. Required stages cannot use SKIPPED; configured skips cannot invent PASSED evidence. Stage outcome evidence must match its kind. Fee and approval outcomes cannot be recorded from a client assertion.

Lifecycle/history: never update outcome rows; append a new revision and retain previous evidence. Current outcome is the greatest revision in a validated linear chain, a derived projection. Indexes: (application_id,policy_stage_id,revision DESC). Permissions: admission.stage.record plus specific document/test/interview authority; approval and fee outcomes are adapter-owned effects with live verification. Audit: admission.stage.recorded/invalidated. Sensitive reason disclosure independently scoped. Query: SELECT DISTINCT ON(policy_stage_id) policy_stage_id,outcome,revision FROM app_private.admission_stage_outcomes WHERE application_id=$1 ORDER BY policy_stage_id,revision DESC.

## Entity: admission_document_links

Purpose/source: historical applicant document relationship and verification state.

Fields: id uuid PK; application_id uuid NOT NULL FK applications; file_object_id uuid NOT NULL FK Foundation file_objects; document_kind text NOT NULL controlled-purpose contract; revision integer NOT NULL CHECK >0; supersedes_id uuid NULL FK same table; verification_state text NOT NULL CHECK IN ('PENDING','VERIFIED','REJECTED','SUPERSEDED'); verified_at timestamptz NULL; verified_by uuid NULL FK principals; verification_reason text NULL; common metadata.

Keys: UNIQUE(application_id,document_kind,revision). Storage: PRIVATE verified bytes, immutable provider-neutral object key and digest, Foundation size/entitlement/purpose controls; no signed URL column. Replacing evidence retains former link and invalidates a dependent completed document stage. Verification facts are history, not a mutable boolean attached to bytes.

Indexes: (application_id,document_kind,revision DESC), (file_object_id). Permissions: admission.document.upload/view/verify separately scoped; stage evaluator reads only required verified links, not all applicant files. Audit: admission.document.linked/verified/rejected/superseded. Future: externally verified documents can reference a typed verifier outcome; public bucket/document sharing is not implied. Query: SELECT file_object_id,verification_state FROM app_private.admission_document_links WHERE application_id=$1 AND document_kind=$2 ORDER BY revision DESC LIMIT 1.

## Entity: admission_assessments

Purpose/source: immutable test/interview outcome revision without conflating Admissions with the later online assessment engine.

Fields: id uuid PK; application_id uuid NOT NULL; policy_stage_id uuid NOT NULL; assessment_kind text NOT NULL CHECK IN ('ADMISSION_TEST','INTERVIEW'); revision integer NOT NULL CHECK >0; assessed_on date NOT NULL; outcome text NOT NULL CHECK IN ('PASSED','FAILED'); score numeric(12,4) NULL; maximum_score numeric(12,4) NULL; remarks text NULL; assessor_id uuid NOT NULL FK principals; supersedes_id uuid NULL FK same table; external_assessment_result_id uuid NULL reserved dependency, no unvalidated FK placeholder in executable migration; common creation metadata.

Keys: UNIQUE(application_id,policy_stage_id,revision). Constraints: score and maximum both null or both nonnull with maximum>0 and 0<=score<=maximum; no future assessment date; stage kind/ancestry exact. Test answers and question secrecy belong to later assessment package, not this status record. Indexed application/stage/revision. Permissions: admission.test.record or admission.interview.record, separate sensitive remarks view; unauthorized assessor denied. History: append correction, invalidate earlier stage/acceptance as required. Audit: admission.assessment.recorded/corrected. Files: optional authorized evidence links through Foundation relation contract. Query: SELECT outcome,score,maximum_score FROM app_private.admission_assessments WHERE application_id=$1 AND policy_stage_id=$2 ORDER BY revision DESC LIMIT 1.

## Entity: admission_fee_clearances

Purpose/source: immutable verification that the exact required admission obligation is satisfied; Finance remains money source of truth.

Fields: id uuid PK; application_id uuid NOT NULL; application_version bigint NOT NULL; policy_version_id uuid NOT NULL; clearance_kind text NOT NULL CHECK IN ('NOT_REQUIRED','FINANCE_SATISFIED'); finance_obligation_id uuid NULL; finance_verification_id uuid NULL; finance_version bigint NULL; checked_at timestamptz NOT NULL DEFAULT clock_timestamp(); checked_by uuid NOT NULL FK principals; common creation metadata.

Keys: UNIQUE(application_id,application_version). NOT_REQUIRED requires published policy fee_requirement=NOT_REQUIRED and all finance fields NULL. FINANCE_SATISFIED requires deployed Finance contract, typed verified obligation/payment-allocation outcome bound to application/currency/amount/version; a bank image or payment evidence record is insufficient. Concrete Finance foreign keys are an implementation dependency; no executable admission migration may accept arbitrary UUIDs in their place.

Lifecycle/history: reversal or correction invalidates unconsumed handoff; consumed Student history remains, and Finance owns any resulting arrears/remediation. No deleting an admitted Student because a payment reverses. Indexes: (application_id,application_version), finance verification reference. Permissions: server Finance bridge verifies canonical state; no client clearance command or manual true flag. Audit: admission.fee.cleared/invalidated; amount details stay in Finance. Query: SELECT clearance_kind,finance_version FROM app_private.admission_fee_clearances WHERE application_id=$1 AND application_version=$2.

## Entity: admission_numbering_profiles / admission_number_series / admission_number_allocations

Purpose/source: immutable school-facing format configuration, transactional counter and retained identifier ledger.

Profiles fields: id uuid PK; school_id uuid NOT NULL; profile_key text NOT NULL; version integer NOT NULL CHECK >0; state text NOT NULL CHECK IN ('DRAFT','PUBLISHED','RETIRED'); number_kind text NOT NULL CHECK IN ('APPLICATION','ADMISSION'); prefix text NOT NULL; separator text NOT NULL; session_format text NOT NULL CHECK IN ('FULL_YEAR','TWO_DIGIT_YEAR'); digits integer NOT NULL CHECK BETWEEN 1 AND 8; start_value bigint NOT NULL CHECK >0; common metadata. UNIQUE(school_id,profile_key,version). Published format immutable; rendered number uniqueness is school-wide per number_kind, preventing prefix/session collisions across profile revisions.

Series fields: id uuid PK; profile_id uuid NOT NULL; academic_year_id uuid NOT NULL; next_value bigint NOT NULL CHECK >0; row_version and common metadata. UNIQUE(profile_id,academic_year_id). Counter bounded by 10^digits-1; overflow rejects allocation. Session label is explicitly derived from validated academic-year start year and snapshotted when series opens.

Allocations fields: id uuid PK; school_id uuid NOT NULL; series_id uuid NOT NULL; application_id uuid NOT NULL; number_kind text NOT NULL; numeric_value bigint NOT NULL; session_label text NOT NULL; rendered_number text NOT NULL; state text NOT NULL CHECK IN ('ALLOCATED','CANCELED'); canceled_at timestamptz NULL; canceled_by uuid NULL; common metadata. UNIQUE(series_id,numeric_value), UNIQUE(school_id,number_kind,rendered_number), UNIQUE(application_id,number_kind). Cancellation retains the identifier; no recycling. Counter increments and allocation occur in the same transaction with series row locked, after verified command authorization. No promise of gap-free externally observed numbering.

Student permanent school_student_id and section roll allocators remain owned by D1 and are separately locked in the intake transaction. A roll manual override requires its dedicated authorized operation; no reuse of admission format for roll identity.

Indexes/query: allocation(application_id,number_kind); SELECT rendered_number FROM app_private.admission_number_allocations WHERE application_id=$1 AND number_kind=$2. RLS/permissions: policy-config permissions for profiles, server-only counter/allocation mutations; scoped read exposes permanent identifiers only. Audit: admission.number.allocated/canceled; no independent number-allocation client API. Storage none. Future: additional number kinds require a deployed contract, not unvalidated school strings.

## Entity: admission_handoffs

Purpose/source: immutable final server-verifiable authorization boundary consumed atomically by student.create.

Fields: id uuid PK; application_id uuid NOT NULL UNIQUE; application_version bigint NOT NULL; policy_version_id uuid NOT NULL; person_id uuid NOT NULL; school_id uuid NOT NULL; academic_year_id uuid NOT NULL; campus_id uuid NOT NULL; class_offering_id uuid NOT NULL; section_id uuid NOT NULL; admission_number_allocation_id uuid NOT NULL UNIQUE; fee_clearance_id uuid NOT NULL; acceptance_approval_application_id uuid NULL; issued_at timestamptz NOT NULL DEFAULT clock_timestamp(); issued_by uuid NOT NULL FK principals; state text NOT NULL DEFAULT 'READY' CHECK IN ('READY','INVALIDATED','CONSUMED'); consumed_at timestamptz NULL; consumed_by uuid NULL FK principals; student_id uuid NULL FK existing D1 students; intake_receipt_id uuid NULL FK Foundation command_receipts; invalidation_reason text NULL; common metadata.

Keys: UNIQUE(student_id) when nonnull; UNIQUE(intake_receipt_id) when nonnull. Exact composite ancestry and Person/application/policy/version binding. READY has no consumption fields; CONSUMED requires all consumption fields and retained receipt; INVALIDATED cannot be consumed. Only consumption/invalidation stamps may change; identity/placement/number snapshot never changes. A corrected application invalidates former acceptance; a replacement handoff is an explicit revision design before implementation, not an UPDATE to its snapshot. The unique application constraint deliberately permits one accepted immutable destination; a different destination after acceptance requires a new application or the existing D1 enrollment-change workflow after intake.

Issue command requires live admission.accept scope, current application version, every required stage's valid latest evidence, policy-approved skips, required generic approval application, current fee clearance and exact destination. Issue allocates admission number atomically, writes typed receipt/audit/event. A handoff does not reserve a seat indefinitely; capacity is checked again at intake.

Index/query: (school_id,campus_id,state,id); SELECT state,application_version FROM app_private.admission_handoffs WHERE id=$1 FOR UPDATE. Reads expose only authorized operational fields. Audit: admission.handoff.issued/invalidated/consumed. Outbox payload contains IDs/states, never applicant sensitive fields. Files none; linked forms render underlying authorized facts.

## Atomic intake and lock contract

1. Verify current actor and both student.create and student.enrollment.place on the exact destination; validate enabled contracts before any receipt disclosure.
2. Acquire documented school/Person/destination allocator lock order compatible with D1; lock application and handoff deterministically. Replay locks retained result target and rechecks current permissions.
3. Require READY final handoff, exact immutable application version/Person/ancestry, no existing Student for Person, current valid stage/approval/fee dependencies and active admissible placement. Never regenerate proof from client flags.
4. Lock section/capacity and numbering rows; recheck capacity against authoritative current enrollments. Dedicated permitted capacity override must follow existing D1 approval/receipt contract; a reason string alone is insufficient.
5. Allocate permanent school_student_id and initial roll; create Student, immutable admission identity, initial status and PRIMARY enrollment with correct effective dates.
6. Mark handoff CONSUMED and application CONSUMED with exact resulting Student/receipt; write receipt, audit and student.created outbox atomically.
7. Any failure rolls back Student, history, enrollment, rolls, counters, handoff/application consumption and events. Same-key replay returns original result; altered intent rejects; competing keys cannot consume a handoff twice.

Lock order and counter behavior require two-session tests before activation. No read-then-insert capacity check without serialization.

## Implementation order and required tests

Order: numbering profiles/series -> policy versions/stages -> applications -> immutable documents/assessments/stage outcomes -> Finance clearance bridge -> acceptance/handoffs -> D1 student intake implementation -> read projections/exports -> clean install and populated upgrade tests. Circular application/handoff references are added last with validated constraints; no unchecked NOT VALID constraints survive acceptance.

All entities inherit common retention, storage, offline, audit and disclosure contracts above. Entity fields and exact existing foreign-key names are verified against runtime catalog before executable SQL. The final migration and functions must enumerate catalog changes rather than altering frozen Foundation files.

Required cases: applicant without Student; all permitted optional-stage configurations; required stage cannot skip; policy revision isolation; stale application correction; denied cross-campus stages/acceptance; unverified payment evidence denied; payment reversal before handoff consumption denied; full/two-digit year and 1..8-digit formats; number overflow; same-key replay and altered intent; concurrent application/number/seat/handoff races; duplicate Person Student denial; whole-transaction rollback; historical stage/document/assessment/approval reconstruction; no auto-family grants; private-file access/entitlement; replay after privilege revocation; clean install, upgrade and lint.

Open dependencies: Finance obligation/clearance physical package; admission document purpose registration and exact role/scope catalog; final D1 allocator/capacity lock compatibility; independent complete D1 acceptance. These are implementation work, not evidence that Admissions is complete. Finance-required acceptance stays disabled until its real bridge exists. No product/vendor/privacy defaults are invented by this design.
