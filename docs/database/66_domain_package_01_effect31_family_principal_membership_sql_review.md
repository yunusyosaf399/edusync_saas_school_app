# D1C1B Effect 31/36 — Family Principal Membership SQL Review

**Status: ACCEPTED STATIC RUNTIME CANDIDATE.**

Trusted runtime candidate: `e93bf31d60d0a7afff8215fd5a2ca732f850a04c`.

Effect 31 implements frozen operation `family.principal_membership.change` as the P1 protected command family for linking an existing Foundation `FAMILY` Principal to a Family grouping through retained effective history. It does not create Principals/Auth bindings, Foundation roles/grants/scopes, relationship facts, child access, or primary context.

## Reviewed command surface

Application entry points are:

- `app.d1_change_family_principal_membership(...)` for P1 DIRECT;
- `app.d1_submit_family_principal_membership_change(...)` for P1 APPROVAL submission;
- `app.d1_review_family_principal_membership_change(...)` for one review decision at the current open step;
- `app.d1_apply_family_principal_membership_change(...)` for explicit apply after approval;
- `app.d1_read_family_principal_membership_request(...)` for participant-only typed request read.

The approved business actions are ADD, END and CORRECT. Principal replacement is never hidden inside CORRECT; changing the shared FAMILY Principal is represented as END of the old membership plus ADD of the replacement Principal.

The final retained-history correction semantics are aligned to the HE lineage: CORRECT repairs a prematurely ended membership by appending a same-Family/same-Principal successor exactly at the closed predecessor boundary through `supersedes_id`. The predecessor remains retained. This preserves immutable Family/Principal identity within one correction lineage.

## Authorization and P1 routing

`family.principal_membership.change` remains a non-family-safe, ALL-only staff permission. Requesters are current authenticated INDIVIDUAL Principals with a complete live ALL/DIRECT grant/scope chain for the exact permission. FAMILY membership itself grants no authority to administer membership.

When policy selects APPROVAL, reviewer candidates must be separate current INDIVIDUAL Principals/Persons and must hold current `family.access.approve` through the exact configured reviewer role and ALL/DIRECT chain. Generic approval permission, role name alone, requester permission or current FAMILY membership cannot substitute.

The final policy resolver fails closed unless exactly one currently effective compatible school-wide policy exists. Campus-specific or otherwise incompatible simultaneously effective policy material makes routing ambiguous and therefore denies. APPROVAL also requires valid configured sequential step templates, one required review per step and `D1_REVIEWER_ROLE_SCOPE` selection.

Review never auto-applies. Apply rechecks current policy, requester authority, reviewer authority and target/domain state. Stale approved state is deterministically invalidated instead of forced through.

## Principal readiness and authority separation

The target membership Principal must be a Foundation `FAMILY` Principal. ADD/CORRECT/revocation readiness is checked against current Principal state, current Auth binding and a live family-only/family-safe `OWN / D1_FAMILY_CHILD` chain. This is readiness for a shared FAMILY credential, not itself child entitlement: actual child access remains a separate Effect-32 fact and later resolver check.

No path creates or changes Foundation role assignments, permission grants, assignment scopes, Auth bindings or Principal identity. The D1 `family_principal_memberships.principal_kind='FAMILY'` structural FK remains the stored kind barrier.

## Concurrency and locking

The generic receipt phase first takes the frozen shared Foundation authorization advisory lock and command-key idempotency lock. The Effect-31 domain order then follows the frozen Principal-before-Family rule:

1. acting/requester/target Foundation Principals collected and locked UUID-ascending;
2. affected Family rows locked UUID-ascending;
3. membership history rows locked/scanned before mutation.

The target Principal expected row version and Family expected row version are bound and rechecked. Revocation therefore synchronizes against concurrent FAMILY-authorized operations that use the same Foundation/Family lock discipline.

The final privilege correction at `e93bf31d...` minimizes the Family executor's Principal row-lock capability to `SELECT(id,kind,row_version)` plus the immutable `id` UPDATE privilege PostgreSQL requires for `FOR UPDATE`; broader Principal columns/update privileges are revoked. The executor remains NOLOGIN and no authenticated client receives direct Principal-table DML.

## Retention and interval behavior

- ADD requires an ACTIVE Family and creates one open retained membership interval.
- END requires the selected unsuperseded open source and closes it once at an exclusive end date after its start.
- CORRECT requires an already closed retained predecessor and appends the same-Family/same-Principal successor exactly at that predecessor end boundary.
- Family archive is not silently converted into membership revocation; retained END/CORRECT history remains a separate explicit command concern.
- Overlap validation scans retained Family membership intervals rather than only current lineage heads, matching the defensive HE non-overlap rule.
- No normal delete exists.

## Idempotency and replay

Canonical command intent binds Family ID/version, target Principal ID/version, action, source membership where applicable, effective date and private reason. Reusing a key with changed business intent conflicts.

Successful replay is proven against retained rows and exact typed result-summary shape. An ADD remains replayable after a later END; an END remains replayable after a later legitimate CORRECT successor because replay does not require the accepted row to remain the current open lineage head.

APPROVAL request state stores only the typed protected shape required for later review/apply. Application evidence is guarded against mismatched operation/request/receipt/result/version combinations.

## Evidence boundary

Successful domain effects emit only `family.principal_link_changed`.

Broad audit/outbox evidence is minimized to typed identifiers, action, safe versions/state and receipt/request/correlation evidence. Arbitrary reason text, Auth-user identifiers, labels, child data, relationship contacts and copied protected request JSON are not copied into broad evidence. The private reason remains in protected command/request history where required by the workflow.

## Exact-SHA gate

GitHub Actions run #192 (`37177474863`) completed successfully on exact SHA `e93bf31d60d0a7afff8215fd5a2ca732f850a04c`.

Full log inspection confirms:

- exact checkout of the trusted SHA;
- 121/121 tooling unit tests;
- frozen Foundation source integrity (`9 migrations + 9 tests`);
- Supabase CLI 2.98.2 and Docker/Linux local stack;
- clean reset of nine frozen migrations with no seed;
- 5/5 Auth fixtures;
- lint error/warning gates passed;
- all nine Foundation TAP files passed, 220/220 assertions total.

This gate intentionally validates the frozen Foundation only. Migration 10 and the Effect-31 continuation fragments remain `.sql.draft`; they were not parsed, executed, deployed or applied by this review.

## Runtime boundary

The delta from the Effect-30 freeze tip `9ce87c272c65e9b9c614405b8e7fbc8072e8227e` to the trusted Effect-31 runtime candidate consists only of 16 ordered Effect-31 `.sql.draft` continuation files. Foundation migrations 1–9 are unchanged. The frozen manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

Independent review included the already-landed corrections for frozen Foundation Principal shape, correction lineage semantics, evidence/replay shape hardening, incompatible-policy fail-closed behavior, FAMILY target readiness, revoke readiness, retained-history overlap scanning and minimized Principal row-lock privilege. No further blocking defect remained at the trusted runtime SHA.
