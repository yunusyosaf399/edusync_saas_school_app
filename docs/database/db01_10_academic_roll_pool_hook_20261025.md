# Academic Offering lifecycle Roll pool hook — DB01-10 G02 candidate

The protected `app.d1_change_academic_offering` command now provisions a missing pool for the current School-local ACADEMIC_CONTEXT policy when it accepts an eligible Offering CREATE or UPDATE. The pool is part of the same transaction as the Offering, capacity revision, receipt, audit and outbox. An existing pool retains its original identity, creator, next value and row version. ARCHIVE and historical command replay preserve pools; no policy or a persistent policy does not invent an academic pool.

The schema-owner helper `app_private.d1_roll_policy_offering_pool` has PRELOCK and PROVISION phases. PRELOCK follows the current authenticated command identity and School lock, locks the current policy and an existing exact Offering pool before academic parent rows. The command locks Campus, Academic Year, Class and Offering, checks current Offering authority and intent, writes its accepted effect, then PROVISION checks the same-school ancestry and current academic policy. A missing pool with existing accepted allocations fails closed rather than reconstructing a lost counter. The helper is private, has a fixed search path, and grants EXECUTE only to the Academic executor. The existing School-local date resolver receives an internal schema-owner execution edge; no client role gains a private function or table grant.

Eligibility follows the I05 provisioning contract: School SETUP/ACTIVE, Class ACTIVE, Campus PLANNED/ACTIVE, Academic Year PLANNED/ACTIVE, Offering PLANNED/OPEN/CLOSED. OPEN with invalid ancestry fails. Zero capacity and no Sections do not exclude an otherwise eligible Offering. No manually entered initial Roll, lazy placement allocation, new permission/operation, Foundation change or hosted activation is introduced.

## Acceptance scope

- Suite 102: 59 assertions exercise protected CREATE after academic policy installation, private ACLs, original Offering lifecycle/replay/denial behavior, one pool at policy start, and retained counter high-water through OPEN/CLOSED/ARCHIVE.
- Suite 103: 12 assertions exercise an Offering created before policy installation, later OPEN provisioning, close/reopen counter preservation, historical CREATE replay, revoked authority denial and verified pool creator.
- Two genuine authenticated PostgreSQL races exercise Offering CREATE versus DB02 DIRECT REPLACE in both School-lock winner orders. An observed `pg_blocking_pids` wait is required. The final academic revision must have one pool for each of both eligible Offerings; the new Offering's counter is 7000 and the prior persistent counter stays 12002.
- Expected complete catalog: 599 functions, 581 definers, 167 app / 432 private, 34/34 forced RLS tables and zero forbidden private client EXECUTE. Registered domain assertions: 4,292. Python tooling tests: 380.

The exact tested commit and completed workflow proof are retained in draft PR #166 and issue #140. These expectations must not be treated as a PASS without that runtime evidence.

## Remaining gates

This candidate addresses the missing Academic command hook and its CREATE/REPLACE contention. It does not supply installed DB03 Student-create/Finance or DB04 Curriculum consumer handoffs, a populated hosted upgrade/rollback, independent Academic/DB02 owner approval or non-author security review. Those DB01-10/11/12 release gates stay open. All Migration 10 SQL remains `.sql.draft`.

## Verified code acceptance — 25 October 2026

**PASSED for draft disposable engineering.** Code SHA `f89d0e43abb28548526f7cf9bc16a098a406bd6e` on [draft PR #166](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/166) passed [static #40207434160](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/40207434160), [Foundation #40207434151](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/40207434151) and [D1 runtime #40207434141](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/40207434141). Runtime confirmed suite 102 **59/59**, suite 103 **12/12**, aggregate domain **4,292/4,292**, Foundation **220/220**, the exact expected catalog above, and `D1C2A_PASS`. Both `D1_ACADEMIC_ROLL_POOL_REAL_PG_RACE_PASS policy_first` and `... offering_first` report `observed_school_wait=true exact_pool=true`. This closes the missing hook implementation and these two race cases; the remaining release gates above remain open.
