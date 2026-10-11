# D1 Effect 30 — P1 Family relationship approval v1 replaced by active policy v2 before APPLY

Date: 2026-10-11
Verdict: **PASS — exact-source disposable local PostgreSQL acceptance. Full Domain Package D1 remains OPEN.**

## Exact accepted source and independent runtime evidence

- Previously frozen `main`: `608ced319a95474e37f29f269ebe2abb5e2b0621`.
- [PR #29](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/29) was **MERGED** as `9476b287a7b17b90fa508621d0c52e1205ca072c` from verified head `dffe7aa36019192e692384252734d65aa4de845b`. The two successful GitHub workflows checked out the exact PR merge-ref tree `08d21732fdf2e9c2a7691f33bee5e1eed1ab4091`, merging that head into that exact previously accepted base. The accepted main merge has those source parents.
- [D1 Migration 10 disposable runtime #234](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38130683950): **PASS**, including `D1C2A_PASS`; **981/981** D1 business pgTAP assertions across **23** suites, including **65/65** in new `23_family_relationship_p1_policy_replacement_stale_apply.sql`; **220/220** post-D1 Foundation regressions; **36/36** Python acceptance harness tooling tests; and unchanged **13/13** true two-session PostgreSQL races with an observed lock wait (3 Employee creation, 3 Family membership, 7 Family relationship). Both SQL lint levels PASS.
- [Foundation local stack #419](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38130683953): **PASS**, including **192/192** Python tooling unit tests, nine frozen Foundation migrations and nine test files, **220/220** SQL assertions, clean local reset and both lint levels.
- CI assembled and applied **202 inactive Migration 10 `.sql.draft` fragments** only on a disposable PostgreSQL local stack, with **34/34** forced-RLS domain tables, **540** finalized SQL functions (**522** SECURITY DEFINER) and no direct authenticated, anon or service_role access to private helper EXECUTE. Five Auth test fixtures passed. **No hosted Supabase database, deployed SQL or real school data was touched.**

## Existing frozen business rules and incremental gap

The finalized `app_private.d1_family_relationship_policy(p_student)` selects the single effective policy for a student's school/campus context. The existing `app.d1_apply_family_relationship_change` re-resolves the *current* policy at APPLY; its `policy_id`, `APPROVAL` route and affected Campus must continue to match the approved request's retained policy reference. When they do not, the request is invalidated with the typed code `D1_FAMILY_RELATIONSHIP_POLICY_STALE`. This checkpoint tests the stronger version-replacement case, beyond [PR #28](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/28)'s retired-policy-without-successor case: **a different policy is demonstrably ACTIVE and able to accept fresh requests, but must not inherit authorization over the old v1 approval.**

## Tested real-request scenario (65 pgTAP assertions)

1. Synthetic schema-owner setup enables accepted `family.relationship.change` and `family.access.approve` grants/scopes. A separate authenticated requester SUBMITs an eligible Family A Student A GUARDIAN ADD under original **ACTIVE** policy v1, `policy_key=d1-family-relationship-p1-approval`, with retained exact old policy ID `76000000-0000-4000-8000-000000000009`. It becomes **PENDING v3** and selects a **different real verified Person/Principal** with an active reviewer assignment and permission.
2. That real authenticated reviewer APPROVEs while v1 remains current. Old request becomes **APPROVED v4** with one immutable review and **no** Family history effects before APPLY.
3. Schema owner creates a genuinely new policy ID `76000000-0000-4000-8000-000000000011`, **revision v2** of the *same immutable policy key*, initially **DRAFT**. It adds the complete one-step `D1_REVIEWER_ROLE_SCOPE` template with the required active reviewer role while the original v1 remains ACTIVE. No frozen template, grant, request evidence, Student/Family version or old policy terms are rewritten.
4. The owner uses the Foundation-authorized `ACTIVE → RETIRED` transition on v1, followed by `DRAFT → ACTIVE` on v2 with required activation/effective timestamps. Tests verify exactly one current ACTIVE revision, one RETIRED revision, and that the already-approved request still pins **v1**. Reviewer and requester permission grants and ALL/DIRECT scopes remain live, the reviewer Principal stays ACTIVE, the old request remains APPROVED before APPLY, and Student/Family aggregate versions remain unchanged.
5. Authenticated original requester explicitly APPLYs the old approved request. It must return **INVALIDATED v5** with a **NULL relationship**, a single immutable `APPROVED → INVALIDATED` transition and rejected typed APPLY receipt `D1_FAMILY_RELATIONSHIP_POLICY_STALE`. Same idempotency-key replay returns the same terminal request/version/result; a new-key APPLY cannot resurrect it. Its real prior APPROVE review remains retained. No successful approval application, Family relationship, primary Family context, child-access entitlement, or `family.relationship_changed` success outbox event is produced.
6. **Positive control:** after activating v2, the same real requester SUBMITs a separate valid **Student B** Guardian ADD. That new request is **PENDING v3 pinned to actual v2 policy ID**, with an independently assigned real reviewer, who genuinely APPROVEs it to **APPROVED v4**. The second request is deliberately **not applied**; its review, both retained request records, five command receipts, and zero premature relationship/application/child-access/outbox mutation are checked. This proves the replacement policy is live and usable without allowing it to legitimize an old approval.

The suite is synthetic, rollback-only `BEGIN`/`ROLLBACK`, and does not require a real student identity or deployment. It never allows authenticated client sessions to SELECT raw `app_private.approval_requests`, `approval_reviews` or `approval_applications`: retained private history is inspected outside `SET ROLE authenticated` only. One Python unit guard enforces the suite plan, client ACL boundary, valid replacement setup and terminal rollback.

This is **not a new lock-race scenario**; the existing thirteen two-session observed-lock races are preserved unchanged.

## Changed files and continued release restrictions

Exactly three acceptance-only repository paths changed:
- `supabase/tests/domain/23_family_relationship_p1_policy_replacement_stale_apply.sql` (new 65-case pgTAP suite).
- `tools/supabase/domain_business_ci.py` (23rd D1 business suite registration).
- `tools/supabase/tests/test_domain_acceptance_ci.py` (new fixture structure and private-client ACL guard).

**No D1 domain SQL draft, executable migration, frozen Foundation, production RLS/permission grant, Flutter/UI, API or remote Supabase configuration was changed.** The **23-suite, 981-business-assertion D1C2A checkpoint is accepted and frozen at this exact source and merge**. The previously accepted **13/13** observed-lock two-session race checkpoint remains frozen.

**Still OPEN:** additional Effect30/31/32 authorization and approval shape combinations, Family portal checked read/field disclosure security, populated upgrades, other D1 business operations, Admissions/Finance and hosted activation. Migration 10 remains **202 unactivated `.sql.draft` fragments**; full D1 acceptance and deployment readiness remain OPEN.

**Checkpoint:** `D1_EFFECT30_P1_POLICY_VERSION_REPLACED_STALE_APPLY_PASS — 981/981 BUSINESS — 220/220 FOUNDATION — 36/36 D1 TOOLING — 13/13 OBSERVED-LOCK RACES — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.
