# D1 Effect 30 — Family relationship protected P1 request-read acceptance

Date: 2026-10-10  
Verdict: **PASS — exact-source incremental disposable local acceptance; full D1 OPEN.**  
PR: [#17](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/17)

## Tested identity and workflows

- Accepted main baseline: `037e9d99db8b4ea8ef03fe39ab30d2037b161424`. Exact tested PR tip: `7dc4ab3ddf53dcff53e25bfc6521294c862d0284`. Merge commit: `67811dc3f5b5afba8c90040324befd88bde2beb6` with tested tip as second parent.
- [D1 disposable runtime #167](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38039810888): **PASS**, `18_family_relationship_p1_checked_request_read.sql` **36/36**, D1 business **759/759 in 18 suites**, post-D1 Foundation **220/220**, runner unit tests **21/21** and six true observed-lock PostgreSQL two-session races (Employee three; Family principal membership P1 ADD/END/CORRECT three). Both local lint levels pass. Disposable local database stopped.
- [Foundation local #366](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38039810874): **PASS**, frozen nine migrations and 220/220 Foundation assertions.
- [D1 static #108](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38039810865): **PASS**, 200 SQL draft fragments, 34 domain relations, 97 permissions, 322 scope alternatives, 36 operations, 540 final functions (522 SECURITY DEFINER), no signature-shape drift and no authenticated/anon/service_role private helper execute rights.
- Local runtime assembled/applied 200 fragments, confirms 34/34 forced-RLS domain tables and 540 final functions; none were deployed to hosted Supabase.

## Security and business behavior

The frozen `family.relationship.change` P1 checked-read surface is `app.d1_read_family_relationship_request(uuid)`: a **typed, participant-only** view of the protected approval request (Student and Family identifiers, requested relationship facts and reason, state, version and participant kind). It is not a client SQL SELECT on private approval workflow tables.

The new 36-assertion suite exercises:
- Original verified requester may view a PENDING request and exact typed reason/action/Student/Family fields under live `family.relationship.change` authority. NULL and unrelated request IDs return no row.
- The separately verified reviewer assigned to the OPEN step may see the reason under the configured reviewer role and live `family.access.approve`. A newly authenticated staff Principal with **the identical role and matching ALL/DIRECT permission scope** but no selected step assignment receives no protected row before or after review.
- Revoking the original reviewer grant removes read rights immediately even with a retained reviewer assignment; restoring it restores visibility. APPROVE closes the review and preserves lawful decided/final reviewer access. Review itself does not execute domain mutation.
- Only explicit requester APPLY executes the approved relationship. The requester can read the retained EXECUTED state while authorized; revoking the requester grant removes protected history access, restoring it permits access again. One retained application and one relationship are created, without child entitlements.
- Neither `authenticated` nor `anon` may directly read private approval reasons, payloads, snapshots or reviewer assignments; clients cannot invoke the internal participant helper. Protected reason is excluded from broad outbox metadata.

## Least-privilege correction

`supabase/migrations/20260928000000_domain_package_01_effect30_30_family_relationship_checked_read_acl.sql.draft` is an **append-only, non-executable continuation**. It adds purpose-limited SELECT columns and Effect30 operation-bound SELECT RLS policies solely for `schoolos_read_executor` and `schoolos_authz_reader` (trusted NOLOGIN roles). The existing `d1_family_relationship_participant_kind` and `app.d1_read_family_relationship_request` preserve their signatures, SECURITY DEFINER owners and pinned search paths but replace inappropriate private workflow `SELECT q.*` with explicit columns. The original authentication, locking and exact participant checks remain intact. No raw SELECT privileges are granted to client roles.

Precisely three PR source files: append-only continuation30, rollback-only 36-assertion pgTAP suite18 and runner registration. Frozen Foundation migrations, production Flutter code, service workers and hosted Supabase are unchanged.

## Release boundary

The security review is an **incremental local-only** accepted gate. Migration 10 remains **200 `.sql.draft` fragments**, deliberately not executable or deployed. Full D1 acceptance, checked Family portal projections, Finance, Admissions, populated upgrade/reconciliation, live hosted authorization and other untested permutations stay **OPEN**.

**Checkpoint: `D1_EFFECT30_P1_PROTECTED_READ_PASS — 759/759 BUSINESS — 220/220 FOUNDATION — 6/6 RACES — STATIC PASS — FULL D1 OPEN`.**
