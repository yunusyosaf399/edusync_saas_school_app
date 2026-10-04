# D1C1B Effect 36/36 — Student Create Security Review

**Status: ACCEPTED DEPENDENCY BOUNDARY; OPERATION REMAINS DISABLED.**

## Security conclusion

`student.create` cannot safely become executable inside D1 alone because its successful effect depends on a trusted final Admissions handoff that does not yet exist in this package. The secure D1C1B result is therefore a fail-closed integration contract, not a denial stub masquerading as an implemented command.

The trusted runtime boundary remains Effect 35 runtime SHA `97e6eb7d8329475861fd3b4c0f7fc5f7e7c175c7`; Effect 36 changes no SQL/runtime surface.

## Authorization boundary

A future successful protected command must require both:

- exact current non-family-safe `student.create` authority; and
- exact current `student.enrollment.place` authority for the resulting accepted placement ancestry.

Creation authority does not imply placement authority. CAMPUS/SECTION scope must match the exact destination selected by the trusted handoff and reviewed placement flow.

No role name, administrator label, Department, Designation, teaching assignment, client screen access or Admissions UI state substitutes for current server authorization.

## Handoff trust boundary

Only the later approved Admissions domain may produce the trusted final handoff. The Student command must verify it server-side and reject untrusted caller assertions.

Forbidden substitutes include:

- client booleans such as `approved=true`;
- free-form or arbitrary JSON approval payloads;
- caller-supplied application/admission numbers used as proof of acceptance;
- a generic privileged override that skips Admissions verification;
- authenticated or service-facing direct base-table DML used as a functional shortcut.

The handoff must be single-consumption/race-safe so concurrent or retried requests cannot mint duplicate Students from one accepted applicant.

## Transactional integrity boundary

Future activation must bind handoff validation/consumption to the same all-or-nothing Student creation transaction, or to an equivalent design that proves exactly-once consumption under concurrency.

The accepted effect must preserve the frozen initial-status, PRIMARY enrollment, capacity and roll completeness rules. Partial Student creation without the required initial state/placement/roll is not an allowed degraded success path.

## Identity boundary

Permanent `school_student_id` is server allocated at actual Student creation. Internal Student UUID, school Student ID, Admissions number/serial and roll remain separate identity namespaces.

A client may not select or forge the school Student ID. Admissions-owned identifiers may enter the Student effect only through the later typed trusted handoff contract.

## Family/Foundation isolation

`student.create` grants no FAMILY authority and creates no automatic family relationship, principal membership, child access or primary context.

It also creates no Foundation role, grant, permission or scope. Family onboarding/access and authorization administration remain separate protected operations.

## Evidence minimization

The selected outbox vocabulary includes `student.created`, but future broad evidence may contain only safe identifiers/state/context required by the frozen evidence contract.

Restricted identity, guardian identity/contact, private address, birth-certificate content, arbitrary Admissions request payload and arbitrary reason text must not be copied into broad receipt/audit/outbox JSON.

Exact receipt/audit shape remains later integration SQL syntax work because D1 does not yet have the Admissions source-of-truth object against which such evidence can be safely bound.

## Public/privilege boundary

Effect 36 adds no public RPC, executor privilege, trigger, SECURITY DEFINER function, RLS policy or table grant. The operation remains disabled in the registered manifest and direct authenticated Student creation remains unavailable.

This zero-runtime-delta closure is security-positive: it avoids creating an untrusted temporary ingress that would be difficult to remove safely later.

## Closure and next gate

D1B4 explicitly allows `student.create` to be accounted for as a documented disabled dependency pending Admissions. With this review, the D1C1B ledger reaches 36/36 accounted contracts without expanding runtime authority.

Migration 10 remains `.sql.draft` and unexecuted. Foundation migrations/tests remain unchanged. D1C2, staging/managed Supabase application, worker activation and Admissions integration remain separately gated.
