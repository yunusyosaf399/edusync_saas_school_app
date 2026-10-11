# D1 Effect 30 — P1 Family relationship APPROVED before competing active policy overlap

Date: 2026-10-11
Verdict: **PASS — exact-source disposable PostgreSQL acceptance; full Domain Package D1 remains OPEN.**

## Exact accepted source and independent CI evidence

- Previous frozen `main`: `0ea1cec85f0eeec2056aebedf9a16e231f3a9c8d`.
- [PR #30](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/30) **MERGED** at `faa207bca5697abbdbea9baef53db3ed359da766` from verified head `f74d5b680329f74356997bea7324c180a8ba3a7c`.
- Both successful workflow jobs checked out the exact same PR merge-ref source `57a7c78adc5633cd55dc53fc511655cd7ec57816`, a merge of the tested head into the exact previously accepted base. The resulting main merge has the same source parents.
- [D1 Migration 10 local runtime #242](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38134284736): **PASS** with `D1C2A_PASS`, **1,058/1,058** business pgTAP assertions across **24** suites, including new `24_family_relationship_p1_approved_policy_ambiguity.sql` **77/77**; **220/220** post-D1 Foundation SQL assertions; **37/37** D1 Python tooling unit tests; unchanged **13/13** observed-lock two-session PostgreSQL concurrency races (3 Employee creation, 3 Family Principal Membership and 7 Family Relationship). Both SQL lint levels PASS.
- [Foundation local stack #425](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38134284729): **PASS**, **193/193** Python tooling tests, nine frozen migrations/nine SQL test suites, **220/220** SQL assertions, local reset and lint PASS.
- D1 assembled/applied **202 inactive Migration 10 `.sql.draft` fragments** on a disposable local stack only. Its catalog passed with **34/34** forced-RLS relations, **540** final functions (**522** SECURITY DEFINER), no authenticated/anon/service-role access to private-helper EXECUTE, and five valid synthetic Auth fixtures. No hosted Supabase deployment or real school data was altered.

## Existing frozen policy contract and acceptance gap

The finalized Effect30 resolver `app_private.d1_family_relationship_policy(student)` requires exactly one currently effective compatible school-wide policy in the Student's no-PRIMARY-placement context; two simultaneous ACTIVE school-wide policies cause the resolver to return **no route**. The already-approved `app.d1_apply_family_relationship_change` must recheck current policy identity, route, and campus at APPLY and terminally invalidate if no compatible unique selection exists, reporting `D1_FAMILY_RELATIONSHIP_POLICY_STALE`.

Previous accepted [PR #28](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/28) demonstrated retiring the original policy without a successor; [PR #29](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/29) demonstrated a clean v1 RETIRED / v2 ACTIVE replacement. This acceptance tests a distinct **v1 ACTIVE + v2 ACTIVE effective overlap** after an authentic v1 approval, and confirms post-ambiguity recovery cannot resurrect an invalidated request.

## Verified live-role workflow and 77 pgTAP assertions

1. A synthetic but **real authenticated requester** with the current exact `family.relationship.change` permission and matching ALL/DIRECT assignment SUBMITs a valid Student A/Family A GUARDIAN ADD under original school-wide **ACTIVE v1** `policy_key=d1-family-relationship-p1-approval`. Request retains its original policy ID and becomes **PENDING v3**.
2. A **different** authenticated Person/Principal with a valid reviewer role, `family.access.approve` grant and live ALL/DIRECT scope genuinely APPROVEs. The original request is **APPROVED v4**, with exactly one real immutable review and **no** premature Family relationship, child access or approval application.
3. Under the disposable schema-owner role, configure a separate **version 2** of the same immutable policy key, with its own ID and valid single-step reviewer template. While this v2 remains DRAFT, the original v1 remains ACTIVE. Activate v2 with required effective-from and activated-at timestamps **without retiring v1**.
4. Assert **two currently effective ACTIVE school-wide versions**, **zero RETIRED versions**, and unchanged requester/reviewer grants, assignments and scopes, reviewer Principal, original v1-pinned request in APPROVED state, and optimistic Student/Family versions. The overlap is genuine ambiguity, not an unrelated authority or state failure.
5. A new authenticated Student B SUBMIT attempted **during the ambiguous period** is rejected by the policy gate (`D1 Family relationship policy selects direct command`). No new request or accepted command receipt is stored; policy ambiguity cannot select either active revision.
6. Original authenticated requester explicitly APPLYs the previously approved v1 request. It returns **INVALIDATED v5** and a NULL relationship rather than EXECUTED; retains exactly one `APPROVED → INVALIDATED` transition and rejected typed receipt with **`D1_FAMILY_RELATIONSHIP_POLICY_STALE`**. Its earlier real review remains intact. Same idempotency key replays the terminal result and a changed APPLY key cannot reopen it. No approval application, relationship, primary-context history, child entitlement, `family.relationship_changed` success event or Student/Family business version change occurs.
7. **Non-retroactive recovery:** retire only competing v2. The original policy v1 becomes the sole eligible ACTIVE route again, but the old request remains terminally INVALIDATED with exactly one transition. An authenticated repeat using the original idempotency key after restoring v1 still returns INVALIDATED v5 with NULL result; a distinct-key attempt still cannot resurrect the terminal request.
8. **Positive control:** after restoring the unique original policy, the authenticated requester SUBMITs a fresh Student B ADD. It correctly pins active v1, becomes **PENDING v3** and selects a real independent reviewer. That reviewer genuinely APPROVEs to **APPROVED v4**. The fresh request is deliberately not applied. Exactly two retained requests and five legitimate command receipts remain with no premature relationship, child access, application or success outbox mutation.

The 77 assertions run inside **BEGIN/ROLLBACK**. Private workflow history is inspected only outside `SET ROLE authenticated`, and new Python acceptance unit coverage guards registration, plan, real overlapping v2 setup, typed policy-stale branch, idempotency and client private-table ACL boundaries. The test adds **no new race**; the previously accepted 13 true observed-lock two-session races remain independently verified and frozen.

## Change boundary and release restrictions

Exactly three test-only source paths changed:
- `supabase/tests/domain/24_family_relationship_p1_approved_policy_ambiguity.sql` — new 77-assertion local rollback-only pgTAP suite.
- `tools/supabase/domain_business_ci.py` — adds the 24th D1 business suite to the explicit manifest.
- `tools/supabase/tests/test_domain_acceptance_ci.py` — guards real ambiguity setup, rollback/plan, exact code and denied raw private workflow SELECT under authenticated role.

**No frozen Foundation migration/test, D1 production or draft SQL, RLS/grant, Flutter app, API, hosted Supabase project or real school record was changed.** The **24-suite, 1,058-assertion D1C2A disposable-local business acceptance checkpoint is accepted and frozen** at the verified source/merge. The earlier **13/13** true PostgreSQL two-session race checkpoint remains accepted.

**Still OPEN:** additional Effect30/31/32 policy, role/scope, Family-context and concurrency combinations, checked Family portal reads and field-level disclosure, populated upgrades, other D1 business operations, Admissions and Finance, Flutter/hosted activation. All **202 Migration 10 fragments** remain inactive `.sql.draft`.

**Checkpoint:** `D1_EFFECT30_P1_APPROVED_POLICY_AMBIGUITY_PASS — 1058/1058 BUSINESS — 220/220 FOUNDATION — 37/37 D1 UNIT — 13/13 OBSERVED-LOCK RACES — 202 DRAFT FRAGMENTS — FULL D1 OPEN`.
