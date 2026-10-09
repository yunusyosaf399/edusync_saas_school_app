# D1 Effect 31 P1 competing membership and stale apply — independent acceptance review

Date: 2026-10-09  
Verdict: **PASS — incremental D1C2A local runtime acceptance; full D1 release remains OPEN.**

## Frozen operation and test coverage

The tested operation `family.principal_membership.change` is non-family-safe, ALL-only, and P1 DIRECT/APPROVAL according to exactly one compatible effective policy. The APPPROVAL route requires an independently authorized INDIVIDUAL reviewer (different Principal and Person) holding the configured role and live `family.access.approve` ALL/DIRECT chain. An approved request does not apply automatically. At explicit APPLY, current policy, requester, reviewer, Principal/Family version and membership history must be rechecked.

This increment proves:
- **Separate approved competing ADD intents:** before application two SUBMIT/APPROVE sequences each leave membership untouched. A successful first explicit APPLY creates one retained membership and approved application; the second revalidates against current state and becomes INVALIDATED, with a typed rejected receipt and replay, no second application or domain event.
- **Target Principal version becomes stale:** after an END request is approved, the shared FAMILY Principal is suspended; its server-owned row version advances. Explicit apply INVALIDATES the stale request, preserving the open membership and avoiding a success event. The immutable rejected receipt replays and carries a typed `D1_FAMILY_PRINCIPAL_MEMBERSHIP_PRINCIPAL_VERSION_STALE` reason.
- **Policy lifecycle becomes stale:** after approving an END request, retire its P1 policy via permitted Foundation `ACTIVE→RETIRED` transition in a rollback-only SAVEPOINT. APPLY invalidates the request and cannot write membership history. The savepoint restores the policy for subsequent independent tests, without illegally changing activated effective terms.
- **Reviewer loses authority:** after approving an END request, revoke the reviewer grant. Requester APPLY invalidates due to `D1_FAMILY_PRINCIPAL_MEMBERSHIP_REVIEW_AUTHORITY_STALE`; rejected receipt replay remains valid for currently authorized requester, with no application or domain event.
- **Real two-session competing APPLY:** create two P1 requests, approve independently, then use two PostgreSQL sessions with different command keys. The first holds transaction locks, the second is observed waiting. On release one commits EXECUTED and the other commits INVALIDATED. Verify exactly one membership row, one immutable approval application and one domain outbox event, six typed family operation command receipts, zero child entitlements. This is an actual observed lock race, not just sequential calls.

The work does not claim all END/CORRECT conflict races, all requester/scope revocations, competing multi-step policies, checked-request participant disclosure, or cross-campus Family portal acceptance.

## Exact-source GitHub evidence

- Trusted base: `14c6856725cc3cbc1d74f444ea36fe0a15235bd7`.
- [PR #12](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/12), exact accepted source: `8cceeb6abe1b0a993de24f0eb4e0d53b2da68680`; verified merge commit `4adef8896cfdcd30ba4403620389702de1823975`.
- [D1 local runtime #138](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37933351755): **PASS**, 35/35 new `14_family_membership_p1_stale_conflicts.sql`, 570/570 D1 business assertions across fourteen suites, 220/220 Foundation regressions, **3/3 Employee observed-lock races**, **1/1 actual two-session P1 Family ADD race** with observed lock wait, one applied and one invalidated request and no duplicate domain effects. Local disposable Postgres only.
- Local source validation locally assembles/applies all **197** non-executable Migration 10 fragments, validates **34/34 forced-RLS relations**, **540** final functions (**522 SECURITY DEFINER**), and private function/table access probes; both warning and error lint gates pass.
- [Foundation #342](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37933351671): **PASS**, frozen migrations/tests unchanged, 220/220 regression assertions.
- Path-filtered D1 static workflow **did not trigger** on test/harness-only changes. Frozen static SQL inputs remain byte-identical to [D1 static #95](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37928235911), which passed. Do **not** claim a new exact-SHA standalone static run.

## Test-only diff and independent failure review

1. **NEW** `supabase/tests/domain/14_family_membership_p1_stale_conflicts.sql`: rollback-only P1 competing ADD and target/reviewer/policy stale-apply pgTAP; 35 checks.
2. **NEW** `supabase/tests/domain/fixtures/family_membership_race_setup.sql`: disposable authenticated staff, live reviewer, shared FAMILY credential and two separately approved conflicting requests, reconstructed in a new transaction after the Employee races.
3. **MODIFIED** `tools/supabase/domain_business_ci.py`: register fourteenth 35-assertion suite; business gate becomes 570.
4. **MODIFIED** `tools/supabase/domain_concurrency_ci.py`: launch actual two-session P1 APPLY race with an observed lock wait, verify one EXECUTED/one INVALIDATED and immutable receipt/approval/member/event cardinality; preserve existing three Employee race checks.

Earlier source attempts are **not** considered accepted:
- [D1 runtime #132](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37932437586) and [#134](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37932487177): 21/35 new checks passed before synthetic policy test illegally attempted to rewrite activated policy's frozen `effective_until`; Foundation correctly denied it. Replaced by valid ACTIVE→RETIRED in a rollback-only savepoint.
- [D1 runtime #136](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37932888955): **35/35 new**, 570/570 overall, 220/220 Foundation and 3/3 Employee races passed, then separate Family race setup failed because previous transaction's JWT claims were intentionally transaction-local. Test fixture now rebinds verified request claims before protected setup DML.
- [D1 runtime #138](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37933351755) passed on final exact SHA, including the real P1 race. No production code/security grants were changed to accommodate fixture issues.

## Accepted boundary and remaining gates

**No D1 SQL draft, Foundation migration/test, RLS permission contract, client API, Flutter code or managed/hosted database was changed.** This is acceptance coverage of one ADD competition race plus selected P1 stale-target/reviewer/policy checks, not full operation acceptance or permission to deploy. Remaining: multi-actor END/CORRECT races, conflicting historical lineage, participant checked reads, multi-step/incompatible policy and cross-campus scope, Effect30 relationship primary/basis/concurrency, broader Family portal, Admissions/Finance, populated upgrade and other unaccepted D1 operations. Migration 10 remains **197 `.sql.draft` fragments**.

**Checkpoint: `D1_EFFECT31_P1_STALE_RACE_PASS — 35/35 NEW — 570/570 BUSINESS — 220/220 FOUNDATION — 3 EMPLOYEE RACES + 1 FAMILY RACE — FULL D1 OPEN`.**
