# DB-02 I02 — pinned School-global Foundation P1 version

**Date:** 2026-10-23. **Status:** draft-only internal implementation + 24 negative/positive pgTAP cases; exact-head CI required for completion. This branch stacks on I01 [PR #143](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/143) at `fd5e53b47a164faec2d14e327daa620e9a6b1edf`. P01/P02 owner decision documents live separately in [PR #138](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/138) / [PR #142](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/142).

## Inactive private implementation

`effect48_01_db02_bound_p1_version.sql.draft` adds **one** Student-owned private SECURITY DEFINER `d1_roll_policy_p1_binding_current(school_uuid,bound_policy_version_uuid,bound_route)` with fixed `search_path=pg_catalog,pg_temp`. The helper checks READ COMMITTED, non-null School, exact UUID and either DIRECT/APPROVAL, a live verified Principal, a real School row, and **reselects the one current globally scoped, NULL-Campus Foundation P1 version** via the existing `d1_roll_policy_p1_version` authz-reader helper. It returns true **only if the selected immutable version UUID and route both equal their pinned values**, with all failures (disabled operation, no/ambiguous policy, wrong UUID, route drift, missing School, invalid actor) returning false. It never trusts route text alone as proof. No new client grant or Workflow EXECUTE.

The same file narrowly `CREATE OR REPLACE`s **only** the Student-owned I01 private context without changing its function signature, existing grants, intent structure, receipt wrapper or School-lock ordering. The context:
1. Acquires the Foundation SHARED authorization lock and selects the **server-derived** P1 version UUID and route; the caller cannot choose field 11.
2. Verifies the original selected UUID/route through `d1_roll_policy_p1_binding_current` **before canonicalizing the 12-element DIRECT/SUBMIT intent**, which incorporates the UUID in the SHA-256/JCS digest.
3. Uses the existing evidence-writer-owned narrow receipt wrapper, verified Principal and idempotency serialization, then the existing School anchor and current School ALL authority.
4. Re-verifies the **same immutable** P1 UUID and route with the bound guard after any School lock wait; a replacement with an identical DIRECT/APPROVAL route but a **different P1 UUID** is denied.
5. Denies any terminal replay until I06 proves the original historical policy/revision/allocators and receipt, and denies APPLY/REVIEW until I10/I11 add their **separate exact typed phases**.

The bound P1 guard can be reused by the *future* I10 APPLY and I06 replay, **but only with the original UUID reconstructed from the server-retained request/receipt and only after a separately approved private Workflow EXECUTE/grant**. A caller-supplied UUID is never independent authorization. No current I02 code executes APPROVAL, writes receipts, revisions, pools, audit or outbox, and no event/permission is enabled.

## Tests and expected inventory

- New rollback-only `90_db02_exact_p1_bound_version.sql`, **24 pgTAP assertions**: exact ownership, definer/search_path, strict deny for PUBLIC/anon/authenticated/service_role/Workflow, valid Student owner edge, NULL School/version/route, unsupported route, operation disabled or P1 absent, current exact UUID, wrong UUID, wrong route, **same-route UUID replacement**, multiple globally ACTIVE versions (ambiguous), and no policy/receipt/event mutation. A positive I01 context is also checked by existing #89.
- All DB-02 #82–86 and #89 remain unchanged; suite #90 uses a distinct full filename. Rollback fixture grants/operation switches are not persistent.
- One new private function and one same-signature private override; expected **552 functions / 534 definers / 395 private / 157 app**, 34 FORCE-RLS relations; no new authenticated/anon/service_role private EXECUTE or table DML.
- GitHub exact-head static, Foundation, and disposable runtime with #90 **24/24** and #89 **28/28** required. No local-success assertion is recorded by the existence of this document.

## Still pending

I03 locked source/date/future commitments; I04/I05 atomic policy revisions and allocator pools; I06 receipt/evidence/replay verifier; I07 DIRECT; I08/I09/I10 APPROVAL SUBMIT/REVIEW/APPLY; I11 separately authorized shared receipt changes; T01–T08 genuine authorization/race/history tests; G01–G06 final current-head integration, independent security review and release approval. **P03/G03 remain blocked** (no non-author reviewer). No Migration 10 activation or Supabase hosted write. Never merge the draft solely because CI passed.
