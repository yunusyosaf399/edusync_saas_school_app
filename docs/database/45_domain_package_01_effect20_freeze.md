# D1C1B Effect 20/36 — Employee experience change freeze

**Status: FROZEN.** Trusted implementation SHA: `91e05dc0eef35144f1b0e37263ed50703b83756d`.

## Operation

- Operation: `employee.experience.change`
- Approval permission when configured: `employee.experience.approve`
- Event: `employee.experience_changed`
- Relation: `app_private.employee_experience_entries`
- Effect class: P1 policy-reviewed DIRECT/APPROVAL

## Frozen business semantics

1. ADD creates a new independent experience lineage with server-generated `experience_record_id` and server apply-time `effective_from`.
2. CORRECT applies only to the current open lineage head, closes it at apply-time, and appends a successor with the same lineage. Correctable facts are organization, role title, start date, end date, and optional summary.
3. ARCHIVE terminally closes the current lineage head without rewriting the professional `ends_on` fact or creating a successor. Reintroduction requires ADD and a new lineage.
4. No-op CORRECT is rejected based on the professional experience facts; reason-only changes do not create snapshots.
5. `starts_on` must not be in the future. `ends_on`, when supplied, must satisfy `ends_on >= starts_on` and must not be in the future. Ongoing experience uses `ends_on = NULL`.
6. External/prior professional experience is independent of current-school employment state. INACTIVE/ENDED Employees remain correctable when current authority is otherwise valid.
7. Employee-global P1 routing uses all current Employee campus affiliations. Authority requires ALL or CAMPUS coverage for every current affiliation. Policy resolution across those campuses must converge on one route; APPROVAL must converge on one policy identity. With no current campus, ALL authority plus one school policy is required.
8. Organization/title/summary/reason free text stays out of broad audit/outbox/receipt evidence.

## Concurrency and authorization

Every mutation takes the Foundation authorization lock SHARED, then command-key/workflow locks as applicable, then School → Employee → experience-history anchors. Lineage ownership is checked under that serialization. Assignment or experience facts grant no RBAC authority.

Requester/reviewer Person separation, reviewer-role scope, current requester authority, every completed approval reviewer's current authority, and current policy are rechecked. Deterministic approved-request failures become `APPROVED → INVALIDATED` with a REJECTED apply receipt and no mutation/application/success event. Malformed stored payload and transient/unclassified failures rollback instead of invalidating. Terminal replay occurs before predecessor-open mutation preflight and returns durable evidence without duplicate mutation/event.

## Evidence and packaging

- Broad audit/outbox contain identifiers and classification only; no organization/title/summary/reason text.
- Successful APPROVAL application is bound to request, operation, receipt, resulting experience snapshot, lineage and target version by the effect-specific application guard.
- Aggregate is `EMPLOYEE_EXPERIENCE`; aggregate reference is the resulting experience snapshot; aggregate version is `1`.
- Public RPC ownership and ACL are explicit; authenticated has EXECUTE only on checked RPCs and no direct base-table DML.
- Post-CI audit corrected the canonical DIRECT/SUBMIT intent arity from 10 to the actual 11 fields in continuation `effect20_02a_experience_intent_shape.sql.draft`. This did not change product semantics.

## Exact-SHA CI evidence

GitHub Actions workflow `Foundation database (local stack)` run **#48**, run id `37093252954`, checked out exact SHA `91e05dc0eef35144f1b0e37263ed50703b83756d` and completed successfully:

- tooling unit tests: **121/121**
- Foundation source/config gates: PASS
- Supabase CLI pin: `2.98.2`
- local reset: nine frozen migrations, no seed
- auth fixtures: **5/5**
- lint error/warning gates: PASS
- pgTAP files 01–09: **220/220** total
- final marker: `FOUNDATION_LOCAL_CI_PASS 9 files / 220 planned / 220 passed; serial execution`

The GitHub runner Node.js deprecation warning is tooling-provider maintenance noise, not a project failure.

Migration 10 remains `.sql.draft` and non-executable. D1C2 and remote/staging application remain unauthorized. This CI is a source/Foundation regression gate and is not a claim that Migration 10 draft SQL executed in PostgreSQL.
