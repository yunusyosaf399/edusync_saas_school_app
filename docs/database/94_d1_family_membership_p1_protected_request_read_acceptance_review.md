# D1 Effect 31 P1 participant-only request-read acceptance review

Date: 2026-10-09  
Verdict: **PASS — incremental D1C2A tested source only, hosted deployment not approved.**  
Pull request: [#14](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/14)

## Source and test provenance

- Exact merged candidate: `80efa53ec4936187fbbaea7370a0a507fbc5ac22` (second parent of merge commit `22cdb54ea2b0dd5d147f8e04914ae67f57d2f13d`). Baseline main before PR: `27ff8aa0c0fc7713aecb5acfae1b3b9c4ca318b7`.
- [D1 disposable runtime #150](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37945865983) **PASS**: **49/49** new Effect31 request-read assertions, **619/619** business assertions in **15** pgTAP suites, **220/220** Foundation regressions, **21/21** acceptance harness unit tests, and **6** two-session lock-observed races (three Employee, Family membership ADD/END/CORRECT). Local error and warning SQL lint **PASS**, local stack stopped.
- [Foundation local #353](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37945865940) **PASS**: frozen Foundation integrity and **220/220** assertions.
- [D1 standalone static #101](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37945865791) **PASS**: 198 non-executable draft fragments, 34 relations, 97 permissions, 322 scope alternatives, 36 operations, 540 final functions (522 SECURITY DEFINER) and zero client private helper EXECUTE. D1 local runtime also reports **34/34 forced-RLS** domain relations and 198 draft fragments applied only in a disposable PostgreSQL environment.

## Frozen security and read contract

`family.principal_membership.change` is an ALL-only, non-family-safe operation. The client-facing checked projection `app.d1_read_family_principal_membership_request(uuid)` is callable only by an authenticated role that resolves to a current Principal. A request row and its protected `reason` are returned only after current-authorization checks establish that the actor is the verified original **REQUESTER**, an assigned **OPEN_REVIEWER**, or an authorized **FINAL_APPROVER/DECIDED_REVIEWER**. Possessing an unrelated staff grant or subsequently acquiring a configured reviewer role does not make a principal a selected participant. Neither raw workflow tables nor private authorization helpers are exposed as general client read surfaces.

The rollback-isolated local suite `supabase/tests/domain/15_family_membership_p1_protected_request_read.sql` contains **49 pgTAP assertions**. Tests include:

- Current requester sees own PENDING/EXECUTED typed request, exact Family and Principal IDs/versions, effective date, action, and protected reason. Null/nonexistent request IDs return zero.
- Live selected reviewer sees the OPEN request, may independently APPROVE it and continues to see current-authorized APPROVED/EXECUTED status. A separately authenticated staff Principal with the same membership-change privilege cannot inspect another request. A late-assigned independently verified reviewer with the exact review role/scope is also denied without request assignment, both before and after approval.
- The verified FAMILY Principal is not a staff approval participant; it cannot read the workflow reason, even with its legitimate family-safe credential material. Anonymous execution is denied.
- Two rollback-only savepoints independently revoke the original assigned reviewer's current grant and the requester's current grant. Each actor immediately loses access to the protected request while the other authorized participant remains readable. Returning a real current grant restores visibility.
- Reads are side-effect free with respect to Family membership and child access; one explicit approved APPLY produces only its one expected Family event. A private reason remains absent from broad outbox payloads and authenticated users cannot query private request reasons, requested payload JSON or old snapshots directly.

## Defect, correction and precise privilege boundary

[First run #144](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37943868753) **FAILED** because the existing typed read RPC, owned by the NOLOGIN `schoolos_read_executor`, lacked SELECT/RLS visibility on the Foundation `approval_requests` table. After eight assertions, the first real participant read raised `permission denied for table approval_requests`. The issue was in trusted internal read wiring; granting raw client table access would have violated the frozen contract.

The append-only `supabase/migrations/20260928000000_domain_package_01_effect31_18_membership_checked_read_execution.sql.draft` corrects internal-only column SELECT/RLS for `schoolos_read_executor` and `schoolos_authz_reader`. Request/operation SELECT policies are limited to Effect31; step/review data are visible only to the private authorization reader. The existing `app.d1_read_family_principal_membership_request(uuid)` body was replaced without altering its signature, ownership, search_path, security-definer boundary or participant checks; the new SQL explicitly selects the request columns it needs instead of `q.*`. The temporary role's schema CREATE privilege is revoked after the replacement. **No exposed authenticated, anon or service_role table SELECT grant or RLS read policy was added.**

[Second run #148](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37945009933) applied/compiled all 198 drafts, passed Foundation and both lint gates, and executed all 49 assertions; **two failed** only because they assumed stricter column restrictions on the *trusted internal roles* than the existing architecture guarantees. The final correction tests the right trust boundary: raw protected snapshot and payload SELECT must be forbidden to the exposed **authenticated** client. [Final run #150](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37945865983) confirms those assertions and all other checks PASS. Previous failing runs are not claimed as accepted.

## Scope and remaining gates

The merged PR changes exactly three files: the new append-only Effect31 draft SQL continuation, the 49-assertion rollback-only business suite, and its D1 test-runner registration. It does not change frozen Foundation migration files, managed Supabase data, Flutter client, or production workers. All SQL draft fragments remain **non-executable** on hosted Supabase.

This closes one concrete participant-only request-read acceptance gap in **Effect31**, not the entire operation or D1 package. Alternate multiple/incompatible P1 policy selection, requester/reviewer concurrency or authority combinations beyond this fixture, checked Family portal reads, Effect30 primary replacement/multi-basis acceptance, populated upgrades, Admissions/Finance and other D1 operations remain **OPEN**. Do not enable student.create or claim migration/deployment readiness.

**Checkpoint: `D1_EFFECT31_P1_PROTECTED_REQUEST_READ_PASS — 619/619 BUSINESS — 220/220 FOUNDATION — 6/6 TWO-SESSION RACES — STATIC PASS — FULL D1 OPEN`.**
