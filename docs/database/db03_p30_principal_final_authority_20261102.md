# DB03 P30 — Independent Principal final-decision authority (2 November 2026)

**Status: inactive security prerequisite; no admission decision or Student creation.** Based on DB03 #203 at merge commit `b370ccb00e712fa399e73fa5c68929a14a8ffb40`, after P29 immutable RETURN/REJECT history.

## Why separate authorization

The Principal's existing `admission.document.approve` scope authorizes verification of **document evidence only**. It must not silently authorize an irreversible final admission, a RETURN/REJECT decision, Student identity, fees, Roll, Enrollment, or child access. P30 introduces an independent, strictly scoped **source** for a future `admission.final.decide` operation without registering that operation or permission in production. Neither the operation nor any assignment is created or enabled by this candidate.

## Private implementation

- `app_private.db03_principal_final_authority(actor,campus)` (owner `schoolos_authz_reader`, fixed SECURITY DEFINER, no public grant) returns an authority digest only when a **distinct enabled** `admission.final.decide` operation and enabled non-family permission exist, an active INDIVIDUAL is bound to a real Auth user, and the same live direct assignment/grant/scope chain has immutable role code `PRINCIPAL`. The existing School-wide or exact Campus scope, validity and revocation windows are evaluated at request time. It does not accept mixed-role fragments as proof.
- `app_private.db03_principal_final_actor(campus)` is restricted to the future protected `schoolos_workflow_executor`. It requires READ COMMITTED, a nonexpired JWT, server-resolved `current_principal_id()`, a Foundation authorization advisory lock, and the independent authority digest. It never takes an actor supplied by the client. The future writer must check the digest **again after** School/Application and other cross-domain locks before any accepted effect, including terminal receipt replay.
- One targeted RLS SELECT policy exposes the dedicated operation row to the existing private authorization reader **only if** that row is separately installed. No operation, permission, role, assignment, Finance fact, receipt, evidence, approval or student object is inserted.
- No public `app.*` RPC is created; `anon`, `authenticated`, `service_role`, the document worker, platform and evidence writers cannot call the functions. A narrow internal workflow EXECUTE grant is installed for this **inactive source only**, not a permission to decide.

## What stays blocked

The owner-approved choices remain `APPROVE`, `RETURN`, and `REJECT`, with reason and expected application revision. **None** is implemented as a mutation. The P29 table still has **no INSERT grant** and does not accept APPROVE. The existing application state model is still DRAFT/WITHDRAWN. A future RETURN must invalidate the forwarded review snapshot without losing the application; a future REJECT must prevent all other intake actions (including re-Forward) without erasing original documents. Implement these as one reviewed state machine with append-only receipts/audit/outbox and current-authority, version and concurrency proof.

APPROVE remains blocked until the DB03 and D1 owners jointly implement an **atomic** Principal finalization → verified canonical Person → one Student ID / admission number → first PRIMARY Enrollment and Roll → private document-to-Student lineage, with School-policy lock ordering and idempotent transaction rollback. `UNPAID` may proceed under the owner decision, `MARKED_PAID` is not bank settlement and independently approved exam skips remain separately verified. Do not enable D1 `student.create` on the strength of this source.

## P30 acceptance scope

The new private draft SQL contains two dedicated source functions and one narrowly scoped RLS SELECT policy. Twenty rollback-only pgTAP cases confirm their ACLs, exact operation isolation, no seeded permission/operation, missing actor denial, live Principal-role checks, Auth claim dependency and absence of a final public mutation. The CI installs this source in a disposable DB03 stack, tests injected-install rollback, and reruns P1–P29 acceptance. Source-only and D1 static checks must pass on the exact PR head. Independent live Auth positive/negative authority races and a final principal/Student handoff **have not been tested or authorized by P30**.

No `main` merge, hosted Supabase deployment, executable migration, production role seed or Principal command activation is part of this PR.
