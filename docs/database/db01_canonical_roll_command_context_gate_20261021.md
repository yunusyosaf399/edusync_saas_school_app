# DB-01 — Canonical Roll correction command context and receipt-key preflight

**Date:** 2026-10-21. **Status:** DRAFT / exact-HEAD PostgreSQL CI and independent security review required. **Non-activating.**

## Dependency and scope

This change is stacked on draft [PR #123](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/123), exact passed head `09c5a5caf68b2f26c2b4b8d9da44c6f9cc4b2987`, which provides private current-Principal/Section scope and P1 route checks. All earlier DB-01 ancestry, private effect and concurrency prerequisites remain stacked and unmerged.

One new **non-executable** Migration 10 fragment, `effect41_04_db01_roll_correct_canonical_command_context.sql.draft`, defines only `app_private.d1_roll_correct_command_context(text,text,jsonb)`, owned by `schoolos_evidence_writer`, SECURITY DEFINER with pinned search path and no client EXECUTE. Only Student and Workflow executors may invoke it.

## Exact typed caller-intent and key semantics

- DIRECT `student.roll.correct` and `request.submit`: 11 positional canonical **JSON string** inputs: Student UUID, expected Student version (decimal text), Enrollment UUID, Section UUID, Enrollment start date, source Roll UUID, source Roll start date, source stored Policy UUID, old number (decimal text), requested number (decimal text), original reason text. Every position is type-checked; UTC/session/current School-local DATE is **never a volatile client hash input**.
- `request.review`: request UUID, APPROVE/REJECT literal, expected request version (decimal text), nonblank bounded reviewer reason. `request.apply`: request UUID and expected version (decimal text).
- Canonical UUID/date/BIGINT spelling is checked; number overflows, equal old/new number, invalid date/shape, blank/bounded reason and blank idempotency key fail closed. The reason is **hashed as provided** and never trimmed before hashing.
- The version-1 digest uses `d1_jcs_typed` and SHA-256, binding exact operation code, contract version/id, verified authenticated Principal, command kind, full validated typed intent and idempotency key.
- Acquire Foundation SHARED authorization advisory lock `(71001,1)`; resolve the server Principal and **enabled** `student.roll.correct` contract version 1; acquire the same per-Principal/operation/key advisory `(71002,<derived int>)` as Enrollment END. Read an existing receipt under this lock; return its immutable result metadata only when kind/canonicalization/hash all match. Mismatch fails rather than silently executing a new correction.

This helper does **not** perform an effect, insert receipts, authorize a caller, select a route or authorize historical disclosure. Protected entry points must do all of those independently and must not trust an arbitrary client-crafted JSON intent. No received optional effective date is permitted.

## Inventory, tests and constraints

Added one private SECURITY DEFINER function: expected **551 functions / 533 definers / 157 app / 394 private**; no increase in authenticated app/private or service/anon grants. Exactly 34 FORCE RLS tables unchanged, and frozen 97/322/36 permission/scope/operation registrar unchanged.

Rollback-only suite `86_db01_roll_correct_canonical_command_context.sql` plans **30 assertions**: disabled-op denial, verified actor/operation, exact independently computed hash envelope, key/kind/reason separation, valid review/apply, invalid UUID/date/version/number/reason, private ACL, and no generated receipts. Synthetic enabling of the operation occurs **only inside BEGIN…ROLLBACK**. New static Python security test enforces allowed command kinds, Foundation advisory lock prefix, absence of public RPC/INSERT or operation enablement. Runtime/CI success must be verified on **exact latest commit**, not previous green heads.

## Explicitly still open

- The actual typed public DIRECT/SUBMIT/REVIEW/APPLY/checked-read handlers and their verified ACS/P1 hooks.
- Durable successful and rejected **receipt insertion** with exact R0→R1 provenance, immutable summary, replays and audit/outbox, plus independent review/approval application evidence.
- Receipt lookup after later legitimate corrections/MOVE/END, including current historical disclosure authorization.
- Protected authenticated two-session CORRECT-versus-P0/MOVE/END/DB-02 policy races and School-local cross-day proof.
- Independent security/integration sign-off, activation and hosted migration.

**No public `student.roll.correct` RPC, policy activation, hosted Supabase change or merge is authorized by this draft.**
