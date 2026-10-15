# D1 Family Primary Context P0 — business acceptance review #64

Date: 2026-10-15. **Status: candidate, not yet frozen; final exact-head CI and pull-request merge required.** Full D1 **OPEN**. All Migration 10 files remain non-executable `.sql.draft`; there was no hosted Supabase migration.

## Prior checkpoint and new operation

Merged frozen baseline [PR #63](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/63), `main` `6326f4a4ce923ca48647dec41a86d18b6254921e`: **63 suites / 2,831 business pgTAP assertions, 30/35 distinct D1 protected change operations**, plus 19 established observed-lock concurrency tests. This review concerns the first dedicated live authenticated acceptance of previously uncovered `family.primary_context.change`, implemented in **frozen Effect33**, with the direct P0 command `app.d1_change_family_primary_context(uuid,bigint,text,uuid,uuid,date,date,text,text)` and three allowed actions `SELECT`, `CORRECT`, `END`.

The change operation is a **display-context selector only**. It is not a family relationship creation, family membership, child-access entitlement, guardian/pickup authority, legal custody, financial responsibility or Foundation role grant. There is no approval workflow for this P0 baseline. The Student is the serialization/version anchor and must **not** receive a manufactured version bump merely because a primary display selection changes. A normal SELECT switch starts a new selection lineage (`supersedes_id IS NULL`), whereas a CORRECT factual repair must use `supersedes_id=source`.

## Source changes

[PR #64](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/64) adds:

- `supabase/tests/domain/64_family_primary_context_p0_select_correct_end.sql`: **37 pgTAP assertions** under BEGIN/ROLLBACK. The synthetic fixture provisions a verified active staff actor, its exact enabled `family.primary_context.change` ALL/DIRECT chain, two active Students, two distinct active Families and three pre-existing eligible relationship-history facts (Father, Mother and unrelated-Student Guardian).
- The **only** primary-context history mutations use authenticated `app.d1_change_family_primary_context`. No privileged direct `INSERT`/`UPDATE` to `app_private.student_primary_family_contexts`, no fabricated command receipts, no approval row fabrication, and no grants to authenticated on private tables.
- `tools/supabase/domain_business_ci.py`: registers suite #64, **37** assertions, retaining the first 63/2,831 suite prefix. Conditional candidate becomes **64 suites / 2,868 assertions / 31 of 35 operations**, with **four** D1 protected operations still without dedicated accepted suites.
- `tools/supabase/tests/test_domain_acceptance_ci.py`: enforces that frozen suite prefix, the 37 assertions and required representative SQL markers, and the prohibition on direct primary-history mutation or private-table grants.

## Invariants exercised

Under real `SET ROLE authenticated` command calls, the test checks:

1. Direct private primary-context SELECT is denied; non-authorized P0 call is denied even with the operation code enabled; a stale Student version, relationship for another Student and blank private reason are denied.
2. **SELECT** chooses exact eligible Father relationship, creates initial retained context, and returns unchanged Student version. An ambiguous second selection with no explicitly supplied source is denied; a same-relationship SELECT replacement is denied as a no-op.
3. A legitimate **SELECT switch** closes the exact source context and creates a new display selection into Mother with no factual `supersedes_id`.
4. An unbounded same-relationship **CORRECT** that would change nothing is denied; a real **CORRECT** back to Father's eligible relationship closes the Mother source and appends a factual successor pointing back with `supersedes_id`.
5. **END** closes the currently selected row at its exclusive end date, without inventing another context. Student version and state remain unchanged.
6. Same-key replay for original SELECT, switch, CORRECT, and END returns the exact original context UUIDs **even after later legitimate closure**. Reusing a key with a changed private reason is denied. All three retained intervals keep exact exclusive boundaries and server end actor/time.
7. There are exactly three retained context rows, four successful P0 command receipts and four `family.primary_context_changed` events. There is **no** family-child portal access, no relationship-row mutation and no Student-status change. Deferred constraints are explicitly checked with `SET CONSTRAINTS ALL IMMEDIATE` prior to rollback.

## Validation and bounded conclusions

Initial implementation head `e0a482a9fb7571d92fa076709cc634462b697743` triggered [D1 runtime #616](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38760606437), [Foundation #730](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38760606447) and [D1 static #226](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38760606452). **Static #226 passed**. D1 runtime and Foundation were still in progress when this review was drafted; **do not count new assertions as accepted until the runtime log confirms 37/37 and 2,868/2,868**. These documentation additions advance the PR head, so all three required checks must be green **on the final exact documented head** before merging.

Out-of-scope acceptance: genuine two-session same-Student competing SELECT/CORRECT/END, concurrent relationship END/CORRECT against primary context, granular CAMPUS/CLASS/SECTION scope isolation, live missing/ambiguous placement, archived Family SELECT vs after-archive END/CORRECT, initially bounded context and invalid relationship temporal containment, and portal-user impersonation. The established 19 prior true-lock races concern other Family and Employee operations and are not evidence of a new primary-context race. The four other incomplete D1 protected operations require separate readiness decisions; the Admissions-blocked Student create and disabled roll-policy change cannot be counted as completed by this suite.

## Acceptance gate

Do not mark PR #64 ready for review or merge until new suite #64 passes **37/37** and all **64/64 business suites / 2,868/2,868 assertions** in the disposable local stack, along with clean Foundation and D1 static/ACL/security guard checks **at the final HEAD**. Preserve original frozen Effect33 SQL; any genuine production code defect must be corrected only through an independent reviewed append-only inactive continuation and separate exact-head CI. No deploy, hosted change or live school data modification is authorized here.
