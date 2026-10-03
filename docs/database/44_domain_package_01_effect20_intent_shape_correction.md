# Effect 20/36 post-CI intent-shape correction

Status: corrective continuation; effect 20 remains UNFROZEN pending exact-SHA CI and final review.

The first effect-20 candidate passed Foundation CI but independent source audit found a canonical command-shape defect: DIRECT and SUBMIT build an 11-element intent array, while `d1_employee_experience_command_context` required length 10. That mismatch would reject every otherwise-valid DIRECT/SUBMIT call before mutation.

Correction:
- add ordered continuation `effect20_02a_experience_intent_shape.sql.draft`;
- replace only the command-context helper body;
- require 11 elements for `employee.experience.change` and `request.submit`;
- keep review at 4 and apply at 2;
- preserve the exact canonical hash fields, advisory locks, receipt lookup and idempotency semantics.

No product semantics, permission/scope catalog entries, approval routing, history behavior, event vocabulary, disclosure boundary, or remote execution status changed.

Migration 10 remains non-executable `.sql.draft`; D1C2 and remote/staging execution remain unauthorized.
