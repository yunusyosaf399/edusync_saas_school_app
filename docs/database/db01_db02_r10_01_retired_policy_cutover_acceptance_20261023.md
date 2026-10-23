# DB01+DB02 R10-01 — Retired stored Roll policy cutover compatibility acceptance

**Date:** 2026-10-23. **Status:** PASS for exactly scoped, rollback-only disposable SQL behavior; **DB01-10 overall RELEASE INTEGRATION BLOCKED**. Source tested at `973ae450654f3dcea745eb3e9eee3bb90291ecaf`, child [draft PR #150](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/150) stacked directly on combined [draft PR #148](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/148). Both original owner branches (#141 DB01 and #147 DB02) are unchanged. All SQL remains `.sql.draft`, not installed on hosted Supabase.

## Why this matters

A Student is enrolled and automatically assigned Roll **12001** under persistent revision 1. The School later replaces its Roll policy with academic-context revision 2 (new configured starting number **3000**). The first Student must **keep 12001 and its immutable source policy**, while a new Student may be assigned **3000** by the new academic allocator. The current DB01 source prelock does not allow rewriting an old-policy Roll after that source revision is retired. This is safe **fail-closed current behavior**, but staff may need a separately owner-approved lawful correction path; this test does not invent one.

## Actual test provenance

- New `supabase/tests/domain/94_db01_db02_retired_policy_cutover.sql` runs in a single `BEGIN`/`ROLLBACK` local pgTAP transaction, including `SET CONSTRAINTS ALL IMMEDIATE`. Shared synthetic `fixtures/command_actor.sql` and School/Campus/Class/Section/Year/capacity fixtures are inherited from the already-tested DB01 #84 protected initial P0 behavior.
- No allocation is inserted manually: `app.d1_place_student_enrollment` under real `SET ROLE authenticated` produces the old Roll at 12001 from the persistent pool.
- The **private** `app_private.d1_roll_policy_revision_transition` I05 function, called only as the trusted Student executor under rolled-back fixture permissions and global DIRECT policy, locks and replaces policy 1. New revision is 2, mode `ACADEMIC_CONTEXT`, stored `supersedes_id` references old policy and the academic Offering pool is created with next value 3000. No DB02 protected external API, receipt, event or production grant is inferred.
- Exact current old Student version, actual retained source Enrollment, old Roll ID, numeric value 12001 and original immutable policy UUID are passed to `app_private.d1_roll_correct_lock_source`. It returns `D1_ROLL_CORRECT_SOURCE_ROLL_STALE` **only after the genuine I05 source retirement**. Original Roll remains current, source pool retains previous high-water, Student version remains unchanged, and no synthetic corrected successor exists.
- Another Student is then successfully enrolled via `app.d1_place_student_enrollment` under `authenticated`, and receives automatically allocated initial Roll 3000 from policy 2; the new academic pool advances to 3001. The old Student still owns 12001. This confirms owner Option A for first Roll and no policy-retirement renumbering.
- Absence of a DB02 policy-change success receipt/event is asserted explicitly because I06 is not implemented. There is no temporary client privilege to the DB02 private transition; DB01 `student.roll.correct` stays disabled outside separately scoped acceptance fixtures.

## Verifiable exact-head CI evidence

| Gate | Exact-head result |
| --- | --- |
| [D1 draft static #39983838891](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39983838891) | SUCCESS |
| [Foundation local stack #39983838906](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39983838906) | SUCCESS |
| [D1 full disposable PostgreSQL #39983838895](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39983838895) | SUCCESS |
| `D1_BUSINESS_TEST_PASS 94_db01_db02_retired_policy_cutover.sql` | 23/23 |
| All combined domain suites | 3,929 assertions; DB01 P1 #92 113/113; DB02 I05 #93 29/29 |
| Foundation regression | 220/220 |
| D1 inventory | 267 draft fragments; 34/34 FORCE RLS; 577 functions, 559 definers, 162 app / 415 private; `auth_private=0 anon=0 service_role=0` |
| End-to-end DB01 race/decision markers | R0→R1→R2, observed APPLY/MOVE/END, P1 APPROVE/APPLY and first/second-step REJECT remain PASS |
| Final runtime | `D1C2A_PASS` |

The report only certifies this exact **tested source commit**. Later documentation-only commits require separate CI.

## Remaining product/security boundary

**NOT VERIFIED:** Protected authenticated DB02 policy-change implementation I06–I11; real two-backend DB02 REPLACE versus DB01 APPLY with observed waiting lock and both winner orders; lawful staff correction route from old stored policy after REPLACE; new Offering pool G02; DB03 Finance and Student handoff; DB04 installed elective histories/consumer snapshots; independent non-author security review; controlled migration upgrade/rollback and explicit user activation approval.

**Product question remains open:** Does EduSync permanently forbid manual correction to a retained Roll whose original policy is retired, or allow an explicitly bounded, approved correction under a new revision without falsifying the immutable original? Neither possibility is approved by this test. **Do not silently change DB01/DB02 policy SQL or enable operations.**
