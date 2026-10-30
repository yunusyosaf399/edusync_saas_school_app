# DB03 S23 — independent return ledger review, without premature bank clearance

**30 October 2026 · inactive candidate.** Stacked on [S22 #184](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/184). The prior official `ADM-` payment, S22 reported bank return and per-allocation compensating reversals remain immutable. This stage deliberately reviews **accounting provenance**, NOT the external bank's decision.

## Independent protected review

An independently authenticated, assigned `ACCOUNTANT` (a different **individual** from the person who originally reported the return **and** the person who issued the original payment) may execute the dedicated Finance worker's `app_private.db03_review_return_ledger(application,expected_version,return_id,decision,seen_return_minor,seen_compensation_minor,private_bank_case_reference,private_reason,idempotency_key)`.

The issuer requires a valid current JWT and live `finance.admission.payment.return.ledger.review` Campus-scoped role assignment, scope contract, grant, permission and enabled operation. The grant and operation are **not seeded in production**; disposable tests define them and authenticate a third distinct synthetic Finance person. School, Campus, academic year, applicant, S22 return and payment are validated under the same Foundation authority fence and School → Campus → Year → Applicant → reported Return → payment transaction locks. The command verifies the S22 receipt plus its audit and outbox, then independently recounts every original S20 allocation and all S22 compensating reversal rows. Reviewers must supply the observed exact minor-unit amounts and private case reference; all compensating amounts and predecessor IDs must match.

Exactly one immutable review is allowed per S22 report. The three terminal outcomes are `LEDGER_MATCHES_REPORT`, `DISPUTE_REPORTED_RETURN` and `REQUEST_BANK_EVIDENCE`. All produce an atomic new receipt/audit/outbox, support exact-key idempotent replays and reject competing reviews, tampering, scope mixing and revoked grants. Raw private notes and private case references are never included in receipts, audit details, or outbox payload.

**All three outcomes retain the S22 return freeze.** Even an independently audited ledger-match does not constitute confirmation that money really left the bank account. No verified-bank status is asserted; no original payment, allocation or reversal is changed; no new allocation, payout, refund authorization, reallocation, admission clearance, Principal approval or Student creation is enabled. The S22 read model continues to report `BANK_RETURN_RECONCILIATION_REQUIRED` and zero effective funding for reported returned money.

## Acceptance

A new private RLS-forced immutable review table; a restricted worker command and authorization helper; **16 pgTAP assertions** and intentionally failed DDL/rollback probes are integrated into disposable DB03 CI. The real Auth and banking-proof chain also exercises cross-applicant denial, independent role grants, witnessed amounts, exact replay, changed-key denial, return dispute, request for evidence, concurrent reviewers, and revocation, while retaining S14–S22 regressions.

**Release blockers:** Actual external bank proof upload and independent verification/dispute resolution; partial return support or settlement; explicitly authorized reconciliation/resumption/reallocation; Finance positive clearance and revocation; Principal-only admissions approval; D1 Student creation. Integration of parallel [PR #102](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/102) (D1 grade destination, monthly tuition, transport/books category scholarships) still needs a separate branch/run-order review. This draft does **not** modify that PR, main, or hosted Supabase.
