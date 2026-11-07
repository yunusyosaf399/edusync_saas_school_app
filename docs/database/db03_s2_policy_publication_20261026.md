# DB03 S2 — protected immediate policy publication

> **S3 follow-on, 26 October 2026:** [Opaque application drafts and retained certificate grace](db03_s3_intake_certificate_grace_20261026.md) implements protected draft/create/withdraw and original-window grace history as a separately tested inactive candidate. Earlier remaining-work statements below are historical for this narrow slice; real identity, upload verification, submitted applications and final completion remain open.

**Implementation candidate, 26 October 2026.** The owner explicitly selected **one authorized administrator** to publish admission rules. The selected description was: “One administrator with the current publishing permission can publish; every change is recorded and published versions are locked.” This is a product choice, not code-review or hosted-deployment approval. Earlier selections require immediate publication for new submissions and preservation of old submitted policy snapshots.

## Entry and exact authority

The four ordered `supabase/proposals/db03/03_*.sql.draft` fragments add one fixed public entry:

```sql
app.publish_admission_policy(
 p_policy_id uuid, p_expected_version bigint,
 p_expected_current_policy_id uuid, p_idempotency_key text
) RETURNS TABLE(policy_id uuid,published_at timestamptz)
```

Only authenticated may EXECUTE. Owner is the existing NOLOGIN `schoolos_workflow_executor`, SECURITY DEFINER with fixed `pg_catalog,pg_temp`, no BYPASSRLS/schema-owner membership. The actor must map through real Foundation Auth binding to a current active INDIVIDUAL with a complete, currently effective ALL/DIRECT `admission.policy.publish` permission chain. Staff role names do not substitute for the grant. The exact operation code/handler, contract/payload version 1 and bound non-family-safe permission must exist and be enabled, with `requires_approval=false`; an independently reviewed route is never bypassed if configured instead. No catalog or permission row is inserted by candidate installation, so default remains unavailable until separately reviewed registration/activation.

Authority lives in an authz-reader-owned private context. A fresh `clock_timestamp()` check after waits handles natural grant expiry as well as revocation. New private SECURITY INVOKER BEFORE STATEMENT fences on nine Foundation authorization input tables take EXCLUSIVE `(71001,1)` before mutations acquire rows; publication holds SHARED. These additive triggers complement the frozen row-interval fences and prevent a revoker from locking a grant row then waiting on the publisher's authorization fence. Original Foundation files/functions are not edited. All current/future auth administration writers must retain this protocol. Its compatibility with the full frozen Foundation behavioral suite and real opposing-arrival races is explicitly tested.

## Locked aggregate and immutable history

Lock order is authorization SHARED → actor/operation/key advisory `(71002,hashtext(...))` → School → sorted referenced profiles → target policy → sorted stages and document rows. Replacement source is also locked while School serializes policy families. A fixed private prelock helper is available to the publisher and future draft writers. Direct schema-owner maintenance must use it before child mutations; defensive triggers still reject published edits, but arbitrary maintenance which violates rank may receive a PostgreSQL deadlock abort and is not a supported writer protocol.

Each stage/document draft mutation locks its policy parent and advances the policy aggregate row_version. This binds the caller's reviewed root version to the exact child roster. Referenced profile formats are frozen even in drafts; to revise one, create another profile and rebind the still-DRAFT policy, advancing its version. Once published, profiles, stages and document rows are immutable; DELETE/TRUNCATE are denied. No client raw configuration DML is granted.

The publisher validates exact typed same-School profiles, one complete contiguous stage/document roster and the mandatory birth certificate ALL / school-leaving certificate TRANSFER entries. Document verification cannot be skipped. Number formats must be nonblank/control-free and fit a documented engineering presentation bound of 128 characters; no School prefix is seeded. These are candidate technical validation limits, not additional quoted owner choices. A REQUIRED APPROVAL stage fails closed until its separately typed workflow route is integrated. Publication itself does not verify applicant files or Finance, allocate numbers, waive grace deadlines, issue READY or create a Student.

First publication requires domain policy version 1 and NULL predecessor. Replacement requires the exact current open predecessor and next sequential domain version. One trusted server clock instant publishes the new policy and closes the old interval at the same boundary. Old policy/roster/profile facts remain retained; RETIRED history cannot be rewritten. There is one open policy per School/policy key. No scheduled/backdated input, END, format-retirement command or retrospective application rebind is exposed. Admission application/consumer commands still need to retain and use their original policy IDs; these tests prove retained policy data, not an already implemented application submission flow.

## Atomic evidence and retry

Publication, required profile freezing, predecessor close, one receipt, one minimized audit and one outbox event commit atomically or all roll back. Evidence writing belongs to `schoolos_evidence_writer`, with only fixed private Workflow call access and operation/event-scoped RLS. No PUBLIC/client private EXECUTE, raw evidence privileges or generic JSON command exists.

Engineering result kind is `ADMISSION_POLICY_PUBLICATION`; command is `admission.policy.publish`, event/audit discriminator `admission.policy.published`, schema version 1. Receipt has exactly seven keys: School ID, policy ID/domain version, publication instant, published aggregate row version, predecessor ID and immutable configuration hash. Audit/outbox have only five safe ID/version/time keys. A fixed JCS array of policy UUID, expected-version string and nullable source UUID is SHA-256 hashed with canonicalization version 1; the actor/operation/key form the receipt namespace. The separate configuration fingerprint hashes fixed ordered policy/profile/stage/document values, excluding mutable lifecycle stamps.

Matching retries recheck current authority and prove retained policy, predecessor interval, config hash, receipt, audit and event before returning the original policy/instant. Changed intent conflicts. A later legal replacement does not rerun an earlier publication. Revoked authority cannot replay an old response. Neither private reasons nor applicant identity/file content enter broad evidence.

## Validation and remaining boundary

The isolated DB03 runner preserves the 40 S1 and 30 certificate tests, then rehearses publication-DDL failure/rollback and runs 40 publication cases with real local Auth-linked staff and transaction-local catalog grants. It checks disabled defaults, revoked scope, missing certificates, roster gaps, stale child versions, direct-SQL denial, immutable published children/formats, exact evidence, output-failure atomic rollback, replacement/history and current-authority replay. It runs all 220 frozen Foundation assertions (baseline catalog before additions; behavior after the new fences).

Five actual two-backend schedules inspect `pg_blocking_pids` before releasing the blocker: publish/edit and edit/publish; revocation/publish and publish/revocation; and natural grant expiry while publication waits on School. Each has independent durable state/receipt checks. SQL fixtures roll back; race fixtures commit only in separately reset disposable databases and are discarded with the CI environment. Exact-head observed CI results are recorded in PR #102 after execution, never inferred from prepared tests.

This is an inactive additive proposal outside executable migrations. No hosted target or global operation registrar/manifest is changed; the original D1 composition remains a separate source. Complete DB03↔D1 integration, independent/security/owner acceptance, populated upgrade/recovery and staged activation remain separate release gates. Administrator upload, actual single-staff identity verification, stored certificate grace/history and final admission/Finance/Student commands remain the next application-layer database work.

**Simple example:** a School publishes a new rule requiring an additional transcript. The previous policy still says that document is optional; the new version says required. Neither version can waive the core certificates. Future submission commands can bind new applications to the new version while retaining the old version for earlier submissions.
