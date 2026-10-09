# D1 business acceptance progress

Updated: 2026-10-09. Status: incomplete; no migration activation or deployment readiness claim.

## Written acceptance coverage

| Group | Assertions | Covered behavior |
|---|---:|---|
| Employee creation | 37 | Deployment registrar counts/idempotency, verified actor, private-table and function denial, employee/history/receipt/audit/outbox atomicity, replay, changed intent, uniqueness, dates, live grant/scope/operation revocation |
| Academic Class lifecycle | 25 | Create/update/archive, identity retention, optimistic version, replay after later changes, denied raw deletion, permission revocation, audit/event preservation |
| Employee state direct route | 22 | Effective policy gate, current version, retained periods, same-day interval rejection, typed receipts, replay and current authorization |
| Employee state approval route | 42 | Submit/select/review/apply, direct bypass denial, revoked-reviewer invalidation, explicit reviewer REJECT, denied post-rejection apply, one immutable rejection review/receipt, preserved Employee history, no success event, no premature effect, retained review/application/transition history and terminal replay |
| Subject Teacher assignment direct route | 25 | Current/future ADD/END/CORRECT, exact authority, self-assignment denial, PRIMARY uniqueness, compatible CO_TEACHER assignment, kind-changing correction lineage, typed replay, retained history, audit/outbox evidence and live scope revocation |
| Subject Teacher retroactive CORRECT P2 | 32 | Direct-route bypass rejection, historical submit/review/apply, independent reviewer authority, revoked reviewer invalidation, immutable predecessor/successor lineage, scoped private helper access and terminal replay |
| Subject Teacher P2 REJECT and stale requester | 37 | Reviewer rejection and terminal replay, denied apply after REJECT, submit replay, denied stale requester apply, authorized final-approver invalidation, no assignment/history mutation or success event |
| Family child-access authorization and replay | 34 | Raw private Student/relationship/entitlement denial, FAMILY credential and relationship basis, unrelated Student UUID rejection, valid ADD/version/replay, overlap denial, reduction-only REVOKE after credential suspension, retained history/evidence and anonymous denial |
| Family shared-Principal membership DIRECT | 38 | No-credential ADD denial, independent relationship/entitlement retention, FAMILY-only OWN readiness, valid ADD/replay/overlap denial, staff grant revocation, suspended FAMILY Principal blocks ADD but allows historical END, receipt/event idempotency and anonymous denial |
| Concurrent employee creation | 3 two-session races | Same-key replay, changed-intent conflict, competing keys for one Person; require observed lock waiting and one result/history/receipt/audit/event per accepted intent |

The latest accepted local gate passes **292/292 business assertions across nine suites** and three two-session employee-creation races. It covers selected paths across **six D1 operations**, including Subject Teacher P2, Family child-access authorization (Effect 32) and Family shared-Principal membership DIRECT (Effect 31). Other protected operations, Effect 30 relationship mutation, Effect 31 P1 approval, Family portal checked reads, scope disclosure, populated upgrades and Admissions remain open. Student creation stays disabled.

The transaction-local shared fixture uses five synthetic Auth fixtures already provided by Foundation. Business tests roll back all application rows and request settings. Race tests commit synthetic setup on the disposable stack and destroy that stack afterward. No managed school, staging or production database is used.

## Current validation evidence

The 2026-10-08 local disposable run used Postgres image 17.6.1.113 and passed draft assembly, catalog/RLS/ACL probes, both lint levels, 220 Foundation assertions, 135 D1 business assertions and all three observed-lock races. It also exposed and fixed generic record-trigger access on non-temporal event rows, missing Teaching-executor helper privileges, the absent Subject-assignment receipt shape, and an ambiguous deferred capacity variable. Exact-commit GitHub evidence for this expansion remains pending.

Validated commit: aaa56b96e25366cb5932e1b872c3ccbf07f42ac0. Exact-commit [Foundation](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37410411568), [static](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37410411522), and [runtime](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37410411685) checks passed: 110 business assertions, three observed-lock races, 220 Foundation assertions, both lint levels and the fixed image with default permission hints.

The local tooling suite has 175 passing tests, including nine new acceptance-runner tests. The D1 source and final-function guards pass locally. Frozen Foundation migration/test bytes remain unchanged.

At database-code commit d5d36cb19378890bb746d32db92e5dcd3729c3a7, Foundation/static/runtime checks passed as recorded in DATABASE_COMPLETION_MATRIX.md. That baseline did not execute D1 business commands.

The expanded runtime run [37408619138](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37408619138) reapplied 197 draft fragments, passed catalog/RLS/grant checks, both lint levels and 220 Foundation assertions, then failed after 10 employee-suite assertions. The failing rendered SQL line 70 was the authenticated denied execution of app_private.d1_register_catalog_v1(); employee creation had not yet run. PostgreSQL logged signal 11 / segmentation fault and restarted recovery. This corrects the preliminary attribution to the creation command.

## Pinned local engine fix

Upstream [Supabase Postgres issue 2112](https://github.com/supabase/postgres/issues/2112) describes a matching segmentation fault in supautils' denied-function permission-hint path for reserved authenticated/anon roles.

The first diagnostic attempt to disable permission-error hints transaction-locally failed because the setting cannot be changed at that point. That workaround has been removed. Supabase's maintainer confirms supautils 3.2.0/3.2.1 caused the crash and the fix shipped with 3.2.2, in Postgres image 17.6.1.113 onward. CLI 2.98.2's source pins the affected 17.6.1.106 image.

The D1 disposable harness keeps CLI 2.98.2 and temporarily pins image 17.6.1.113 using the CLI's source-verified supabase/.temp/postgres-version cache. It restores prior cache bytes on exit and rejects any running container with a different image. Business denial assertions remain executed with default permission hints and unchanged grants/RLS. No managed school engine/configuration is changed. Run [37409845794](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37409845794) verified image ghcr.io/supabase/postgres:17.6.1.113 and passed all 84 employee-create/Class/direct-status assertions, including authenticated/anon denied execution and deferred constraints. The approval group passed its first 13 assertions before revealing the separate trigger defect below. This partial run does not certify the complete suite.

The runtime harness prints sanitized PostgreSQL process diagnostics on failure before destroying its disposable stack. It filters process failures and redacts JWT/DSN patterns; it does not dump environment variables or application tables.

## Application trigger defect found by business execution

The employee approval application reached a Student-status correction trigger attached to the shared approval_applications table. The trigger read NEW.result_kind, but Foundation approval_applications has no such column; the discriminator belongs to command_receipts. Lint did not detect this untyped trigger-record field error.

The draft fix selects the operation code using NEW.operation_id, skips unrelated operations, and requires the linked receipt's D1_STUDENT_STATUS_CORRECT_APPLY result kind before validating a Student correction effect. It preserves the request/receipt/result binding and existing executor permissions.

The final-state static guard now validates direct NEW/OLD column references in triggers attached to frozen approval_applications, including later function replacements. Regression tests cover unavailable columns and ignored string/comment text. The employee approval business test remains the runtime cross-domain regression. The complete 26-assertion employee approval suite and three races pass at aaa56b96e25366cb5932e1b872c3ccbf07f42ac0. Student correction's own positive/negative acceptance is still open.

## Next acceptance gates

1. Preserve the passing 292-assertion/three-race local checkpoint and frozen Foundation regression; extend exact-SHA business acceptance without weakening already frozen behavior.
2. Extend acceptance across remaining D1 operations and read scopes; add correction, rejection, cancellation and concurrency coverage at relevant boundaries.
3. Implement the Admissions physical design and real final-handoff/atomic intake dependency, including Finance-required clearance behavior.
4. Validate a populated upgrade, default engine denial stability and exact resulting Foundation/static/runtime checks before activating Migration 10.
5. Continue the complete school-domain matrix; Flutter remains after the final database gate.

## Exact-SHA PR #2 acceptance gate (2026-10-08)

The earlier pending exact-commit CI qualification is superseded. On `ff4b612eefa77f25e1fe1220eeff5ab0ff8f25ad`, the [D1 runtime workflow #70](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37793587538) passed **135/135 D1 business assertions** across the five suites listed above and **three two-session employee-creation races with observed lock waiting**. The companion [static #62](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37793587525) and [Foundation #284](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37793587873) passed the same SHA. This records the D1C2A disposable-local baseline only; tests for other operations and future Admissions remain open. See the [review](81_d1c2a_pr2_independent_review.md).

## Employee state rejection acceptance increment (2026-10-08)

The new [incremental review](83_d1_employee_state_rejection_acceptance.md) records 16 additional assertions for `employee.state.change` approval rejection/replay: suite 04 now **42/42**, total D1 business assertions **151/151** across the same five suites. Exact-source [D1 runtime #75](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37823838987) and [Foundation #289](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37823845846) passed commit `288afa81232ffa409a21a41423041a43914e1b51`. Test-only corrections are merged as `3422420c8b7bb3a4cdb77b292352837ffdc04e44` (PR #3); the merge introduced no additional file changes. This is incremental evidence, not full D1 business acceptance or Migration 10 activation.

## Subject Teacher P2 correction acceptance increment (2026-10-09)

[PR #4](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/4) is merged at `e1daafdfe623e3731a0dc79dd282cc24d86c5c83`. The corrected exact tested SHA `d7a03bcc68658d0fc5a725ee1f6eabadac964d7b` passed [D1 runtime #82](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37826893299), [Foundation #294](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37826893302) and [D1 static #66](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37826893310). Subject Teacher P2 adds **32/32** assertions, taking business coverage to **183/183**; Foundation stays **220/220** and observed employee-create races **3/3**. The initial failing candidate revealed a real `SECURITY DEFINER` trigger's missing EXECUTE on two `SECURITY INVOKER` validation helpers; the new grants are internal to `schoolos_schema_owner`, with explicit negative client-EXECUTE tests. See [independent review](84_d1_subject_teacher_p2_acceptance_review.md). Full D1 acceptance, populated upgrade and D1 migration activation remain open.

## Subject Teacher P2 REJECT and stale-requester increment — 2026-10-09

[PR #5](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/5) was merged at `ffe7eb227c9a3dead22b49d4354919d4aeaca35f`. Source `e9a41df526da4abf036ca3f5f4639dc6efee156a` passed [D1 local #85](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37889455840) with **220/220 D1 business tests**, 220/220 Foundation regressions, three observed-lock races, 197 applied disposable draft fragments and 34/34 forced-RLS D1 relations. [Foundation local #297](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37889455843) also passed the same source. The new seventh suite contributes 37 assertions for explicit reviewer REJECT, denied post-rejection apply, terminal review/submit replay, requester grant revocation, final-reviewer-driven invalidation and no success effects. This is a **test-only** increment; no new D1 static workflow was triggered. See [independent review](85_d1_subject_teacher_p2_reject_requester_stale_review.md). Full D1 acceptance and Migration 10 activation remain open.

## Family child-access boundary acceptance increment (2026-10-09)

[PR #6](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/6) merged as `32dfb27f727c9506e7bf4d61c68873d5cff9ae58`. Trusted tested source `997bb5037551f8275d13d1f457bd8058ef6cfb34` passed [D1 runtime #93](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37891944915), [Foundation #304](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37891944930), and [D1 draft static #71](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37891944864). The eighth business suite added **34/34** assertions, for **254/254 total D1 business tests**, 220/220 Foundation regressions, three employee-creation races, 197 disposable draft fragments and 34/34 forced-RLS relations. Two real D1 draft defects were fixed: missing `family.child_access.change` typed receipt phases and an invalid attempt to set Student/Family server-owned timestamps directly. Exact failure-and-fix evidence is recorded in the [independent review](86_d1_family_child_access_acceptance_review.md). The earlier same-source Foundation #303 failed on local `supabase start`, then #304 passed. This does **not** complete Family portal checked reads, D1 operation acceptance, populated upgrades, or migration activation.

## Family shared-Principal membership DIRECT acceptance increment — 2026-10-09

[PR #7](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/7) merged as `cd69c08e32e5b256153ff6a8b5c23760172f1f04`, based on exact tested source `1f2c5869560420cb94f4c3a17372f53712e8e2e1`. [D1 runtime #99](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37895744474), [Foundation #308](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37895744742), and [static #75](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37895744435) all **PASS**. The new ninth suite adds **38/38** assertions for private membership table denial, current FAMILY credential/role readiness, preserved Family/Student relationships, distinct child access, authorized membership ADD/END, overlap and stale-authorization denial, suspended FAMILY Principal reduction-only END, immutable retained history and stable typed receipt/event replay. Aggregate **292/292 D1 business**, **220/220 Foundation** and **3/3 observed-lock Employee races** passed with 197 disposable Migration 10 draft fragments and 34 forced-RLS relations. The D1 master `.sql.draft` adds exactly four typed membership receipt phases, without new grants. Failures #95 (duplicate fixture Principal) and #97 (fixture private read under authenticated role) were corrected without weakening security; [independent review](87_d1_family_principal_membership_acceptance_review.md) records details. Effect 31 P1 approval, Effect 30 relationship-change acceptance, checked-read portals and full D1 release gates remain open.
