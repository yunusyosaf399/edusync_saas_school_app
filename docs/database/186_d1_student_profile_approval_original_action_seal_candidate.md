# Student Profile typed APPROVAL action seal — isolated receipt-binding trial

Date: 2026-10-17. **Status: LOCAL-ONLY candidate, not a production approved operation.** Follows owner decisions SP-01…08, ADR-005 B, and the authenticated SUBMIT/REVIEW/APPLY trial in PR #83.

## Problem and solution

The earlier P1 typed APPROVAL adapter validated six action fields, then submitted only its computed **after image** to the legacy protected workflow. The legacy receipt hashes that final image. Different original action patterns that resolve to the same six values could be silently accepted with one idempotency key.

This candidate provides a **separate immutable receipt-linked action seal** without changing the frozen D1 workflow or Employee RPCs. Its pure canonicalizer validates exactly six keys, action/value arity, trims SET values, and normalizes dates and photo UUIDs. A fixed-order intent contains the operation, phase, Student UUID, Campus hint, original expected Student version, **normalized tri-state actions**, and trimmed private reason. The local SQL hashes this normalized JSON array with SHA-256.

Inside the SAME authenticated SUBMIT transaction, actor/key advisory serialization and original-actor binding are checked. A same-key difference in actions, reason, Student, version, or Campus is denied **before** recomputing Student projection. New keys must not adopt an unsealed legacy SUBMIT receipt. The wrapper resolves current PRIMARY placement, current scoped permission and APPROVAL policy, validates the Student version and the existing typed preflight, creates a genuine PENDING request, and inserts exactly one immutable seal with foreign keys to that exact request and SUBMIT receipt. FORCE RLS and purpose-scoped grants keep these seals private from ordinary authenticated, anon, FAMILY and Student users. Any exception aborts both request and seal.

**Historical replay:** when a Student version has advanced after APPLY, a normalized identical retry must not recompute the stale earlier profile. It must recheck the current authenticated individual principal, Student active context, current campus, live authority and APPROVAL route, validate the original receipt/request/actor bond, and return the original submitted request/version without a new effect. If the current grant is revoked, replay is denied. Same-result different-action retries conflict even if the legacy profile projection matches.

The authenticated local acceptance reuses the unchanged 41-assertion P1 approval suite #67 and the PR #83 separate-Person reviewer test: normalized original SUBMIT replay, APPLY and historical SUBMIT replay, semantic collision where CLEAR an already-empty contact and UNCHANGED contact share the same final image, changed-reason/version key conflicts, revoked-grant historical denial, receipt/request FK consistency, immutable seal, no authenticated seal reads, exactly one private Student history revision and redacted outbox, and rollback cleanup.

## Explicit limits

- The legacy SUBMIT receipt itself continues to hash the materialized six-field profile. This candidate binds the original normalized action digest through a **unique immutable companion record linked to that receipt**, not by changing the frozen receipt's hash format. A production version requires independent approved migration, roles, RLS, retention and privacy, and a cross-platform canonical encoding/version contract.
- Positive photo ownership/purpose/availability/entitlement, six-field successful SET/CLEAR tests, purpose-scoped production history writer, independent security review, no-placement ALL semantics and real two-session DIRECT/APPROVAL/grant-revocation races remain open.
- All SQL remains in quarantined proposal files and disposable BEGIN/ROLLBACK; no hosted Supabase changes, no active Migration 10 or frozen D1 package edits, no alteration to Employee Profile, and no protected-operation acceptance increment.

**Baseline unchanged:** 31/35 accepted operations, Issue #67 still open, 34 D1 base tables, 228 Migration 10 draft fragments, 97 permissions, 322 scope alternatives, 36 operation contracts.

**Example:** A clerk submits SET Previous School to Oak Academy and UNCHANGED Contact. After approval and APPLY, the exact retry returns the original request. Changing Contact to CLEAR on the retry conflicts, even if Contact was already empty and the resulting Student values would be identical.
