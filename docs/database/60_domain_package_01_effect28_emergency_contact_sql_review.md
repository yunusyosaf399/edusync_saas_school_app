# D1C1B Effect 28/36 — Student Emergency Contact SQL Review

**Status: PASS / ready to freeze.**

Trusted runtime SHA: `a2d725b4bddbd4df1d891f10c091e0547dbaf20d`.

Effect 28 implements `student.emergency_contact.change` as the frozen P1 ADD / END / CORRECT command family over retained `student_emergency_contacts` history. The comparison from the Effect-27 freeze baseline `907d35e757b79acfb5dc68702ad3456958f46321` to the trusted runtime SHA contains only 17 ordered Effect-28 `.sql.draft` continuations. No Foundation migration/test, Flutter, Supabase config, deployment tooling, or Effect-29 artifact is part of the runtime delta.

## Reviewed domain behavior

- ADD creates a new independent Emergency Contact lineage at the caller-supplied accepted business date.
- END closes one selected open lineage head at the supplied exclusive end date and creates no successor.
- CORRECT closes one selected open lineage head and appends a successor using `supersedes_id`.
- CORRECT rejects factual no-ops; a changed administrative reason alone does not manufacture a new contact snapshot.
- Multiple distinct contacts may coexist. Existing-Person contacts are duplicate-checked by Person; standalone contacts use normalized name plus phone identity.
- Person-backed contact rows do not create Family membership, child access, guardian authority, pickup/custody authority, or Foundation role/grant/scope facts.
- Source chronology, open-head status, Student version, duplicate identity, and proposed facts are revalidated under the protected command path.
- Student is the concurrency/authorization anchor. Current placement ancestry is re-resolved while the Student row lock is held.

## P1 workflow

The operation supports deployment-selected DIRECT or APPROVAL routing. Missing, ambiguous, or incompatible policy fails closed.

APPROVAL preserves the hardened transaction split:

`submit -> review -> APPROVED -> explicit request.apply`

Requester/reviewer separation is enforced at Principal and Person level. Review/apply recheck current reviewer/requester authority and the exact Student context. Deterministic approved-request staleness invalidates with a rejected apply receipt and no domain effect; malformed protected state and unclassified SQL failures roll back.

The application guard binds the successful apply receipt and request to the exact reviewed contact facts and source facts before an `approval_applications` row can exist.

## Independent audit corrections

Two defects were found after the initial Effect-28 candidate and were corrected before freeze:

1. **Canonical reason binding** — DIRECT and request.submit accepted and retained a private `reason`, but the original canonical idempotency intent omitted it. Commit `f03767cac118a6547733850ba8dcbd9ba21ab7e5` adds `reason` to both canonical intents and changes the expected intent length from 10 to 11. The reason remains excluded from broad audit/outbox payloads.
2. **Retained-history replay** — the original result verifier required successful ADD/CORRECT result rows to remain open forever. Commit `a2d725b4bddbd4df1d891f10c091e0547dbaf20d` instead proves replay from the retained receipt summary plus immutable lineage facts, so a valid old command remains replayable after a later legitimate END/CORRECT without weakening result binding.

## Evidence and privacy

Successful domain effects emit only `student.emergency_contact_changed`. Broad audit/outbox evidence contains safe identifiers/action/correlation evidence only. Contact name, relationship text, phone, email, and arbitrary reason text are not copied into broad audit/outbox payloads. Sensitive proposed/current contact values remain available only inside the protected workflow/domain surfaces required for review and apply.

## Authorization / ACL boundary

- Business mutation uses the existing `student.emergency_contact.change` permission and current Student ACS ancestry.
- Review uses `student.emergency_contact.approve`, the configured reviewer role, exact workflow step, exact Student scope, and requester separation.
- Foundation authorization advisory lock `(71001,1)` remains SHARED for D1 business paths.
- No command mutates Foundation grants, roles, scopes, Family relationships/access, or guardian authority.
- Public RPCs remain typed; authenticated users receive no direct D1 base-table DML.
- Private helpers remain executor-only and no schema-owner runtime shortcut was introduced.

## Exact-SHA validation

GitHub Actions run #142 (`37134286751`) completed successfully on trusted runtime SHA `a2d725b4bddbd4df1d891f10c091e0547dbaf20d`. The workflow job reports successful Tooling unit tests, Frozen Foundation integrity, and Clean local Foundation validation.

This remains a source/static gate: all Effect-28 SQL files are `.sql.draft`. Migration 10 was not executed locally, on staging, or on a managed Supabase project by this Effect-28 gate.

## Frozen manifest boundary

Effect 28 registers no new permission, scope alternative, or operation contract. The D1B4 deployment manifest remains:

- **97 permissions**
- **322 permission/scope alternatives**
- **36 operation contracts**

**Verdict:** `D1C1B STUDENT.EMERGENCY_CONTACT.CHANGE PASS — EFFECT 28/36 READY TO FREEZE — MIGRATION 10 REMAINS NON-EXECUTABLE`.
