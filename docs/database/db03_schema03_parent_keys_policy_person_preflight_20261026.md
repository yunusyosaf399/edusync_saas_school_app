# DB03 SCHEMA-03 — P1/P2 parent keys, published policy and verified Person preflight

**Completed 26 October 2026 — source and schema-design preflight only.** This completes SCHEMA-02's recorded next task for draft PR #102. No Admissions schema, command, permission or positive runtime acceptance is installed by this document. Existing owner decisions remain binding; proposed relational keys below are engineering candidates for the later reviewed DDL.

## 1. Source identity and current dependency status

| Source | Exact inspected identity / result |
|---|---|
| DB03 baseline | PR #102, `d9995a47295a5b6e0ddecf127a47453081517d98` |
| Main | `df1c98d5c2d19424946986fc6ba7615202b0a443` |
| Accepted DB02 integration successor | `06c2be2412e1699f3fa8f2804969e9808eb16e09`; G04/G05 complete, G06 release preparation complete but release open |
| Foundation parents | Frozen identity/School migration `20260924122445`, workflow `20260924122446`, receipts `20260924122448`, plus the complete nine-file Foundation chain |
| Academic parent layouts | D1 base `20260928000000_domain_package_01.sql.draft`; base bytes match the accepted successor, while D1 remains inactive draft source |
| Current hosted observation | G06's 26 October read-only staging audit found nine Foundation migrations, 33/33 forced-RLS tables and no Roll Policy table; it is not an installed D1/Admissions environment |

The companion [parent-key inventory](db03_schema03_parent_key_inventory_20261026.json) pins checked source hashes, actual PK/UQ names, proposed reference choices, and validation scope. Source checks include later Foundation/D1 fragments for added/changed keys; an existing UUID PK does not invent a composite parent key. The four parent-defining source files are byte-identical between this DB03 baseline and the accepted successor. No branch composition or SQL import is performed here.

Read the approved master specification §§11,18,72.1; decisions, guardrails and security workflow; P1/P2 specifications; P2-D01 and P3-D01 owner records; SCHEMA-01/02 and the 21 October school/Finance/test-skip clarifications. Historical proposals remain linked, with these corrections taking precedence for this scoped schema preflight. G06's packet is on the separate DB02 successor at `docs/deployment/db02_g06_release_packet_20261026.md`, not assumed present in this older DB03 branch.

## 2. Actual external parent keys and missing semantic proof

| Actual parent | Referencable source key | What a matching FK does **not** establish |
|---|---|---|
| `app_private.school_profiles` | `school_profiles_pkey (id)` | ACTIVE/SETUP eligibility or caller School authority |
| `app_private.people` | `people_pkey (id)` | Canonical real-child verification; `row_version` is mutable and not a unique `(id,row_version)` key |
| `app_private.principals` | `principals_pkey (id)`; `principals_id_kind_key (id,kind)` | Live INDIVIDUAL actor, Person independence, current roles or permissions |
| `app.campuses` | `campuses_pkey (id)`; `campuses_school_id_code_key (school_id,code)` | No checked `(id,school_id)` UQ; an ID FK alone does not validate an application's stored School |
| `app.academic_years` | `academic_years_pkey (id)`; `academic_years_id_school_id_key (id,school_id)` | Current year eligibility; this exact composite can enforce stored School ancestry |
| `app_private.academic_classes` | `d1_01_pkey (id)`; `d1_u02_key (id,school_id)` | Active class, destination authority or available capacity |
| `app_private.class_offerings` | `d1_03_pkey (id)`; `d1_u05_key (id,campus_id)` | No checked `(id,school_id,academic_year_id,campus_id)` UQ; stored School/year still need exact ancestry comparison |
| `app_private.section_offerings` | `d1_04_pkey (id)`; `d1_u06_key (class_offering_id,code)` | No checked `(id,class_offering_id)` UQ; Section ID FK alone cannot prove the application's target Class Offering |
| `app_private.approval_policy_versions` | `approval_policy_versions_pkey (id)`; `approval_policy_versions_id_operation_id_key (id,operation_id)` | Active exact operation/route UUID, correct target/scope, current reviewer eligibility or executed effect |
| `app_private.command_receipts` | `command_receipts_pkey (id)`; `command_receipts_id_operation_id_key (id,operation_id)` | Correct operation/actor/target/result/canonical intent; FK existence alone is not business evidence |

All are source facts, not a claim that D1 parents are hosted. Foundation actor columns use `principals.id`, not Supabase `auth.users.id` or `people.id`; Person binding uses `people.id`. Every proposed FK is **ON UPDATE RESTRICT / ON DELETE RESTRICT**. No CASCADE/SET NULL is introduced to erase retained intake history or detach submitted applications.

## 3. Proposed relational reference and key matrix

All proposed DB03 tables are `app_private`, UUID PK, server actor/timestamps, ENABLE+FORCE RLS, default-deny raw client access. Mutable drafts/projections use server-maintained positive `row_version`; append-only histories use domain revision/sequence. These are **candidate** keys/guards, not deployed constraints or new owner selections.

| Child reference | Exact proposed FK target / nullable shape | Additional locked invariant / installation dependency |
|---|---|---|
| #01 numbering profile `school_id` | NOT NULL → `school_profiles(id)` | Stable School/profile family; `(school_id,profile_key,version)` UQ, positive version, kind APPLICATION/ADMISSION; published format immutable |
| #02 number series `profile_id` | NOT NULL → #01 `(id)` | Profile published/eligible and unchanged kind/format |
| #02 series `academic_year_id` | NOT NULL → `academic_years(id)` | Series has no stored `school_id` in current candidate: compare Year.school_id with Profile.school_id under their approved locks; do not write a nonexistent composite child FK |
| #04 policy `school_id` | NOT NULL → `school_profiles(id)` | `(school_id,policy_key,version)` UQ; add candidate `UNIQUE(id,school_id)` only if implementing the same-School composite application FK below |
| #04 two numbering profile IDs | Both NOT NULL → #01 `(id)` | Both same School; application ref kind APPLICATION, admission ref kind ADMISSION; published/retired eligibility is P1 lifecycle policy, not inferred from two successful ID FKs |
| #05 stage `policy_version_id` | NOT NULL → #04 `(id)` | `(policy_version_id,ordinal)` and `(policy_version_id,stage_kind)` UQ; controlled kind, positive ordinal and exact contiguous publish roster |
| #05 optional `approval_policy_version_id` | NULL or → actual Foundation `approval_policy_versions(id)` | If configured, verify exact operation/route, target/scope and current source; no fictitious `approval_applications` parent |
| #16 document requirement `policy_stage_id` | NOT NULL → #05 `(id)` | Actual parent must be DOCUMENT_VERIFICATION; ID FK cannot check stage kind. Candidate UQs `(policy_stage_id,document_kind)` and `(policy_stage_id,ordinal)`; kind registry/purpose still need their approved source |
| #06 application `school_id` | NOT NULL → `school_profiles(id)` | Exact stored School anchor; no extra tenant/organization column |
| #06 `(academic_year_id,school_id)` | Both NOT NULL → actual `academic_years(id,school_id)` | Parent key exists; year state and operation eligibility remain checked |
| #06 `campus_id` | NOT NULL → actual `campuses(id)` | Compare Campus.school_id with application.school_id; no Foundation key/DDL modification from this task |
| #06 `(class_offering_id,campus_id)` | Both NOT NULL → actual `class_offerings(id,campus_id)` | Parent key exists in D1 draft; compare Offering.school_id and academic_year_id with application as well |
| #06 optional `section_offering_id` | NULL or → actual `section_offerings(id)` | When supplied, exact Section.class_offering_id and campus_id must equal the application destination. Do not silently introduce a Section composite FK whose parent UQ is absent |
| #06 optional `policy_version_id` plus School | Proposed `(policy_version_id,school_id)` → candidate #04 `(id,school_id)` with MATCH SIMPLE | Requires that new DB03 parent UQ before FK installation. Policy may be NULL in DRAFT; successful SUBMIT requires exact published snapshot. Terminal-before-submission policy behavior is not invented |
| #06 `person_id` | NULL only DRAFT under approved P2-D01; otherwise → actual `people(id)` | SUBMITTED requires verified current same-application identity head, active Person and valid source/version, not just nonnull UUID |
| #07 identity `application_id` / `person_id` | NOT NULL → #06 `(id)` / actual `people(id)` | No Foundation Person creation/match authority follows from either FK |
| #07 `person_version` | Positive bigint historical snapshot; **not** an FK to `(people.id,people.row_version)` | Server-read after approved Person lock; compare again at verification-dependent commands; never cascade later Person versions into retained evidence |
| #07 optional `supersedes_id` | Candidate `(supersedes_id,application_id)` → #07 `(id,application_id)` with MATCH SIMPLE | Add candidate `UNIQUE(id,application_id)` first; existing proposed UQ `(application_id,revision)` and partial UNIQUE nonnull predecessor stop duplicate revision/forks; protected exact prior head/revision+1 check still required |
| #07 verification source | **NO concrete FK target established** for `verification_source_ref/revision` | Do not deploy arbitrary UUID as trusted proof or make FK target `file_objects` merely because it exists; source owner supplies exact verifier/evidence/revocation contract |
| #03 number allocation `series_id` / `application_id` / `school_id` | NOT NULL → #02 `(id)` / #06 `(id)` / actual `school_profiles(id)` | Install #06 first; locked joins prove same School, profile kind and year. UQs `(series_id,numeric_value)`, `(school_id,number_kind,rendered_number)`, `(application_id,number_kind)` retain reservations across all profile versions |
| #13 transition `application_id` / `command_receipt_id` | NOT NULL → #06 `(id)` / actual `command_receipts(id)` | `(application_id,sequence_number)` UQ and exact state/version/actor/command proof. Receipt cardinality is not frozen: no global UNIQUE(receipt_id) across multi-effect commands |
| All actor columns | Required or paired-null as applicable → actual `principals(id)` | Live authority at command execution; historical actor rows remain, without treating FK survival as current authorization |

The optional composite FKs above use **MATCH SIMPLE** because one optional identity/reference column may be NULL while its required aggregate/School column is nonnull. MATCH FULL would reject that intended partial-null shape. Pair this with row-level NOT NULL/state predicates; MATCH SIMPLE does not validate an omitted optional reference. A positive `CHECK` alone permits NULL, so fields declared required also need NOT NULL. Partial unique predecessor/live-state indexes are **not FK parent keys**. Use full PK/UQ/non-partial unique targets, and choose child-side indexes from actual FK/read/lock access paths rather than duplicating indexes already supplied by UQ.

## 4. Publication, Person and lineage checks that keys cannot replace

**Published policy/stage/document roster is one aggregate.** Every draft stage/roster writer and publisher must take the same approved policy-parent serialization lock **before** child edits, then re-read DRAFT state after waits. Publisher validates and freezes the entire stage/roster/profile snapshot together. FK existence or its internal key-share lock is not the publication mutex. A concurrent append cannot sneak into a previously frozen roster. Retired published history remains immutable and participates in approved temporal non-overlap; a PUBLISHED-only exclusion predicate must not release an old interval when state becomes RETIRED. Exact effective-time/replacement/gap rules remain P1-D03; do not import DB02's School-today rule.

Applications snapshot the selected policy UUID, not a mutable “latest policy”. A later published document roster never changes an older submitted application's required kinds. P3-D01 authorizes policy-specific requirements; document-kind registry, optional-kind/ordinal semantics, upload to an unresolved DRAFT, purpose/retention and verifier independence remain separate gates. Required documents cannot be verified from arbitrary JSON or a public URL. Policy SKIPPED and independently reviewed per-application pending-test skip remain distinct; a FAILED assessment cannot be bypassed. Finance-authorizer clearance is mandatory before READY in every case, even with waiver or configured fee-stage skip.

**Person existence is not identity verification.** Actual Foundation `people` contains only id, display_name, state, actor/timestamps and mutable row_version. It has no canonical applicant ID/DOB verifier or immutable verification relation. This bounded source review establishes no approved P2-D02 matching/creation/merge adapter. A future identity owner must supply: typed source/record key and evidence revision; exact Person/version/School binding; current authorized resolver; verification result/validity/revocation; protected revalidation/lock interface; minimum disclosure and recovery/replay behavior. These are return-artifact requirements, not a fabricated function name, handler, table or new owner approval.

SUBMIT must lock/revalidate the real source and exact latest app identity head, compare the retained Person/version and projection, check policy/destination/live actor authority and duplicate intake, and allocate only the APPLICATION number atomically with transition and evidence. Stale/ambiguous/unavailable proof fails closed, with no partial number, state, Student or READY. Later unrelated Person edits need the P2-D08 stale-verification policy; this preflight neither approves automatic re-verification nor treats a saved version as a permanent live guarantee.

**DRAFT terminal edge conflict:** the approved P2-D01 record says Person NULL exclusively in DRAFT; older P2 command candidates also discuss WITHDRAW from DRAFT. An unresolved DRAFT cannot be moved to a NULL-Person terminal state under a blanket interpretation of that approved rule. Preserve P2-D01 and leave that optional transition unavailable until the owner explicitly resolves it; do not insert a dummy Person, delete the application or silently relax the NULL rule. Similarly, `CANCELED` and exact terminal/reapply/CONSUMED duplicate predicates remain P2-D03/04 decisions, not extra accepted states from this task.

**No reverse-pointer cycles.** #06 must not depend on #03 allocation, #07 current identity or #12 final handoff IDs merely to create its parent row. Derive allocation from `(application_id,number_kind)` and identity from the locked linear revision head. #07 points to #06; #03 points to #06; later #12 may reuse the same retained ADMISSION allocation across invalidated handoff revisions. Self-reference guards prevent forks/skipped revision/cycles; highest numeric revision alone is not proof of valid lineage or verified evidence. Never add a unique constraint on admission-number allocation across every handoff revision.

**No speculative lock graph.** This preflight does not approve the stale older DB03 Academic Class→Campus→Year prose as the current global order. Inspect current D1 helpers and obtain the SC-06 integrated rank, including Foundation auth/receipt fences, School, number-series/Person/academic parents, app/identity/roster and future Finance reversal/handoff locks. Pre-read immutable IDs where necessary; revalidate after waits. A child FK's hidden parent locks and lifecycle writers must be included. Publication mutex design does not settle Finance/D1 total lock order.

## 5. Acyclic installation and schema/command separation

| Step | Proposed objects / references | Mandatory stop condition |
|---|---|---|
| S0 | Frozen Foundation parents; checked D1 Academic parents | Actual installation and exact key/privilege evidence required before any child DDL; source is not deployment |
| S1 | #01 profiles; #02 series | Material P1 format/session/lifecycle choices and authorized schema slot unresolved; no number issuance |
| S2 | #04 policy → #01; then #05 stage → #04 | Define exact publish/retire/time contract, actor scopes and optional Foundation route before protected publication |
| S3 | #16 policy document roster → #05 | Requires exact DOCUMENT_VERIFICATION guard, publication mutex and reviewed kind/requirement/purpose semantics; no document upload activation |
| S4 | #06 application → School/Year/Campus/D1 parents/#04/Person | P2-D01 NULL rule intact; additional same-School UQ on #04 first if using its composite FK; no reverse child pointers |
| S5 | #07 identity history; #13 transitions → #06 and real external sources | #07 storage/command proof source unresolved; do not fill it with a dummy verifier/FK. DRAFT/transition layout alone cannot enable verified SUBMIT |
| S6 | #03 number allocations → #02 and #06 | Real application parent exists; no orphan allocator or NULL application workaround; protected issuance still separately gated |
| S7 | Later P3–P7 children and D1 consumer | Assessment/Finance/exception parents and signed SC-06 actual interfaces first; no premature READY/Student or broad registrar grants |

No stage requires a circular app→child→app FK, disabled constraints, NOT VALID integrity shortcuts, placeholder Finance/Person tables or changes to frozen Foundation/D1 keys. Future additive schema-only candidates can be separately reviewed, but cannot be labelled runnable protected business operations without real registered authority and proof sources.

## 6. Acceptance catalogue and completion evidence

All database cases below are **planned / NOT RUN**; this task validates source keys and design consistency, not runtime behavior. Use genuine protected commands after the separately approved schema/source interfaces exist. Every rejected case asserts no committed partial application/number/history/receipt/event; retained history is not deleted for cleanup.

| Case IDs | Future cases / required durable result |
|---|---|
| K01–K04 | Cross-School Year denied by real composite FK; Campus mismatch, Class Offering year/School mismatch and Section from another Offering denied by exact protected ancestry checks |
| K05–K08 | Policy from another School denied; wrong-kind numbering profile denied; optional draft policy/Section NULL accepted only in approved shape; unresolved Person NULL succeeds only DRAFT and never SUBMITTED |
| K09–K12 | Existing Person without approved verification denied at SUBMIT; stale Person/source version denied; forged/arbitrary source UUID denied; missing/ambiguous verifier leaves no allocation/transition/Student |
| K13–K16 | Identity predecessor from another app denied; skipped revision/fork/cycle denied; unrelated Person edit retains old evidence unchanged; app projection cannot silently switch to an unverified Person |
| K17–K20 | Document roster attached to INTERVIEW denied; duplicate kind/ordinal denied; published child edit/append denied; later policy publication leaves old application's roster unchanged |
| K21–K24 | Number ledger cannot exist without app; rejected/withdrawn numbers retained; invalidated handoff reuses same ADMISSION allocation; receipt FK to wrong actor/operation/target is rejected by evidence verifier |
| K25–K28 | Multi-effect command does not hit an invented global receipt uniqueness constraint; terminal NULL-Person edge remains unavailable pending explicit decision; raw client/private SQL denied; no cascade deletion or new Foundation keys |

| Race IDs | Required two-backend schedules, both arrival orders |
|---|---|
| R01 | Policy publisher versus stage insert/update: one complete immutable roster or denied stale edit; observe actual parent-row blocking |
| R02 | Policy publisher versus #16 document-kind append: no post-publication extra requirement |
| R03 | SUBMIT versus Person/source revision or revocation: only current approved source wins; no stale identity submission |
| R04 | Two SUBMIT keys for same resolved Person/Year: approved active-intake uniqueness and canonical replay, no duplicate application-number effect |
| R05 | Identity rebind versus SUBMIT: exact application/head/Person coherence after wait, no mixed snapshot |
| R06 | Target Offering/Section lifecycle change versus SUBMIT: recheck destination ancestry/state; no accepted stale target or implicit reserved seat |

Each future race must capture real backend PIDs/blocked locks, reverse arrival order, commit and relevant rollback outcomes, immediate deferred-constraint checks and durable third-session inspection. Source assertions, design tables and unrelated green CI do not count as these runs.

**SCHEMA-03 exit:** actual parent keys and gaps checked; proposed P1/P2/#16 reference and NULL matrix completed; current Person verification gap and temporal/lineage protections documented; app-child cycles removed from the candidate order; 28 future cases and six race schedules specified. Source evidence and Markdown links were checked; only DB03 documentation changes. No tests are reported passed unless actually executed, no operation/permission enabled, no changes to main/DB01/DB02/Finance/shared SQL/CI or hosted database.

**Next implementation gates:** settle remaining material P1 numbering/publication and P2 identity-source/terminal-state choices with their concrete owner artifacts, then review the first bounded non-activating DB03 schema candidate. P2-D01 and P3-D01 are already selected and must not be re-asked. Finance clearance and real P7/D1 integration remain later distinct tasks; this document does not mark them implemented.

PostgreSQL semantics checked against [PostgreSQL 17 constraints](https://www.postgresql.org/docs/17/ddl-constraints.html): NULL-aware CHECK/FK behavior, full referencable unique keys and limits of cross-row CHECK constraints. The proposed publication/verification mutexes still require actual runtime proof.
