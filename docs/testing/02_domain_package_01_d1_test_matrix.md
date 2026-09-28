# D1B4 — future executable test contract

**Design only.** No test SQL is created or executed here. D1C must turn this matrix into disposable local positive and negative tests before any Migration 10 application is proposed. The frozen Foundation migrations 1–9 and tests 01–09 are compatibility inputs, not editable fixtures. The [D1B3B permission/disclosure catalog](../security/08_domain_permission_disclosure_catalog.md), [checked-read and command contracts](../security/09_domain_checked_reads_and_commands.md), [execution matrix](../security/10_domain_execution_rls_matrix.md), [D1B2 constraints](../database/30_domain_package_01_constraint_matrix.md), [locking](../database/31_domain_package_01_concurrency_and_locking.md), and [D1B4 implementation review](../database/34_domain_package_01_query_retention_offline_review.md) determine expected results.

Each case below requires a positive assertion where the contract permits an action and a negative assertion for the nearest forbidden variant. A successful protected mutation must assert domain effect, receipt, audit and selected outbox event in the **same committed transaction**. A rejected mutation must assert no partial domain effect or success evidence; a deterministic rejected receipt follows the Foundation protocol. Use synthetic data only, including two unrelated Students, Families, Employees, Campuses and Sections so an accidental broad predicate cannot pass. Test the authenticated RPC boundary separately from trusted fixture setup. Never grant a test principal extra application authority merely to make a test pass.

## Structure and source integrity

| ID | Future executable assertions |
|---|---|
| S01 | Exactly 34 D1 private relations with UUID PKs and approved ownership; the 11 mutable projections/catalogs, three immutable event families and 20 effective-history relations follow the physical catalog. No Admissions relation is invented. |
| S02 | Selected 21 full unique, three partial unique and 47 D1 nonunique B-tree indexes exist with exact columns, order and predicates; PK indexes are counted separately. Two target-first typed-scope indexes exist on the Foundation extension. No speculative index or duplicate. |
| S03 | All 34 CHECK bundles, selected composite FKs and ancestry guards enforce the matrix. Test both matching and mismatched school/parent, kind, state, interval and file purpose. |
| S04 | RLS enabled and forced on all 34 relations; all five D1 executor roles are NOLOGIN with exact memberships, owners and grants. The Foundation table extension leaves Foundation role topology intact. |
| S05 | A fresh application of frozen Foundation migrations then D1 draft is independently reproducible; all nine Foundation migration and test blob hashes remain unchanged. No Migration 10 execution is authorized by this design document. |
| S06 | D1 migration creates no SYSTEM Principal or catalog seed; a missing/duplicate bootstrap actor, exact replay and semantic collision exercise the separately invoked registrar after bootstrap. Vocabulary begins disabled and produces no user role/grant assignment. |

## Temporal, completeness and concurrency

| ID | Future executable assertions |
|---|---|
| T01 | Half-open intervals allow adjacency and reject strict overlap, including future or closed intervals, for every selected temporal parent/key. Same-parent predecessor/supersession rejects self, cross-parent and cyclic or inconsistent lineage. |
| T02 | Two concurrent PRIMARY placement attempts for one Student serialize on Student; exactly one conflicting placement can commit. Two Students racing for the last Class or Section slot serialize on both capacity anchors; full-limit decision uses all effective breakpoints. |
| T03 | Two concurrent roll allocations in each selected namespace cannot claim the same number for different Students. Persistent claims survive policy revisions; academic-mode claims use policy revision plus offering and interval. A correction retains prior evidence. |
| T04 | A status stream allocates positive server sequence under Student lock; same-day as-of ordering uses `(effective_on, sequence_number)`, not insertion timestamp. Ordinary backdating and inconsistent predecessor reject; reviewed factual supersession preserves prior rows and recomputes projection. |
| T05 | The initial Student status and accepted PRIMARY enrollment are complete at commit. Each accepted enrollment has exactly one effective matching roll allocation. A capacity change has exactly one typed revision. Over-limit placement has exactly one complete override receipt/evidence row; within-limit placement has none. Force missing/duplicate evidence at commit to prove deferred defenses. |
| T06 | Future-dated move leaves today's roster at source, reserves destination capacity at the future effective date, and retains source/destination history. Destination and source authorization are both rechecked after waits. |
| T07 | Family relationship/context/access containment is rechecked across the whole interval, including multiple bases and a basis ending. A revocation racing a child operation serializes on Student/Family and new statements after revoke deny. Emergency Contact never creates relationship or access. |
| T08 | Ending ACTIVE employment or teaching capability racing a new assignment either closes all affected assignments at a valid bound or rejects; no committed ineligible effective assignment remains. One class teacher per Section, PRIMARY Subject teacher, CO_TEACHER and bounded SUBSTITUTE rules are exercised independently. |
| T09 | Section room ancestry and one effective room assignment hold under concurrent writers. Qualification/experience same-lineage correction is owned by the same Employee; independent external experience may overlap. |
| T10 | Concurrent catalog/archive, policy, capacity and assignment commands obey Foundation SHARED → receipt key → principals → sorted D1 hierarchy. Exercise opposing source/destination UUID order and post-wait revalidation; no command performs an unregistered blind retry. |

## Authorization and disclosure

| ID | Future executable assertions |
|---|---|
| A01 | Each direct ALL/CAMPUS/CLASS/SECTION/SUBJECT scope passes only with the complete action grant and matching stored target ancestry. Wrong campus, mixed grant/scope, missing typed scope and unknown resolver deny. |
| A02 | Student-self and Employee-self paths require current principal identity and the expressly supported self permission. FAMILY child path requires current FAMILY membership, approved relationship basis, child access and family-safe permission; unrelated child and stale relationship deny. |
| A03 | Current class-teacher, exact Section+Subject teacher and teaching-any alternatives distinguish their assignment and capability predicates. Historical assignment, campus affiliation, Department, Designation, qualification and specialization grant nothing. |
| A04 | Revoked grant/binding/principal state and stale token deny on the next checked statement. A historical relationship or placement never revives current authority. School-scoped reads cannot leak another school's project data via a caller-supplied identifier. |
| A05 | ROSTER, PROFILE, RESTRICTED and SPECIAL returns have explicit column allowlists. Subject teacher may get ROSTER only when granted and cannot obtain PROFILE through that grant; class teacher PROFILE needs its separate grant. Student-self Restricted Identity is denied. |
| A06 | FAMILY Emergency Contact returns only current safe display fields, with no Person ID or lineage; unrelated child denied. Historical Emergency Contact, Restricted Identity, Special, employment, relationship and teaching reads require their separate historical permissions and present live authority. |
| A07 | Every selected checked-read family has an exact typed entry point and allowed field-class test. Current endpoints do not accept an as-of selector; history endpoints require an explicit as-of/interval contract. No `SELECT *`, arbitrary table/permission selector or generic row JSON endpoint is callable. |
| A08 | Report, export, search, AI and offline-facing adapters, when later implemented, use the same or narrower projections. No D1B4 implementation of those adapters is implied. |

## Commands, workflow, receipts and evidence

| ID | Future executable assertions |
|---|---|
| C01 | Each of the 36 fixed operation contracts is accounted for by an explicit entry point or a documented disabled dependency (`student.create` pending Admissions). Test the required permission, target kind, expected version/state and exact field allowlist. |
| C02 | All externally retriable commands bind `(principal, operation, idempotency_key)` to a canonical authority-relevant intent hash. Exact terminal replay returns the same result without a second domain row, ID, roll, audit or outbox event; same key/different intent rejects. |
| C03 | Stale expected version, invalid state, wrong source/destination scope and authority revoked while waiting reject. P0 direct path still checks context; P1 missing policy denies and configured review blocks direct apply; P2 always blocks direct apply. |
| C04 | For **each P1 operation in approval mode**, requester permission alone cannot review; review permission alone cannot bypass configured Foundation step/role eligibility. Wrong exact review permission, correct review permission at wrong scope, correct role without review permission, and permission without selected reviewer role all deny. Reviewer cannot self-approve through another assignment/role or same Person. Revoked review grant denies on the next statement. Direct apply denies while approval mode is active; absent/ambiguous P1 policy denies. Exercise representative Student, Employee and Teaching operations as well as a data-driven check of all ten new mappings. |
| C04A | Approved P1 apply rechecks requester and reviewer live authority, target/version/state, changed source and destination scopes and D1 invariants. An approved request that becomes stale/invalid denies and cannot force a domain write. A valid explicit direct-mode P1 command still requires its request permission, current scope and version. |
| C04B | The ten new `.approve` permissions are `family_safe=false`; none supports OWN/FAMILY/ASSIGNED unless its explicitly selected direct scope set includes it (the ten selected sets do not). No role template, automatic grant or generic administrator review path appears. |
| C05 | Capacity override requires its additional action permission, nonblank reason, verified actor and exact retained typed evidence; capacity alone does not force approval. Wrong override evidence or altered limit/occupancy snapshots reject. |
| C06 | Foundation authorization EXCLUSIVE revocation cannot pass a concurrent D1 SHARED command unchecked; whichever wins determines the fresh outcome. D1 does not write Foundation grant/scope rows. |
| C07 | `student.create` vocabulary can be disabled, but no successful callable path exists before a verified final Admissions handoff. A denial-only stub cannot be reported as an implemented create command; direct authenticated Student INSERT denies. |
| E01 | Every successful protected command emits the approved safe audit type and the selected outbox event when applicable; typed receipt and workflow application point to the same effect. A rollback emits no success audit/outbox. |
| E02 | Audit/outbox carry identifiers, safe state/action labels, interval and correlation only. Assert absence of raw national/B-Form/CNIC, Special, Emergency Contact, qualification/experience, arbitrary reason, signed URL, object key, password and request JSON. |
| E03 | Retained status, enrollment, roll, Family, Employee, teaching, capacity and immutable evidence cannot be silently destroyed by ordinary direct DML; authorized one-way close preserves prior facts and historical reads remain separately protected. |

## Files, SQL boundary and regression

| ID | Future executable assertions |
|---|---|
| F01 | Student photo, birth certificate and Employee photo link only to AVAILABLE files of their exact approved purposes. Wrong purpose, unavailable object, guessed file ID, wrong typed owner and wrong school reject. |
| F02 | A structurally valid file link does not authorize upload/download. Server path rechecks school entitlement, current actor permission/scope and typed owner relationship; signed URLs and provider credentials are never stored in D1 data or broad evidence. |
| L01 | `anon` and `authenticated` cannot DML D1 base tables. `service_role` has no application-grant shortcut. Authenticated EXECUTE is limited to enumerated fixed `app` RPCs; private evaluators, registrars and apply internals deny direct EXECUTE. |
| L02 | SECURITY DEFINER functions have exact expected owners, hardened search paths, no unreviewed PUBLIC grants and no recursive policy dependency. Test effective execution as each D1 executor and each non-owner role. |
| R01 | Frozen Foundation tests 01–09 still pass with their original expected assertions after D1 installation. New D1 tests must not weaken or rewrite those tests or Foundation migrations. |

This matrix is a **future assertion contract**, not a claim that Migration 10, D1 runtime behavior, approvals, file service or hosted deployment has passed. D1C must record actual per-test counts and first failure separately.
