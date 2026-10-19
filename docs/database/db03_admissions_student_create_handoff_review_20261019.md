# DB-03 — Admissions design audit, decision register and review handoff

**Status:** DESIGN READY FOR REVIEW — product decisions SC-01…SC-07 remain OPEN. This is an independent-readiness handoff, not a frozen behavior or SQL-implementation approval.
**Repository:** yunusyosaf399/edusync_saas_school_app
**Pinned inspected main:** e526de3fd4668483623ef52cccc34d38d893c249
**Dedicated branch:** db/db-03-admissions-intake-design
**Domain:** Admissions only; no D1 command, Finance logic or shared integration edits.

## Source and current-state audit

AGENTS.md was read before requirements and implementation plans. Read master specification §§10–12,17–18,72.1; decisions/invariants, database guardrails, security/workflow/audit; existing D1 academic/Student/roll physical model #27, constraints #30 and concurrency #31; proposed Admissions design #79; Effect36 accepted disabled dependency #76; D1 P0 readiness #155; D1 acceptance #80 and database completion matrix.

At inspection, main was e526de3fd4668483623ef52cccc34d38d893c249 (not an assumed old baseline). Open [PR #100](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/100) owns DB-01 roll correction and must remain isolated. DB-02 owns school roll-policy decisions. The existing operation manifest still counts 36 D1 operations but student.create has no executable successful mutation; Admissions has no installed source handoff. Existing D1 Roll/Enrollment accepted operations do not constitute admissions intake.

## Material design discrepancies and proposed disposition

1. **Draft Person binding:** #79 requires application.person_id even for a DRAFT with unresolved identity. Proposed remedy: nullable draft binding or server-created provisional Person, requiring explicit SC-01 owner selection. Neither is frozen.
2. **Offers and exception history:** requirement specifies offers and optional stages, while #79 has no dedicated offer or approved required-stage exception entity. Proposed admission_offers and admission_stage_exceptions are candidates only, with no fee/identity override.
3. **Application state transitions:** #79 holds current projection and Foundation audit; proposed explicit admission_application_transitions preserves authoritative reasons and cancellation/outcome reconstruction.
4. **Fee clearance:** Finance typed FK/interface not installed. Keeping conceptual arbitrary UUIDs without verified Finance checks would forge admission acceptance. Finance-required handoff MUST deny until SC-03 is implemented and independently proven.
5. **Handoff/FK cycles:** #79 points application at handoff and handoff at application; need dependency-safe installation, deferred validation or removal of redundant pointer before physical freeze. A handoff does not reserve a D1 seat.
6. **Identity/capacity/roll race:** no cross-package locked consumption proof exists. D1 Student ID and roll remain distinct allocator domains. SC-04 and SC-06 owner contract plus D1/Finance review are blockers.
7. **Security registration:** #79 suggests commands/permissions/events/purposes but no approved deployment registrar, role/scope matrix, reviewer routing, retention or file classification. Do not silently alter D1 97/322/36 or Foundation tables.

## Decision review checklist

| Gate | Reviewer question | Required approval evidence |
|---|---|---|
| SC-01 | Is Person resolution mandatory at submission, and are stage/offer/exception requirements exactly defined? | signed policy state/evidence, identity source and offer/exception lifecycle |
| SC-02 | Is handoff final and single-use with valid terminal states/unique keys? | approved physical constraints, immutable payload, consumption receipt and cancellation rules |
| SC-03 | What is the real Finance bridge and reversal fence? | Finance-owned typed verification contract, reconciliation and reviewer evidence |
| SC-04 | Which accepted destination/roll effective date and capacity override/number namespaces? | reviewed D1 allocator and placement mapping; DB-01/DB-02 dependencies |
| SC-05 | Which typed D1 command input/result and replay/expected version shapes? | D1 owner-approved protected RPC contract, not implemented by DB-03 |
| SC-06 | Where exactly do Admissions/Finance locks fit D1 global order? | joint lock DAG, true concurrent winner/loser matrix and observed-lock test plan |
| SC-07 | Which authenticated end-to-end install/upgrade/security/race proof closes the package? | real Admissions-issued handoff fixture, positive and negative CI, independent review |

No recommendation in the design should be recorded as a frozen decision without explicit product-owner approval. New event codes, approval route and sensitive disclosures remain pending. Detailed 46-case positive/negative matrix, 12 observed-lock race scenarios and proposed migration ordering are in the design companion.

## Static/design validation and forbidden-change check

Design-only: no local/hosted SQL executed, no Supabase database accessed, no Migration 10 activation, no D1 Student create command or tests implemented. Proposed foreign keys, check constraints, indexes and functions are written as a contract; catalog and migration execution are future gates. This branch should add only these two DB-03 Markdown files. Do not edit AGENTS.md, central acceptance tracker, SQL draft fragments, Foundation or D1 migrations/tests, CI, workflow registration, Finance, DB-01 or DB-02 documents. A future PR review must diff against pinned base and recheck latest main before eventual merge.

**Decision:** DESIGN READY FOR REVIEW. Required owner decision: SC-01 through SC-07 and nested Admissions permissions/files/events/exception choices. No deployment and no implementation authority is implied.
