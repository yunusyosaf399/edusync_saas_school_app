# DB-04 CUR-01 — Approved First-Effective Date, Mid-Year Cutover and Historical Integrity

**PRODUCT OWNER APPROVED — 2026-10-21.** Exact approval in DB04v1.1:

> For DB-04 CUR-01, I explicitly approve T1 + M1 + S1 + F1 + H1. All five proposed rules are approved. Record my decisions in DB-04 documentation and continue the next documentation-only task without SQL.

This approves the **five precisely scoped choices** in [the CUR-01 outstanding decision gate](db04_cur01_effective_date_cutover_owner_gate_20261021.md), *in addition to* the existing [approved overlap/no-precedence rule](db04_cur01_approved_applicability_decision_20261020.md). As of this owner response, **CUR-01 PRODUCT DECISIONS ARE COMPLETE**; installation, security and consumer signoffs are **not** complete. No SQL, executable acceptance, RLS/permission grant, migration release or deployment is authorized.

## 1. Approved rules and exact constraints

| Owner-approved option | Binding product behavior |
|---|---|
| **T1 — Explicit first effective date** | A School must supply an explicit Curriculum first-effective business date within the exact academic year of the affected authoritative D1 Class Offering. Future-effective initial publication is allowed. Missing dates must be rejected; never default silently to today's date or Year start. |
| **M1 — Mid-year replacement** | A prospective mid-year replacement is allowed **only by CUR-05 P2 independently reviewed publication/REPLACE**, with an explicit cutover date, old-to-new **adjacent half-open effective intervals** and immutable original published content. Approval of a request is not its APPLY. |
| **S1 — Protect accepted Student selections** | Before replacement APPLY, verify all impacted current/future BF-1 finalized T7 sets and T8 members and Section Subject Offerings across relevant effective segments. **Reject an unsafe cutover** that strands a selected Subject, violates strict B-M1, or changes eligibility without a separately authorized coherent transition. No implicit election migration, grandfathering, mapping or silent reparenting to a new Revision or Enrollment. |
| **F1 — Recheck at APPLY** | Regardless of earlier draft validation or P2 approval, recheck actual D1 Enrollment/Subject/Section and Class Offering/Year context, applicable grants/reviewer disjointness, revision/version/digest, School-first lock/fence, NULL-campus coverage conflicts and Section feasibility under the then-current serialized state. Concurrent conflicting APPLY attempts must not both take effect. |
| **H1 — Preserve history** | Retain original declared effective bounds and immutable published revision/rule/digest, one-way reviewed closure and successor lineage, receipt/audit/outbox evidence, original student T7/T8 choices, and consumer-owned as-observed Exams/Learning/Timetable snapshots. Never rewrite old published facts by selecting a newer Revision. |

**Previously approved CUR-01 overlap rule remains binding:** at most one effective published Curriculum for any real D1 Class Offering and business date. School-wide and Campus-specific curricula are equal peers: neither automatically overrides the other. Both conflicting publication and replacement are denied. Adjacent `[old_start,cutover)` and `[cutover,new_end)` intervals do not overlap. No implicit preference for campus, latest version or a newer command receipt.

**Time bounds:** D1 Academic Year has an inclusive `ends_on`; the DB-04 candidate half-open representation converts this to the exclusive next-day bound. The actual D1 Class Offering Year controls validity, not a guessed School "active year". The precise installed SQL type/closure semantics remain CUR-08 physical-review work, not frozen DDL here.

## 2. Invariants and worked examples

1. School Year `[2026-09-01,2027-09-01)`: the School may select first effective date `2026-10-15`; it must not silently use `2026-09-01` or today's date if the requested date is absent.
2. An authorized School P2 reviewer approves `2027-01-01` as a prospective replacement cutover. The old published rule is retained with applicable interval ending `2027-01-01`; the new published rule starts on that same date. A late or competing APPLY must revalidate both effective coverage and active student choices.
3. A student accepted Music under a T7/T8 set, but the replacement lacks Music. The School must resolve the affected choice via a **separately authorized and historically traceable transition**; an otherwise approved P2 replacement **cannot APPLY** while it would strand the accepted choice. No automatic Music→Art substitution.
4. If School-wide and Campus-specific replacement requests concurrently target the same Class Offering/date, at most one conflicting accepted result can exist, independent of arrival order.
5. A Student moved into a new D1 Enrollment just before APPLY must be evaluated against current authoritative Enrollment identities; old T7/T8 entries cannot be copied to the new Enrollment. This follows CUR-06.
6. An Exam already published under the prior effective revision keeps its originally captured as-observed basis; a later change in the Curriculum is not permission for DB-04 to revise the Exam.

These are accepted product **expectations** and planned acceptance cases, not observed PostgreSQL runtime test results. The dates are illustrations only, not a school calendar declaration.

## 3. Implementation dependencies, still not approved

- **CUR-07** consumer contract A1–G1 remains product-UNAPPROVED; Exams first capture checkpoint, Learning audience freezing and Timetable Section-only feed require independent signer verification.
- **CUR-08** eight-entity physical fields and especially P01 T7 set granularity/OPTIONAL linkage and P02 effective accepted-head uniqueness remain product-UNAPPROVED. See [new focused decision gate](db04_cur08_selection_set_granularity_head_owner_gate_20261021.md).
- The **D1 release** must expose exact parent keys/lock hierarchy and runtime-compatible Enrollment END/MOVE, Subject ARCHIVE and Section changes, including implicit FK/trigger locks.
- **Foundation/deployment owners** must register separate CUR-04 permissions, CUR-05 P2 review/application executors, receipt/audit/outbox and protected checked reads; existing registrations are not implicitly active.
- Independent data-integrity, authorization, real two-session concurrency, consumer immutable snapshot and populated-upgrade tests must be executed at a pinned released source before production authorization.
- **Do not** alter Foundation migrations 1–9, D1 Migration 10 drafts/contracts, DB-01/02/03, Exams/Learning/Timetable source, global registrars/CI or hosted Supabase on the basis of this decision.

**Status: CUR-01 PRODUCT DECISIONS COMPLETE AND RECORDED; CUR-07, CUR-08 AND INTEGRATION/RELEASE GATES PENDING. DOCUMENTATION ONLY.**
