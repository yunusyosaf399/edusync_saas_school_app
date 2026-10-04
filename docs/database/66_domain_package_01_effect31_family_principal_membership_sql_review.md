# D1C1B Effect 31/36 — Family Principal Membership SQL Review

**Status: ACCEPTED STATIC RUNTIME CANDIDATE.**

Trusted runtime candidate: `077aacd3f07f4cd89fa7371fd90339429e88296f`.

Effect 31 implements frozen operation `family.principal_membership.change` as the P1 protected command family for linking an existing Foundation `FAMILY` Principal to a Family grouping through retained effective history. It does not create Principals/Auth bindings, Foundation roles/grants/scopes, relationship facts, child access, or primary context.

## Reviewed command surface

Application entry points are:

- `app.d1_change_family_principal_membership(...)` for P1 DIRECT;
- `app.d1_submit_family_principal_membership_change(...)` for P1 APPROVAL submission;
- `app.d1_review_family_principal_membership_change(...)` for the current configured review step;
- `app.d1_apply_family_principal_membership_change(...)` for explicit apply after approval;
- `app.d1_read_family_principal_membership_request(...)` for participant-only typed request read.

The approved actions are ADD, END and CORRECT. Principal replacement is never hidden inside CORRECT: changing the shared FAMILY Principal is END of the old membership plus ADD of the replacement Principal.

CORRECT repairs a prematurely ended membership by appending a same-Family/same-Principal successor exactly at the retained predecessor boundary through `supersedes_id`. The predecessor remains immutable retained history.

## Authorization and P1 routing

`family.principal_membership.change` is non-family-safe and ALL-only. Requesters are current authenticated INDIVIDUAL Principals with a complete live ALL/DIRECT chain for that exact permission. FAMILY membership itself grants no authority to administer membership.

APPROVAL reviewer candidates must be separate current INDIVIDUAL Principals/Persons and hold current `family.access.approve` through the exact configured reviewer role and ALL/DIRECT chain. Generic approval authority, a role name alone, requester authority, or FAMILY membership cannot substitute.

The final policy resolver fails closed unless exactly one currently effective compatible school-wide policy exists. Campus-specific or otherwise incompatible simultaneous policy material makes routing ambiguous and denies. Review never auto-applies. Apply rechecks current policy, requester authority, reviewer authority and domain state; stale approved state is invalidated instead of forced through.

## Principal readiness and revocation correction

ADD and CORRECT create or restore an effective membership and therefore require the target Foundation `FAMILY` Principal to be currently usable: correct kind/version plus current Principal/Auth/family-only/family-safe `OWN / D1_FAMILY_CHILD` readiness.

Independent audit found one late revocation defect in the earlier candidate: END also required that readiness. That could make an existing membership impossible to explicitly revoke after the FAMILY credential had already been disabled or had lost its Auth/family-safe chain.

Append-only continuation `effect31_17_membership_end_disabled_principal.sql.draft` corrects this. END now still locks and revalidates exact FAMILY Principal kind/version, Family/version, source membership ancestry and interval state, but it does **not** require the credential to remain login/permission-ready. ADD/CORRECT continue to require readiness.

This correction removes authority; it never creates or restores it.

## Concurrency and retention

The implementation follows the frozen lock hierarchy:

1. Foundation shared authorization lock and namespace-71002 idempotency serialization;
2. acting/requester/target Foundation Principals UUID-ascending;
3. Family row(s);
4. retained membership history.

Expected Principal and Family versions are bound and rechecked. Revocation therefore remains serialized against FAMILY-sensitive operations using the same Principal/Family anchors even when the target credential has already been disabled.

ADD requires ACTIVE Family. Family archive does not silently rewrite membership history. END is an explicit retained-history closure. CORRECT restores the same stable Family/Principal lineage only.

Strict overlap is denied by scanning retained Family membership intervals under the Family lock; adjacency is allowed. No normal delete exists.

## Idempotency and replay

Canonical intent binds Family ID/version, target Principal ID/version, action, source membership where applicable, effective date and private reason. Same key with changed intent conflicts.

Successful replay is retained-history based:

- ADD replay does not require the row to remain open;
- END replay proves the retained accepted closure;
- CORRECT replay proves the retained predecessor/successor lineage and boundary.

Approval application additionally proves the matching application/receipt/request/result relationship.

## Evidence and disclosure

The only successful domain event is `family.principal_link_changed`.

Broad audit/outbox evidence is minimized to typed identifiers, safe action/version/outcome and receipt/request/correlation evidence. Arbitrary reason text, Auth-user identifiers, labels, child data, relationship contacts and copied protected request JSON are not copied into broad evidence. Protected workflow state retains the private reason only where required.

## Least privilege

The Family executor remains NOLOGIN. Final Principal row-lock hardening leaves only `SELECT(id,kind,row_version)` plus immutable `UPDATE(id)` privilege required by PostgreSQL `FOR UPDATE`; broader Principal column/update privileges are revoked. Authenticated callers cannot directly invoke private preflight/effect/evidence helpers or table DML.

Effect 31 performs no mutation of Foundation roles, permissions, assignments, grants, scopes, Auth bindings or Principal identity, nor of Family relationship, child-access or primary-context rows.

## Exact-SHA gate

GitHub Actions run #193 (`37179696695`) completed successfully on exact SHA `077aacd3f07f4cd89fa7371fd90339429e88296f`.

Full log inspection confirms:

- exact checkout of the trusted SHA;
- 121/121 tooling unit tests;
- frozen Foundation source integrity (`9 migrations + 9 tests`);
- Supabase CLI 2.98.2 and Docker/Linux local stack;
- clean reset of nine frozen migrations with no seed;
- 5/5 Auth fixtures;
- lint error/warning gates passed;
- all nine Foundation TAP files passed, 220/220 assertions total.

This gate intentionally validates the frozen Foundation only. Migration 10 and Effect-31 continuation fragments remain `.sql.draft`; they were not parsed, executed, deployed or applied by this gate.

## Runtime boundary

The Effect-31 runtime SQL delta from Effect-30 freeze tip `9ce87c272c65e9b9c614405b8e7fbc8072e8227e` to trusted runtime SHA `077aacd3f07f4cd89fa7371fd90339429e88296f` is the 17 ordered Effect-31 `.sql.draft` continuation files (`effect31_01` through `effect31_17`). Foundation migrations 1–9 are unchanged. The manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.
