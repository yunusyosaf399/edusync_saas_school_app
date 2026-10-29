# DB08 F1 — Finance fee and obligation storage baseline

This increment starts actual Finance-owned storage after DB03 S10 established a deny-only missing-source boundary. It implements five inactive tables with real typed Foundation ancestry, exact amount constraints, retained price revisions and immutable individual gross charges. It does not replace S10's denial: no Finance clearance issuer exists yet.

Sources: master §§30–36; AGENTS; invariants; database guardrails/security workflow; entity design template; approved 21 October Finance-authorizer decision; [ADR-005](../decisions/ADR-005-finance-charge-storage-baseline.md). Domain ownership is Finance, in the same School project. These relations are separate from Admissions, with no fake external IDs, test verifier registration or seeded financial decisions.

## Entity catalog and fields

All entities have UUID `id` (generated), `created_at` (transaction time) and mandatory `created_by` (real Foundation Principal FK). All fields below are required except the explicitly nullable predecessor pair. These are retained configuration/history facts; there is no mutable balance, paid flag, net-due cache or clearance column.

| Table | Purpose / authority | Additional fields and types | Keys and relationships |
|---|---|---|---|
| `finance_currency_units` | Authoritative retained money-unit configuration | `school_id uuid`, `currency_code text`, `minor_unit_scale integer` | School FK; unique School/code and id/School; explicit scale 0–6; no defaults for code or scale |
| `finance_fee_categories` | Authoritative retained category identity/label | `school_id uuid`, `code text`, `label text` | School FK; unique School/code and id/School; school-custom categories, no required category seed |
| `finance_fee_rules` | Stable fee identity and scope | `school_id`, `campus_id`, `academic_year_id`, `category_id`, `currency_unit_id` UUIDs; `rule_key`, `frequency` text | Real Campus FK plus same-School insert guard; composite Year/School, category/School and units/School FKs; unique School/rule key; fixed frequency and context |
| `finance_fee_rule_revisions` | Authoritative retained gross-price revision history | `rule_id uuid`, `revision bigint`, nullable `previous_revision bigint` and `previous_id uuid`; `gross_amount_minor numeric`, `frequency text`, `valid_from/valid_through date`, `reason text` | Exact same-rule predecessor FK; initial revision one with no predecessor, successors previous+1; unique rule/revision and predecessor; exact root/frequency FK |
| `finance_fee_obligations` | Authoritative initial gross charge for a canonical Person | School/Campus/Year/Person/rule/revision UUIDs; `gross_amount_minor numeric`, `frequency text`; `period_start/period_end/due_on date`; `assessment_key uuid` | Person FK; exact root+School+Campus+Year FK; exact revision+root+amount+frequency FK; unique School/key and rule/Person/exact period; one-time partial unique index |

All FKs use ON UPDATE/DELETE RESTRICT. No cascade deletion. Finite ordered dates are required. Initial revision validity must fit the referenced AcademicYear when inserted; the assessed period must fit the retained price revision. These are initial-context validations, not live authorization or a claim that mutable Foundation dates can rewrite financial history. Due date is independently explicit; this slice chooses no monthly due-day rule. Frequency supports MONTHLY, QUARTERLY, HALF_YEARLY, ANNUAL, ONE_TIME and CUSTOM; no dates are automatically calculated.

Amounts are integer minor units, nonnegative and strictly below 10^24. Fractional input is rejected before rounding because the column has no numeric scale typmod. Negative, NaN and infinity fail. There is no currency conversion, proration, tax or discount arithmetic. The exact price FK covers one configured full-price occurrence. Approved concessions later produce separate retained Finance facts, without changing the original gross charge.

## Lifecycle, history and correction

All five tables are append-only and deny statement-level UPDATE, DELETE and TRUNCATE, including no-op writes and CASCADE truncation. Price changes append linear revisions. Root context, frequency and currency interpretation cannot be changed beneath prior charges. New prices do not rewrite existing assessments. This baseline has no draft/published pricing state or operational current-price selector: a stored revision is not permission to bill it. Future authorized publication/selection and closure history must define effective precedence, retroactivity and approval before writers are enabled.

Exact repeated rule/Person/period assessments are prevented across revisions; the stable rule ID provides this invariant. A one-time rule can occur at most once per Person even across periods/revisions. The same School assessment key cannot identify a different charge. A future idempotent command must distinguish exact replay from a changed request and return a retained receipt; uniqueness alone is not an idempotent API. Custom/overlapping period aliases and semantic duplicates across distinct rule keys remain assessment-command work. No arbitrary alternate rule key may be treated as approval to double-charge.

No financial hard deletion or mutable cancellation status is introduced. Existing charge correction, cancellation, waiver, scholarship, credit, refund, allocation and reversal will use their own authorized retained effects. Permanent numbers/invoices/receipts and generated PDFs follow later. There is no object storage, attachment or uploaded payment-evidence flow in F1.

## Authorization, workflow and audit

FORCE RLS on every private table. Only `schoolos_schema_owner` has policies for inactive schema install and disposable fixtures. No normal role, including Principal, Administrator, Accountant, parent, anonymous user, service_role, workflow executor or file/event login, receives Finance table access. An existing job title or Admissions document permission does not grant Finance access. Two private invoker triggers have fixed `pg_catalog,pg_temp` search paths and no runtime EXECUTE grants.

There is no protected business writer or read RPC yet. No actual fee-setting, assessment, waiver or clearance operation is activated. Future commands must use exact current action permissions, School/Campus scope and configured independent approvals, revalidate after waits, bind server-derived actor/time and idempotent immutable receipts/audit/outbox, and minimize event data. `created_by` is provenance FK storage, not authentication. A record inserted in a synthetic privileged fixture is not evidence of a reviewed real-world financial action.

Sensitive amounts/Person relationships stay private. No report/search/AI grants or unencrypted offline cache is created. Future reads need dedicated financial permissions and Family/child scope. Offline fee posting and offline clearance are not enabled; later retries must reauthorize online. Notifications/reminders are downstream committed events, not automatic debt messages generated from these fixtures.

## Query/index and installation design

Indexes cover obligation Person/Year/due date, Campus/Year/due date and source revision; rule Campus/Year/category and category/currency references; unique revision history and assessment business keys. Example privileged diagnostic query (not a client API):

```sql
SELECT o.id, o.gross_amount_minor, u.currency_code, u.minor_unit_scale,
       r.revision, o.period_start, o.period_end
FROM app_private.finance_fee_obligations o
JOIN app_private.finance_fee_rules f ON f.id=o.rule_id
JOIN app_private.finance_currency_units u ON u.id=f.currency_unit_id
JOIN app_private.finance_fee_rule_revisions r ON r.id=o.rule_revision_id
WHERE o.person_id = $1 AND o.academic_year_id = $2;
```

Order: frozen Foundation migrations 1–9; inactive DB08 F1 units/categories → rule identities → price revisions → obligations → guards/RLS/ACLs. No D1/Admissions install is required. The entire candidate is installed in one transaction; injected failure must remove every F1 table/function. No executable migration file, bootstrap manifest, deployed data or existing domain SQL is changed. A release migration is a separate later gate. Historical/source retention has no automatic expiry job.

## Validation and limits

73 rollback-only pgTAP cases cover valid configuration/revision/charge persistence, real ancestry, invalid money, fake price/frequency, missing context, out-of-range periods, price-history preservation, duplicate assessments, one-time repeats, no financial history destruction, all runtime ACLs and default-deny RLS even after an accidental test-only table grant. Fixtures use the schema owner, explicitly structural acceptance rather than operational authorization acceptance. The disposable CI workflow pins the accepted Foundation commit, CLI and PostgreSQL image, rehearses transactional DDL rollback, checks fixture cleanup, reruns all 220 frozen Foundation assertions and stops the stack. Exact run/head evidence is recorded in the PR after observation; source checks alone do not imply runtime success.

Next: protected Finance configuration/publication and assessment commands with scoped authorization, configured approvals and audit/receipt/outbox acceptance. Then commercial concessions/adjustments, payment evidence and official payments/allocations, invoices/receipts, explicit Finance clearance issuance/revocation and jointly fenced Admissions/D1 consumption. Class-specific/student-specific rule selection and discount thresholds/period/rounding need explicit contracts; F1 does not invent them.

Example: a configured fee is 100.00 in February. Its assessment retains that gross price. A later price revision of 120.00 can be used for an explicitly assessed March occurrence; February remains 100.00. This is storage behavior, not a claim that a billing UI or production assessment command exists. Neither charge means paid or admission-cleared.
