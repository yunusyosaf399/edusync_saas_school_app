# D1C1B effect 20/36 — Employee experience SQL review

Status: implementation candidate; **not frozen** until exact-SHA CI and independent post-push audit pass.

Operation: `employee.experience.change`; P1 review permission `employee.experience.approve` when configured.

This candidate translates the approved external-experience contract without changing the frozen 97 permissions / 322 scope alternatives / 36 operation contracts. Migration 10 remains non-executable `.sql.draft`; D1C2 and remote/staging execution remain unauthorized.

## Implemented product semantics

- ADD creates a new server UUID `experience_record_id` lineage and accepted `effective_from` at server apply time.
- CORRECT is limited to the current open lineage head; it closes that snapshot at apply time and appends a successor with the same lineage.
- ARCHIVE closes the current lineage head with no successor and does not rewrite the professional `ends_on` fact.
- Different experience lineages may overlap; same-lineage reassignment to another Employee is denied.
- Exact factual no-op CORRECT is rejected; changing only `reason` cannot create another snapshot.
- Structured facts are `organization_name`, `role_title`, `starts_on`, optional `ends_on`, optional `summary`.
- `starts_on` and supplied `ends_on` cannot be future relative to accepted/apply date; supplied `ends_on` must be >= `starts_on`.
- INACTIVE/ENDED Employees remain eligible targets for authorized HR correction because this relation is prior/external history, not current-school employment eligibility.
- Current-school `employment_periods`, teaching capability, assignments and grants are not mutated.

## Authorization and route

- Exact `employee.experience.change`/`employee.experience.approve` complete Foundation grant chain only.
- Employee action authority is ALL or CAMPUS covering every current Employee campus; zero current campus requires ALL.
- Policy resolution is performed across every current Employee campus with campus-over-school fallback; all routes must converge.
- DIRECT/APPROVAL contradiction denies. APPROVAL requires one converged policy-version identity and valid D1 reviewer-role steps.
- Requester/reviewer same-Person separation is preserved.
- Every completed reviewer is revalidated with current exact approval authority at apply.
- Apply may be performed only by the current-authorized requester or final approver participant.

## Concurrency, idempotency and history

- Foundation `(71001,1)` is acquired SHARED through the effect-specific command context.
- Command-key idempotency uses the Foundation receipt key and a fixed-shape typed experience intent.
- Domain lock order is School -> Employee -> experience history.
- Successful replay returns the durable receipt result after current participant/authority/policy checks and does not require a predecessor to remain open.
- Deterministic stale policy/authority/history failures invalidate an APPROVED request with a REJECTED `request.apply` receipt; malformed protected payloads raise and roll back instead.

## Evidence boundary

Broad command receipts, audit and outbox omit `organization_name`, `role_title`, `summary` and arbitrary `reason` text. Audit/outbox retain only operation/action, Employee, snapshot/lineage/source refs and version/correlation evidence. Event vocabulary is `employee.experience_changed`; aggregate is `EMPLOYEE_EXPERIENCE` / resulting snapshot UUID / version 1.

The application guard binds EXECUTED request, successful apply receipt, operation, target version, Employee, experience lineage and result snapshot before an `approval_applications` row is accepted.

## Ordered candidate fragments

1. `effect20_01_experience_auth.sql.draft`
2. `effect20_02_experience_effect_evidence.sql.draft`
3. `effect20_03_experience_direct_submit.sql.draft`
4. `effect20_04_experience_review_apply_read.sql.draft`
5. `effect20_05_experience_application_guard.sql.draft`

No runtime deployment or executable migration is authorized by this review record.
