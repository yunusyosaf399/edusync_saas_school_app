# Section 03 — D1 integration ownership and release gates (2026-11-01)

**Status: inactive draft / deployment NO-GO.** This is a non-executable coordination contract for PDF tasks DB-025–DB-042. It makes no claim that Section 03 is complete. The owner has authorized work in GitHub, but has not authorized hosted deployment.

## Exact starting point and protected ownership

This documentation branch starts at the validated owner-composition commit `f472f2abf3303ffef10d4744a4dd6af5735acc5e` from PR #168. Its G02 contract pins 291 ordered draft fragments, 112 suites, 4,292 assertions, 34/34 forced-RLS candidate relations, zero forbidden private client EXECUTE and the existing School-lock concurrency tests. These are **historical exact-SHA results**, not an acceptance of this document or of newer DB03 work.

- **Foundation / Section 02:** nine frozen executable migrations; auth identities, permissions, workflow approvals, command receipts, audit and outbox are not to be copied or rewritten.
- **DB01 / Section 01:** roll correction and placement use the School → policy → pool / academic ancestry lock ordering. DB01-10 requires consumer handoffs and DB01-11/12 review and release.
- **DB02 / Section 02:** School Roll Policy and allocator, including the Academic Offering pool hook, are composed in PR #168. G04–G06 integration, contract freeze and deployment are still open. Do not reset allocator high-water counters or enable `student.roll_policy.change` independently.
- **DB03 / Section 04:** #199/#202 permit incomplete administrator DRAFTs and record SKIPPED, MARKED_PAID or UNPAID admission-fee disposition. The newer stacked PR #203 (`fabaaeb871874107db28346ef4db688eb34e837e`) requires current receipt-backed destination, explicit fee disposition and required documents before administrator Forward, exposing PENDING_DETAILS and can_forward; it is not yet exact-head database-CI accepted. UNPAID may forward. MARKED_PAID is not a bank settlement. Principal alone approves final admission, and #203 still does not create Student records. The old deny-only Finance clearance gate must be replaced by an approved positive handoff; do not assume an approved payment receipt or Student discount is admission clearance.
- **DB04 / Curriculum:** later curriculum/class assignment consumer acceptance must run against the same reconciled D1 catalog and final student placement state.
- **DB08 / Finance:** bank-slip evidence and student fees remain separately approved/reviewed flows; do not infer payment from a school administrator's fee declaration. No gateway, bank cryptography or purchase-linking activation.

## Section 03 acceptance matrix

| IDs | D1 deliverable | Required proof | Cross-owner block |
| --- | --- | --- | --- |
| DB-025, 029 | Exact ordered draft chain, manifests, upgrade and Migration 10 packaging | Byte-pinned fresh install, populated upgrade and rollback; no same-name final definition drift | DB01, DB02 G04–G06; DB03/DB04 consumer freeze |
| DB-026–028 | Campus/year/grade/class/section/room/subject/teacher catalogs | Composite ancestry, capacity, overlap, archive and School-local-date tests | DB02 roll-pool hook and DB04 selection |
| DB-030–034 | Immutable Person/Student lifecycle, profile/photo and family relations | Authorized same-family reads, changed custody, sensitive edits, history retained and wrong-child denial | DB03 final Student creation, Section 02 family grants |
| DB-035–039 | Initial enrollment, roll and changes | Allocation/correction/replay, retained counters and two-session CREATE/TRANSFER/END/PROMOTE races | DB01 correction, DB02 School policy cutover, DB03 approval |
| DB-040–042 | Employee/qualification/status/teaching commands | HR versus class/subject teacher scope, changes under contention, non-destructive history | Section 02 authority, DB04 curriculum and future HR |

## Final admission → D1 handoff (must be one transaction)

1. Lock and reauthorize current application, independent Principal decision and original required certificate source identities. Preserve incomplete DRAFTs and document grace state until eligible.
2. Revalidate current School/Campus/year/intake and eligible destination Class Offering/Section with capacity. Inspect fee **disposition** without mistaking it for a verified payment. Apply any later agreed positive Finance condition by its immutable source ID, not a client boolean.
3. Bind or create the canonical Person subject to the DB03 one-open-application/Person fence, then create **at most one** immutable Student identifier and record its status.
4. Acquire the DB01/DB02 School-policy and Roll-pool locks in their established order. Allocate one unique School-local Roll and admission number under their respective frozen policies; do not recycle high-water numbers on rollback/retry, except transaction-local uncommitted allocations.
5. Create exactly one initial primary Enrollment and the relevant historical membership and document-to-Student links, keeping the original uploaded objects private and source lineage intact.
6. Commit Principal approval, Person/Student/Enrollment/Roll and document linkage together with one typed idempotent command receipt, audit entry and outbox fact. A failed precondition must leave **none** of these accepted effects. Exact-key replay returns the same accepted identities; changed-payload replay denies.
7. Test concurrent identical and competing applications, Principal approval versus document revocation, transfer versus placement, allocation versus School policy REPLACE, and campus/section capacity consumption with real two-session locks.

This defines integration acceptance, **not permission to implement a new parallel allocator, approval engine or public privileged RPC**.

## Explicit stop conditions before Section 03 is called closed

- Current branch heads differ from the G02 pin: regenerate exact ordered source/hash manifest and rerun full candidate CI. Never inherit an older run's PASS.
- DB01 final handoff or DB02 G04–G06 remains unresolved: keep Migration 10 `.sql.draft`, preserve protected operation disablement, and do not modify hosted school data.
- DB03 Principal-final command lacks a positive, atomic Student/Enrollment/Roll contract: DB-030, DB-035, DB-039 and DB-029 remain open.
- DB04 curriculum selection could invalidate catalogs/teaching assignment ancestry: freeze and validate its exact consumer contract before final rollout.
- Missing authorized non-author review, final staged upgrade, recovery evidence or explicit production GO: no deployment/merge claim.

## Cross-chat update protocol

At each Section 03 increment, query latest open PRs and actual head SHAs of DB01, DB02, DB03 and DB04. Review changed filenames and effective SQL ownership before editing. Treat a newer stacked PR as *candidate*, not as merged, executable or tested evidence; capture exact-head CI before integrating it. In particular, #203 changes Forward readiness and must be reflected by eventual Student-create handoff tests. Never rewrite an active owner branch or assert another chat has finished based on a draft PR alone.

## Next safe Section 03 engineering increment

On a **new isolated draft branch** from a freshly reconciled integration head, add source-only ancestry/capacity/overlap/archival regression fixtures for DB-026–028 without redefining shared receipts, School Roll Policy, Student.create or Admissions. First rerun the entire frozen Foundation and D1 source/runtime suite, then update this matrix with the exact resulting SHA and CI links. This sequencing allows independent catalog strengthening while cross-domain finalization is pending.

**External requirement:** no action outside GitHub is needed for this document. Hosted Supabase deployment, private original-file Storage activation, staging Auth users, recovery rehearsal and production GO will require separately identified authority/availability later.
