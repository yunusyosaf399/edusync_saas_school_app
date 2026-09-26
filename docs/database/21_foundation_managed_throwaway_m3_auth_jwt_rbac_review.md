# Foundation managed throwaway — M3 real Auth, JWT, RBAC and RLS review

**Verdict: M3 PASS — READY FOR SEPARATE M4 AUTH DELETION AUTHORIZATION.** The retained disposable managed project accepted five real hosted Auth users and their password-issued JWTs. The live Data API resolved bound principals, enforced the binding cutoff, complete grants, campus and OWN/FAMILY scope, and rejected direct DML and private-schema access. The nine frozen hosted pgTAP files passed serially, 220/220. This is M3 only; no hosted Auth Admin deletion was performed.

## Source, target and prerequisites

- Starting repository HEAD: `1ae9b04dd42b196c16230f38568f5c0e3cbb6160`; starting worktree clean. Supabase CLI `2.98.2`; hosted PostgreSQL `17.6`.
- Retained target: `schoolos-foundation-preflight-pooler-m1-20260925-5fdddb`, ref `lndjtslixvugswnnctam`, organization Ilmora (`jyssocxpozqlditlaogq`), region `ap-northeast-2`. Management project detail and independent project listing agreed before mutation and at the end; project status `ACTIVE_HEALTHY`.
- Before Auth creation: exactly the nine reviewed Foundation migration versions, each once; five requested M3 emails absent; `auth.users=0`; DB, Auth and REST healthy. The hosted API schema list was `public,graphql_public,app`, excluding `app_private`. The M2 boundary remained 33/33 enabled and forced RLS tables, 49 policies and 39 application SECURITY DEFINER functions.
- Database route: a freshly rotated temporary password on this disposable project, official Supavisor **session** pooler on port 5432, TLS, passwordless URI and process-only `PGPASSWORD`. No transaction pooler, linked/direct IPv6 route, CLI update or schema-setting change. A transient first login immediately after rotation cleared after propagation; the same route then worked.
- The nine migration files and nine frozen database test files remained unchanged. The review-15 source-integrity baseline remained the source baseline.

## Real hosted Auth and token evidence

The official hosted Auth Admin create-user endpoint generated five distinct UUIDs using independently generated, temporary passwords of 48 alphanumeric characters. Each `.example.invalid` address was marked email-confirmed without sending real mail. Each user then completed the real hosted password sign-in flow. Only safe decoded access-token metadata is recorded below; no JWT or password is recorded.

| Email | Hosted Auth UUID / JWT `sub` | Fresh JWT numeric `iat` | JWT role | `is_anonymous` |
| --- | --- | ---: | --- | --- |
| `foundation-test-001@example.invalid` | `d1a0a663-df04-46d4-8988-c9835e81a0e3` | `1790427144` | `authenticated` | `false` |
| `foundation-rbac-001@example.invalid` | `87cb1a71-f983-4368-942e-9406395d8ef4` | `1790427144` | `authenticated` | `false` |
| `foundation-family-001@example.invalid` | `605b9175-9555-4e9b-86e8-7419f8c3a7fe` | `1790427145` | `authenticated` | `false` |
| `foundation-own-001@example.invalid` | `e169238e-5209-4529-95d7-beff5a7cba12` | `1790427146` | `authenticated` | `false` |
| `foundation-own-002@example.invalid` | `308eb25e-4252-4bf8-b03c-18d44b20c2a1` | `1790427146` | `authenticated` | `false` |

The `sub` of each Auth-issued JWT matched its hosted Auth UUID; each had numeric `iat`, `role=authenticated` and `is_anonymous=false`. The five emails each appeared once and all UUIDs were distinct. The optional separate `request.jwt.claim.sub` GUC was not independently observed because doing so would require a diagnostic function; the real JWT → reviewed helper → RLS behavior below establishes the relevant application path.

Before binding, the RBAC user's real JWT called `app.read_own_principal()` through PostgREST and received HTTP 200 with zero rows. After its binding was committed, that same pre-binding token (`iat=1790426522`) still received HTTP 200 with zero principal rows and zero campuses. The binding's actual `tokens_valid_from` epoch was `1790427052`; its version was `1`. A fresh real JWT (`iat=1790427144`) returned HTTP 200 with exactly the expected ACTIVE principal `a0c035b5-8dd3-5999-a862-4caa593767c9`. This proves the actual cutoff distinction without changing the cutoff manually.

## Committed synthetic fixture and real Data API checks

The committed fixture used the reviewed shapes in frozen tests 02, 07 and 08, with deterministic M3-specific application UUIDs and the five generated Auth UUIDs. It includes one active reconciliation SYSTEM actor, a synthetic school, two campuses, FAMILY and INDIVIDUAL principals, four normal bindings, staff and family roles, reviewed permission/grant/assignment/scope chains, and own notifications/preferences. `foundation-test-001` intentionally remained unbound. No real school data or application ACL/RLS change was used.

Key retained IDs: reconciliation actor `fd91abd0-b90a-5d79-af62-626f70cbb34c`; school `a0be7a19-dabe-5bba-ab0f-f59e12458608`; Campus A `4fbd9e60-819b-5ee7-bc15-bf5d3d0e18e8`; Campus B `c43ddabb-8a8f-5113-b4ef-e00495e8435b`; FAMILY principal `3a44adb29-9585-5176-b33b-0664048e24b0`; OWN principals A `d507bcf0-64ef-52c7-b635-f19d71f37f01` and B `d35e1fab-e614-5f91-80a9-23fcdefb5824`; RBAC principal `a0c035b5-8dd3-5999-a862-4caa593767c9`; RBAC binding `5fa50373-c3e8-54d5-9b4f-a3ba8e0de592`. All other application fixture UUIDs are deterministic UUIDv5 of `schoolos-managed-m3:<frozen-test-08-UUID>` or a named M3 fixture element. The normal binding triggers generated four durable binding-evidence rows; they were not inserted manually.

All following application requests used the project's public/anon API key plus `Authorization: Bearer` with the **real user JWT**, and `Accept-Profile: app`. The service-role key was used only for supported Auth Admin user creation, never as application authorization.

| Real-JWT check | Expected and observed result |
| --- | --- |
| Unbound identity | `foundation-test-001`: `read_own_principal()` HTTP 200, zero rows; campus query HTTP 200, zero rows. |
| Bound principal | RBAC user: `read_own_principal()` HTTP 200, exactly the expected RBAC principal. OWN users A/B likewise resolved only their respective principals after the reviewed OWN self-scope chain was complete. |
| Authenticated relation resolution / complete grant | RBAC user queried `app.campuses` with allowed columns: HTTP 200, Campus A returned once. The relation was resolved by PostgREST and RLS permitted the reviewed complete role/grant/assignment/scope chain. |
| Campus isolation | The same RBAC JWT queried Campus B: HTTP 200, zero rows. |
| Incomplete/mixed grant | Following frozen test 07's negative pattern, the assigned staff role's Campus grant was revoked and an unrelated Role B received a live grant for the same permission. The committed pieces did not form one complete chain: the same RBAC JWT queried Campus A and received HTTP 200, zero rows. The test intentionally leaves the synthetic Campus grant revoked on this disposable target. |
| FAMILY ceiling | FAMILY JWT read its own notification: HTTP 200, one row. It queried the staff A notification and Campus A: HTTP 200, zero rows for each. |
| OWN A and OWN B | OWN A read its own notification (one row) and preference (one row), but the B notification returned zero. OWN B resolved its own principal after adding the exact B self-scope row from frozen test 08, and could not resolve A's principal or read A's notification. OWN B's inbox remained empty because frozen test 08 does not give B a notification OWN scope; no broader scope was invented. |
| Anonymous | Anon-key-only campus and principal RPC requests were HTTP 401, PostgreSQL `42501`, `permission denied for schema app`. |
| Direct mutation | RBAC JWT attempted a harmless synthetic `POST app.campuses`: HTTP 403, PostgreSQL `42501`, `permission denied for table campuses`; no row was inserted. |
| Internal API | Authenticated request with `app_private` profile to `current_principal_id()` returned HTTP 406, `PGRST106`, with the exposed-schema list `public, graphql_public, app`. |

An initial notification/preference probe requested `recipient_id`/`principal_id`, columns deliberately absent from the authenticated SELECT allowlist, and correctly returned HTTP 403 `42501`. The probe was corrected to request only M2-approved visible columns (`id`, `category_code`, `summary` or `enabled`); those produced the successful RLS observations above. During fixture assembly, a first attempted B self-scope INSERT referenced the frozen test UUIDs rather than the transformed M3 IDs and failed FK validation inside an uncommitted transaction. The corrected deterministic-ID INSERT committed normally. Neither transient probe changed permissions or migration/test files, and neither was an authorization failure.

## Frozen hosted pgTAP suite

pgTAP `1.3.3` was installed under `extensions` solely as test infrastructure. Before committing the persistent M3 application fixture, all frozen files were run **serially**, one CLI process at a time, with `supabase test db <file> --db-url <passwordless session-pooler URI>` and process-only `PGPASSWORD`. This order avoids collision between frozen tests' globally unique synthetic permission codes and the subsequently committed runtime fixture. The suite was not rerun after fixture commit; the real-JWT/API checks above were performed on the committed state. Test 09 was only its frozen SQL reconciliation contract and did not perform a hosted Auth Admin deletion.

| Frozen file | Planned | Passed | Result |
| --- | ---: | ---: | --- |
| `01_foundation_catalog.sql` | 44 | 44 | PASS |
| `02_auth_helper_preflight.sql` | 6 | 6 | PASS |
| `03_file_objects.sql` | 16 | 16 | PASS |
| `04_family_intervals.sql` | 16 | 16 | PASS |
| `05_approval_lifecycle.sql` | 25 | 25 | PASS |
| `06_evidence_delivery.sql` | 16 | 16 | PASS |
| `07_authorization_rbac.sql` | 33 | 33 | PASS |
| `08_family_own_scope.sql` | 41 | 41 | PASS |
| `09_auth_deletion_reconciliation.sql` | 23 | 23 | PASS |
| **Total** | **220** | **220** | **PASS** |

## Final state and boundary

Final read-only inspection found five `auth.users` rows with five distinct IDs, no M4 deletion email, four retained application bindings, four binding-event rows, five principals and two campuses. The same nine migration versions remained recorded once each. The API schemas remained exactly `public,graphql_public,app`; `app_private` remained unexposed. The project, DB, Auth and REST statuses were `ACTIVE_HEALTHY`. The synthetic committed fixture and immutable evidence remain on this disposable project for later preflight phases; they were not erased. The reconciliation SYSTEM actor remains ACTIVE and is the one synthetic actor of that purpose; M4 should inspect and reuse the existing actor as allowed by its separate instructions.

No hosted Auth Admin DELETE, real FK `ON DELETE SET NULL` integration, or M4 reconciliation was attempted. No migrations, frozen tests, Supabase config, Flutter code or dependencies were changed. Temporary Auth passwords, access/refresh JWTs, DB password, passwordless DB URI, API keys and management token were cleared from the active process after evidence capture. No credential or full token was written to this review.
