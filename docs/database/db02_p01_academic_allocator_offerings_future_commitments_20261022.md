# DB-02 P01 — academic allocator eligibility and future-commitment cutover contract

**Date:** 2026-10-22  
**Status:** P01 engineering contract documented and scoped for implementation; **NOT implemented SQL, NOT an accepted protected command, NOT security/deployment approval**.  
**Owner branch:** `db/db-02-p01-academic-pools-future-commitments`, stacked on DB-02 [PR #101](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/101) head `1cf6aa51827000c77f17c7489be8b4fc18aebc97`; separate from shared-receipt PR #122 and DB-01/DB-03/DB-04 branches.  
**Tracker:** [DB-02 issue #69](https://github.com/yunusyosaf399/edusync_saas_school_app/issues/69), task P01. Later **I03/I05/T05/T07/G02** implement and verify the behavior.

## 1. Source-backed constraints (existing; not new product decisions)

1. Owner-approved first release (2026-10-20): trusted School-local **today-only INIT or REPLACE**, no END/backdate/future scheduling, retained numeric Roll ownership and no automatic migration of existing allocations; School-global P1 route. See `docs/database/20261020_owner_choices_and_dependency_resolution.md`.
2. `app_private.roll_allocator_states`: **one NULL-Class Offering pool** for each persistent policy revision, or **one Class-Offering-specific pool per academic policy revision**. Partial unique indexes enforce both namespaces; counter is server-managed. `docs/database/27_domain_package_01_physical_catalog.md`, `30_domain_package_01_constraint_matrix.md`.
3. `app_private.class_offerings` has School, Class, Campus and Academic Year ancestry, state `PLANNED|OPEN|CLOSED|ARCHIVED`, and capacity which may be zero. `section_offerings` belong to one Class Offering. A Section is never a numeric namespace. Class/Section and Foundation parent state checks are enforced in the existing structural guard `effect30_32_crossrow_campus_local_rename.sql.draft`.
4. `app_private.d1_enrollment_place_prelock_roll` in `effect25_19_enrollment_place_school_anchor.sql.draft` locks the **School first**, re-reads ancestry after any wait, selects the policy effective at the Enrollment's requested `effective_from`, then locks the exact policy and (policy,Offering) or (policy,NULL) pool. A missing academic pool fails with `D1_ENROLLMENT_PLACE_ROLL_ALLOCATOR_MISSING`; it **does not create** the pool.
5. Existing DB-02 `effect43_01_db02_roll_policy_source_preflight.sql.draft` verifies INIT/REPLACE, School date, immutable source snapshot and School→source policy→source pool locking. It currently denies accepted future `roll_allocations` **on the source policy** when `effective_from >= School-local today`. It **does not** provision new pools, check every School future Enrollment/roll, or implement the protected effect.
6. Existing protected PLACE and MOVE may accept future-effective placement dates (their own date/authorization contracts govern those actions). A policy-change command must not silently cancel or reinterpret such previously committed rows. Latest DB-01 [PR #132](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/132) and combined draft [PR #133](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/133) are separate ownership/test evidence, not a completed DB-02 policy transition.

## 2. P01 engineering rule: which Offerings receive an academic pool

For a successfully authorized **new** `ACADEMIC_CONTEXT` revision `rNew`, provision **exactly one** allocator `(rNew.id, co.id)` for **each existing, structurally usable, nonarchived Class Offering** belonging to the same School, under the same transaction *before* the policy-change success receipt can commit.

The deterministic candidate set at the School-locked snapshot is:

- `co.school_id = locked_school_id`.
- `co.state IN ('PLANNED','OPEN','CLOSED')` (exclude `ARCHIVED`). Closed-but-reopenable and planned Offerings are included conservatively so reopening an Offering cannot immediately encounter a missing pool.
- Matching immutable ancestry: `co.class_id` belongs to the School, `co.campus_id` belongs to the School, `co.academic_year_id` belongs to the School, and all existing composite/structural checks remain valid. To be *potentially usable*, parent School is `SETUP|ACTIVE`, Academic Class is `ACTIVE`, Campus is `PLANNED|ACTIVE`, and Academic Year is `PLANNED|ACTIVE`. These are the existing `effect30_32` parent-state gates, not a new Campus policy or arbitrary year-date window.
- **No Section filter** (even zero Sections or all Sections closed): an Offering, not a Section, owns the allocator namespace.
- **No capacity > 0 requirement**: capacity 0 blocks new placement through existing checks, but capacity is mutable and is not a valid allocator existence predicate.
- **No campus-only scope or selection**: provision across the whole School; the policy is School-wide. A different School's Offering is excluded.

Offerings with unusable/archived ancestry are **excluded**, not repaired or reopened by a policy change. A currently `OPEN` Offering with inconsistent ancestry is a **fail-closed structural conflict**, not silently skipped. Existing invalid pending records are not made valid through this operation.

**INIT/REPLACE same rule:** an academic INIT and a transition to a *new* academic revision both generate a new set of revision-specific pools; a REPLACE does not repoint old pools or Rolls. Persistent INIT/REPLACE creates **only one** `(rNew.id,NULL)` pool with historical School-wide high-water restrictions tracked separately under I05/T07.

**Atomicity and order:** Foundation SHARED authorization/receipt prefix → lock School → verify policy/source and future commitments → lock relevant current policy/pools in stable order → inspect and lock eligible Offering ancestry in existing academic lock order → create immutable new revision and its unique pool rows in the **same transaction**. Process Offering UUIDs deterministically, avoid a late School lock, and let the real constrained inserts/privileges fail closed on duplicate/invalid context. Do not grant a client the right to INSERT pools.

### Offerings added or made usable *after* cutover (cross-owner integration requirement)

The current PLACE/MOVE prelock **does not lazily create an allocator**. Therefore an Offering created after policy activation, or an excluded Offering whose parent state later becomes usable, must obtain its matching pool through a separately authorized **School-locked Offering-create/open/parent-reactivation lifecycle integration** *before* any Enrollment can be accepted there. If that integration is absent, PLACE/MOVE must keep failing closed on missing pool; **never bypass the prelock, use another Offering's pool, create a client-side counter, or silently defer provisioning**.

The academic-offering owner must approve the exact state transition/provisioning hook. This cross-owner **implementation dependency is still OPEN** under I05/G02; P01 only fixes its expected behavior, not its implementation. Do not modify academic/Enrollment owner SQL under this DB-02-only task.

## 3. P01 cutover rule: already committed future-effective Enrollments and Rolls

Define `t` **once** as the trusted `app_private.d1_roll_business_date(locked_school_id)`, evaluated after acquiring the School anchor in the same transaction. Replacement is contiguous: source `effective_until=t`, successor `effective_from=t`. The preexisting source `effective_from < t` requirement remains.

Under the same School lock and *after lock-wait re-reads*, refuse INIT/REPLACE if an already **committed** placement or Roll assignment in this School **starts at or after t** and would be forced under a different policy version/namespace by the proposed today-only cutover. First-release conservative behavior is **reject the policy change**, not rewrite, reparent, void, or relabel an accepted Enrollment or `roll_allocations` row.

Implementation must examine both immutable sources:
- All School-owned `roll_allocations` with `effective_from >= t`, joining their recorded `policy_revision_id` to `roll_policy_revisions` and their `enrollment_id` to its Section→Class Offering→School. A future Roll already bound to the open source or any incompatible earlier policy **blocks cutover**, regardless of its current end/supersession state. Check all School rows; the present preflight's source-only future-roll check is a **subset**.
- All School-owned accepted `enrollments` with `effective_from >= t`, even when an allocation is unexpectedly absent. Reject this inconsistent case rather than assuming later deferred triggers will heal it. Only accepted/committed Enrollment records are considered; a mere unexecuted draft request does not create an immutable placement, but an approved DB-02 APPLY must redo the check after waiting.

An accepted Enrollment/Roll whose **effective_from < t** and effective period extends beyond t **does not block cutover merely by crossing t**. Keep its old policy ID, numeric Roll, effective interval, and lineage immutable. It does not acquire a replacement Roll automatically. Historical and future scheduled placement remain read-as-of their original effective date, not rewritten by the policy-change operation.

In the initial `INIT` case, any already committed future School Enrollment or Roll without a usable policy is an **integrity anomaly**: deny INIT and surface a bounded internal structural error for review; never invent a policy to repair accepted data. The actual future-placement/future-roll checks belong to the protected effect **I03/I04**, not to the evidence-writer receipt validator.

**Concurrent ordering:** School-row locking is the serialization gate shared with PLACE/MOVE. If future PLACE/MOVE wins, REPLACE re-reads committed rows and denies when incompatible; if REPLACE wins, PLACE/MOVE re-reads the new as-of policy and only succeeds with its preprovisioned correct pool. A rejected change makes **zero** revisions/pools/receipts/success events. An APPROVED request still carries no effect; APPLY repeats all checks, and a stale deterministic conflict INVALIDATES under the separately approved workflow contract.

Do not broaden the frozen independent Enrollment date rules, create an alternate policy for a conflicting future placement, change prior receipt history, or weaken the separate School/Principal/approval locks.

## 4. P01 acceptance cases for I03/I05/T05/T07 (not executed by this documentation task)

| Case | Fixture / arrival order | Required result |
|---|---|---|
| P01-A01 | Academic INIT with no usable Class Offerings | One revision; zero Class-specific pool rows; later Opening requires separately approved pool provisioning |
| P01-A02 | Two eligible OPEN Offerings in one School, different campuses | One distinct pool per Offering, correct new revision; same policy School-global |
| P01-A03 | PLANNED/CLOSED Offerings with usable ancestry and capacity=0 or zero OPEN Sections | Pool exists per Offering; no admission capability granted by pool existence |
| P01-A04 | ARCHIVED Offering or historical Offering with unusable archived parent | Excluded; never auto-unarchive or mutate old roll |
| P01-A05 | Existing OPEN Offering with invalid School/parent ancestry, or different-School Offering | Structural conflict fails closed for invalid in-School OPEN Offering; foreign Offering never receives pool |
| P01-A06 | Same policy and Offering double allocation attempt / duplicate namespace | Exactly one unique pool; no partial success/evidence on failure |
| P01-A07 | New Class Offering or parent reactivation after policy commit | Pool created by approved School-locked academic lifecycle before PLACE/MOVE, else missing-pool denial |
| P01-F01 | Source policy roll assigned for exactly t or t+3 | REPLACE denied; source/new revision/pools/history unchanged |
| P01-F02 | School future Enrollment at t or t+3 with missing Roll (corrupt fixture) | REPLACE/INIT fail closed; no partial change |
| P01-F03 | Old Enrollment and allocation begin at t−1 and cross t | REPLACE allowed if all other invariants hold; immutable historical Roll preserved |
| P01-F04 | Already committed future MOVE into different Offering after t | REPLACE denied if that MOVE's Roll would be reinterpreted |
| P01-F05 | Two backend sessions: future PLACE/MOVE holds School first, then REPLACE | Real wait observed; REPLACE denies stale/conflicting cutover; placement retained |
| P01-F06 | Two backend sessions: REPLACE holds School first, then future PLACE/MOVE | Real wait observed; placement selects new effective policy/new pool or fails its own lawful validation |
| P01-F07 | Submitted/approved policy request, intervening future Enrollment before APPLY | APPLY rechecks, terminally invalidates deterministic stale request; zero effect |
| P01-F08 | Policy-change transaction fails during 3rd Offering pool INSERT | Entire change/revision/pool/evidence transaction rolls back, no orphan pools |

All assertions need actual disposable PostgreSQL behavior and final role/ACL checks before checked-off **T05/T07**; proposed return/error labels in this document are descriptions, **not registered public error/event codes**.

## 5. Boundary and completion record

**P01 completion means:** deterministic *design/engineering eligibility and future-commitment rules are specified and source-audited*. Actual end-to-end behavior, real two-session races, and academic lifecycle hook **remain unimplemented** (I03, I05, T05, T07 and G02). This document adds **no SQL, no tests, no tables, no grants, no workflow handler, no activation**; no independent security signoff is implied.

**Source audit used:** `AGENTS.md`; `docs/database/27_domain_package_01_physical_catalog.md`, `30_domain_package_01_constraint_matrix.md`, `db02_policy_transition_implementation_readiness_20261019.md`, `20261020_owner_choices_and_dependency_resolution.md`; final relevant `effect25_19`, `effect25_16`, `effect30_32`, `effect43_01`, `effect39_01` draft SQL. Compare latest merged/source versions before implementing: this is a pinned 2026-10-22 snapshot.
