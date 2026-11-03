# DB03 P33 — Protected Principal RETURN/REJECT candidate command

**2 November 2026 — Draft, no user/client activation.**

P33 stacks directly on DB03 #203 at merge SHA `f5ac2c63a148bf80949b044b6b1f4635b20d9655`, after P32. All code remains in `.sql.draft`; no production migration, Supabase hosted write or main merge. DB01/DB02/D1 #168 stays Draft and unchanged.

## New protected effect implementation

This increment adds the server-only `app.decide_admission_principal(application_id,expected_version,forward_id,decision,reason_private,idempotency_key)` source, owned by `schoolos_workflow_executor` with **no EXECUTE privilege for `authenticated`, `anon`, `service_role` or file/identity/platform workers**. It accepts only `RETURN` or `REJECT`; `APPROVE` is invalid. A Principal cannot run it simply by holding an existing document-approval right.

When activated in a separately approved integration, the body will:

1. Require a nonblank private reason, supported decision, application version, exact forwarded record ID and valid idempotency key.
2. Take the Foundation global authorization lock, derive the server-authenticated Principal through P30 `db03_principal_final_actor`, build a canonical payload hash using a SHA-256 digest of the private reason, and serialize exact-key requests through an advisory lock. No actor ID or authority token is accepted from the client.
3. Lock the School, Campus, Academic Year, then the application row; recheck the same active Principal, operation and authority digest **after locks**, including before accepting a receipt replay.
4. Reproduce a verified existing same-key receipt (or reject a changed canonical intent/version). Only if no prior receipt exists, confirm DRAFT and exact application version, matching latest live/undecided Forward and current document snapshot through the P32 private fence. A separate Forward or conflicting prior decision cannot reuse the record.
5. Insert an immutable P29 decision with current version/stage epoch, monotonic revision and superseded source link. The P29/P31 triggers enforce same-application Forward, one decision per Forward, terminal REJECT, and immutable history. No UPDATE on the application row is needed to invent a rejected state: the P31/P32 lifecycle projection and mutation guards enforce REJECT; after RETURN, a real amendment must increment `application_version` before re-forwarding.
6. A fixed-owner private evidence function `app_private.db03_principal_final_receipt` seals the source-specific `command_receipts`, `audit_events` and `outbox_events` records in the *same PostgreSQL transaction*. It binds actor, operation, key, canonical payload, expected version, decision source, target and one matching audit/outbox row; the private reason is retained only in the decision source and not exposed in receipt or outbox payload. A failure aborts all writes.

## Why P33 is deliberately not released

- The **distinct** `admission.final.decide` operation/permission is neither seeded nor enabled by P33. The public `app.decide_admission_principal` RPC remains **REVOKED from authenticated users**. Internal P29 INSERT access is granted only to the guarded workflow executor, not app clients; evidence functions remain fixed-owner.
- The owner-approved **APPROVE** action is not implemented; it requires one coordinated atomic transaction creating the canonical Person/Student/Admission number/first Enrollment/Roll plus current roll-policy locks and original private document lineage. Neither a fake accepted handoff nor a successful RETURN/REJECT authorizes Student creation.
- Positive end-to-end live Auth tests and genuine concurrent backend schedules are still required before any user EXECUTE grant or permission provisioning. In particular, exercise exact-key replay, changed-payload conflict, two different Principal decision races, School permission revocation while waiting on locks, withdrawn/returned/revised Forward, document quarantine, and rollback on evidence-write error.
- The scope of P32's terminal REJECT guard is enumerated Admissions mutation sources. Other integrations (especially Finance reversals, policy publication and private document archival) must preserve their separate rights. Do not assume a terminal decision deletes or loses previous rejected applicant records.
- Final-decision events must not be exposed to parents or used for financial settlement; `UNPAID`, `MARKED_PAID` and school-authorized assessment skip semantics remain as previously decided.

## CI and acceptance boundary

P33 adds 30 rollback-only pgTAP assertions covering protected function and fixed-owner evidence presence, complete client/RPC ACL denials, dedicated authority and exact-Forward source checks, role/lock/order and post-lock auth revalidation, immutable receipt/audit/outbox schema and application-version binding, duplicate detection, explicit APPROVE refusal, and unknown source rejection. The disposable runner checks exactly scoped source, an injected install failure that rolls back its public function, then a clean install and 30 assertions. Existing P1–P32 DB03 and D1 static acceptance must continue to pass.

**P33 success means protected server-only candidate code and deny-by-default structural checks pass, not that authenticated school Principals can make live RETURN/REJECT decisions.** The release gate remains positive and adversarial Auth/race testing plus separately approved operation registration, with APPPROVE/Student creation blocked.
