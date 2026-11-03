# DB-04 CUR-04 — Approved Student, FAMILY, Staff and Teacher Authorization

**OWNER APPROVED — 2026-10-21. Product policy CUR-04 A1+B1+C1+D1+E1+F1.** Approval provenance: immediately after the assistant asked **“Do you approve A1+B1+C1+D1+E1+F1, allowing explicitly authorized staff to manage accepted choices, while Students and linked parents receive separately granted current-data read access, teachers gain no automatic authority, and confidential history remains separately protected?”**, the owner replied **“I approved continue”**. This resolves the six explicitly identified CUR-04 choices. It does **not** approve [CUR-05 P0/P1/P2 proposals](db04_cur05_workflow_reviewer_authorization_owner_decision_gate_20261021.md), seed roles/permissions, or authorize SQL or deployment.

This record supersedes the historical **PENDING OWNER** status in the [CUR-04 option analysis](db04_cur04_student_family_staff_authorization_decision_gate_20261021.md) and the relevant CUR-04 status in the [owner/integration signoff dossier](db04_cur_owner_decision_and_cross_domain_signoff_dossier_20261020.md). Previously approved CUR-01 no-overlap rule, CUR-02 A1+B1+C1, CUR-03 A1+B1+C1+D1+E1 and BF-1/B-M1 remain in force.

## 1. Approved authorizations — product semantics, not current grants

| CUR-04 option | Approved rule | Must not be interpreted as |
|---|---|---|
| **A1 — staff accepted writes** | Only staff holding a separately **registered and live action permission**, an effective Principal and one complete matching School/Campus/Section authorization context may FINALIZE, AMEND or WITHDRAW an accepted OPTIONAL/ELECTIVE choice set. Apply only when an independently authorized CUR-05 workflow permits it. | An Administrator/Principal/Teacher role name or employment record automatically permits the action; a staff account can act across Campuses. |
| **B1 — Student SELF current reads** | A verified Student SELF Principal **may** receive a purpose-specific, minimal, current offered/accepted elective and BF-1 finalization-status read **only when an explicit current registered grant authorizes the exact own Student target**. | Student login alone grants that read, accesses peer Students, permits writes or unlocks complete archived histories. |
| **C1 — FAMILY CHILD current reads** | Current linked FAMILY Principal **may** receive a minimal child-current view via fixed **family_safe** checked-read permission, after verifying present FAMILY membership, child relationship/access/consent and live current grant on each call. | A past or current parent relationship alone constitutes a grant; access continues after revocation; a Family principal can mutate choices or enumerate peers. |
| **D1 — teacher contextual access** | Class Teacher, Subject Teacher, CO_TEACHER, or Timetable assignment **does not itself grant** subject-choice read or mutation. A teacher who separately qualifies as explicitly granted scoped staff can receive only that independently permissioned action/view. Approved aggregate classroom context cannot reveal individual choices through small-group leakage. | Employment/teaching assignment is equivalent to `curriculum.selection.change` or reviewer grant. |
| **E1 — no Student/FAMILY proposals in v1** | No SELF or FAMILY submit/reviewed-proposal or direct accepted-election endpoint in the initial Curriculum release. Staff-owned change initiation is distinct from Foundation reviewer APPLY and its policy. | Submission from a Student/FAMILY automatically becomes accepted or creates a pending proposal; browser UI gating is enough. |
| **F1 — protected history** | Detailed accepted/withdrawn/corrected historical finalization sets and selected Subject histories are separately permissioned **staff-only** checked reads. Current Student/FAMILY views contain only current safe state, not old correction reasons, reviewer identity or unrelated Student records. | Family-safe current view gives historical audits or sensitive workflow evidence; current staff action authority implies historical-read permission. |

**No rights become active through approval alone.** Foundation/deployment registrar must approve each exact action and read permission code, its explicit scopes, `family_safe` bit, typed resolver and effective grants; School role templates must not be silently seeded. All private DB-04 relations keep FORCE RLS and default-deny, with only narrow reviewed fixed-function access by approved executors. No `anon`/`authenticated` direct private table SELECT/INSERT/UPDATE/DELETE and no generic dynamic `purpose` RPC.

## 2. Fixed disclosure ceilings and linkage tests

Approved **product ceilings** (final executor/interface names await CUR-08 and Foundation security):

- **STAFF CURRENT**: For one authorized Student's exact **accepted D1 PRIMARY Enrollment**, exposed safe current Curriculum revision/Section Subject Offerings, group restrictions, BF-1 `NOT_SUBMITTED` vs `FINALIZED_EMPTY` vs `FINALIZED_WITH_CHOICES`, chosen Subject identifiers and effective interval. Never include private Principal IDs, receipt payloads or reviewer reasons by default.
- **STUDENT SELF CURRENT**: Same narrow own-Student choice/finalization projection and offered choices, only after own-Principal mapping, live grant and target ancestry. No arbitrary old-year as-of read, peer Student identifier, Student roster or P1/P2 request details.
- **FAMILY CHILD CURRENT**: Current child offered/accepted Subjects and BF-1 finalization state, only after **one live FAMILY CHILD grant AND current family membership/access/consent**. No Person/Principal lineage, identity/contact, request reason, reviewer note, family sibling roster or arbitrary old-year eligibility.
- **STAFF HISTORY**: Distinct history-view permission and exact scope, with typed date/revision/Enrollment query. Return only reviewed facts. Confidential reasons and Foundation audit/review records remain on their own existing permission surfaces.
- **TEACHER MINIMAL CONTEXT**: Only explicitly permissioned Section-subject offering context or a separately privacy-reviewed classroom aggregate; assignment does not authorize individuals’ current elective selections.

At read time, evaluate **current** Foundation principal/grant/Scope + stored D1 Enrollment ancestry + current authorized relationship. Historical source rows remain reconstructable for approved history consumers, but stale family links do not revive access to them. This policy must apply equally to exports, AI, notifications, reporting and offline cached responses, with live authorization and cache revocation barriers—not just UI pages.

## 3. Protected staff commands and immutable BF-1 data

An authorized staff action derives Principal server-side, checks a **registered** exact School/Campus/Section grant, Foundation SHARED auth/receipt/idempotency fence, obtains **School before Student**, locks exact accepted D1 Enrollment and academic ancestry, then locks DB-04 revision/applicability/selection-set and member history; it rechecks Student `row_version` (D1 Enrollment has **no row_version**), approved immutable published digest and exact Section offering and date.

- **FINALIZE** can emit an accepted BF-1 selection-set row even with **zero chosen Subjects**; this is `FINALIZED_EMPTY`. No selection-set row means `NOT_SUBMITTED`, subject to correct version/as-of projection. The eight candidate relations are not yet executable DDL.
- **AMEND/WITHDRAW** creates retained one-way closure/successor evidence, not destructive overwrites. The original accepted Enrollment and prior choice-set generation remain historical. Staff choice action cannot move a Student, allocate a roll or alter D1 Subject catalog/Enrollment.
- **CUR-03 B-M1** remains strict: for every Section/effective segment, `0 ≤ min ≤ max ≤ distinct actually offered elective Subjects` and finalized batch group-count bounds. No prereq, seat-capacity/lottery or global deadline engine.
- **P1/P2** action routing is **not** automatically approved by CUR-04; see CUR-05. Requester/reviewer Person separation, live reauthorization at APPLY, registered School policy and safe receipt/audit/outbox remain implementation prerequisites.
- Wrong Campus or Section, old Enrollment, unavailable elective, Subject category mismatch, revoked staff grant, teacher-only assignment, Student/FAMILY mutation and unauthorized history are denied **without disclosing whether a targeted Student exists**.

## 4. Implementation dependencies and acceptance handoff (not executed)

| Handoff | Required specialist confirmation | Negative or concurrency evidence |
|---|---|---|
| **Foundation permission/registrar** | Unique typed current/self/family/history and staff action codes; allowed ALL/CAMPUS/SECTION, OWN/STUDENT_SELF and OWN/FAMILY_CHILD resolver sets; `family_safe` only for independently authorized current safe projections, never for staff changes. No default grants. | Staff wrong-Campus, Student peer, former guardian, unsafely scoped reviewer and unregistered-code denials. |
| **D1 Student/FAMILY** | Current accepted PRIMARY Enrollment+Section ancestry, Student SELF mapping and FAMILY membership/child-access revocation synchronization; published D1 END/MOVE lock prefixes. | MOVE/END vs FINALIZE and Family revoke vs checked read under real separate backend waits. |
| **DB-04 eight-entity physical** | CUR-08 determines BF-1 set/member FK constraints, one-current-head, group snapshot, membership/digest, effective history, nullable OPTIONAL linkage and narrow checked-read result types. | Two authorized staff competing BF-1 set heads, zero-selected finalized batch, immutable old histories, no direct table grants. |
| **Exams/Learning/Timetable** | CUR-07 bounded consumer queries and immutable `valid_at/observed_at` source snapshots, no unsafe Student roster. | Old published Exam never changes after a Student election correction or later revision. |
| **CUR-05 workflow owner** | Specific P0/P1/P2 operations and independent reviewer model approved and registered separately. | APPROVE≠APPLY, revoked requester/reviewer authority at APPLY fails closed; no role switching self-review. |

**Planned tests**: AU-01…AU-12 in the historical [CUR-04 option analysis](db04_cur04_student_family_staff_authorization_decision_gate_20261021.md) remain designed only. They must be implemented with real Principal/grant fixtures and correct disclosure; no test has run, no permissions were installed and no hosted Supabase project was changed.

> **Workflow decision update (2026-10-21):** [CUR-05 A1+B1+C1+D1+E1+F1+G1+H1 owner-approved](db04_cur05_approved_workflow_reviewer_policy_20261021.md), superseding any earlier ‘CUR-05 unapproved’ status below. This does **not** activate permissions, configured P1 School modes or review codes. [CUR-06](db04_cur06_transfer_archive_replacement_history_owner_gate_20261021.md) is the next open owner decision.

## 5. Decision ledger and next gate

**Approved:** CUR-01 only the School-wide/Campus overlap/no-precedence portion; CUR-02 A1+B1+C1; CUR-03 A1+B1+C1+D1+E1 plus BF-1/B-M1; **CUR-04 A1+B1+C1+D1+E1+F1**.

**Still unapproved:** CUR-01 future first-effective dates and cutovers; **CUR-05 A1+B1+C1+D1+E1+F1+G1+H1** approval class/reviewer decisions; CUR-06 transfer/archive/revision replacement; CUR-07 consumer snapshots; CUR-08 eight-entity exact DDL/executors/permissions/installation. D1 release, Foundation specialist/registrar approval and actual concurrency tests remain external.

**NEXT OWNER REQUEST:** Review [CUR-05 P0/P1/P2 reviewer and APPLY option set](db04_cur05_workflow_reviewer_authorization_owner_decision_gate_20261021.md) and explicitly approve or change **A1+B1+C1+D1+E1+F1+G1+H1**. A further safe independent task is the CUR-05 permission/reviewer-registration **proposal crosswalk**, no SQL.

**Disposition: CUR-04 SIX-OPTION PRODUCT POLICY OWNER-APPROVED; NO REGISTERED GRANTS, SQL, RUNTIME PASS OR PR MERGE.**
