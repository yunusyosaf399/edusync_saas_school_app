# DB03 P46A — retained forwarded-policy candidate, private and read-only

**6 November 2026. Inactive candidate source; no external database write.**

## Product reconciliation

The school administrator already chooses a **published** admissions policy when running the existing protected `prepare_admission_documents` command. The selected policy is retained in `admission_document_intakes.policy_version_id`, and the later protected `forward_admission_to_principal` command retains the exact `intake_id` that the Principal is asked to review.

Therefore **P46 should not introduce a second user-facing policy selector**. A separate checkbox/dropdown after forwarding would create a race or allow the policy to drift away from the document roster that was reviewed.

## Added

- Private `app_private.db03_policy_binding_candidate_source(application_id,expected_version,forward_id)`, fixed `schoolos_schema_owner`, SECURITY INVOKER, no client/worker/executor EXECUTE grants and no mutation.
- Refuses stale Application version, withdrawn/closed state, stale latest Forward, unlinked/missing document intake, inconsistent School, policy not published **at the Forward timestamp**, wrong-School/Kind/unpublished profiles, or missing/invalid 32-byte immutable configuration hash.
- Correctly permits an old **retired** policy as historical evidence if it was effective when that specific Forward occurred, so a new publication cannot rewrite an already forwarded application policy.
- Returns the candidate exact Policy ID, its own APPLICATION/ADMISSION profile IDs, School, Academic Year, Application version and Stage epoch, forwarded Intake/Forward IDs and published configuration fingerprint only for a valid source.
- Every output explicitly says `actor_authorized_to_bind=false`, `policy_binding_committed=false`, `can_bind=false`, `can_approve=false` and `can_create_student=false`. No client operation, policy snapshot writer or Student creation is enabled.
- 24 rollback-only pgTAP tests, private access/source guard, injected failed-install rollback rehearsal, full combined DB03 acceptance.

## Simple example

Ahmad's administrator prepares the required document checklist under Policy A, then forwards the complete file to the Principal. Even if the school later publishes Policy B, the private candidate source points to **Policy A from the retained Forward**, not the latest policy version. It also checks that A was effective when the file was forwarded.

A mismatched Forward ID or changed application version produces no usable candidate.

## Next dependency: P46B policy binding writer + final Principal handoff

A future authorized effect must recheck this candidate **after acquiring all required locks**, validate Principal authority and current Forward/review evidence, atomically retain the P44 snapshot with its revision and signed command receipt/audit/outbox, and reconcile the S3/S5 NULL application policy projection without relaxing unrelated protections. Owner behavior is still Administrator DRAFT/Forward → Principal review/sole final approval, not another manual approval.

If the binding forms part of the final Principal APPROVE, it must commit with the P38/P45 Admission number and D1 Student/Enrollment/roll creation or all roll back. The old S10 admission-fee restriction must be reconciled with the owner-accepted UNPAID/SKIPPED/MARKED_PAID statuses before activation.

No changes to `main`, hosted Supabase, actual student records, or previously frozen D1 migrations.
