# DB01 + DB02 I05 — frozen draft-only combined PostgreSQL preview

**Integration-only, no owner branch edits and no production activation.**

Source parents are immutable: DB01 [draft PR #141](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/141) at `c8800dcfa8f2a4439c989f6d37bc25da611227d4`; DB02 [draft PR #147](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/147) at `2553e10a1848762f9865038c3efcfdf12b53585a`. This integration branch creates a **two-parent merge** and brings only DB02-owned docs, effects42–51, suites82–93 and its acceptance-unit additions onto the DB01 source. SQL fragments are **byte-for-byte from DB02**, with no rewritten School Policy behaviors or unexpected client EXECUTE grants. The three common test manifests are reconciled separately on this preview branch.

## Test ownership and measurable acceptance

- DB01 source tests #81–92 plus genuine authenticated P1 APPLY, multistep rejection, School-local correction, and real two-backend race drivers remain registered.
- DB02 test suites #82–86, #89–93 are registered under their **full distinct filenames**, not numeric prefixes. The DB02 original #92 and DB01 #92 must both run.
- Expected sum of registered domain pgTAP plans: **3,906 = DB01 3,686 + ten DB02-only suites totaling 220**. This is only a manifest prediction before real CI.
- Expected D1 catalog after applying draft effects: **577 functions, 559 definers, 162 app, 415 private**, with 34 FORCE-RLS relations, no forbidden anon/authenticated/service-role private EXECUTE. This is a computed union (**DB01 569 functions + DB02 8 net private definers**), not a passing observed count.
- Revalidate static, Foundation 220/220, D1 all suites, and all real PostgreSQL race markers on the **same integration SHA**. No earlier separate-workstream success constitutes this result.

## Release-blocked integration decisions

1. **DB02 policy REPLACE / DB01 correction:** The current DB01 `effect41_01` refuses an expired stored Roll policy; DB02 I04/I05 retains original current Roll allocations across revision cutover. Keep this fail-closed behavior; the owner must separately decide whether and how a legitimate later correction under a newly effective policy is possible. Do not silently assign a new policy UUID to historical Roll.
2. **DB02 I05 private-only cutover:** no protected authenticated DIRECT/APPROVAL, terminal receipt/audit/outbox, future Class Offering hook, independent non-author security signoff, or genuine two-backend CHANGE/CORRECT contention yet.
3. **DB03 P7:** approved Finance-authorizer clearance and one-shot Student creation handoff are not installed; no generated Roll during a mere application or submitted offer. Initial Roll is server-assigned at successful Enrollment P0 under owner Option A.
4. **DB04 CUR-06:** no automatic migration of elective history on actual Enrollment MOVE; Roll correction changes Student version but not Enrollment identity, selection sets or prior consumer-published snapshots. DB04 eight-table physical schema and Exams/Learning/Timetable signoffs are not installed.

## Merge/rollback

This draft integration head is **not** intended as a second deployable copy of either owner stack. Do not merge it into main along with its complete source ancestry; choose one reviewed integration ancestry after CI, independent DB01-11/security approval and user-authorized DB01-12. All Migration 10 fragments remain `.sql.draft` and Roll operations remain disabled outside ephemeral CI.
