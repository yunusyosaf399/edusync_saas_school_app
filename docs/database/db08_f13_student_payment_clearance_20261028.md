# DB08 F13: explicit Student payment clearance (inactive candidate)

F13 is a payment-backed clearance for an **existing Student**, Campus and current AcademicYear. It does not satisfy the pre-Student Admissions Finance gate. DB03 requires a separate Finance-authorizer source for an applicant before D1 creates a Student, including approved pre-admission concessions; F1–F12 Student charges cannot be silently substituted for that source.

An authenticated individual with a current, explicit Campus-scoped `FINANCE_AUTHORIZER` issue grant may create an immutable `ISSUE` event only when at least one selected charge has positive net and all selected charges in that Campus and AcademicYear have been fully covered by official F10 payments through F11 allocations. A distinct revoke grant permits an explicit `REVOKE` successor; a later issue may follow if the settled evidence remains valid. Each event has a strictly ordered revision, predecessor, School/Campus/Student/year, amount snapshot, digest of retained charge/discount/allocation sources, reason, actor, command receipt, audit and outbox. Exact-key replay returns the same event after a current grant check. There is no mutable paid or cleared flag.

The checked status read uses the F12 family-child or staff Campus read grant. `ACTIVE` requires the latest event to be `ISSUE`, the current source digest to match, and the current net to remain positive and fully allocated. A later charge, changed allocation evidence or other new financial fact makes the old issuance `STALE` until a new explicit decision after settlement. A `REVOKE` head yields `REVOKED`. Zero due without an issued event yields `NONE`.

This draft includes no waiver, automatic clearance, Admissions reference, interface, hosted activation, or production permission seed. A separate pre-admission Finance contract and jointly fenced DB03 handoff are still required.

Disposable acceptance covers worker-only entry and install rollback, real Auth denial of unsettled charges and family issuance, issue/replay, revoke/reissue, a later charge making status stale, retained history, and immediate denial after issuer revocation.
