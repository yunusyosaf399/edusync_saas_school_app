# Section 02 - Foundation, authentication and access control

Status: IN PROGRESS, 1 November 2026. Backlog DB-012 through DB-024.
This ledger reports implementation acceptance, not only architecture decisions.
Section 01 is closed by merged PR #197 / main `1dc58ec`; its remaining physical
implementation gates are retained in the owning domains.

## Scope and current increment

The owner authorized minor Section 03 dependencies in the Section 02 chat.
Do not wait for all D1 or Admissions work to finish before advancing independent
Foundation/security tasks. Reuse existing D1 relations and commands. No frozen
Foundation migrations 1-9 or frozen tests 01-09 change. No hosted deployment,
new real accounts, grant seeds, Flutter implementation or external service setup.

Current increment adds 12 rollback-only assertions to D1 business suite 28
(67 -> 79). Existing executable SQL is unchanged. One real synthetic Auth user
is bound to one FAMILY principal with existing family-safe OWN grants. Two
children have real PRIMARY enrollments in separate campuses and retained rolls.
The second child has a separate approved relationship fixture and a real
protected child-access ADD; a relationship alone still denies reads.

The test verifies first and second child roster access, exact second Section,
separate profile disclosure, restricted-identity denial, existing-token denial
for both children after principal suspension, protected first-child revocation,
and survival of second-child roster/profile access. Fixture suspension is a
schema-owner setup, not a newly implemented account-suspension command. The
case forces deferred constraints and rolls back to its savepoint before the
original one-child revocation/receipt assertions. Whole-suite rollback remains.

## Acceptance ledger

| Task | Current evidence / remaining acceptance |
|---|---|
| DB-012 Frozen Foundation | Nine migrations and nine frozen suites retained. Source/config guard passes locally. Exact-head runtime evidence is recorded in the PR. |
| DB-013 Identity / username-email login | Server-only login service, private worker resolver and committed rate counters implemented as an inactive candidate; 24 unit tests PASS. Exact real Auth/PostgreSQL results are tracked in [PR #200](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/200). See the [login boundary](../security/10_school_login_boundary.md). HTTP hosting and release activation remain OPEN. |
| DB-014 Staff/shared-family credentials | A new inactive, protected suspension-command candidate checks current individual authority, locks the school, and appends receipt/audit/outbox. Disposable Auth/PostgreSQL CI now exercises its live denial and replay. Creation, revocation, recovery and Auth session cleanup remain OPEN; no production operation or permission is seeded. |
| DB-015 Authorized multiple children | PR #198 merged at 3b13992. Suite 28 passed 79/79, full D1 business 3270/3270 and Foundation 220/220 on tested head 30f1218. D1 migration release remains separate. |
| DB-016 Planned-role/action catalog | Current master specification role catalog and D1 97 permissions exist. Later module action catalogs/default role mappings need domain-specific registration and acceptance; no blanket role grants added. OPEN across planned modules. |
| DB-017 Typed scopes | Existing Foundation/D1 ALL/CAMPUS/CLASS/SECTION/SUBJECT/OWN/ASSIGNED contracts reused; academic year derives from typed offering ancestry. Later consumer acceptance stays OPEN. |
| DB-018 Teaching assignment authority | Existing class/subject teacher tests and resolvers reused. Attendance and marks consumers need exact effective-assignment tests when implemented. OPEN across those consumers. |
| DB-019 Protected surfaces | Foundation/D1 private schemas, forced RLS and fixed commands exist. Later domains must register protected reads/commands; absence of direct grants is preserved. OPEN across planned domains. |
| DB-020 Live authority / retries | Existing revocation/race suites plus new suspended-FAMILY two-child read checks. Full delayed/offline consumer and credential lifecycle acceptance remains OPEN. |
| DB-021 Workflow reuse | Existing Foundation workflow and typed D1 P1/P2 consumers retained. Exam/HR/final Admissions integration remains domain-owned and OPEN. |
| DB-022 Independent review / staleness | Existing requester/reviewer, stale policy/version/grant and P1/P2 tests retained. No claim that every future consumer is accepted. OPEN across domains. |
| DB-023 Receipt/audit/outbox | Existing atomic D1 command evidence and original suite 28 receipt/outbox checks retained. All-domain acceptance remains OPEN. |
| DB-024 Negative security tests | Existing wrong-campus, revoked-grant and private-table/function tests retained; new sibling isolation and suspended-principal cases added. Exact-head CI and later-domain security evidence remain required. |

This does not close Section 02 or Section 03. Counts of tests are evidence, not
completion percentages. Architecture closure does not substitute for executable
login/lifecycle functionality or all-domain consumer acceptance.

## Section 03 handoff - do not rebuild these prerequisites

1. Retain `family_principal_memberships`, `family_relationships` and
   `family_student_access` as separate sources. Neither shared credentials nor
   a guardian relationship silently creates child entitlement.
2. Use existing protected `app.d1_change_family_child_access` and checked reads
   `app.d1_read_student_roster` / `app.d1_read_student_profile` with the current
   `D1_FAMILY_CHILD` resolver. One FAMILY principal may have independent access
   to several children in different campuses. No parent-wide campus wildcard.
3. Revoking one child must preserve other authorized children. Suspending the
   FAMILY principal denies every child even with an already issued JWT.
4. Keep shared FAMILY and individual staff identities separate; display numbers
   are lookup identifiers, never authorization. Preserve ADR-007 permanent
   Student UUID/Student ID/admission number and enrollment-effective roll rules.
5. ADR-007 one-open-application-per-applicant enforcement, pre-Person identity
   resolution, allocator/Student handoff and races are substantive DB03/D1 work,
   not a minor dependency of family login. No duplicate command or alternate
   schema is introduced here; those items remain explicitly OPEN.
6. Keep Migration 10 draft-only pending its source composition, populated
   upgrade, authorization/release gates. These new tests do not activate it.

Affected paths: suite 28, its expected count in `domain_business_ci.py`, and
cumulative expected totals in `test_domain_acceptance_ci.py` and
`test_domain_db01_prerequisite_ci.py`. No role, SQL
function, migration or catalog semantics changed. Other chats touching those
test registries must preserve this increment when composing their branches.

## Validation and next implementation

Local Foundation source/config guard and 73 acceptance tooling tests PASS.
D1 static source guard PASS (243 fragments, 34 relations, 97 permissions,
322 scope alternatives). These are source/tool checks, not PostgreSQL runtime.
The PR must record exact-head Foundation and D1 runtime status separately.

The next DB-014 slice is `supabase/proposals/section02_credential_suspend.sql.draft`.
It requires an explicit live non-family `identity.credential.suspend` ALL grant,
the matching enabled direct operation contract, a different active individual
actor, active School and exact target version. Both family and staff targets
can be suspended; an actor cannot suspend itself. A replay with the same intent
returns the original receipt without another event. The school-wide exclusive
authority lock serializes the state change with grant and binding changes.
The candidate installs no catalog rows or grants. The disposable test creates
its own synthetic role, permission, operation and Auth accounts. Its direct
SQL JWT fixture models trusted gateway claims and is not a production auth path.
Existing alias constraints remain private. Other DB-014 creation/recovery work
continues independently of the Section 03 Admissions release.

No owner PC, hosted Supabase activation, SMTP subscription or other external
service is required for the current disposable GitHub Actions tests. Actual
Auth/recovery delivery configuration must be reported before that integration
is activated; this increment does not choose a provider or request credentials.
