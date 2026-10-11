# D1 Effect 30 — P1 APPROVAL v1 to DIRECT v2 after real approval

Date: 2026-10-11
Verdict: **PASS — exact-source disposable local PostgreSQL business acceptance. Full D1 remains OPEN.**

## Accepted source, merge, and independently checked workflows

- Previously frozen `main`: `3036916e5569636925430a63272083a182922ef2`.
- [PR #31](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/31) was **MERGED** as `d70664a40cf3c3475ba301028e2ac890e487cbe2` from exact accepted head `b38ec3ec9f2511a083308374022363dd852404b2`.
- The two successful GitHub Actions workflows checked out the **same** PR merge ref `9a1ea081d0102f8c740c85de65b87191a4b9e4b0`, merging that exact head into that exact prior base. The actual main merge uses those source parents.
- [D1 Migration 10 disposable runtime #247](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38135061428): **PASS**, `D1C2A_PASS`, **1,142/1,142** business pgTAP assertions across **25** suites, including new `25_family_relationship_p1_approval_to_direct_route_stale_apply.sql` **84/84**; **220/220** post-D1 frozen Foundation assertions; **38/38** D1 Python acceptance unit tests; and the existing **13/13** genuine observed-lock two-session PostgreSQL races (3 Employee creation, 3 Family Principal Membership, 7 Family Relationship). D1 SQL lint warning and error gates PASS.
- [Foundation database local stack #429](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38135061411): **PASS**, including nine frozen migrations/nine test files, **194/194** tooling tests, **220/220** Foundation SQL assertions, clean local reset and both lint gates.
- D1 runner assembled and applied **202 inactive `.sql.draft` Migration 10 fragments only in disposable local PostgreSQL**; catalog checks found **34/34** forced-RLS D1 tables, **540** SQL functions (**522** SECURITY DEFINER), no direct `authenticated`, `anon` or `service_role` private-helper EXECUTE, and five synthetic Auth fixtures. **No hosted Supabase migration, production schema, or school data was changed.**

## Frozen domain boundary under review

The finalized `app_private.d1_family_relationship_policy(student)` resolves one compatible effective policy with its immutable ID and route. An existing real APPROVAL request pins the policy ID used at SUBMIT. Even after authentic independent reviewer APPROVE, `app.d1_apply_family_relationship_change` requires the *same current APPROVAL policy* on explicit APPLY, not merely a previously accepted reviewer signature. An otherwise eligible new DIRECT command `app.d1_change_family_relationship` is a **separate authorized operation** under a genuinely selected DIRECT route, with its own command receipt, target-version and idempotency checks. Changing v1 APPROVAL to v2 DIRECT cannot inherit, transfer or auto-execute the original P1 request.

PR #28 checked retirement without a successor; PR #29 checked a clean replacement by another APPROVAL revision; PR #30 checked overlapping active policy ambiguity. PR #31 independently verifies the distinct **route change from APPROVAL to DIRECT**, including negative gates on both sides and a valid separate DIRECT success.

## Exact scenario: 84 rollback-only pgTAP assertions

1. A synthetic, legitimately authenticated requester with live `family.relationship.change` grant and ALL/DIRECT assignment scope SUBMITs an eligible Student A / Family A GUARDIAN ADD under **ACTIVE APPROVAL v1**. Request is `PENDING v3` pinned to the exact policy ID; the selected reviewer is a **different authenticated Person and Principal** with real active reviewer role, `family.access.approve` grant and matching ALL/DIRECT scope.
2. That reviewer genuinely APPROVEs to `APPROVED v4` with exactly one immutable review and no automatic relationship, approval application or child-access mutation.
3. While policy v1 is still APPROVAL, the same real requester attempts a separately eligible Student B DIRECT ADD and is denied by `D1 Family relationship requires approval request` before a success receipt: the current original P1 route cannot be bypassed.
4. The schema owner creates a **different immutable policy ID, version v2, same policy key**, configured `DIRECT` and **zero reviewer steps**, while it remains DRAFT and original v1 remains ACTIVE. The owner then performs supported state transitions **v1 ACTIVE → RETIRED**, **v2 DRAFT → ACTIVE** with required activation/effective timestamps. Exactly one ACTIVE policy remains. The earlier APPROVED request still pins APPROVAL v1, while requester/reviewer permissions and scopes, reviewer Principal and optimistic Student/Family aggregate versions remain valid and unchanged.
5. Under current DIRECT v2, a new authenticated P1 SUBMIT for Student B fails with `D1 Family relationship policy selects direct command`. No second approval request or receipt is created. Thus the new current route is demonstrably DIRECT, not merely missing or ambiguous.
6. The original requester explicitly APPLYs the old fully APPROVED v1 request. It returns **INVALIDATED v5** and NULL relationship, with one immutable `APPROVED → INVALIDATED` transition and a **rejected** typed command receipt `D1_FAMILY_RELATIONSHIP_POLICY_STALE`. Original reviewer approval remains intact; same idempotency-key replay returns the same terminal result and a new-key APPLY cannot reopen the request. There is zero stale successful application, stale Student A relationship, primary context, child access, or stale success event.
7. **Positive DIRECT control:** on **different Student B** (still at optimistic version 1), the same authorized requester independently executes a fresh DIRECT ADD under the new ACTIVE v2 route. It creates exactly one Student B relationship, advances Student B and Family versions once to 2, retains its own `SUCCEEDED` receipt and one `family.relationship_changed` event. Its same-key replay preserves the exact result and versions; no new P1 workflow, reviewer or successful P1 approval application is fabricated, and no child entitlement or primary Family context is created.
8. **Cross-route isolation:** after that independent DIRECT business mutation, replaying the *original* obsolete P1 APPLY still returns `INVALIDATED v5` and NULL relationship rather than identifying the new DIRECT relationship. Student A version remains 1 and has no Family relationship. The genuine historical APPROVE review and rejected P1 receipt remain retained independently from the DIRECT success. Exactly four legitimate command receipts (old SUBMIT, REVIEW, rejected APPLY, separate DIRECT success) are present.

The suite runs `BEGIN` / `ROLLBACK` in the disposable stack, with no preloaded real school data. Private `app_private.approval_requests`, `approval_reviews` and `approval_applications` are inspected only under owner-role SQL **after** `RESET ROLE`, never as the authenticated client. The new Python harness unit test guards registry, plan, rollback, both route denials, exact typed stale reason and no direct client approval-table reads.

This suite is **not** a newly observed database lock race. The prior thirteen true two-session observed-lock cases remain accepted unchanged.

## Bounded source delta and continued release restrictions

Exactly three acceptance-only files changed:
- `supabase/tests/domain/25_family_relationship_p1_approval_to_direct_route_stale_apply.sql` — new **84** rollback-only assertions.
- `tools/supabase/domain_business_ci.py` — registers the **25th** business suite.
- `tools/supabase/tests/test_domain_acceptance_ci.py` — guards test plan and authenticated/private ACL boundaries.

No D1 Migration 10 SQL fragment or executable migration, frozen Foundation migration, production RBAC/RLS grant, application UI, API or hosted Supabase configuration changed.

**Accepted/frozen checkpoint:** **25 suites / 1,142 business assertions**, **220/220 Foundation**, **38/38 D1 tooling**, **194/194 Foundation tooling**, existing **13/13 observed-lock races**. **Full Domain Package D1 remains OPEN**, including further policy/authority and Family relationship-history combinations, checked Family portal reads and disclosure boundaries, populated upgrades, other operations, Admissions/Finance, and hosted migration activation. All **202** Migration 10 SQL fragments are still non-executable `.sql.draft`.

**Marker:** `D1_EFFECT30_P1_APPROVAL_TO_DIRECT_ROUTE_STALE_APPLY_PASS — 1142/1142 BUSINESS — 220/220 FOUNDATION — 38/38 D1 UNIT — 13/13 OBSERVED-LOCK RACES — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.
