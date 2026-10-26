# DB02 G06 — staging release preparation and remaining blockers

Prepared 26 October 2026. **Decision: NO-GO for deployment; G06 remains open.** G05 is complete. This packet completes the release-planning portion of G06, with a verified staging baseline, exact ordered source inventory, upgrade/recovery acceptance matrix and the remaining authorization boundary. It does not claim an executable migration, upgrade/restore rehearsal or staged authenticated command acceptance.

## Candidate and verified target

The candidate is the accepted DB02 successor `6351fdfc2cc5dda31950deb7d362af0fe620fc82`, tree `bee50b1b33a1122cf232f9fda057a0cb58a1f36a`, containing G04 source integration and G05's accepted contract. Its business SQL and runtime harness are identical to exact tested head `64ce0e6afe2915a6e899a1402217d0d87e66ebaa` with static/Foundation/D1 green. G05 documents 112 suites / 4,292 assertions, Foundation 220/220, real contention/replay and disabled defaults. This packet adds documentation only; no new runtime on its documentation commit is claimed.

Read-only Supabase project discovery, migration listing and a `BEGIN READ ONLY` aggregate query independently verified the pinned target on 26 October:

| Target observation | Actual result |
|---|---|
| Project | `schoolos-staging-main` / `whwongqcgjakcfrzbvcg` |
| Organization / region | `jyssocxpozqlditlaogq` / `ap-northeast-2` |
| Health | ACTIVE_HEALTHY |
| Database | SQL server version 17.6; project image metadata 17.6.1.166 |
| Migration history | Exactly the nine frozen Foundation versions; no Migration 10 |
| Application base tables / FORCE RLS | 33 / 33 |
| School / Principal rows | 0 / 0 |
| Permission / operation rows | 0 / 0 |
| Receipt / approval / audit / outbox rows | 0 / 0 / 0 / 0 |
| `app_private.roll_policy_revisions` | Absent |

The account containing this target is the connected **SchoolAgent** account. The other connection lists a different inactive project; the synthetic photo lab is also a different target. Neither is substituted for the pinned staging project. No hosted SQL mutation, fixture, project, backup, configuration or operation enablement was performed. These observations are a dated baseline, not a reusable authorization or proof of absence of every possible type of data.

The [machine-readable plan](db02_g06_release_plan_20261026.json) pins the target, nine Foundation migration hashes and all **291 draft fragment paths in actual lexical execution order**, with size and SHA-256. The combined source digest is the G02-frozen `61362b17d094371e7b6ebaec8a9ca577fc3c6fbadb11bf9c903fd5721f57f809`. Fragment order is not inferred from effect numbers or PR numbers.

## Why deployment is currently blocked

| Gate | Evidence and required next action |
|---|---|
| Whole-package release scope | The candidate creates the entire D1 package, including DB01 and Academic/Employee/Family/Teaching routines; copying only DB02 fragments would omit dependencies and final shared overrides. Do not treat DB02 owner acceptance as acceptance of all included workstreams. Complete the package's release gates or prepare a separately reviewed, tested split release. No split is supplied by this packet. |
| DB01 integration/security | [Issue #140](https://github.com/yunusyosaf399/edusync_saas_school_app/issues/140) remains open for full DB01-10 installed handoffs, DB01-11 review and DB01-12 release. The Academic pool hook implementation and G03's scoped DB02 compatibility acceptance are already complete; they do not close the remaining gates. ADR-006 only changes DB02 P03/G03's review mechanism. |
| DB03 / DB04 handoffs | PR #102 head `d9995a47295a5b6e0ddecf127a47453081517d98` and PR #103 head `98a2453e7314ee443dd09bb320cc474ef3fed168` remain unmerged draft design/readiness work. Installed Admissions/Student-create/Finance and Curriculum consumer handoffs are not demonstrated by the accepted D1 runtime. These are the current DB01-10 dependencies, not missing DB02 command implementation. |
| Executable migration / staging policy | Existing `foundation_staging_contract.json` permits **Foundation only**. No reviewed D1 staging contract or tracked executable Migration 10 exists. Do not bypass that executor, rename draft files wholesale, or alter migration history to imply installation. |
| Populated upgrade / recovery | Current runtime resets to nine Foundation migrations with no seed before applying the draft chain. The observed hosted target is also unbootstrapped. Neither proves a populated Foundation upgrade or a post-commit restore. Required rehearsals below have not been run. |
| Post-bootstrap catalog / permission rollout | Migration-time catalog inserts and SYSTEM-Principal creation are forbidden. The target has no School, Principals, permissions or operations. The trusted bootstrap actor, reviewed D1 registrar, enabled global route and exact staff permission/scope configuration need their own controlled post-DDL sequence. CI actor SQL is not a hosted provisioning script. |
| Exact release authorization | No concrete executable bundle, backup/restore proof or staging enablement approval exists. The instruction to continue work authorizes preparation; it does not identify a production target or waive missing acceptance. Do not ask for deployment approval while these technical blockers remain unresolved. |

## Proposed migration and activation order

1. Close or formally revise the whole-package dependencies above, preserving each workstream's acceptance policy. Refresh actual owner heads, recompose if they changed and rerun exact-source static, Foundation and complete D1 acceptance. Re-freeze the changed candidate; do not keep using G05's digest after a source change.
2. Generate the future executable migration through `supabase migration new` using the reviewed CLI after inspecting its help. Do not select a fictional timestamp here. Preserve all 291 fragments in the plan's order, including final shared receipt and Academic overrides. No seed, business permission activation or bootstrap data belongs in that migration. Record both the exact final migration bytes/hash and its source commit/tree.
3. Prove the packaged SQL's transaction behavior in a disposable database. The existing draft runner uses `psql` without a surrounding explicit transaction and is not an atomic rollback proof. An all-or-nothing package is the proposed strategy, subject to successful end-to-end packaging/recovery tests; no claim that raw fragment application is atomic follows from current CI.
4. Produce the new staging-only D1 deployment contract/executor against this exact project and verified Foundation history. Preserve frozen Foundation files and the Foundation-only executor. Require a clean checkout, exact migration plan, no drift, target version/extension compatibility, minimized Data API exposure and no migration-history repairs. Review the migration dry-run before any write.
5. Rehearse populated upgrade and recovery below, including the current managed image behavior. Securely retain backup references/checksums outside the repository when they contain protected data. Stop application/domain writers and workers for the authorized migration window; verify the backup can actually be restored before relying on it.
6. Present one concrete staging-only approval: target ref, exact source and executable migration hash, backup/restore proof, maintenance plan, fixture plan and whether it covers DDL only or temporary synthetic command enablement. Record the owner's actual response and scope. Production/customer deployment remains a later separate decision.
7. Only after approval, apply the tracked migration once through the reviewed deployment route. Verify migration history, final owners/search paths/grants, all forced RLS and expected dormant defaults before bootstrap or enabling anything. Stop on any drift or partial installation; investigate transaction state and history instead of blindly retrying `CREATE ROLE`/DDL.
8. Use the controlled trusted bootstrap/registrar path with reviewed actor and exact catalog payload; then configure only the agreed School-wide P1 route and minimum real/synthetic staff grants. Keep unrelated operations and delivery/automation workers disabled. Use a fresh authenticated Principal, not service-role credentials, for business acceptance.
9. Run staged negative and positive cases below; restore the pre-enable disabled state unless continued staging operation was explicitly approved. Preserve synthetic immutable evidence and document fixture cleanup boundaries. Do not hard-delete retained receipts/audits/history to make the target look fresh. Record final health/drift/history and close G06 only against actual acceptance evidence.

## Required upgrade and recovery rehearsals

| Rehearsal | Required proof before it can pass |
|---|---|
| Populated Foundation → D1 | A disposable copy built from frozen nine-migration Foundation, with synthetic School/Campus/Year, different-Person staff identities, RBAC grants/scopes, active and retired workflow configurations, requests, terminal receipts/audits/outbox and retained settings. Capture deterministic per-table row counts and canonical content digests, not only schema counts. Apply the exact packaged migration and prove every pre-existing row/history/version unchanged, expected additive objects present and zero unexpected bootstrap/catalog activation. |
| Pre-commit failure | Inject errors after early, middle and final DDL checkpoints. Reconnect and compare pre-upgrade data plus roles/memberships, function definitions/owners/ACLs, table columns/constraints/indexes, triggers/RLS policies and migration history. All must return to the baseline; a client error or `ROLLBACK` message alone is not proof. |
| Successful commit / retry | Verify tracked migration appears once and dry-run reports no pending application on retry. Test loss of client response by inspecting actual transaction/history before deciding whether to retry. Do not rerun raw non-idempotent draft SQL. |
| Post-commit recovery | Restore the recorded pre-upgrade backup into an isolated recovery target, preserving original staging, or validate an independently reviewed forward fix. Verify data digests, auth binding references, RBAC, approvals/evidence, version/history and grants. Document measured restore time and accepted recovery point. No arbitrary RTO/RPO is invented by this packet. |
| Storage / secrets coverage | Database backups cover metadata, not external object bytes. Include any applicable external object version/preservation and required secret/custom-role recovery procedure separately. No backup subscription or PITR entitlement is assumed. |
| Managed compatibility | Validate extensions, privileged DDL and executor behavior against the actual managed target image. Local PostgreSQL 17.6.1.113 acceptance and a hosted 17.6.1.166 image are not byte-identical environments. Any provider image upgrade requires review and appropriate rerun rather than an automatic upgrade here. |

A post-commit incident first stops affected writers/operation enablement while preserving retained history. Restoration is a separately reviewed action with an explicit recovery point and potential data-loss assessment; never execute DROP CASCADE, project reset/delete, generic down migrations, catalog-history edits or backup restore automatically. Existing G05 history guarantees prohibit destructive “rollback” of policy/Roll/evidence after business writes.

## Staged authenticated acceptance matrix

| Area | Required cases / evidence |
|---|---|
| Defaults and raw access | Disabled operation/permission denies DIRECT/SUBMIT/REVIEW/APPLY as applicable; anon and service_role have no DB02 EXECUTE; authenticated cannot read/write private policy/Roll/approval/receipt/audit/outbox data; current-policy and typed request reads retain their independent authorization. |
| DIRECT | INIT and a legal later-day REPLACE, exact source, School-local date, contiguous revisions, exact pools, one receipt/audit/event; reject END, future/backdate attempts, same-day replacement, stale source, conflicting future placement and narrow Campus/Family authority. Do not spoof clocks or change persistent target timezone to simulate genuine elapsed days without separately reviewed fixture authorization. |
| APPROVAL | Genuine SUBMIT → assigned different-Person REVIEW → APPROVED with no effect → separate APPLY → EXECUTED once. Cover REJECT, self-review, stale version/global P1 UUID, revoked requester/reviewer authority and elapsed trusted date; invalidation has no domain effect/application/success event. |
| Replay / privacy | Lost-response retry returns the same retained response under current authority; changed intent conflicts; revoked participant denied then restored-authority replay; later legal revision does not duplicate effects. Private reason absent from public returns, receipt summary, broad audit and six-key schema-v1 event. |
| Interoperability | Exact policy revision + Offering academic namespace; persistent retained/corrected-away ownership and high-water; atomic new Offering pools without counter reset; DB01 correction and future Enrollment commitments honor the accepted shared School lock. |
| Regressions / health | Exact-source static/Foundation/full D1 disposable suites and observed-lock races remain green; staged ownership, ACL/RLS, Data API, migration history, current grants and advisories match the reviewed release contract. Hosted output must be recorded separately from disposable CI. |
| Final state | Record exact target, timestamp, migration/source hashes, exercised actors/permissions, sanitized result/event IDs/counts, unchanged history digests, operation/worker states, retained synthetic evidence and final health/drift. No keys, JWTs, passwords or private reasons in repository evidence. |

All rows are **planned acceptance**, not passed tests. No authenticated staged DB02 command can be claimed on the current Foundation-only target because its policy table and endpoints are not installed.

## Provider references reviewed

Supabase's [migration guide](https://supabase.com/docs/guides/deployment/database-migrations) distinguishes versioned migration files from tracked remote installation and recommends a forward migration for production rollback. Its [backup guide](https://supabase.com/docs/guides/platform/backups) documents restore behavior and the absence of Storage object bytes in database backups. The [25 September PostgreSQL compatibility notice](https://supabase.com/changelog/postgres-15-19-17-11-breaking-changes) requires review for affected extension indexes, legacy encrypted data and custom operators when moving to 17.11. The [12 October TLS notice](https://supabase.com/changelog/cbc-tls-ciphers-deprecated) concerns HTTP APIs, not direct/session-pooler database connections. These were reviewed for planning, not used to change this project's version, entitlement or configuration.

## Continuation

G06 stays unchecked in issue #69: **38 completed / 1 remaining / 39 gates**. The immediate database work can continue with the outstanding DB03/DB04 handoffs and DB01 release review while the populated-upgrade/recovery and staging executor are developed. No Flutter work or production activation follows from this preparation. The sole maintainer can perform planning and implementation; the existing scoped review policies still govern the affected workstreams.
