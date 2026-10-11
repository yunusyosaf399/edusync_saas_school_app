# D1 Effect 30 — P1 Family relationship DIRECT v1 replaced by APPROVAL v2

Date: 2026-10-11
Verdict: **PASS — exact-source disposable local PostgreSQL acceptance. Full Domain Package D1 remains OPEN.**

## Accepted source and independently verified GitHub CI

- Previous frozen `main`: `9da685c82f3fbb6fce12da705898716145ae75ca`.
- [PR #32](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/32) was **MERGED** as `98d486e27bda015e6c628b91231cf7f62ebb55d2` from verified head `8d1a02cc106fa3d5c8604f663a5f1f8707e6b548`.
- Both successful GitHub workflow jobs checked out exact PR merge ref `dc8d5885ae99095ef2d580344b7e9d930e9792ec`, merging that same head into that same prior base; the final `main` merge has those source parents.
- [D1 disposable runtime #252](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38141516273): **PASS**, including `D1C2A_PASS`; **1,222/1,222** D1 business pgTAP assertions across **26** suites, including the new `26_family_relationship_p1_direct_to_approval_route.sql` **80/80**; **220/220** post-D1 Foundation regressions; **39/39** D1 Python tooling unit tests; and unchanged **13/13** true two-session PostgreSQL races with observed lock waits (3 Employee creation, 3 Family Principal Membership, 7 Family Relationship). Both SQL lint levels PASS.
- [Foundation local stack #433](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38141516133): **PASS**, **195/195** Python tooling tests; nine frozen Foundation migrations and nine test files; **220/220** Foundation pgTAP SQL assertions; clean local reset and error/warning lint passes.
- Disposable CI assembled and applied **202 non-executable Migration 10 `.sql.draft` fragments** locally only, with **34/34** forced-RLS D1 domain tables, **540** final functions (**522** SECURITY DEFINER), no authenticated/anon/service-role private helper EXECUTE, and the previously accepted five synthetic Auth fixture checks. **No hosted Supabase deployment, production schema or real school data changed.**

## Frozen route/replay contract under test

The finalized `app_private.d1_family_relationship_policy(student)` chooses exactly one currently effective P1 policy and route. The accepted `app.d1_change_family_relationship` **re-resolves the current route and requires DIRECT before it returns an earlier SUCCEEDED command receipt**. Consequently a successful DIRECT operation's history and receipt remain immutable after a policy switch to APPROVAL, but even a same-key replay through the DIRECT command API must then be **denied** (`D1 Family relationship requires approval request`) rather than bypassing the school's new reviewer requirement. This does not undo its historical accepted result.

The new `app.d1_submit_family_relationship_change` must instead select the current APPROVAL policy, genuinely assign and obtain an independent review, and later require an explicit `app.d1_apply_family_relationship_change`. PR #31 covered the opposite **APPROVAL→DIRECT** direction; this accepted PR verifies the distinct **DIRECT→APPROVAL** behavior, with current-role gates and a successful reviewed new change.

## Exact 80-assertion synthetic transactional scenario

1. A verified authenticated requester with live `family.relationship.change` grant and matching ALL/DIRECT scope starts with school-wide policy **DIRECT v1 ACTIVE** under `policy_key=d1-family-relationship-p1-approval`; there is no reviewer step for DIRECT, although an independent real Person/Principal reviewer and matching `family.access.approve` scope are fixture-provisioned.
2. The requester executes an actual **Student A / Family A GUARDIAN DIRECT ADD** with optimistic Student/Family version 1. This produces a real relationship ID, Student A version 2, Family version 2, one `SUCCEEDED` DIRECT receipt and one `family.relationship_changed` event; an identical request/key **while DIRECT is still current** replays that exact successful result with no second mutation.
3. A new Student B APPROVAL SUBMIT while v1 remains DIRECT is denied with `D1 Family relationship policy selects direct command`: zero fake P1 requests or receipts.
4. Schema owner configures policy **v2 DRAFT** of the same immutable key, with a separate policy ID, actual `APPROVAL` route and one complete reviewer step identifying a different Person/Principal and the live `family.access.approve` permission/scope. Supported transitions **v1 ACTIVE→RETIRED** and **v2 DRAFT→ACTIVE** establish a unique effective policy. Original DIRECT relationship/receipt, requester and reviewer grants/scopes and optimistic aggregate versions remain unchanged.
5. Under APPROVAL v2 the original DIRECT operation's same-key replay **fails closed** with `D1 Family relationship requires approval request` (rather than returning its earlier receipt). A new otherwise eligible Student B DIRECT command is denied by the same current-route check. The original `SUCCEEDED` receipt still points to the historical relationship; neither denied call creates an accepted receipt, relationship or outbox event.
6. Requester SUBMITs a fresh Student B / Family A Guardian ADD through the P1 API, using Student B v1 and Family v2. It correctly pins **current APPROVAL policy v2** and enters **PENDING v3**, selecting one genuinely independent reviewer, without applying any relationship or advancing either business version.
7. The separately authenticated reviewer genuinely **APPROVEs v4** and retains one immutable review, with zero relationship/application mutation. The authenticated requester then explicitly **APPLYs**, yielding `EXECUTED v5` and a distinct real Student B relationship ID; exactly one successful approval application and `APPROVED→EXECUTED` transition. Same-key APPLY replay returns the identical result and version without duplication.
8. Final assertions enforce exactly one preserved historical Student A DIRECT relationship and exactly one independently P1-applied Student B relationship, four legitimate operation receipts (original DIRECT, P1 SUBMIT, REVIEW, APPLY), **two** success events and no child entitlement or primary Family context. Student A remains v2; Student B advances only on APPLY to v2; Family advances precisely once per successful change, to v3. Original DIRECT policy remains RETIRED without rewriting its historic receipt.

The SQL is entirely bounded by `BEGIN` and `ROLLBACK` on a disposable stack. All private `app_private.approval_requests`, `approval_reviews` and `approval_applications` history checks are performed outside `SET ROLE authenticated`, with no client-side raw approval history exposure. The new Python tooling test guards the manifest, 80-case plan, real route change and receipt-gate distinction, rollback, grants/scope constraints and denied client private reads. The previous thirteen observed-lock concurrency tests are retained independently, not extended.

## Exact three-file boundary and continued release restrictions

- `supabase/tests/domain/26_family_relationship_p1_direct_to_approval_route.sql` — new **80/80** rollback-only pgTAP acceptance.
- `tools/supabase/domain_business_ci.py` — explicit 26th suite registration.
- `tools/supabase/tests/test_domain_acceptance_ci.py` — unit guard for route, receipt, permission and transaction boundaries.

**No domain/production SQL, D1 SQL draft, frozen Foundation migration/test, RLS/role/grant, Flutter UI/API or remote Supabase resource was changed.** The **26-suite, 1,222-assertion disposable D1C2A business checkpoint is accepted and frozen** at the tested head/merge; the prior **13/13 observed-lock** checkpoint remains frozen.

**Full D1 is still OPEN** for additional Effect30/31/32 policy, reviewer/target history and authorization combinations; checked Family portal reads and field-level disclosure; populated migration upgrade; other D1 business operations, Admissions/Finance and hosted Migration 10 activation. **202 Migration 10 fragments remain non-executable `.sql.draft`.**

**Checkpoint:** `D1_EFFECT30_P1_DIRECT_TO_APPROVAL_ROUTE_PASS — 1222/1222 BUSINESS — 220/220 FOUNDATION — 39/39 D1 UNIT — 13/13 OBSERVED-LOCK RACES — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.
