# Domain Package 01 — Effect 19 Executor Ownership Correction

**Status:** SECURITY CORRECTION CANDIDATE — EFFECT 19/36 NOT FROZEN.

The independent post-push audit of candidate `80e90cec216f47a2e532fba61211ca4e9bca6001` found an executor-boundary packaging defect, not a product-policy defect.

Effect 19 requires:

- authorization predicates owned by `schoolos_authz_reader`;
- DIRECT domain command owned by `schoolos_employee_executor`;
- submit/review/apply workflow RPCs owned by `schoolos_workflow_executor`;
- checked request read owned by `schoolos_read_executor`;
- evidence helpers owned by `schoolos_evidence_writer`;
- defensive trigger owned by `schoolos_schema_owner`.

Because the review fragment did not reset its role before the next file, fragment ordering could leak the workflow-executor role into the authorization-reader section. In addition, the apply RPC was created after that section's reset and therefore required an explicit transfer from the outer migration owner to `schoolos_workflow_executor`.

The corrective continuations restore the outer role between fragments, revoke the temporary workflow CREATE edge, explicitly transfer apply ownership, and preserve only the authenticated EXECUTE grant on the public apply signature.

The qualification lock helper also receives only the column privileges needed for the frozen School anchor lock: `SELECT(id), UPDATE(id)` on `app_private.school_profiles` to `schoolos_employee_executor`. This privilege exists solely as the implementation substrate for `FOR UPDATE`; it does not create an authenticated table path, School management permission, or role/grant authority.

No new executor membership, schema-owner runtime entry point, service-role shortcut, direct authenticated DML, or Foundation authorization mutation is introduced.

Exact-SHA CI and final independent review remain required before effect 19 may be frozen.
