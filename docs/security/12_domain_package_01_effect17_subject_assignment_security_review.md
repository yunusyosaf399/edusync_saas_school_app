# D1C1B Effect 17/36 — Subject Teacher Assignment Security Review

Status: **candidate pending independent review and CI**.

Baseline: `6b60fb5d93ab13359682837cfb948a16234e0ede`.

## Authorization boundary

`teaching.subject_assignment.change` is non-family-safe TS authority. The command
accepts only one complete live DIRECT permission chain through:
- ALL;
- matching CAMPUS;
- exact SECTION; or
- exact SUBJECT represented by the exact Section Offering + Subject pair.

CLASS is deliberately not accepted. An existing Subject Teacher assignment,
Employee Campus Affiliation, Department, Designation, qualification, creator
identity, or teaching ASSIGNED resolver never becomes mutation authority.

Retroactive CORRECT review additionally requires the current
`teaching.assignment.approve` permission, the configured active reviewer role,
the same affected Section+Subject scope rules, and requester/reviewer Person
separation. There is no generic administrator fallback.

## Self-assignment

ADD/CORRECT reject a requester whose active INDIVIDUAL principal Person resolves
to the destination Employee. END does not create a destination assignment and
therefore does not use the self-assignment test.

## Locking and TOCTOU control

After the Foundation authorization/receipt path, the command discovers all source
and destination Employee IDs and locks Employees in UUID order. It then follows:
Academic Class → Campus → Academic Year → Class Offering → Section Offering →
Subject → employment periods → Teacher Capability → exact Section+Subject
assignment history.

The destination's ACTIVE employment and Teacher Capability are rechecked for the
entire requested interval while those dependency rows are locked. P2 apply repeats
the context locks and authority checks after approval, so approval is not a stale
authorization token.

## P2 lifecycle

Retroactive CORRECT alone is P2:
1. submit stores an exact old/requested payload;
2. reviewer candidates require the configured `D1_REVIEWER_ROLE_SCOPE` role/step,
   live review permission and Person separation;
3. review records a decision against an expected request version;
4. explicit apply rechecks requester authority, reviewer authority, policy,
   Section version, source facts, Subject, Employee eligibility and overlap rules;
5. deterministic business/state failures transition APPROVED→INVALIDATED and write
   a REJECTED `request.apply` receipt;
6. unclassified SQL/infrastructure failure is not converted into INVALIDATED and
   instead rolls the transaction back.

The operation-specific `approval_applications` trigger accepts a successful
application only when its receipt, request, source, successor, Subject, kinds,
dates and target version agree.

## Disclosure

The checked request read returns only workflow state plus:
Section, Subject, action, source assignment/Employee/kind/start, requested
Employee/kind, and requested dates. It does not expose private reason text,
arbitrary workflow JSON, identity/profile fields, authorization internals,
receipts, or broad audit data.

Audit/outbox evidence includes IDs, kind, dates and Section version but excludes
the protected reason. Successful effects emit only
`teaching.subject_assignment_changed`.

## Privilege surface

Authenticated receives EXECUTE only on the five exact public RPCs and receives no
new base-table DML. Private helpers revoke PUBLIC/anon/authenticated/service_role
EXECUTE and are granted only to the narrow NOLOGIN executor roles that need them.
Relation-34 broad provisional SELECT/INSERT is replaced with explicit retained
history columns; the previously reviewed one-way history end update remains.

The 14 ordered continuations are `.sql.draft` files and are not executed. They do not change the 97/322/36
catalog manifests and do not authorize D1C2 or any remote Supabase action.
