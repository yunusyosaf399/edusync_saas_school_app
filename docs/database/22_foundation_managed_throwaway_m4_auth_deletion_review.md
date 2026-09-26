# Foundation managed throwaway — M4 real hosted Auth deletion review

**Verdict: M4 PASS — READY FOR SEPARATE M5 EVIDENCE + DESTRUCTION AUTHORIZATION.** A real hosted Supabase Auth Admin hard delete removed the dedicated synthetic Auth user. The external FK set the surviving School OS binding's subject to NULL, the normal triggers advanced versions and cutoff exactly once, and immutable UNBOUND and reconciliation audit evidence was created. The deleted subject no longer resolved through either its real pre-delete JWT or fresh/stale transaction-local helper claims. The project is retained for M5; no final destruction was performed.

## Source and retained target

- Starting repository HEAD `c0e6cc958d817f69bdc579e3d512c312170b9f76`, clean worktree. Supabase CLI `2.98.2`; hosted PostgreSQL `17.6`.
- Project name `schoolos-foundation-preflight-pooler-m1-20260925-5fdddb`, ref `lndjtslixvugswnnctam`, organization Ilmora (`jyssocxpozqlditlaogq`), region `ap-northeast-2`. The Management project-detail response and independent project listing agreed before mutation and at final inspection; project status `ACTIVE_HEALTHY`.
- Before M4: the exact nine Foundation migration versions were recorded once each; only the five named M3 Auth users existed; the M4 email was absent; DB, Auth and REST were `ACTIVE_HEALTHY`; exposed API schemas were `public,graphql_public,app` with `app_private` absent. Exactly one ACTIVE SYSTEM `identity-reconciliation` actor existed: `fd91abd0-b90a-5d79-af62-626f70cbb34c`. It was reused, not duplicated.
- A fresh temporary database password was rotated for this disposable project through the supported Management endpoint. All SQL used the official Supavisor **session** pooler at port 5432 with TLS, a passwordless URI and process-only `PGPASSWORD`. An immediate password-authentication failure cleared after normal password propagation. No transaction pooler, linked/direct IPv6 route, CLI upgrade or persistent credential file was used.

## Dedicated identity and pre-delete evidence

The hosted Auth Admin create-user endpoint created exactly one confirmed synthetic user, `foundation-auth-delete-integration-001@example.invalid`, with generated Auth UUID `69f22c68-8a5f-4f69-bb11-35d75faec519`. Its independent 48-character alphanumeric password was generated with Python `secrets` and held only in process memory. Real hosted password sign-in succeeded. The pre-delete JWT used for the integration check had safe metadata: `sub=69f22c68-8a5f-4f69-bb11-35d75faec519`, `role=authenticated`, numeric `iat=1790429193`, `is_anonymous=false`; no token or signature was recorded.

Under the reviewed trusted `schoolos_schema_owner` path, a committed synthetic Person `7b6d44ef-4bd0-535c-b9bb-b583f61e0005`, ACTIVE INDIVIDUAL principal `8d67a35a-1e0c-536e-a2d3-baccd746f3de`, and binding `4cd00920-4c08-5825-a3d8-0dc8d7aac7ff` were created normally. The principal received the existing M3 reviewed `principal.self` role/grant/OWN-scope chain so `app.read_own_principal()` could be tested without broadening client privileges. The actor above created the fixture; binding triggers, not manual evidence INSERTs, generated the BOUND event and initial audit.

| Pre-delete item | Observed value |
| --- | --- |
| Auth row, Person, ACTIVE principal, binding | One each; binding subject equalled the hosted Auth UUID |
| `binding_version` / `row_version` | `1` / `1` |
| `tokens_valid_from` | `2026-09-26 13:25:23+00` |
| `bound_at` | `2026-09-26 13:25:23.069051+00` |
| Binding events | Exactly one `BOUND`, with the new subject and version 1 |
| Binding-change audits | Exactly one `WORKER` / `BOUND` event; SYSTEM actor was the retained reconciliation actor |
| Reconciliation actors | Exactly one ACTIVE actor, with the expected ID |
| Real JWT principal RPC | `app.read_own_principal()` returned HTTP 200 and exactly the dedicated M4 principal |

## Hosted Auth Admin delete and reconciliation

The single deletion request was hosted Auth Admin `DELETE /auth/v1/admin/users/69f22c68-8a5f-4f69-bb11-35d75faec519` with `should_soft_delete=false`. It returned **HTTP 200** with an empty JSON object. No SQL DELETE of `auth.users`, manual binding NULL update, trigger bypass or migration repair was used.

| Post-delete assertion | Observed result |
| --- | --- |
| Hosted Auth UUID and M4 email | Both absent from `auth.users` (count 0); total Auth users returned to 5 |
| Binding | Same ID and principal retained; `auth_user_id IS NULL` from the external FK `ON DELETE SET NULL` |
| Person and principal | Both retained once; principal remained `ACTIVE` |
| `binding_version` | `1 → 2`, exactly one increment |
| `row_version` | `1 → 2`, exactly one increment |
| `tokens_valid_from` | `2026-09-26 13:27:10+00`, strictly later than the pre-delete cutoff |
| `bound_at` | Exactly unchanged at `2026-09-26 13:25:23.069051+00` |
| Binding events | Historical `BOUND` retained once; exactly one `UNBOUND`, version 2, old subject = deleted Auth UUID, new subject NULL, `created_by` = existing reconciliation actor |
| Binding-change audits | Initial `WORKER` / `BOUND` retained once; exactly one new `AUTH_RECONCILIATION` / `UNBOUND` with SYSTEM actor, binding target, deleted Auth UUID in `auth_subject_snapshot`, `SUCCEEDED` outcome and details `{"event_kind":"UNBOUND","binding_version":2}` |
| Reconciliation actor | Still exactly one ACTIVE actor, with unchanged ID |

The deleted synthetic Auth UUID remains in historical BOUND/UNBOUND evidence and the reconciliation audit snapshot as required; it was not erased. The real pre-delete JWT, preserved in memory, called the hosted `app.read_own_principal()` RPC after deletion and received **HTTP 200 with zero rows**. The request reached the application path; this was not merely an upstream gateway rejection.

In a rolled-back read-only transaction under `schoolos_read_executor`, matching deleted-subject request claim GUCs returned **NULL** from `app_private.current_principal_id()` for both a fresh numeric `iat` after the new cutoff and the stale pre-delete `iat=1790429193`. This is supplementary helper-level evidence alongside the real JWT request; no persistent claim state was changed.

Ordinary rollback-only DELETE attempts against the M4 binding-event and audit rows each raised SQLSTATE **`P0001: immutable foundation evidence`**. A separate rollback-only fixture attempted to assign the deleted historical Auth UUID to a different principal's detached binding; the reviewed BEFORE trigger raised **`P0001: historical Auth subject cannot change principal`** before the external FK could accept a reassignment. No probe Person, principal or binding persisted. Forced reuse of a hosted Auth UUID was not attempted because hosted Auth generates UUIDs; the test proves the database-side historical guard, not a platform UUID-reuse mechanism.

## Final boundary and retained state

The FK remains `FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON UPDATE RESTRICT ON DELETE SET NULL`. All application tables still have enabled and forced RLS; `authenticated` had zero effective whole-table DML surfaces. No School OS role gained Auth `INSERT`, `UPDATE` or `DELETE` privilege or `supabase_auth_admin` membership. The API schema list remained exactly `public,graphql_public,app`, excluding `app_private`. The exact nine migration versions remained recorded once each, and no migration 10 exists.

The five M3 Auth emails remained unchanged; the M4 email and UUID were absent. The detached M4 binding, surviving Person/principal, two binding events, two audits and ACTIVE reconciliation actor are intentionally retained on this disposable target. Project, DB, Auth and REST finished `ACTIVE_HEALTHY`. The M3 serial hosted pgTAP result remains 9 files / 220 planned / 220 passed; M4 used targeted assertions and did not rerun the full suite.

No M3 user was deleted, no evidence cleanup or M5 destruction was performed, and no migration, frozen test, Supabase config, Flutter code or dependency was changed. Temporary Auth password, real JWT/refresh token, database password, passwordless URI, API keys, management token and `PGPASSWORD` references were cleared from the active process. No secret, Authorization header or full token is recorded here.
