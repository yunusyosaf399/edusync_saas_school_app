# DB-01 — Remaining Work Register (as of 2026-10-22)

**Scope:** Student Roll Correction `student.roll.correct`, DB-01 only. Owner-approved RC-01...RC-08 in the DB-01 contract of [draft PR #100](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/100); implementation is a **stacked chain of draft PRs**, not installed in production. Checked base: [green PR #136](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/136), `04164b015e516b7a497c0dd9ae0b22a2dfb10071`. Never assume passing a disposable D1 stack permits a merge or operation activation.

## Already passed in disposable PostgreSQL

- Product-owned source, namespace, effective-date, successor/origin and P1 policies approved in frozen DB-01 document. Cross-workstream integration/production agreement is **not** approved by this document.
- Protected authenticated DIRECT R0→R1 correction, typed immutable audit/receipt/outbox, same-key authorized replay, current history authority, collision and source checks.
- Different-key and same-key genuine protected concurrency, permission revocation during lock contention, CORRECT versus Enrollment MOVE/END in both winner orders, historic replay after protected MOVE/END, and actual protected cross-Campus history access checks.
- Authenticated **P1 APPROVAL SUBMIT** request without Roll mutation; exact source snapshot, protected reviewer candidate selection, authenticated idempotent request receipt/audit; `33/33` new pgTAP assertions and `3,489` aggregate domain assertions, [D1 run #39718738669](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/39718738669).
- All these changes remain `.sql.draft`, with operation and permission **disabled** in the frozen catalog.

## Outstanding task register (status means verified accepted, not source committed)

| Task ID | Deliverable and acceptance gate | Initial status |
| --- | --- | --- |
| DB01-01 | Authenticated independent P1 APPROVE and REJECT; configured step review, distinct Person, current reviewer grant, exact review receipt/audit; no Roll mutation | **IN PROGRESS**: stacked draft candidate effect41_09 and isolated pgTAP #90; exact-head runtime not accepted |
| DB01-02 | Revoked/withdrawn reviewer, policy alteration, step/expected version/idempotent terminal replay and multi-step revalidation; real lock-wait security | PENDING |
| DB01-03 | Separately authenticated APPROVED→APPLY; fresh requester/reviewer/policy/source locks, school-local date and number collision checks, one R0→R1, Student N+1 | PENDING |
| DB01-04 | APPLY stale/rejected/invalidated/duplicate/no-op/grant-revoked terminal integrity, canonical receipt/applications and audit/outbox proof | PENDING |
| DB01-05 | Checked requester/reviewer/administrator P1 request read with minimal typed data; current history-number permission independent | PENDING |
| DB01-06 | Same-Person and impersonation resistance, reviewer cross-Campus/Section grants, audit/outbox minimization, zero forbidden EXECUTE privileges | PENDING |
| DB01-07 | Two-backend REVIEW/REVIEW, REVIEW/APPLY, APPLY/CORRECT and APPLY/MOVE/END contention with observed blockers | PENDING |
| DB01-08 | Later successive corrected heads, cross-School fail closed, policy cutoff/ambiguous/expired boundaries and school-local midnight | PENDING |
| DB01-09 | Full genuine SUBMIT→APPROVE→APPLY and SUBMIT→REJECT integration, updated contract and reviewed invariants | PENDING |
| DB01-10 | Reconcile downstream DB-02 roll namespaces, DB-03 Enrollment, DB-04 impacts; stacked PR dependency and migration merge order | PENDING |
| DB01-11 | Independent security/integration review with findings addressed and accepted | PENDING |
| DB01-12 | Merge, upgrade/rollback, checked migration and controlled operation enabling, **only after explicit production authorization** | BLOCKED ON PRIOR GATES |

**Tracking rule:** Mark a task PASSED only when the exact branch HEAD and matching D1 static, Foundation, local PostgreSQL tests prove its required behavior. A completed CI run is not independent security or product release approval. After each increment, retain its exact SHA, PR, three workflow URLs, proof markers, unresolved failures and next dependency here.

**No cross-workstream changes:** Only DB-01 SQL draft, its acceptance fixture and DB-01 documentation/test runner manifests. Do not modify DB-02, DB-03 or DB-04 contracts or enabling flags.

**High-risk release blockers:** Cross-domain synchronization of server School-local date/policy revision and DB-02 retained numeric namespace, stack merge readiness, independently authorized review/APPLY, and security signoff remain separate decisions.
