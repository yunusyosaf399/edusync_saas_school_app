# DB03 P38 — private single-use Student handoff storage (inactive)

**5 November 2026.** Isolated database change based on draft parent PR #102. This increment creates a real *candidate table*, database constraints, strict RLS and an always-deny mutation trigger inside the disposable DB03 test environment. It is **not** a live admission approval, a Student-create RPC, a school deployment or an issuance/consumption implementation.

## Why

P36 and P37 establish which forwarded application, canonical Person, reviewed documents, explicit admission-fee disposition, Grade and Section the Principal is considering. D1 Effect36 still has no **trusted single-use source** from Admissions and cannot safely create a Student.

For example, if Ahmad's Principal approves Grade 1-A, a later approved transaction must consume precisely the evidence for *Ahmad's one application* and create **one** permanent Student, initial status, PRIMARY enrollment and roll. It must not create two Students on double-click, reuse another application's documents, or count an administrative `MARKED_PAID` flag as settled bank funds.

## Implemented physical contract (P38)

`app_private.admission_student_handoffs` includes:

- One immutable application identity (**UNIQUE application_id**) and FK to actual application; a composite FK binds `forward_id` to **the same application**.
- Typed FKs to the original identity resolution, Person, Class Offering, Section Offering and the exact administrative fee-disposition record. Later approval must **revalidate** that each source belongs to the same current application, under the cross-package locks; individual FKs do not themselves prove latestness.
- Exact application version, stage epoch and a 32-byte reviewed snapshot digest. The writer must eventually verify all three and current canonical Person/document/grade/section/effective capacity.
- Distinct unique approval receipt, consumption receipt and resulting Student UUID. State accepts only READY or CONSUMED; a CONSUMED record must have all three consumption fields, while READY has none.
- A single-application uniqueness rule compatible with the owner's principle of **exactly one successful final approval**; a failed attempt must roll back instead of committing a stale READY record.

**Security is fail-closed:** RLS ENABLED and FORCED; sole schema-owner policy. No public/client, workflow, Student executor or service-role table grants. The installed `db03_student_handoff_mutation_unavailable()` trigger rejects **all INSERT, UPDATE, DELETE, TRUNCATE**, including privileged test-owner inserts. It will need a separate reviewed replacement after an actual Principal-authorized APPROVE and D1 Student create operation are implemented, tested and jointly installed. It does **not** create a shortcut grant.

## Acceptance

- Source-only validator ensures one explicitly named table, one denial-only trigger function, no positive command/GRANT, and non-permissive state.
- 27 pgTAP assertions inside BEGIN/ROLLBACK cover RLS, ownership, uniqueness, state, composite FK, typed FKs, forbidden roles, triggers, failed owner insert and forbidden truncation.
- Deliberately aborted schema installation verifies no handoff table/function remains; installed candidate is tested only in the disposable Supabase stack.
- Existing real signed-Auth P35B/P37 check remains in the same full DB03 pipeline and must not regress.

## Still blocking Principal APPROVE → D1 Student

**P38 is storage only; nobody can write it.** The next integration must implement the live Principal-only protected operation; verified identity and original private certificates; post-lock version/Section/capacity/roll and active authority rechecks; owner-selected UNPAID/SKIPPED/MARKED_PAID declaration without fake settlement; real school Student ID and admission number allocation; one Student + status + PRIMARY Enrollment + Roll + document lineage; receipt/audit/outbox, concurrent winner/loser and exact replay, and all-or-nothing rollback.

A separate cross-package runtime/permission review must precede any Student.create activation, hosted migration or merge to `main`.
