# D1C1B Effect 27/36 — Student Enrollment End Security Review

**Status: SECURITY REVIEW PASS — exact-SHA CI PASS; freeze record follows.**

Trusted runtime candidate: `ddcfa8eddc8c20e2ef34afca756704a3d08463e3`.

Reviewed security properties:

- `student.enrollment.end` is P1; a single current policy selects DIRECT or APPROVAL, otherwise deny.
- Only an active bound INDIVIDUAL principal with a complete live grant/scope chain can act. FAMILY/SYSTEM ordinary business paths remain unavailable.
- Source authority is evaluated against stored source Section ancestry using ALL/CAMPUS/CLASS/SECTION ACS. The Enrollment itself grants nothing.
- Approval mode requires the exact configured reviewer role and current `student.enrollment.approve`; requester/reviewer separation is enforced by Person.
- School-policy fallback remains pinned to the affected source Campus for request context and later policy revalidation.
- Foundation SHARED authorization locking and Student/source-history serialization are preserved; no grant administration path is widened.
- Authenticated receives EXECUTE only on five fixed typed `app.*` RPCs: direct, submit, review, apply and bounded participant read. Private Effect-27 helpers revoke authenticated/service-role generic access.
- No authenticated direct base-table DML is introduced.
- Successful replay rechecks current authority and proves exact ended Enrollment/Roll facts, expected Student version, source/destination-free ancestry metadata and effective bound before returning.
- Approval apply has an operation-specific application guard binding the exact request, SUCCEEDED apply receipt, target version and result Enrollment.
- Deterministic stale approved requests invalidate without domain mutation or success event; malformed workflow/evidence state raises and rolls back.
- Arbitrary end reason is retained only in protected Enrollment/request history and excluded from broad audit/outbox payloads.
- No role-label authorization, no client-supplied authority ancestry and no destructive enrollment deletion are introduced.

Independent review corrected the school-fallback Campus mismatch, missing application binding, incomplete replay metadata proof and missing typed read/ACL packaging before this pass.

Exact-SHA GitHub Actions run #125 (`37125078838`) passed the trusted runtime candidate, including 121/121 tooling tests and 220/220 Foundation pgTAP assertions.

Migration 10 remains `.sql.draft`; this security review authorizes no D1C2, database application, remote/staging deployment or worker activation.