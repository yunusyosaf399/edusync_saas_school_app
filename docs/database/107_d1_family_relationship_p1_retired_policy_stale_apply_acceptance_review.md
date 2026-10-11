# D1 Effect 30 — P1 Family relationship approval policy retired after APPROVE, before APPLY

Date: 2026-10-11
Verdict: **PASS — exact-source disposable local PostgreSQL acceptance. Full D1 remains OPEN.**

## Source and confirmed GitHub workflow evidence

- Previously frozen `main` source: `385bac0407695946ca2f4472ec50f649af7ab76a`.
- [PR #28](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/28) **MERGED** at `950d1f18eb584910cbb145ce015ab2496f560354` from the exact verified head `4364ab9ce65a6265a873aa9f127b3efddec2d0fe`.
- Both successful PR workflows actually checked out merge-ref `37502bc5c9ea25d668317de454123d3d7e346ec4`, merging the exact head into the exact prior base. This has the same source parents as the accepted merge.
- [D1 runtime #229](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38124389846) **SUCCESS**, including `D1C2A_PASS`. **916/916** D1 business pgTAP assertions across **22** suites; new `22_family_relationship_p1_retired_policy_stale_apply.sql` **43/43**; post-D1 frozen Foundation **220/220**; Python D1 harness **35/35**; existing **13/13** actual observed-lock two-session races (three Employee create, three Family Principal membership and seven Family relationship). Both local SQL lint gates PASS.
- [Foundation #415](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38124389849) **SUCCESS**: nine frozen migrations and nine test files, **191/191** tooling unit tests, **220/220** SQL tests, local reset and lint PASS.
- D1 runner assembled and applied **202 non-executable Migration 10 `.sql.draft` fragments** only inside its disposable local stack: **34/34 forced-RLS D1 tables**, **540** final functions, **522** SECURITY DEFINER, zero client-role/anon/service-role access to private helper EXECUTE, all five Auth fixtures accepted. No hosted environment or real school data was modified.

## Accepted frozen behavior and exact scenario

This suite adds new Effect 30 acceptance for a separate **APPROVE → policy RETIRED → APPLY** boundary. The previously accepted Effect31 membership suite covered policy staleness for shared Family Principal memberships, but had not directly exercised this Family *relationship* P1 apply path. The already-frozen `app.d1_apply_family_relationship_change` compares the currently resolved approval policy against the request's immutable selected policy before mutation; a missing/retired/mismatched policy invalidates the request with typed `D1_FAMILY_RELATIONSHIP_POLICY_STALE`.

A synthetic independent **real authenticated requester** uses a legitimate `family.relationship.change` permission and ALL/DIRECT assignment scope to SUBMIT an otherwise eligible Student A/Family A GUARDIAN ADD. It becomes `PENDING` version **3**, pins the actual active P1 policy ID, and selects one different authenticated Person/Principal holding a real reviewer-role assignment and `family.access.approve` with matching ALL/DIRECT scope. The different reviewer genuinely approves the request, reaching `APPROVED` version **4**, with exactly one immutable approval review but no relationship mutation.

The test owner changes **only the selected approval policy state `ACTIVE → RETIRED`**, which is a supported Foundation state transition; it does not backdate policy dates, forge approval rows, revoke requester/reviewer permission grants or scopes, or advance Student and Family business versions. The retired policy, still-APPROVED request, live reviewer Principal and both unchanged role grants/scopes are explicitly asserted before APPLY.

An authenticated requester executes `app.d1_apply_family_relationship_change(request_id,4,key)`. All **43** rollback-only pgTAP assertions pass, demonstrating:

- Explicit APPLY returns request `INVALIDATED`, version **5**, with the same request identity and **NULL** result relationship; it does not execute an already-approved request after its original approval policy is retired.
- Exactly one immutable `APPROVED → INVALIDATED` transition records the policy-stale typed reason. The **rejected** APPLY command receipt's `error_code` is exactly `D1_FAMILY_RELATIONSHIP_POLICY_STALE`, rather than a reviewer or requester authorization code.
- The previous genuine review is retained. A **same-key** replay returns the same terminal result/version and null relationship, and a different-key apply cannot reopen the already invalidated request. One SUBMIT, one REVIEW and one APPLY receipt exist with no duplicate success.
- There is **no** approval application, new Family relationship, Student primary-family context, child entitlement or `family.relationship_changed` success outbox event. Student and Family optimistic business versions remain unchanged, and the originally selected policy stays retained as RETIRED.
- No raw `app_private.approval_requests`, `approval_reviews` or `approval_applications` read runs under `SET ROLE authenticated`; independent test-owner SQL validates retained private evidence after `RESET ROLE`.

This validates an ordinary sequential stale-policy workflow rather than a concurrency race; the previously frozen **13** observed-lock races remain separately accepted.

## Changes and release boundary

Exactly three acceptance-only files were added/edited:
- `supabase/tests/domain/22_family_relationship_p1_retired_policy_stale_apply.sql` — 43 rollback-only SQL assertions.
- `tools/supabase/domain_business_ci.py` — register new test suite and planned assertion count.
- `tools/supabase/tests/test_domain_acceptance_ci.py` — enforce fixture registration, rollback, policy-only mutation boundary and no raw private workflow history reads as authenticated client.

**No production/D1 SQL draft, Foundation migration/test, RLS authorization rule, database grant, Flutter/UI, API or hosted Supabase deployment was changed.** The **22-suite, 916-assertion D1C2A business checkpoint is accepted/frozen** at the above verified tree and merge. The prior **13/13 observed-lock race checkpoint remains accepted**.

**Still OPEN:** other Effect30/31/32 policy, permission, replacement and concurrency combinations; Family portal checked reads and field-level disclosure; populated migration upgrade; Admissions/Finance and untested D1 operations; hosted deployment and active executable Migration 10. All **202** Migration 10 fragments remain unactivated `.sql.draft`.

**Checkpoint:** `D1_EFFECT30_P1_POLICY_RETIRED_STALE_APPLY_PASS — 916/916 BUSINESS — 220/220 FOUNDATION — 35/35 D1 UNIT — 13/13 OBSERVED-LOCK RACES — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.
