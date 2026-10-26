# Principal-only admission verification and completion

Owner: `yunusyosaf399`. Recorded 26 October 2026 from the current conversation.

> So only principle is allowed to verify the admissions details then complete the application, while admin only create application

“Principal” here means the school leadership role, not the Foundation `principals` table, whose records represent many kinds of authenticated actors.

## Required behavior

- Admission administrators create/prepare applications and collect supporting certificates. Intake access alone never permits verification or final completion.
- Only a currently authorized school principal verifies admission details, including original identity/document attestations, and authorizes completion. Require the principal-role assignment plus exact action permission, applicable scope and current workflow conditions; role display text alone is insufficient.
- Retain the selected independent certificate reviewer rule: the principal cannot verify a certificate they uploaded themselves. Holding an administrator role as well does not bypass this separation.
- Keep mandatory certificates, the maximum two-month missing-document window, duplicate review, Finance and other applicable completion gates. Principal approval cannot make missing certificates complete or permit provisional enrollment.

## Later owner clarification: forwarding, submission and Student creation

The owner further specified that missing documents must block **forwarding to principal approval**, not merely final enrollment. While required certificates are missing, the application remains pending with the administrator. Within the existing allowed window, the administrator attaches the received documents and then forwards the complete application for principal review. Upload/attachment is collection, not verification or approval; the principal still checks the documents and admission details.

Only after the principal approves may the application become submitted and the Student record be created. Forwarding for review must therefore be distinct from submission. Neither pending collection, attachment nor forwarding creates a Student. Completion must recheck current required documents and all other applicable gates; replay must not create duplicate Students. A previously created canonical Person is a separate identity record and does not mean a Student or enrollment already exists.

Required sequence: administrator preparation → pending documents when anything required is missing → administrator attaches all required documents within the allowed window → forwarded for principal review → principal verification and approval → submitted application and protected Student creation. These are product workflow descriptions, not newly implemented database status values. The existing grace deadline must not reset when documents are attached or the application is forwarded. Post-deadline handling remains unresolved; do not invent automatic rejection or extension.

This narrows earlier eligibility for one authorized staff verifier and school-wide identity staff. It does not change the original-document inspection method or permit automatic duplicate creation/merging. Earlier owner-answer records remain historical evidence.

## Implementation status

S4 `db03_identity_actor_context` and S5 `db03_person_actor_context` now require the active, non-family role with immutable deployment code `PRINCIPAL` on the exact live permission/assignment/scope chain. Foundation already makes role codes immutable; labels do not grant authority. S5 Person creation includes an identity attestation and receives the same restriction. No deployment role or grant is seeded. Administrator draft intake remains separate. Runtime validation is recorded in the S6 acceptance note. Final submission/completion and private certificate verification are not yet implemented.

The candidate denies administrators with verification grants but no eligible principal chain, including mixed-role actors; rechecks current eligibility after lock waits and on replay; and preserves school-wide scope for canonical Person creation. Twenty-seven new assertions and four additional observed-lock schedules cover the restriction. The independent uploader check belongs to the remaining file workflow. Historical S4/S5 results predate the restriction; use the new exact-source run for acceptance.

The original clarification record changed no SQL. The subsequent S6 implementation updates two inactive SQL authority candidates and test fixtures; executable migrations, deployment grants and hosted databases remain unchanged. See [S6 implementation and remaining work](db03_s6_principal_authority_20261026.md).

Example: Ali's birth certificate is missing, so his application stays pending with the administrator and cannot reach the principal's approval queue. His family supplies it within the allowed window; the administrator attaches it and forwards the complete application. The principal checks and approves it. Only then may the application be submitted and Ali's Student record created, subject to the other required gates.
