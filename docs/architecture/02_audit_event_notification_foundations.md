# 02 - Audit, Event and Notification Foundations

**Status:** PROPOSED contracts, 2026-09-22. Required audit, permission-aware delivery and future-ready attendance boundaries are CONFIRMED; transport, retention, payload and provider choices remain proposed/TBD.
**Sources:** [AGENTS.md](../../AGENTS.md), [master specification](../requirements/School_OS_SaaS_Master_Specification_v0.2.md) sections 17, 22.1, 49-58 and 64-78, [security rules](../security/SECURITY_WORKFLOW_AND_AUDIT.md).

## 1. Four different responsibilities

| Concept | Question answered | Owner / example | Mutability and consumers |
|---|---|---|---|
| Audit event | Who attempted or performed what, when, why and with what authority/outcome? | Audit: Principal approved request R; later Attendance applied correction C | Append-only evidence; restricted investigators/reviewers; not a delivery queue |
| Domain event | What committed business fact may other modules react to? | Attendance: attendance.corrected with aggregate/version and safe identifiers | Immutable versioned fact; authorized consumers; not a full change log or arbitrary client event |
| Notification | What information should a particular recipient receive? | Notifications: a correction was completed; open the authorized record | Per-recipient inbox/read state and separate delivery attempts; not proof that the fact happened |
| Automation action | What constrained work should run due to a rule/time/event? | Automation: recalculate an attendance metric | Idempotent command with actor/purpose and outcome; a new fact/audit may result |

They must not become one entity with a shared lifecycle or retention policy. A single business transaction can create audit evidence and domain events, but their meaning, payload and access differ.

## 2. Audit envelope

PROPOSED F19 fields and invariants:

| Field group | Required meaning / minimization |
|---|---|
| Identity | Event UUID; stable initiating principal; executor principal if different; proven Person only when supported; Auth subject snapshot for correlation, never password/token |
| Authority | Active context and relevant assignment/permission/policy versions or references; do not infer unlimited authority from a displayed role name |
| Action and target | Domain, registered action, target kind/ID descriptor, result/outcome and target version; optional trusted campus context |
| Change | Allowlisted old/new values or protected revision references where appropriate; distinguish requested proposal from actual committed values |
| Reason and workflow | Human reason where required, approval request/review references, domain-result/revision reference |
| Time | Server recorded_at and action occurred_at; external captured_at is separately labelled with trust provenance |
| Correlation | Request/trace identifier, command/idempotency reference, causation/event identifiers |
| Session/device/source | Verified session reference where available, bounded device/client metadata, UI/API/server/automation/integration/future-device source, network metadata if justified |

A shared-family action identifies its account and FAMILY context. It must not falsely name the teacher Person associated with that account as the acting adult. User-entered device names and capture times remain claims.

Capture enough old/new evidence to explain a correction without making audit a duplicate unprotected database. Do not log passwords, access tokens, service keys, SMTP secrets, raw biometric material or full file bodies. Restricted health/identity details use field-level redaction or protected domain revision references; audit summaries remain useful without disclosing the payload to every audit reader. Redaction policy and exceptional retention are T10.

## 3. Audit coverage and trust limits

Audit account activation/suspension/relinking, role/permission/scope changes, configuration changes affecting rules, approval submissions/decisions/reassignment/cancellation/execution, protected data corrections, publication/finalization, financial changes, sensitive exports/document access where required, AI administrative actions and deployment/backup/restore administration.

Super Admin, Owner, operator and service execution are not exempt. Sensitive successful writes require synchronous evidence in the same database transaction. Failures/denied attempts use a separate security-attempt path after rollback, with rate limits to prevent log flooding. Authentication/provider failures require an explicit ingestion/operational evidence strategy (T04/T10); a domain trigger cannot observe every external login failure.

Normal clients cannot insert invented audit facts or update/delete audit history. Restricted writers and bounded read policies apply even to application administrators. The application audit boundary does not make a database owner or infrastructure operator cryptographically incapable of tampering. Higher-assurance immutable external archives, administrator logs and integrity verification are optional operational safeguards to evaluate under T10, not claimed as already implemented.

No normal deletion of protected finance, results, attendance or audit history is introduced. Retirement of an account keeps stable actor history. Where eligible cleanup is later allowed, require documented policy, reason, approvals and durable audit of the cleanup. Exact retention durations, jurisdictional obligations, legal holds, encryption/key handling and anonymization are TBD; no automatic TTL is chosen.

Notification read state, transient delivery diagnostics and eligible drafts have different retention needs from business history. Archiving audit to another store requires access controls, completeness verification, restore/retrieval tests and preservation of references; “archive” must not mean losing evidence.

## 4. Domain event and outbox contract

PROPOSED F20 is an immutable event envelope committed alongside the domain change: event UUID, type/schema version, aggregate ID/version, recorded/occurred times, originating command, correlation/causation and minimum payload. Event type/validator is application-owned. Do not send full private records to a general event bus.

F21 is separate mutable delivery state per event/consumer: lease/fencing token, attempts, next-attempt time and outcome. This is a transactional outbox design, not event sourcing; domain records/history remain authoritative.

Delivery is **at least once**. Consumers deduplicate by event ID and consumer purpose. Domain commands additionally keep their own durable operation uniqueness. Repeated delivery must not send a second financial command or duplicate an inbox item. Per-aggregate version ordering is used where it matters; no global event-order guarantee is claimed.

Retry transient faults with bounded backoff; expose exhausted items to an authorized dead-letter/replay process. A crashed worker's lease may expire; a stale worker must not acknowledge or overwrite a later lease. Replays preserve original event identity and causation. Log replay authority/reason; do not fabricate a new business event just to retry delivery.

Transport/broker choice, polling mechanism, retention and throughput targets remain T08. No dependency, queue product or Supabase worker is installed.

## 5. Notifications and preferences

F22 represents each recipient's inbox item. F27 stores allowed recipient preferences, and F28 tracks channel attempts independently. Initial channels are CONFIRMED as in-app, push and email; WhatsApp is FUTURE. No push provider is selected. Email provider configuration references secrets securely rather than placing passwords in settings records.

Compute recipients through current authorized relationships; never blindly trust client-supplied recipients. Deduplicate by business event/recipient/category. Resolve preferences only after authorization; a preference cannot grant access. Mandatory categories, opt-outs and quiet hours are T08.

Store minimal safe notification content. Recheck access at dispatch and when opening the referenced record. After a family link or staff scope is revoked, suppress any future sensitive delivery and prevent target access. A previously delivered email/push cannot reliably be recalled, so it should avoid protected details. Recipients are distinct principals: staff messages addressed to Ahmed's individual principal must not appear in the shared-family inbox or go to a shared endpoint merely because a Person/contact/family link matches. T01 covers account/session isolation; T08 covers verified delivery endpoints. Preferences never merge inboxes or staff authority across principals.

Read/dismiss commands affect only the recipient's permitted notification. Operators may inspect sanitized delivery diagnostics with separate privileges; they do not acquire unrestricted inbox or target access.

## 6. Automation boundary

A rule firing is not proof that its action was authorized or executed. Future automation runs as an explicit purpose-bound SYSTEM principal, preserving triggering user/event and policy version. It calls the same typed commands, observes current scope/state and produces its own audit/application result.

Distinguish recalculating a derived metric from modifying business truth. A configured fee action must use Finance validation and approvals where required; AI or automation cannot approve itself merely because it runs on the server. Scheduled actions need school timezone/DST rules, idempotent occurrence identity and loop prevention. Full rules/scheduler entities are postponed.

## 7. Worked attendance correction sequence

1. Teacher in verified staff context submits a typed correction request with old/new status and reason; request creation is audited.
2. The configured Principal reviewer is currently eligible and approves the assigned step; append approval audit evidence. Attendance is still unchanged.
3. Attendance revalidates approval, scope, target version and domain rules. Commit canonical correction history, application receipt, attendance-change audit and attendance.corrected event atomically.
4. Outbox consumer creates permitted Teacher/Family inbox items if configured and schedules authorized channel delivery.
5. Automation may recompute derived attendance metrics idempotently. That is a separate action; its failure does not erase the correction or audit.
6. Parent access is resolved through current family-child links. No family user inherits the submitting teacher's staff context.

Event processing failures do not relabel an executed correction as failed. Approval failure and domain application failure remain different outcomes.

## 8. Files, request metadata and future capture adapters

Uploads use private object storage with validated metadata and typed ownership. A file is not available merely because its metadata exists; storage upload and database finalization need reconciliation. Evidence must survive the request's protected retention requirements. Generated PDFs normally use persistent facts/identifiers and on-demand rendering.

Signed URLs are temporary bearer access: previously issued links may outlive a permission change until expiry. Prefer authenticated access for sensitive material or a suitably short-lived authorized download path; exact policy is T11. [Provider-neutral private access](04_provider_neutral_object_storage.md) governs all adapters; Supabase Storage is one possible adapter.

Manual and QR now, and biometric/fingerprint, RFID/NFC, camera/face-recognition and other sources in future, follow:

~~~mermaid
flowchart LR
  S["Manual, QR, future capture source"] --> A["Capture adapter and source event"]
  A --> I["Identity resolution"]
  I --> V["Source, time, scope and replay validation"]
  V --> D["Attendance domain command"]
  D --> C["Canonical attendance record and history"]
  C --> E["Audit and committed domain event"]
~~~

A captured input is an untrusted observation until verified. It is not the same as a committed attendance domain event. Preserve method, source/event ID, capture/receive times and provenance where justified; validate duplicates, stale/replayed input, campus/assignment and confidence when applicable. A device credential is not a teacher's identity.

**Postponed:** device/integration registry, vendor SDKs, protocols, biometric template location, face media/embeddings, anti-spoofing, consent/privacy rules and raw-media retention (T14). Nothing in Foundation requires a device inventory now. Bounded request/session/device audit metadata suffices; no separate canonical attendance database per method is proposed.

## 9. Review links

[Entity map](../database/02_foundation_entity_map.md) describes F19-F28. [Approval design](../workflows/01_approval_engine_design.md) supplies execution semantics. [Test strategy](../testing/01_foundation_test_strategy.md) covers transactional rollback, duplicate delivery, audit tampering, context leakage and future input safety. [ADR-001](../decisions/ADR-001-foundation-database-principles.md) owns unresolved choices.
