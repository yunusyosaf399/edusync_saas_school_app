# D1C1B Effect 30/36 — Family Relationship SQL Review

**Status: ACCEPTED STATIC RUNTIME CANDIDATE.**

Trusted runtime candidate: `3ae3bc65efb2e5f2d45c05b36d9c094f0d7c22e7`.

Effect 30 implements frozen operation `family.relationship.change` as the P1 ADD / END / CORRECT command family over retained `family_relationships` history. It also provides the corresponding approval workflow and fixed read surface. It does not create Family groupings, Principals, Auth identities, Foundation authorization grants, FAMILY memberships, or child-access entitlements.

## Reviewed command surface

The reviewed public mutation surface consists of:

- `app.d1_change_family_relationship(...)` for DIRECT routing;
- `app.d1_submit_family_relationship_change(...)` for APPROVAL submission;
- `app.d1_review_family_relationship_change(...)` for approval review;
- `app.d1_apply_family_relationship_change(...)` for explicit approved application.

The effect is represented by 29 ordered non-executable Migration-10 continuation drafts. Static review treats those continuations in order, so later `CREATE OR REPLACE FUNCTION` definitions are the authoritative final definitions.

Accepted domain actions are exact:

- `ADD` — create a new open relationship fact for an ACTIVE Family.
- `END` — end the selected current relationship at the accepted effective date while retaining history.
- `CORRECT` — end the selected current relationship and append a replacement relationship linked through `supersedes_id`.

## Authorization and routing

Authorization is rechecked through the exact `family.relationship.change` permission using the frozen interval-effective Student context. ALL, matching CAMPUS, matching CLASS, or matching SECTION authority may satisfy the operation according to the frozen scope alternatives; relationship existence itself grants no authority.

The active approval-policy version selects DIRECT or APPROVAL. APPROVAL binds the operation contract's review permission to `family.access.approve`, requires the configured reviewer role, and resolves reviewer candidates through live matching Student scope. A requester cannot review their own request, including through a second Principal for the same Person.

Review never auto-applies. Application is explicit and rechecks requester authority, live review authority, policy identity, target versions, replacement ancestry, and current domain preflight. Stale approved business state is deterministically invalidated rather than applied.

## Concurrency and retained ancestry

The final lock helper precollects retained source/replacement ancestry and locks involved rows in the frozen hierarchy: relevant Person rows, Student rows UUID-ascending, Family rows UUID-ascending, then relationship rows UUID-ascending. The effect then locks dependent primary/access history before mutation.

Cross-ancestry source or replacement substitution is rejected after locks are acquired. Optimistic Student and Family row versions are checked before accepted mutation.

## Relationship, primary-context, and access semantics

- ADD requires an ACTIVE target Family and does not silently create primary context or child access.
- END/CORRECT require an open, unsuperseded retained source relationship and an effective date strictly after its start.
- Duplicate overlapping relationship facts are rejected.
- CORRECT retains the source row, ends it, and appends the corrected row with `supersedes_id=source`.
- If END removes the relationship selected by an effective primary-family context and another selectable relationship exists, the caller must explicitly identify the replacement relationship. The server never guesses a replacement.
- A replacement must be effective for the Student on the change date, belong to an ACTIVE Family, and contain the affected primary-context interval.
- Future primary-context intervals that cannot be transformed safely are rejected.
- END examines affected `family_student_access` intervals and closes access only when the ended relationship was the final relationship basis for that access interval. Access still justified by another retained relationship remains open.
- Future access dependencies that would create an invalid interval are rejected instead of producing zero-length or structurally inconsistent history.

Archived Families cannot receive new ADD relationships. Retained existing relationship history remains correctable/endable according to the frozen rules.

## Idempotency and replay

Canonical intent binds the Student, expected Student version, Family, expected Family version, action, source relationship, new relationship facts, effective date, reason, explicit primary replacement, and command-specific request/review/apply fields.

Successful replay validates typed retained result evidence rather than requiring the result to remain the current open lineage head. Consequently a previously successful ADD/CORRECT receipt remains replayable after later legitimate relationship evolution. END replay likewise proves the retained ended relationship and typed dependent-effect evidence without comparing against unrelated later access endings.

Receipt result shapes are exact and NULL-safe. Malformed or semantically mismatched receipt summaries fail closed.

## Evidence and disclosure boundary

Successful domain effects emit minimized typed receipt, audit, and outbox evidence. Broad evidence carries identifiers and safe action/version/state metadata only. It does not copy display name, relationship contact, reason text, arbitrary request JSON, child profile data, or unrelated private values.

Approval request payloads retain only the private facts required to review/apply the exact requested change. Evidence helpers and application guards validate the operation/result linkage before accepting retained application evidence.

## Exact-SHA gate

GitHub Actions run #173 (`37140015253`) completed successfully on exact SHA `3ae3bc65efb2e5f2d45c05b36d9c094f0d7c22e7`.

Full log inspection confirms:

- exact checkout of the trusted SHA;
- 121/121 tooling unit tests;
- frozen Foundation source integrity (`9 migrations + 9 tests`);
- Supabase CLI 2.98.2 and Docker/Linux local stack;
- clean reset of nine frozen migrations with no seed;
- 5/5 Auth fixtures;
- lint error/warning gates passed;
- all nine Foundation TAP files passed, 220/220 assertions total.

This gate intentionally validates the frozen Foundation only. Migration 10 remains `.sql.draft`; Effect-30 SQL was not parsed, executed, deployed, or applied to a local/managed project by this workflow.

## Runtime boundary

The Effect-30 runtime delta from the Effect-29 trusted runtime SHA `a319c946fdde033d54b8755aa6176b4600aff956` to `3ae3bc65efb2e5f2d45c05b36d9c094f0d7c22e7` contains the four Effect-29 review/freeze documents plus 29 ordered Effect-30 `.sql.draft` continuation files. Foundation migrations 1–9 are unchanged. The manifest remains **97 permissions / 322 scope alternatives / 36 operation contracts**.

The four Effect-29 documents are documentation-only predecessor-freeze records and do not change runtime semantics.