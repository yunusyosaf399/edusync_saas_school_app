# D1C1B security SQL review — in progress

**Status: INCOMPLETE STATIC DRAFT.** Migration 10 remains
`supabase/migrations/20260928000000_domain_package_01.sql.draft`. It has not
been executed, and its broad provisional D1 executor policies are not approved
as the final authorization boundary. Do not activate D1 operations or rename
the file to `.sql` on the basis of this review.

## Accepted checkpoint

Commit `ee7d9adf8718e5a9f2afb0c2c426337fd7eea5a5` is an accepted
**partial** D1C1B checkpoint. It already supplied the exact approved
`deployment-bootstrap` SYSTEM actor UUID/purpose check, 97 permission rows,
322 scope alternatives, 36 operation contracts, and the ten product-owner
approved P1 reviewer permissions and operation mappings. Those are inherited
from that checkpoint, not new work in this continuation. Registration remains
private, post-bootstrap, disabled by default, and uninvoked by the migration.

## Continuation work under static review

- A D1 business actor is restricted to an ACTIVE INDIVIDUAL or FAMILY Principal;
  SYSTEM Principals cannot enter the ordinary D1 evaluator. The existing
  same-chain Foundation authority query and six named contextual resolvers
  remain the basis for further review. Subject-teacher resolution now requires
  an explicit Subject, and an Employee-campus target can be evaluated against
  the particular stored affiliation row rather than a different concurrent
  affiliation.
  The evaluator and P1 policy selector are declared `VOLATILE` so a protected
  command can make a fresh authorization/policy read after waiting on its row
  locks; declaring either `STABLE` would risk retaining the calling statement's
  earlier snapshot. This is a static concurrency correction, not a runtime
  concurrency test.
- The product owner selected an explicit P1 route field. The draft adds
  nullable `approval_policy_versions.d1_route_mode` with `DIRECT` and
  `APPROVAL` values, preserves existing Foundation rows, and freezes a
  selected route after activation. This was a **product-owner-approved
  clarification discovered during SQL translation**: approval-step count is
  validation evidence, never the source of truth for the mode. A private P1
  selector recognizes only the frozen P1 codes and requires exactly one
  applicable active policy. Missing/invalid mode denies; `DIRECT` selects the
  protected direct path regardless of template count; `APPROVAL` requires at
  least one structurally valid sequential step with an ACTIVE reviewer role
  and denies direct application. Policy
  activation checks the P1 mode/step requirement, and a mandatory-approval
  operation cannot select `DIRECT`; the two mixed P0-current/P2-retroactive
  teaching contracts likewise cannot use the field to select `DIRECT`. P0
  retains its frozen direct contract; P2 retains mandatory approval. This is
  draft SQL, not a runtime-proven
  workflow.
- Fixed, typed checked-read functions have been added for the approved
  Academic, Student, Family, Employee, and Teaching current/history disclosure
  families. Current FAMILY Emergency Contact returns only display name,
  relationship, phone, and email. FAMILY relationship/summary reads filter
  each returned Family row to the caller's current membership, preventing
  one child's other Family records from appearing through that projection.
  Current and retained relationship rows additionally require current
  child-access evidence for that **same** Family; a grant through another
  Family cannot disclose them.
  Sensitive Student identity/Special and Employee restricted identity remain
  separately permissioned from roster/profile. Historical reads use their
  separate history permission and present grant checks. These interfaces
  still require independent field-by-field and non-owner review.
- A private receipt lookup now takes the Foundation authorization SHARED lock,
  a namespace-71002 SHA-256-derived command-key lock, and the current actor
  row lock before comparing the full immutable receipt tuple. A first fixed
  `academic.class.change` P0 draft demonstrates typed create/update/archive,
  expected version, postlock reauthorization, atomic receipt, safe audit, and
  selected outbox event. This single command has not been SQL-executed or
  generalized to the other operation contracts.

## Open completion gates

1. The complete 36-operation ledger is not implemented. In particular,
   `student.create` remains unavailable pending the approved Admissions
   handoff; 34 of the other 35 supported effects still need fixed typed
   commands or reviewed private workflow apply paths. The first Academic Class
   command also needs independent static and later runtime review.
2. Foundation receipt/idempotency, P0/P1/P2 application, reviewer-step
   eligibility, source/destination lock and reauthorization, safe audit/outbox,
   and capacity-override command evidence remain unimplemented.
   Foundation's `selection_resolver_key` has only a nonblank constraint; a
   reviewed executable reviewer-selection value/behavior is still needed
   before an `APPROVAL` route can be considered implementation-complete.
3. The provisional broad executor `USING (true)`/`WITH CHECK (true)` policies
   and DML grants still require final narrowing, along with the function
   EXECUTE allowlist and file-service authorization boundary.
4. Static SQL syntax and privilege review, complete inventory, manifest
   recount, and the required Foundation guard/staging validation must be
   repeated at completion. D1C1C and D1C2 are separate and unauthorized.

This document is a continuation work record, **not** a D1C1B PASS or an
independent review approval.

## Interim static inventory

An independent lexical recount of the registrar VALUE lists in this working
draft found **97/97 unique permission IDs/codes**, **322/322 unique scope IDs**
for the approved 97 permission codes, and **36/36 unique operation IDs/codes**.
The current draft has 47 public `app.d1_read_*` functions, one public D1
business command, 71 `SECURITY DEFINER` function declarations, 202 policy
declarations, 34 D1 `FORCE ROW LEVEL SECURITY` statements, and the five named
D1 executor-role declarations. These are text counts, not PostgreSQL catalog
counts or proof that the SQL parses and runs.

During this continuation, `foundation_guard.py --future report` returned
`FOUNDATION_SOURCE_PASS 9 migrations + 9 tests` and `LOCAL_CONFIG_PASS`;
`foundation_staging.py validate` returned `STAGING_VALIDATE_PASS`, and
`git diff --check` found no whitespace errors. These checks cover the frozen
Foundation/config boundary and formatting. No D1 SQL or remote operation was
executed. All counts and checks must be repeated after the remaining command
and policy work.
