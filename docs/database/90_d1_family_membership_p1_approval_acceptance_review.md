# D1 Family shared-Principal membership P1 approval — independent acceptance review

Date: 2026-10-09  
Verdict: **PASS — incremental D1C2A business acceptance only. Full D1 release/operation acceptance remains OPEN.**

## Exact source and GitHub Actions

- [PR #10](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/10) was based on `49413136a88a27644e85aca06f6d88f9c8f0a861` and merged as `48fffee75ac31ec8377235201994b473bec5d28e`; verified tested source is second parent `24f1839564e89f8be32b243d816c1940d5f34ce7`.
- [D1 disposable local runtime #124](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37928235969): **40/40 new P1 assertions**, **450/450 D1 business** across twelve suites, **220/220 Foundation regressions**, **3/3 observed-lock Employee-create races**. Local disposable application of **197 non-executable Migration 10 draft fragments**, **34/34 forced-RLS relations**, 540 final functions (522 SECURITY DEFINER), zero authenticated/anon/service_role private-function EXECUTE exposure in catalog probe, both lint levels PASS.
- [D1 static #95](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37928235911): **PASS**, unchanged **97 permissions / 322 scope alternatives / 36 operations**, 34 relations, final-function owner and signature checks, frozen Foundation source.
- [Foundation #331](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37928235928): **PASS**, 9 frozen migrations/tests, 220/220 pgTAP. No managed school/staging/production SQL executed.

## Reviewed six-file runtime/test delta

1. `supabase/migrations/20260928000000_domain_package_01_effect31_03_membership_evidence_reviewers.sql.draft`: authz-reader candidates and live-review helpers select only the exact request/step columns needed instead of `SELECT *`; reviewer/Person separation and exact ALL-only staff authority preserved.
2. `supabase/migrations/20260928000000_domain_package_01_effect31_05_membership_direct_submit.sql.draft`: submit snapshot derives `source_effective_from` from its locked typed preflight; ADD receives NULL safely rather than referencing an unassigned `src` record. END/CORRECT retain source ancestry/date binding.
3. `supabase/migrations/20260928000000_domain_package_01_effect31_06_membership_review_apply.sql.draft`: restrict approval-application evidence SELECT to trusted workflow executor with operation-only RLS and five explicit columns; keep live requester authority on accepted SUCCEEDED replay, but do not revoke immutable REJECTED/INVALIDATED replay to an independently authorized final reviewer solely due to requester revocation. Fresh approved application still revalidates the requester and invalidates without domain mutation when stale.
4. `supabase/migrations/20260928000000_domain_package_01_effect31_08_membership_read_acl.sql.draft`: participant authz-reader uses column-limited request projection; separate checked-read executor remains unchanged.
5. `supabase/tests/domain/12_family_principal_membership_p1_approval.sql`: **40 rollback-isolated pgTAP assertions** for ready SHARED FAMILY credential without child access, ALL-only staff authority, independent reviewer, direct bypass/self-review/revoked-reviewer denial, SUBMIT→APPROVE→later APPLY, receipt and application replay, reviewer REJECT, stale-requester INVALIDATED receipt and replay, event deduplication, and anonymous/private read denial.
6. `tools/supabase/domain_business_ci.py`: adds twelfth suite with 40 planned assertions; raises expected business aggregate from 410 to 450.

No frozen Foundation SQL/tests, general workflow grants, client authenticated private-table SELECT, Flutter, worker activation, or managed Supabase deployment changed.

## Failure-and-correction evidence

- On unverified original candidate `6ec3408a29206b549eb2d730dd7b74589f87a090`, [runtime #122](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37927839076) failed after the first **6/40 assertions without mismatches** during valid P1 ADD SUBMIT: PL/pgSQL unassigned `src` record while building `old_snapshot`. All previously accepted **410/410** business tests and **220/220** Foundation regressions continued to pass; static #93 and Foundation #329 passed.
- The exact root-cause patch in `24f1839564e89f8be32b243d816c1940d5f34ce7` removes the unnecessary record dereference and binds to locked `pre.source_effective_from`. Subsequent exact-source runtime #124, static #95 and Foundation #331 all passed. Do not conflate the failed original SHA with the passing corrected SHA.

## Accepted boundary and next remaining gates

This acceptance confirms **Effect 31 membership P1 ADD success, END request REJECT and stale-requester INVALIDATED terminal replay**; it does **not** cover every END/CORRECT successful application, alternate policy layouts, multi-step review chains, concurrent membership changes, or all request participant checked-read disclosure surfaces. Independent Effect 30 alternate relationship basis/primary replacement/scope and concurrency tests, Family portal reads, wider domain operations and populated upgrade still require separate acceptance. `student.create` and Admissions/Finance handoff remain disabled/unaccepted. Migration 10 is still **197 `.sql.draft` fragments**, unauthorized for hosted application.

**Result: `D1_FAMILY_MEMBERSHIP_P1_PASS — 40/40 NEW — 450/450 D1 BUSINESS — 220/220 FOUNDATION — 3/3 EMPLOYEE RACES — FULL D1 OPEN`.**
