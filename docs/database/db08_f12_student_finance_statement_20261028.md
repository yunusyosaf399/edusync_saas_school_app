# DB08 F12: checked Student Finance statement (inactive candidate)

F12 reads a current Student's assessed F5 charges, retained F6 discounts, F10 official payments and F11 allocations. It returns charge lines with gross, discount, net, allocated and remaining amounts; official payment lines with permanent receipt serial, allocated and unused amounts; and totals computed from those rows. Pending/rejected bank slips are excluded. There is no stored balance, paid flag or mutable cache.

A real Auth family principal with a live `finance.statement.view` child grant can read the linked Student's current School history. A staff member with the same permission scoped to the Student's current Campus reads only that Campus's facts. The private file worker has only a checked function entry, with no direct source table read or public client RPC. The function rechecks active School, Student and current primary enrollment, the live D1 grant, and the token expiry. A shared School fence and row lock keep the multi-query statement coherent with fee, discount, allocation and official payment issuance.

The output is a read snapshot, not an invoice, payment confirmation for a pending proof, or Admissions Finance clearance. A zero due amount alone does not issue clearance. This is a draft SQL and server adapter candidate with synthetic fixture permissions only. Production IAM, UI, presentation, recovery and activation remain separate gates.

Disposable acceptance checks worker-only execution and failed-install rollback, then real Auth parent access to one child, denial of another child, Campus staff scope, correct totals after two official payments and two allocations, exclusion of the rejected duplicate, and immediate denial after family or staff grant revocation.
