# DB-01 — APPROVAL APPLY application provenance: third guarded integration increment

**Prepared 2026-10-19, DB-01 owner-authorized contract, implementation proposed NOT activated.** This ChatGPT DB-01 workstream directly owns this documentation and the staged SQL PRs; Codex is not involved. Product RC-01…RC-08 were approved in [DB-01 contract v1](db01_student_roll_correct_owner_approved_contract_20261019.md). **DB-02 RP-02/03/07 School-local T-B policy compatibility and D1 MOVE prelock remain independent unsigned dependencies.**

## 1. Cumulative implementation stack and reviewer boundaries

1. [#106](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/106) retained historic PS allocation and END prelock; [#107](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/107) non-self Roll lineage CHECK.
2. [#109](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/109) strict original 12-field retained R0→R1 verifier; owner `schoolos_student_executor`, suite #77 **30/30 exact-head PASSED**, 3,196 D1 assertions (previous verified HEAD `7e2ac543a34ac42a08ed7a1c4096ebae6a15516b`).
3. [#111](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/111) second **DIRECT only** provenance function: original SUCCEEDED receipt bound to actor/key/hash, R0→R1, unique audit/outbox. Runtime discovered Student executor cannot read Foundation `command_receipts`, evidence writer cannot SELECT `outbox_events`. Chosen security-preserving repair is schema-owner private read-only verifier with Student-owned row-proof narrowly EXECUTE-delegated to schema owner; **no broad table grants**, explicit negative EXECUTE checks. Suite #78 now **24** structural/ACL assertions, and **all three workflows PASSED at exact PR #111 HEAD** `7836270c9772a658ba14c6205e0ae078a67f95a3`: 24/24, 3,220 total business assertions, catalog 544 functions / 526 definers / 387 private, no client-private/anon/service-role EXECUTE. That is synthetic structural proof, not an authenticated CORRECT command.
4. [#113](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/113) third proposed **APPROVAL application evidence** increment, stacked on #111, distinct [integration owner issue #112](https://github.com/yunusyosaf399/edusync_saas_school_app/issues/112). Do not conflate #112 with previous #108/#110 owner signoffs. PR remains DRAFT/unmerged, no operation enablement.

## 2. Third gated SQL effect

New `supabase/migrations/20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft` defines
`app_private.d1_roll_correct_application_receipt_guard() RETURNS trigger`, owned `schoolos_schema_owner` and attached as BEFORE INSERT to existing `app_private.approval_applications`. It short-circuits without side effects for all operation IDs except `student.roll.correct`; **does not modify generic Foundation approval schema or existing D1 handlers**.

For a correction it denies application insertion unless all of the following match:

- The request is `EXECUTED`, targets an exact Student ID and has approved requester-bound reason, stored target version and **nine-key** canonical source `old_snapshot` identifying exact Enrollment, Section, Roll, revision, old number, dates and origin.
- The request's `requested_payload` has exactly one proposed bigint value, equal to the actual successor numeric.
- The retained command receipt is `request.apply`, `SUCCEEDED`, `D1_STUDENT_ROLL_CORRECT`, has exactly the **14-key** APPROVAL result (12 base R0→R1 keys plus `request_version`, `state=EXECUTED`), matching source and intended target version and corrected Roll UUID.
- It delegates immutable predecessor/successor validation to #109's already gated Student-owned helper, granted to schema owner by **narrow function EXECUTE only**.
- The corrected successor's **restricted `correction_reason` matches** the original approved request reason exactly. There is at most one successful receipt referencing that successor. The selected request has one or more `APPROVED` steps, each with one `APPROVE` review bound to an assigned reviewer with a **different real Person** from the requester.

**Important gaps / not implied:** This trigger is not an authenticated APPLY command; it cannot by itself prove **current** requester/reviewer grant freshness, live ACS scope, selected latest policy as-of School-local date, race-safe source and destination locks, or idempotent approved-request execution. These belong in the future protected SQL RPC. It also does not yet enforce a dedicated immutable APPLY success audit/outbox chain (separate evidence gate). A forged privileged fixture does not prove actor authorization.

## 3. Strict catalog/privilege delta

The stacked third increment proposes exactly `functions 544→545`, `security_definers 526→527`, `private_functions 387→388`; `app_functions=157`, `authenticated_app_execute=157`, `authenticated_private_execute=anon_execute=service_role_execute=0`, D1 relations/indices/RLS/role memberships unchanged. Source guard and exact runtime metrics must remain enabled. The schema-owner trigger is not granted callable EXECUTE to public, authenticated, anon or service_role. First/second count expansions remain their own owner-review issues #108 and #110.

### Proposed local acceptance

`supabase/tests/domain/79_db01_approval_application_receipt_guard.sql` is an independently rollback-only **12-assertion structural fixture**: genuine authenticated P0 Enrollment and original Roll seed, a clearly **synthetic** R0→R1 history, a synthetic distinct-Person reviewer and typed reviewed request/receipt, one matching synthetic application insert, mismatched version and corrected Roll denial, actual function privileges and disabled operation verification. The initial fixture was rejected because Foundation requires creation in DRAFT/WAITING, not EXECUTED/APPROVED. The fixture now follows DRAFT → SUBMITTED → PENDING → APPROVED → EXECUTED and WAITING → OPEN → APPROVED under schema-owner structural test setup. **Exact PR #113 HEAD `b09f19f098ec685aad9675dd74ab6ea2d41ef354` PASSED all three workflows**, including suite #79 **12/12**, suite #78 **24/24**, suite #77 **30/30**, **3,232** total D1 business assertions, **234** `.sql.draft` fragments successfully applied in disposable local PostgreSQL and catalog **545 functions / 527 definers / 157 public / 388 private**, with **zero** authenticated-private, anon or service-role EXECUTE. This is local runtime evidence only, not independent integration/security approval. The suite is not P1 DIRECT/SUBMIT/REVIEW/APPLY positive acceptance.

**Acceptance state: LOCAL TECHNICAL ACCEPTANCE PASSED; INDEPENDENT SECURITY/INTEGRATION APPROVAL STILL PENDING.**

**Release disposition:** product contract approval does not constitute PR merge, shared-schema approval, hosted migration or grant activation. Any new SQL failures must be corrected in the same stacked PR, with final SQL ownership, catalog drift, RLS/privilege zeros, and rollback-only pgTAP evidence independently verified. DB-02 RP decisions and shared MOVE source prelock remain external integration blockers.

**Next DB-01 task after #111/#113 pass and integration review:** independently gated authenticated DIRECT/SUBMIT/REVIEW/APPLY handlers with School-local T-B synchronized across policy/MOVE/END, verified current authorizations, durable typed receipt and request evidence, two-session observable row-level lock tests, stale invalidation, checked historical disclosure and separate activation approval.