# Section 03 / DB-03 — Student creation dependency audit (2026-11-01)

**Decision: NO-GO / source-only readiness.** This document does not implement, authorize, or enable `student.create`. It records a snapshot of the **31 open draft PRs** checked against GitHub on 2026-11-01, in the machine-checkable companion `section03_db03_student_create_handoff_gate_20261101.json`. Recheck live PR heads before any future merge or release; these IDs/SHAs are an audit snapshot, not live assertions.

## Remaining workstream owners (31 open drafts at audit)

| Owner / area | Open PRs | Count | Treatment |
|---|---|---:|---|
| DB01 Roll Correction design | #100 | 1 | Separate design branch; Git history diverges from #168, do not close by ancestry alone |
| DB03 Admissions / DB08 Finance root | #102 | 1 | Authoritative source chain root; preserve |
| DB04 Curriculum | #103 | 1 | Independent curriculum owner and Student subject-consumer gate |
| Student Photo | #120, #135 | 2 | Separate document/storage/private API security work |
| Consolidated DB01/DB02/Section03 | #168 | 1 | Draft, not merged to `main`; Student creation remains disabled |
| DB03 / Finance incremental candidates | #175–#196, #199, #202, #203 | 25 | Stacked and partly parallel DB03/Finance work; no final handoff proven |
| **Total** | | **31** | **0 production GO approvals** |

**Precise current integration:** PR #168 head `695c883904770e4fc5c7e31e185eb177afefd043` includes Section03 PR #208 and the earlier DB02 113-suite/4,315-assertion candidate. Its code was CI-green at PR #208 SHA `f0a5c996eb71c23466afd7d6771b580363bd21f4`; do not mistake previous CI for independent DB03/DB04 final-handoff acceptance.

**Precise DB03 source:** PR #203 head `fabaaeb871874107db28346ef4db688eb34e837e` extends #202 (fee dispositions), which extends #199 (one open application/verified Person). GitHub DB03 inactive policy draft run #41293808863 passed, including `DB03_FORWARD_READINESS_DATABASE_PASS 12/12; Principal_decision_unavailable=true`. DB03 principal snapshot PR #191 passed structural checks with `can_finalize=false`. These checks do **not** prove a Principal final decision, a READY/CONSUMED handoff, or Student creation. The DB03 branch and #168 histories diverge; do not merge their SQL catalogs directly or treat the independent runs as a single accepted stack.

## One Student creation — the required sequence

An administrator may save an incomplete DRAFT and later record a grade destination, private required birth/leaving certificates and a receipt-backed admission-fee disposition. Once current requirements are available the school administrator may **Forward** to the Principal. Forward does not approve admission. A Principal alone must approve or return/reject following revalidation of the latest original documents, assessment/test rules and current Person, School/Campus/Year/Class/Section context.

At final approval the future *one protected transaction* must lock/recheck the exact authoritative Admissions application and Principal decision and either produce one valid single-use final handoff consumed by D1 in the same transaction, or implement the same atomic guarantee without an exposed reusable token. It must then bind/create the verified Person, create exactly one Student and immutable School Student ID, allocate an admission number and initial PRIMARY Enrollment/Roll under DB01/DB02 School→policy→pool and academic locks, retain private certificate lineage, and emit one minimal idempotent receipt/audit/outbox. A failed gate or concurrent cancellation must leave **no** accepted partial effects. Same-key replay returns the exact Student; changed-intent replay denies.

The admission-fee administrative statuses are **SKIPPED**, **MARKED_PAID**, and **UNPAID**. `UNPAID` does not by itself block Forward or Principal approval under the 2026-11-01 owner decision. `MARKED_PAID` is only a staff declaration, **not** a bank settlement or Finance clearance. A separate configured positive Finance clearance, where required by a different charge policy, must be independently verified; this document never forges payment or waives tuition. `FAILED` assessment cannot be bypassed; any approved administration test-skip needs separate authorized reviewer/effect.

## Exact seven stop gates

| Gate | Missing integration proof |
|---|---|
| SC-01 | Final approved Admissions outcomes and current canonical Person/identity evidence |
| SC-02 | Principal final APPROVE/RETURN/REJECT and durable one-time acceptance/handoff contract |
| SC-03 | Current receipt-backed fee disposition plus any independently required Finance reconciliation |
| SC-04 | Real atomic Student + number + initial Enrollment + Roll + document lineage across owners |
| SC-05 | Enabled authenticated `student.create` protected command with permission, replay and evidence |
| SC-06 | Genuine two-backend Principal/Admissions/Student/roll policy and authority races, including rollback |
| SC-07 | Positive accepted handoff + deny/replay tests, non-author security review and release readiness |

Every gate is **BLOCKED** in the adjacent JSON. There is no safe inference from #203 `can_forward` to final acceptance or `student.create`. The existing DB01/DB02 roll allocation acceptance proves its own subsystem, not the missing Admissions join.

## Next owner-isolated implementation order

1. **DB03 owner:** finish a Principal final decision/return/reject contract and current source invalidation; keep #203 Forward readiness distinct. Resolve stage outcome issuer, independently approved test-skip, original-file review and current Person binding before declaring final eligibility.
2. **Joint DB03+D1 contract review:** decide exact consumed-once handoff identity/version, Principal authority, lock ordering (including future School Roll policy REPLACE), and idempotent rollback semantics. This requires explicit owner coordination; no implicit client-side gate.
3. **D1 owner:** implement `student.create` only after source contracts are installed/approved and prove a real successful authorized intake. Retain existing `supabase/tests/domain/65_remaining_student_commands_fail_closed.sql` while disabled; do not disguise deny-only tests as completed Student creation.
4. **Independent acceptance:** add positive/negative Auth fixtures and genuine two-session races, cross-domain Section03/DB04 consumer acceptance, SQL security review and controlled staging upgrade/rollback before any final merge/hosted release decision.

**Scope of this increment:** documentation plus source-level guard only. No SQL migrations, new public RPCs, permission changes, family access grants, financial settlement, `main` merge, hosted activation or deployment. Full CI on this audit branch will validate only the D1 candidate still passes with its protected Student-create operation disabled.

**Sources at snapshot:** root DB03 #102; DB03 Principal source #191; stage outcome #194; drafts #199/#202; Forward #203; D1 `docs/database/155_d1_student_create_admissions_handoff_contract_readiness.md`, `supabase/tests/domain/65_remaining_student_commands_fail_closed.sql`, and merged PR #208 on Draft #168.
