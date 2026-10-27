# DB08 F2 — initial fee publication and one full-price assessment

F2 adds two guarded Finance commands on top of F1's five retained tables. It is a proposal in the draft PR, not a deployed migration or an admission clearance issuer. One School occupies one Supabase project; the fee rule binds one Campus and one Academic Year.

| Command | Required source and authority | Atomic retained result |
|---|---|---|
| `app.configure_finance_fee` | Active individual Auth-linked staff, live `finance.fee.configure` contract, permission, assignment, grant and `ALL/DIRECT` scope; active Campus and planned/active Year; valid minor-unit price | School currency unit/category as needed, one rule, revision 1, immutable publication, receipt, audit and outbox |
| `app.assess_finance_fee` | Same live authority chain for `finance.charge.assess`; active School/Campus/Year/Person; explicit rule, latest published revision, dates within the revision and Year | One full-price obligation for the chosen Person and nonoverlapping period, receipt, audit and outbox |

Both RPCs are granted only to `authenticated`; no direct Finance table DML is granted to clients or `service_role`. A fixed advisory-lock order serializes these initial Finance writers and current actor/operation checks run again after waiting. An exact idempotency-key replay returns the original immutable source after its evidence is checked; a changed request with the same key fails. The audit and outbox payloads contain source references, not the Person or price.

Only School-wide `ALL/DIRECT` authority is accepted. The Foundation Person record does not establish a Campus assignment; Campus-only permission would permit an unsupported Person-to-Campus inference. F2 takes a specific Person and period, without automatic schedule, enrollment/Student eligibility, tuition enrollment classification, concession, invoice, collection, payment, allocation or clearance semantics. Each configured initial rule has exactly one published revision through this API; later revisions/corrections require a separate command and acceptance. A charge says what was assessed, not what was paid or whether an admission can proceed.

Acceptance runs the F1 structural tests and frozen Foundation regression first, rehearses failed F2 DDL installation and rollback in a disposable pinned Supabase stack, then installs F2 and runs rollback-only command assertions. The synthetic current Auth claims exercise the authenticated database role and linked Foundation principal; they are not an external Auth-token exchange. No hosted School data is changed. Runtime run IDs and exact-commit conclusions belong in the draft PR after CI observation.

Example: an authorized staff member configures a February tuition price of 100.00. They explicitly assess that rule for Person A for February, creating one retained 100.00 obligation. Retrying the same command returns that obligation; another command for the overlapping period fails. This is not a payment or admission clearance.
