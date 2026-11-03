# DB-04 — CUR-04/CUR-05 Approved Product Policies; Pending Permission and Reviewer Registration Crosswalk

**Status update 2026-10-21: CUR-04 AND CUR-05 PRODUCT APPROVED; ALL PERMISSION/OPERATION/REVIEWER CODES REMAIN UNREGISTERED. REGISTRATION PLAN ONLY.** Prepared 2026-10-21 for DB-04 PR #103. Owner explicitly approved [CUR-04 A1+B1+C1+D1+E1+F1](db04_cur04_approved_student_family_staff_authorization_20261021.md). [CUR-05 A1+B1+C1+D1+E1+F1+G1+H1](db04_cur05_approved_workflow_reviewer_policy_20261021.md) is **owner-approved product policy**; every operation/review code name below remains **candidate registration**, not an active permission. No SQL, migration, catalog rows, CI, School workflow policy or Supabase deployment performed.

> **2026-10-21 confirmation:** [CUR-05 P0/P1/P2 and independent reviewer choices are approved](db04_cur05_approved_workflow_reviewer_policy_20261021.md). The existing operation class rows below describe **approved workflow behavior** but **unregistered code names and unconfigured School P1 mode**. [CUR-06 transfer/archive/replacement](db04_cur06_transfer_archive_replacement_history_owner_gate_20261021.md) is not yet approved and cannot be smuggled in through a P2 APPLY grant.

## 1. Existing source constraints, not new permissions

- `docs/security/08_domain_permission_disclosure_catalog.md` D1 pattern: permission support sets **A** = ALL/DIRECT; **ACS** = ALL/CAMPUS/CLASS/SECTION DIRECT; **SE** = ACS DIRECT only, no OWN/ASSIGNED; **SF** = ACS plus OWN/D1_FAMILY_CHILD for family-safe current reads; SELF uses the verified D1_STUDENT_SELF own resolver where explicitly allowed. A support set determines which permissions *may* be registered, **not a grant**. A FAMILY Principal must use an OWN/FAMILY_CHILD alternative on `family_safe=true`; a different generic permission must not permit FAMILY through a direct scope.
- `docs/security/09_domain_checked_reads_and_commands.md` D1 P0/P1/P2 and exact typed reads: live verified Principal and one complete matching same-chain grant/assignment/scope; no caller-chosen permission/target function; historical read always separate. P1 School policy must explicitly choose DIRECT or REVIEWED and missing/ambiguous denies. Reviewer current separate permission, matching configured reviewer step/role and same-Person self-review denial; APPLY revalidates.
- `docs/security/SECURITY_WORKFLOW_AND_AUDIT.md` requires bounded review, actor, reason/evidence, audit/outbox privacy. Foundation owns `approval_requests`, `approval_reviews`, `approval_applications`, `command_receipts` and audit/outbox. Do not add a Curriculum copy or modify D1's exact 34-table / 97-permission / 322 scope-alternative / 36-operation guarded inventory.
- D1 exact Student `PRIMARY enrollment_id` and Student current `row_version` bound to Curriculum. `enrollments` has **no row_version**. CUR-03 BF-1 approved **8 proposed** Curriculum entities, including durable finalized-empty `student_subject_selection_sets` plus selected Subject members. The exact SQL field/constraint names are CUR-08.
- **No generic “Administrator,” “Class Teacher,” “Subject Teacher,” relationship, School Principal or service-role bypass.** The current actor must possess an independently granted explicit permission and complete context. CUR-04 permits staff-only accepted writes, and separately granted current Student SELF/FAMILY CHILD reads.

## 2. Proposed permission and disclosure vocabulary (NOT a registration)

Define **fixed distinct codes** owned by DB-04 domain, validated/registered only by Foundation/deployment owner. Candidates must pass collision review, length/family-safe/scope schema checks, and be adjusted by the registrar if a frozen name already exists.

| Code proposal | family_safe (proposed) | Allowed resolved alternatives (conceptual, not a new scope engine) | Ceiling and current status |
|---|---|---|---|
| `curriculum.definition.manage` | false | ALL/DIRECT | Staff School-wide definition create/change only via fixed protected P0 candidate; **CUR-05 A1 approved; code unregistered**. |
| `curriculum.revision.draft` | false | ALL/CAMPUS/CLASS/SECTION DIRECT if coverage is complete | Staff versioned draft/edit/validate; no published APPLY or reviewer bypass. |
| `curriculum.revision.publish` | false | ALL/CAMPUS/CLASS/SECTION DIRECT matching **all affected** Class Offerings | Staff publication REQUEST/APPLY, not reviewer grant; if applicability school-wide touches both campuses, one-campus scope insufficient; **CUR-05 B1 approved; code unregistered**. |
| `curriculum.revision.approve` | false | same complete affected direct scope | Separate reviewer permission, only configured reviewer step/role plus distinct Person; no blanket inheritance from publish permission. |
| `curriculum.offering.manage` | false | ALL/CAMPUS/CLASS/SECTION DIRECT, exact Section | Change Section Subject Offering without changing D1 Section; **CUR-05 D1 approved; code unregistered**. |
| `curriculum.offering.approve` | false | same direct scope | Separate P1 reviewed-mode permission only where required by registered School operation policy. |
| `curriculum.selection.change` | false | ALL/CAMPUS/CLASS/SECTION DIRECT on target Student’s **accepted PRIMARY Enrollment** | Staff FINALIZE empty/nonempty, AMEND/WITHDRAW typed full batch, original BF-1 generation and canonical School-first lock. |
| `curriculum.selection.approve` | false | same direct scope as selected Student/Section | Distinct reviewer P1 permission only if School's approved policy requires review; still requester/reviewer Person separation. |
| `curriculum.selection.correct` | false | same direct scope across all impacted historic and current enrollment/Section contexts | Correction REQUEST/APPLY is candidate P2, must not rewrite Exam observed snapshot; **CUR-05 E1 approved; code unregistered**. |
| `curriculum.selection.correct.approve` | false | full impacted direct scope | Separate P2 reviewer permission; no actor may review own correction using an alternate Principal/role. |
| `curriculum.section_offerings.view` | false | ALL/CAMPUS/CLASS/SECTION DIRECT | Staff approved Curriculum Section Subject availability only, no Student roster. |
| `curriculum.selection.current.view` | false | ALL/CAMPUS/CLASS/SECTION DIRECT | Staff one-Student current status/choice view, no complete history or private approval reason. |
| `curriculum.selection.student_self.view` | false | **OWN/D1_STUDENT_SELF only**, subject to registrar validating this resolver set | Verified Student's **own** currently applicable choice/finalization status, not peer, historic correction, or mutation. Different from Staff and FAMILY code. |
| `curriculum.selection.family_child.view` | true | **OWN/D1_FAMILY_CHILD only**, current School family link/access/consent + matching grant | Narrow family_safe current child choice/finalization status; no old selection history, identity, sibling roster or sensitive request fields. |
| `curriculum.selection.history.view` | false | ALL/CAMPUS/CLASS/SECTION DIRECT only; no OWN/FAMILY/ASSIGNED | Separate staff history permission for a specific Student/Enrollment/revision window; no raw audit or private reason fields. |

**Registrar compatibility caveat:** D1's fixed sets are **precedents**, not automatic DB-04 registration sets. The exact Foundation deployment catalog must review whether a permission can use **OWN/D1_STUDENT_SELF only** without separate staff alternatives, and whether staff scope must be ALL for school-wide draft rather than granular. If an existing fixed resolver doesn't support a safe alternative, **stop and escalate** to Foundation owner; do not simulate an alternative with caller-supplied identity or join a family_safe permission to privileged staff writes. Neither candidate code nor its `family_safe` value exists in active permissions until an authorized migration installs it.

## 3. Candidate operation → requester/reviewer → workflow crosswalk

**P0/P1/P2 assignments are now CUR-05 owner-approved product rules; CUR-04 actor constraints also approved. The action and reviewer code strings and exact School policy registration remain proposed only.** Each row requires an exact operation registration, fixed typed command signature, a School policy where P1, independent review policy where P2, current grant/scope and an authorized Foundation receipt/audit/outbox path.

| Proposed operation | Accepted requester/writer | Additional reviewer when reviewed | Proposed CUR-05 route | Key denial / evidence |
|---|---|---|---|---|
| `curriculum.definition.create` | STAFF with `curriculum.definition.manage` | none | P0 | unknown School/code, stale/no grant denied |
| `curriculum.revision.draft/edit/validate` | STAFF with `curriculum.revision.draft` | none | P0 | immutable published revision cannot be edited; content hash/version |
| `curriculum.revision.publish` | STAFF with `curriculum.revision.publish` | independent STAFF with `curriculum.revision.approve` | P2 | approved digest, Year/Class/Campus full scope, CUR-01 overlap, B-M1 actual Section offering count |
| `curriculum.revision.replace/retire` | STAFF publish permission or distinct registrar-selected action | independent reviewer with operation-matched grant | P2 | forbid unapproved CUR-01 mid-year cutover, preserve history/Exam snapshot |
| `curriculum.section_subject_offering.change` | STAFF with `curriculum.offering.manage` | `curriculum.offering.approve` **only if P1 REVIEWED** | P1 | wrong Section/dates, archived D1 Subject, stranded BF-1 set/future B-M1 denied |
| `curriculum.selection.finalize` | STAFF with `curriculum.selection.change` | `curriculum.selection.approve` **only if P1 REVIEWED** | P1 | BF-1 set row even for zero elected members; live Student/Enrollment, exact group+head |
| `curriculum.selection.amend/withdraw` | STAFF with `curriculum.selection.change` | same independent reviewer if P1 REVIEWED | P1 | original finalization retained, max/min per Section/time, no double receipt |
| `curriculum.selection.correct_history` | STAFF with `curriculum.selection.correct` | separate `curriculum.selection.correct.approve` reviewer | P2 | P2 exact source/successor and as-known vs as-observed history; no silent old Exam rewrite |

**No Student or FAMILY mutation/proposal operation.** Teacher with explicit full staff permissions can act only as a separately authorized staff Principal; D1 teacher assignment is never sufficient. `APPROVED` state cannot apply the change by itself. An unregistered action/code or missing P1 operation policy denies before mutation. Foundation review authority and Principal identity must be reverified at exact APPLY after obtaining the approved lock prefix and on rerunnable receipts. Role templates, automatic grants and School policy defaults are not supplied here.

## 4. Fixed checked-read response ceiling and safe errors

| Candidate fixed read | Safe fields (illustrative projection, subject to CUR-07/08 signer) | Explicitly excluded |
|---|---|---|
| `curriculum.section_offerings.read` | Section offering ID, published Revision ID and effective safe Subject/Group labels, type/classification needed for user purpose | Student IDs or elections, teacher assignment, raw command payload |
| `curriculum.selection.staff.current` | exact authorized Student target ID, accepted Enrollment and Section safe IDs, selected Subject IDs, `NOT_SUBMITTED/FINALIZED_EMPTY/FINALIZED_WITH_CHOICES`, group limits and effective date | other Students, correction narrative, reviewer name/id, raw receipt and privacy details |
| `curriculum.selection.self.current` | own offered safe Subjects, accepted choices, BF-1 finalization status, group min/max, effective date | other Student records, old-year history, actor/grant/Principal IDs, arbitrary workflow |
| `curriculum.selection.family_child.current` | only currently authorized child's safe current offered/accepted Subjects and BF-1 status | Student identifiers not necessary for display, other children/peers, old year/history, identity, review/audit |
| `curriculum.selection.staff.history` | exact allowed old Enrollment/revision/choice-set generation IDs, effective and recorded timestamps, safe change classification | unrestricted reason text, reviewer notes, Foundation review chain, unrestricted exports |

**Denial order:** validate current Principal and live target permission/grant/scope before exposing specific existence, group count or enrollment evidence; then resolve target D1 ancestry and permitted read version, and apply safe field allowlist. For **unknown and unauthorized** target return the same generic `NOT_ACCESSIBLE`. More specific `INVALID_CONTEXT`/`CHOICE_GROUP_LIMIT`/`REVIEW_REQUIRED` are internal or only for already-authorized staff; no unauthorized enumeration. The [existing DB-04 proposed denial catalog](db04_synthetic_fixtures_and_safe_denial_codes_20261020.md) is **not** a registered Foundation error taxonomy.

## 5. Threat-driven authorization matrix (planned, not executed)

| ID | Principal / operation / scope | Expected |
|---|---|---|
| `PM-01` | Authorized Staff/Campus A tries finalize Campus A Student exact Section/Enrollment under registered DIRECT P1 | Accepted only when current live policy, D1 snapshot, BF-1 head and B-M1 constraints all pass. |
| `PM-02` | Same Staff Campus A attempts Campus B Student | Generic `NOT_ACCESSIBLE`, no identity leak, no command mutation. |
| `PM-03` | Teacher assigned a Section but has no independent DB-04 staff grant tries `curriculum.selection.finalize` | Denied; assignment alone is not a permission. |
| `PM-04` | Student SELF with a live, explicit SELF grant reads own FINALIZED_EMPTY | Safe current status; no base SELECT and no peer Student data. |
| `PM-05` | Student SELF without the separate registered grant attempts same read | Denied despite login/identity; no default self visibility. |
| `PM-06` | Current FAMILY CHILD link + live `family_safe` grant reads child | Safe current data only, one bound child target; no history or other Student disclosure. |
| `PM-07` | Revoked FAMILY link, or link present but grant missing | Indistinguishable denial; revoke vs read concurrency requires Foundation control. |
| `PM-08` | Student or FAMILY sends request to propose/finalize accepted choices | No registered proposal/mutation command; denied. |
| `PM-09` | STAFF with `curriculum.selection.change` but no `curriculum.selection.history.view` reads corrections | Denied; current write permission does not automatically permit historical read. |
| `PM-10` | Staff requester approves same P2 publication as an alternate role or Principal for same Person | Denied self-review under approved CUR-05; independent *registered* active reviewer grants required for implementation. |
| `PM-11` | Campus A reviewer tries approving School-wide publication touching Campuses A+B | Denied insufficient full affected scope. |
| `PM-12` | P1 policy missing/ambiguous; or DIRECT attempted under REVIEWED mode | Denied, not silently downgraded to P0. |
| `PM-13` | Valid request approved, then requester or reviewer grant revoked before APPLY | Reject/invalidate at APPLY after revalidation; one safe receipt, no accepted DB-04 writes. |
| `PM-14` | Authorized staff retries FINALIZE same canonical key, then changed intent same key | Same result only after fresh authorization; changed-intent conflict without new BF-1 generation. |
| `PM-15` | Direct `authenticated`/`anon` SELECT/INSERT on any of eight app_private DB-04 tables | Denied by privileges+FORCE RLS. |
| `PM-16` | Current SELF/FAMILY read via search/export/AI/offline cache after role/relationship revoke | No stale permitted cache/write disclosure; same checked field ceiling and live-access semantics. |
| `PM-17` | Foundation School policy changes while two backends review/APPLY same Student finalization | Revalidate exact operation mode/typed intent and current permissions, no duplicate set/outbox. |
| `PM-18` | D1 Enrollment MOVE/END racing authorized finalized-empty set APPLY | Lock School before Student, re-evaluate exact Enrollment after waits, do not reparent old set to destination. |

These planned cases supplement [AU-01–12](db04_cur04_student_family_staff_authorization_decision_gate_20261021.md), [WF-01–12/WFR-01–06](db04_cur05_workflow_reviewer_authorization_owner_decision_gate_20261021.md) and [BF1/BM1 specs](db04_cur03_bf1_bm1_approved_eight_entity_design_20261021.md). **No tests have been run.** Runtime concurrency requires two real PostgreSQL backends, observed `pg_stat_activity`/`pg_blocking_pids` and both arrival orders, with fresh post-commit DB-04 source, audit/receipt/outbox and permission checks. Never conflate a drafted test with an actual green CI run.

> **Source/consumer decision update — 2026-10-21:** [CUR-06 A1+B1+C1+D1+E1+F1 approved](db04_cur06_approved_transfer_archive_history_policy_20261021.md) limits stale Enrollment APPLY and prevents unsafe historical reassignment; [CUR-07 consumer snapshot/checked-read proposal](db04_cur07_exams_learning_timetable_eligibility_snapshot_owner_gate_20261021.md) is pending. No consumer resolver, permission or workflow code registered.

## 6. Review/handoff ledger

| Signer / owner | Exact approval requested | Current state |
|---|---|---|
| **Product owner CUR-04** | Staff-only writes; Student/FAMILY bounded current checked reads; no teacher shortcut/proposals; separately permissioned history | **APPROVED A1+B1+C1+D1+E1+F1**, [verbatim decision](db04_cur04_approved_student_family_staff_authorization_20261021.md). |
| **Product owner CUR-05** | Exact P0/P1/P2 per operation and independent reviewer routing | **APPROVED A1+B1+C1+D1+E1+F1+G1+H1** [decision](db04_cur05_approved_workflow_reviewer_policy_20261021.md); registration and School policy settings remain pending. |
| **Foundation permission/deployment registrar** | Uniqueness/length and supported Scope-set for codes, family_safe/OWN resolver, Principal/Person distinct review, operation/policy/permission/executor registration, safe outputs | **NOT RECEIVED**; do not seed D1 counts or role templates. |
| **D1 Academic/Student/FAMILY owners** | Exact source keys, active Enrollment lock prefix, Student SELF/FAMILY CHILD resolver and revocation semantics, no late School/Student trigger lock | **NOT RECEIVED**. |
| **Exams/Learning/Timetable, CUR-07** | Independent narrow consumer read/snapshot and confidentiality of observed old choices | **NOT RECEIVED**. |
| **Independent security/CUR-08 integrator** | Eight-domain-table RLS/ACL, fixed typed functions, populated local install, all race outcomes, exact-head CI | **NOT RECEIVED**. |

**Next:** CUR-05 owner decision is recorded and this crosswalk is reconciled to product policy; **Foundation registrar has not approved/registered codes**. The [CUR-06 Enrollment MOVE/END, Subject ARCHIVE, replacement and history gate](db04_cur06_transfer_archive_replacement_history_owner_gate_20261021.md) is prepared but requires owner decision. No SQL.

**Disposition: CUR-04/CUR-05 PRODUCT CHOICES APPROVED; ALL EXACT PERMISSION/OPERATION REGISTRATIONS, SCHOOL P1 CONFIGURATION AND SPECIALIST SIGNOFFS UNAPPROVED; ZERO SQL/GRANTS/CI/DEPLOYMENT.**
