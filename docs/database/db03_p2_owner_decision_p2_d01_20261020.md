# DB-03 owner decision — P2-D01 (2026-10-20)

**Owner approved Option A:** an Admissions application can be DRAFT with no linked Foundation Person. Before SUBMITTED, a verified canonical Foundation Person binding is required.

**SQL consequence once installation is separately authorized:** `admission_applications.person_id uuid NULL REFERENCES app_private.people(id)`; allow NULL exclusively in DRAFT and reject SUBMITTED or later unless the current application-specific identity-resolution head proves the same canonical Person and checked version. Person verification must be server-authoritative.

**Not approved by this decision:** matching by personal name, identity verification source, automatic Person creation, Person merge, draft personal-data retention, permissions/approvals, Finance integration, D1 Student Creation or migration activation. These remain separate owner/security/integration gates. No client `is_verified` flag can satisfy the SUBMIT rule.

This record supersedes historical P2-D01 undecided wording in previous DB-03 design documents. It does not authorize executable SQL.
