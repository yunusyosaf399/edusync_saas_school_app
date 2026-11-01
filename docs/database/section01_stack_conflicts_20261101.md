# Section 01 stack conflict analysis

Snapshot 1 November 2026. Compared exact Git object trees; no merge or SQL execution.

Changed paths are measured against pinned main, including shared inherited changes. A shared path is a review candidate, not proof of an unresolved textual or semantic conflict.

| Stack A | Stack B | Shared changed paths | Paths with different final blobs |
|---|---|---:|---:|
| db01_db02 #168 | admissions_finance #102 | 7 | 7 |
| db01_db02 #168 | admissions_assessment #194 | 7 | 7 |
| db01_db02 #168 | curriculum #103 | 7 | 7 |
| db01_db02 #168 | receipt_scope #195 | 7 | 7 |
| db01_db02 #168 | receipt_bytes #196 | 7 | 7 |
| db01_db02 #168 | deferred_bank_signing #190 | 7 | 7 |
| admissions_finance #102 | admissions_assessment #194 | 267 | 47 |
| admissions_finance #102 | curriculum #103 | 50 | 45 |
| admissions_finance #102 | receipt_scope #195 | 267 | 45 |
| admissions_finance #102 | receipt_bytes #196 | 267 | 46 |
| admissions_finance #102 | deferred_bank_signing #190 | 262 | 55 |
| admissions_assessment #194 | curriculum #103 | 50 | 45 |
| admissions_assessment #194 | receipt_scope #195 | 267 | 47 |
| admissions_assessment #194 | receipt_bytes #196 | 267 | 48 |
| admissions_assessment #194 | deferred_bank_signing #190 | 262 | 56 |
| curriculum #103 | receipt_scope #195 | 50 | 45 |
| curriculum #103 | receipt_bytes #196 | 50 | 45 |
| curriculum #103 | deferred_bank_signing #190 | 50 | 45 |
| receipt_scope #195 | receipt_bytes #196 | 267 | 46 |
| receipt_scope #195 | deferred_bank_signing #190 | 262 | 55 |
| receipt_bytes #196 | deferred_bank_signing #190 | 262 | 56 |

DB-009 remains IN PROGRESS. Differing source, registration, test and documentation paths require package-owner composition and exact-source acceptance; retaining both sets of files alone does not prove compatibility. PR #190 is excluded from the current receipt-only scope.

## db01_db02 / admissions_finance: different final paths

- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `tools/supabase/domain_business_ci.py`
- `tools/supabase/domain_local_ci.py`
- `tools/supabase/tests/test_domain_acceptance_ci.py`
- `tools/supabase/tests/test_domain_local_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## db01_db02 / admissions_assessment: different final paths

- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `tools/supabase/domain_business_ci.py`
- `tools/supabase/domain_local_ci.py`
- `tools/supabase/tests/test_domain_acceptance_ci.py`
- `tools/supabase/tests/test_domain_local_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## db01_db02 / curriculum: different final paths

- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `tools/supabase/domain_business_ci.py`
- `tools/supabase/domain_local_ci.py`
- `tools/supabase/tests/test_domain_acceptance_ci.py`
- `tools/supabase/tests/test_domain_local_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## db01_db02 / receipt_scope: different final paths

- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `tools/supabase/domain_business_ci.py`
- `tools/supabase/domain_local_ci.py`
- `tools/supabase/tests/test_domain_acceptance_ci.py`
- `tools/supabase/tests/test_domain_local_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## db01_db02 / receipt_bytes: different final paths

- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `tools/supabase/domain_business_ci.py`
- `tools/supabase/domain_local_ci.py`
- `tools/supabase/tests/test_domain_acceptance_ci.py`
- `tools/supabase/tests/test_domain_local_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## db01_db02 / deferred_bank_signing: different final paths

- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `tools/supabase/domain_business_ci.py`
- `tools/supabase/domain_local_ci.py`
- `tools/supabase/tests/test_domain_acceptance_ci.py`
- `tools/supabase/tests/test_domain_local_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## admissions_finance / admissions_assessment: different final paths

- `docs/database/20261020_enrollment_db01_composed_integration.md`
- `docs/database/20261020_enrollment_end_lock_prefix_acceptance.md`
- `docs/database/20261020_enrollment_move_roll_union_review.md`
- `docs/database/20261020_owner_choices_and_dependency_resolution.md`
- `docs/database/218_student_photo_provider_neutral_delivery_recovery_candidate.md`
- `docs/database/219_student_photo_provider_neutral_delivery_recovery_ci_merge_freeze.md`
- `docs/database/220_student_photo_provider_adapter_trust_contract_candidate.md`
- `docs/database/221_student_photo_provider_adapter_trust_contract_ci_merge_freeze.md`
- `supabase/migrations/20260928000000_domain_package_01_effect37_01_db01_allocator_history.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect37_02_db01_end_source_prelock.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_01_db01_roll_lineage_nonself.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_02_db01_roll_correct_result_pair.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_03_db01_direct_receipt_provenance.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_01_enrollment_move_roll_union.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_02_enrollment_move_entry_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_03_enrollment_move_apply_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_04_enrollment_move_workflow_prelock_acl.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_05_enrollment_move_reviewer_projections.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_06_enrollment_move_application_replay.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_01_school_local_roll_date.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_02_school_local_roll_consumers.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_03_db01_apply_request_version.sql.draft`
- `supabase/tests/domain/75_db01_allocator_retained_history.sql`
- `supabase/tests/domain/76_db01_end_stored_policy_prelock.sql`
- `supabase/tests/domain/77_db01_retained_result_pair_private_acl.sql`
- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `supabase/tests/domain/80_school_local_roll_business_date.sql`
- `supabase/tests/domain/fixtures/enrollment_end_lock_prefix.sql`
- `supabase/tests/domain/fixtures/enrollment_move_approval.sql`
- `supabase/tests/domain/fixtures/enrollment_move_roll_union.sql`
- `tools/db03/document_review_ci.py`
- `tools/db03/schema_candidate_ci.py`
- `tools/supabase/domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/domain_enrollment_move_approval_ci.py`
- `tools/supabase/domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/domain_roll_business_date_ci.py`
- `tools/supabase/tests/test_domain_db01_prerequisite_ci.py`
- `tools/supabase/tests/test_domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_approval_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## admissions_finance / curriculum: different final paths

- `docs/database/20261020_enrollment_db01_composed_integration.md`
- `docs/database/20261020_enrollment_end_lock_prefix_acceptance.md`
- `docs/database/20261020_enrollment_move_roll_union_review.md`
- `docs/database/20261020_owner_choices_and_dependency_resolution.md`
- `docs/database/218_student_photo_provider_neutral_delivery_recovery_candidate.md`
- `docs/database/219_student_photo_provider_neutral_delivery_recovery_ci_merge_freeze.md`
- `docs/database/220_student_photo_provider_adapter_trust_contract_candidate.md`
- `docs/database/221_student_photo_provider_adapter_trust_contract_ci_merge_freeze.md`
- `supabase/migrations/20260928000000_domain_package_01_effect37_01_db01_allocator_history.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect37_02_db01_end_source_prelock.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_01_db01_roll_lineage_nonself.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_02_db01_roll_correct_result_pair.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_03_db01_direct_receipt_provenance.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_01_enrollment_move_roll_union.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_02_enrollment_move_entry_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_03_enrollment_move_apply_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_04_enrollment_move_workflow_prelock_acl.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_05_enrollment_move_reviewer_projections.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_06_enrollment_move_application_replay.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_01_school_local_roll_date.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_02_school_local_roll_consumers.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_03_db01_apply_request_version.sql.draft`
- `supabase/tests/domain/75_db01_allocator_retained_history.sql`
- `supabase/tests/domain/76_db01_end_stored_policy_prelock.sql`
- `supabase/tests/domain/77_db01_retained_result_pair_private_acl.sql`
- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `supabase/tests/domain/80_school_local_roll_business_date.sql`
- `supabase/tests/domain/fixtures/enrollment_end_lock_prefix.sql`
- `supabase/tests/domain/fixtures/enrollment_move_approval.sql`
- `supabase/tests/domain/fixtures/enrollment_move_roll_union.sql`
- `tools/supabase/domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/domain_enrollment_move_approval_ci.py`
- `tools/supabase/domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/domain_roll_business_date_ci.py`
- `tools/supabase/tests/test_domain_db01_prerequisite_ci.py`
- `tools/supabase/tests/test_domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_approval_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## admissions_finance / receipt_scope: different final paths

- `docs/database/20261020_enrollment_db01_composed_integration.md`
- `docs/database/20261020_enrollment_end_lock_prefix_acceptance.md`
- `docs/database/20261020_enrollment_move_roll_union_review.md`
- `docs/database/20261020_owner_choices_and_dependency_resolution.md`
- `docs/database/218_student_photo_provider_neutral_delivery_recovery_candidate.md`
- `docs/database/219_student_photo_provider_neutral_delivery_recovery_ci_merge_freeze.md`
- `docs/database/220_student_photo_provider_adapter_trust_contract_candidate.md`
- `docs/database/221_student_photo_provider_adapter_trust_contract_ci_merge_freeze.md`
- `supabase/migrations/20260928000000_domain_package_01_effect37_01_db01_allocator_history.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect37_02_db01_end_source_prelock.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_01_db01_roll_lineage_nonself.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_02_db01_roll_correct_result_pair.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_03_db01_direct_receipt_provenance.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_01_enrollment_move_roll_union.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_02_enrollment_move_entry_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_03_enrollment_move_apply_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_04_enrollment_move_workflow_prelock_acl.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_05_enrollment_move_reviewer_projections.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_06_enrollment_move_application_replay.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_01_school_local_roll_date.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_02_school_local_roll_consumers.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_03_db01_apply_request_version.sql.draft`
- `supabase/tests/domain/75_db01_allocator_retained_history.sql`
- `supabase/tests/domain/76_db01_end_stored_policy_prelock.sql`
- `supabase/tests/domain/77_db01_retained_result_pair_private_acl.sql`
- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `supabase/tests/domain/80_school_local_roll_business_date.sql`
- `supabase/tests/domain/fixtures/enrollment_end_lock_prefix.sql`
- `supabase/tests/domain/fixtures/enrollment_move_approval.sql`
- `supabase/tests/domain/fixtures/enrollment_move_roll_union.sql`
- `tools/supabase/domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/domain_enrollment_move_approval_ci.py`
- `tools/supabase/domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/domain_roll_business_date_ci.py`
- `tools/supabase/tests/test_domain_db01_prerequisite_ci.py`
- `tools/supabase/tests/test_domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_approval_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## admissions_finance / receipt_bytes: different final paths

- `docs/database/20261020_enrollment_db01_composed_integration.md`
- `docs/database/20261020_enrollment_end_lock_prefix_acceptance.md`
- `docs/database/20261020_enrollment_move_roll_union_review.md`
- `docs/database/20261020_owner_choices_and_dependency_resolution.md`
- `docs/database/218_student_photo_provider_neutral_delivery_recovery_candidate.md`
- `docs/database/219_student_photo_provider_neutral_delivery_recovery_ci_merge_freeze.md`
- `docs/database/220_student_photo_provider_adapter_trust_contract_candidate.md`
- `docs/database/221_student_photo_provider_adapter_trust_contract_ci_merge_freeze.md`
- `services/payment_evidence/service.py`
- `supabase/migrations/20260928000000_domain_package_01_effect37_01_db01_allocator_history.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect37_02_db01_end_source_prelock.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_01_db01_roll_lineage_nonself.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_02_db01_roll_correct_result_pair.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_03_db01_direct_receipt_provenance.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_01_enrollment_move_roll_union.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_02_enrollment_move_entry_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_03_enrollment_move_apply_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_04_enrollment_move_workflow_prelock_acl.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_05_enrollment_move_reviewer_projections.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_06_enrollment_move_application_replay.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_01_school_local_roll_date.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_02_school_local_roll_consumers.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_03_db01_apply_request_version.sql.draft`
- `supabase/tests/domain/75_db01_allocator_retained_history.sql`
- `supabase/tests/domain/76_db01_end_stored_policy_prelock.sql`
- `supabase/tests/domain/77_db01_retained_result_pair_private_acl.sql`
- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `supabase/tests/domain/80_school_local_roll_business_date.sql`
- `supabase/tests/domain/fixtures/enrollment_end_lock_prefix.sql`
- `supabase/tests/domain/fixtures/enrollment_move_approval.sql`
- `supabase/tests/domain/fixtures/enrollment_move_roll_union.sql`
- `tools/supabase/domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/domain_enrollment_move_approval_ci.py`
- `tools/supabase/domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/domain_roll_business_date_ci.py`
- `tools/supabase/tests/test_domain_db01_prerequisite_ci.py`
- `tools/supabase/tests/test_domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_approval_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## admissions_finance / deferred_bank_signing: different final paths

- `docs/database/20261020_enrollment_db01_composed_integration.md`
- `docs/database/20261020_enrollment_end_lock_prefix_acceptance.md`
- `docs/database/20261020_enrollment_move_roll_union_review.md`
- `docs/database/20261020_owner_choices_and_dependency_resolution.md`
- `docs/database/218_student_photo_provider_neutral_delivery_recovery_candidate.md`
- `docs/database/219_student_photo_provider_neutral_delivery_recovery_ci_merge_freeze.md`
- `docs/database/220_student_photo_provider_adapter_trust_contract_candidate.md`
- `docs/database/221_student_photo_provider_adapter_trust_contract_ci_merge_freeze.md`
- `docs/database/db08_f6_student_discount_choice_20261027.md`
- `docs/requirements/School_OS_SaaS_Master_Specification_v0.2.md`
- `supabase/migrations/20260928000000_domain_package_01_effect37_01_db01_allocator_history.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect37_02_db01_end_source_prelock.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_01_db01_roll_lineage_nonself.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_02_db01_roll_correct_result_pair.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_03_db01_direct_receipt_provenance.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_01_enrollment_move_roll_union.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_02_enrollment_move_entry_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_03_enrollment_move_apply_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_04_enrollment_move_workflow_prelock_acl.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_05_enrollment_move_reviewer_projections.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_06_enrollment_move_application_replay.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_01_school_local_roll_date.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_02_school_local_roll_consumers.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_03_db01_apply_request_version.sql.draft`
- `supabase/proposals/db08/06_01_discount_storage.sql.draft`
- `supabase/proposals/db08/06_03_discount_commands.sql.draft`
- `supabase/proposals/db08/06_04_discount_review.sql.draft`
- `supabase/proposals/db08/06_05_discount_application.sql.draft`
- `supabase/tests/db03/14_applicant_official_payment.sql`
- `supabase/tests/db08/06_student_discounts.sql`
- `supabase/tests/domain/75_db01_allocator_retained_history.sql`
- `supabase/tests/domain/76_db01_end_stored_policy_prelock.sql`
- `supabase/tests/domain/77_db01_retained_result_pair_private_acl.sql`
- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `supabase/tests/domain/80_school_local_roll_business_date.sql`
- `supabase/tests/domain/fixtures/enrollment_end_lock_prefix.sql`
- `supabase/tests/domain/fixtures/enrollment_move_approval.sql`
- `supabase/tests/domain/fixtures/enrollment_move_roll_union.sql`
- `tools/db03/schema_candidate_ci.py`
- `tools/db08/schema_candidate_ci.py`
- `tools/supabase/domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/domain_enrollment_move_approval_ci.py`
- `tools/supabase/domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/domain_roll_business_date_ci.py`
- `tools/supabase/tests/test_domain_db01_prerequisite_ci.py`
- `tools/supabase/tests/test_domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_approval_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## admissions_assessment / curriculum: different final paths

- `docs/database/20261020_enrollment_db01_composed_integration.md`
- `docs/database/20261020_enrollment_end_lock_prefix_acceptance.md`
- `docs/database/20261020_enrollment_move_roll_union_review.md`
- `docs/database/20261020_owner_choices_and_dependency_resolution.md`
- `docs/database/218_student_photo_provider_neutral_delivery_recovery_candidate.md`
- `docs/database/219_student_photo_provider_neutral_delivery_recovery_ci_merge_freeze.md`
- `docs/database/220_student_photo_provider_adapter_trust_contract_candidate.md`
- `docs/database/221_student_photo_provider_adapter_trust_contract_ci_merge_freeze.md`
- `supabase/migrations/20260928000000_domain_package_01_effect37_01_db01_allocator_history.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect37_02_db01_end_source_prelock.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_01_db01_roll_lineage_nonself.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_02_db01_roll_correct_result_pair.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_03_db01_direct_receipt_provenance.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_01_enrollment_move_roll_union.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_02_enrollment_move_entry_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_03_enrollment_move_apply_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_04_enrollment_move_workflow_prelock_acl.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_05_enrollment_move_reviewer_projections.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_06_enrollment_move_application_replay.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_01_school_local_roll_date.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_02_school_local_roll_consumers.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_03_db01_apply_request_version.sql.draft`
- `supabase/tests/domain/75_db01_allocator_retained_history.sql`
- `supabase/tests/domain/76_db01_end_stored_policy_prelock.sql`
- `supabase/tests/domain/77_db01_retained_result_pair_private_acl.sql`
- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `supabase/tests/domain/80_school_local_roll_business_date.sql`
- `supabase/tests/domain/fixtures/enrollment_end_lock_prefix.sql`
- `supabase/tests/domain/fixtures/enrollment_move_approval.sql`
- `supabase/tests/domain/fixtures/enrollment_move_roll_union.sql`
- `tools/supabase/domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/domain_enrollment_move_approval_ci.py`
- `tools/supabase/domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/domain_roll_business_date_ci.py`
- `tools/supabase/tests/test_domain_db01_prerequisite_ci.py`
- `tools/supabase/tests/test_domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_approval_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## admissions_assessment / receipt_scope: different final paths

- `docs/database/20261020_enrollment_db01_composed_integration.md`
- `docs/database/20261020_enrollment_end_lock_prefix_acceptance.md`
- `docs/database/20261020_enrollment_move_roll_union_review.md`
- `docs/database/20261020_owner_choices_and_dependency_resolution.md`
- `docs/database/218_student_photo_provider_neutral_delivery_recovery_candidate.md`
- `docs/database/219_student_photo_provider_neutral_delivery_recovery_ci_merge_freeze.md`
- `docs/database/220_student_photo_provider_adapter_trust_contract_candidate.md`
- `docs/database/221_student_photo_provider_adapter_trust_contract_ci_merge_freeze.md`
- `supabase/migrations/20260928000000_domain_package_01_effect37_01_db01_allocator_history.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect37_02_db01_end_source_prelock.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_01_db01_roll_lineage_nonself.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_02_db01_roll_correct_result_pair.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_03_db01_direct_receipt_provenance.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_01_enrollment_move_roll_union.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_02_enrollment_move_entry_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_03_enrollment_move_apply_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_04_enrollment_move_workflow_prelock_acl.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_05_enrollment_move_reviewer_projections.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_06_enrollment_move_application_replay.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_01_school_local_roll_date.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_02_school_local_roll_consumers.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_03_db01_apply_request_version.sql.draft`
- `supabase/tests/domain/75_db01_allocator_retained_history.sql`
- `supabase/tests/domain/76_db01_end_stored_policy_prelock.sql`
- `supabase/tests/domain/77_db01_retained_result_pair_private_acl.sql`
- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `supabase/tests/domain/80_school_local_roll_business_date.sql`
- `supabase/tests/domain/fixtures/enrollment_end_lock_prefix.sql`
- `supabase/tests/domain/fixtures/enrollment_move_approval.sql`
- `supabase/tests/domain/fixtures/enrollment_move_roll_union.sql`
- `tools/db03/document_review_ci.py`
- `tools/db03/schema_candidate_ci.py`
- `tools/supabase/domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/domain_enrollment_move_approval_ci.py`
- `tools/supabase/domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/domain_roll_business_date_ci.py`
- `tools/supabase/tests/test_domain_db01_prerequisite_ci.py`
- `tools/supabase/tests/test_domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_approval_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## admissions_assessment / receipt_bytes: different final paths

- `docs/database/20261020_enrollment_db01_composed_integration.md`
- `docs/database/20261020_enrollment_end_lock_prefix_acceptance.md`
- `docs/database/20261020_enrollment_move_roll_union_review.md`
- `docs/database/20261020_owner_choices_and_dependency_resolution.md`
- `docs/database/218_student_photo_provider_neutral_delivery_recovery_candidate.md`
- `docs/database/219_student_photo_provider_neutral_delivery_recovery_ci_merge_freeze.md`
- `docs/database/220_student_photo_provider_adapter_trust_contract_candidate.md`
- `docs/database/221_student_photo_provider_adapter_trust_contract_ci_merge_freeze.md`
- `services/payment_evidence/service.py`
- `supabase/migrations/20260928000000_domain_package_01_effect37_01_db01_allocator_history.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect37_02_db01_end_source_prelock.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_01_db01_roll_lineage_nonself.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_02_db01_roll_correct_result_pair.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_03_db01_direct_receipt_provenance.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_01_enrollment_move_roll_union.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_02_enrollment_move_entry_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_03_enrollment_move_apply_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_04_enrollment_move_workflow_prelock_acl.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_05_enrollment_move_reviewer_projections.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_06_enrollment_move_application_replay.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_01_school_local_roll_date.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_02_school_local_roll_consumers.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_03_db01_apply_request_version.sql.draft`
- `supabase/tests/domain/75_db01_allocator_retained_history.sql`
- `supabase/tests/domain/76_db01_end_stored_policy_prelock.sql`
- `supabase/tests/domain/77_db01_retained_result_pair_private_acl.sql`
- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `supabase/tests/domain/80_school_local_roll_business_date.sql`
- `supabase/tests/domain/fixtures/enrollment_end_lock_prefix.sql`
- `supabase/tests/domain/fixtures/enrollment_move_approval.sql`
- `supabase/tests/domain/fixtures/enrollment_move_roll_union.sql`
- `tools/db03/document_review_ci.py`
- `tools/db03/schema_candidate_ci.py`
- `tools/supabase/domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/domain_enrollment_move_approval_ci.py`
- `tools/supabase/domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/domain_roll_business_date_ci.py`
- `tools/supabase/tests/test_domain_db01_prerequisite_ci.py`
- `tools/supabase/tests/test_domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_approval_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## admissions_assessment / deferred_bank_signing: different final paths

- `docs/database/20261020_enrollment_db01_composed_integration.md`
- `docs/database/20261020_enrollment_end_lock_prefix_acceptance.md`
- `docs/database/20261020_enrollment_move_roll_union_review.md`
- `docs/database/20261020_owner_choices_and_dependency_resolution.md`
- `docs/database/218_student_photo_provider_neutral_delivery_recovery_candidate.md`
- `docs/database/219_student_photo_provider_neutral_delivery_recovery_ci_merge_freeze.md`
- `docs/database/220_student_photo_provider_adapter_trust_contract_candidate.md`
- `docs/database/221_student_photo_provider_adapter_trust_contract_ci_merge_freeze.md`
- `docs/database/db08_f6_student_discount_choice_20261027.md`
- `docs/requirements/School_OS_SaaS_Master_Specification_v0.2.md`
- `supabase/migrations/20260928000000_domain_package_01_effect37_01_db01_allocator_history.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect37_02_db01_end_source_prelock.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_01_db01_roll_lineage_nonself.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_02_db01_roll_correct_result_pair.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_03_db01_direct_receipt_provenance.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_01_enrollment_move_roll_union.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_02_enrollment_move_entry_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_03_enrollment_move_apply_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_04_enrollment_move_workflow_prelock_acl.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_05_enrollment_move_reviewer_projections.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_06_enrollment_move_application_replay.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_01_school_local_roll_date.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_02_school_local_roll_consumers.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_03_db01_apply_request_version.sql.draft`
- `supabase/proposals/db08/06_01_discount_storage.sql.draft`
- `supabase/proposals/db08/06_03_discount_commands.sql.draft`
- `supabase/proposals/db08/06_04_discount_review.sql.draft`
- `supabase/proposals/db08/06_05_discount_application.sql.draft`
- `supabase/tests/db03/14_applicant_official_payment.sql`
- `supabase/tests/db08/06_student_discounts.sql`
- `supabase/tests/domain/75_db01_allocator_retained_history.sql`
- `supabase/tests/domain/76_db01_end_stored_policy_prelock.sql`
- `supabase/tests/domain/77_db01_retained_result_pair_private_acl.sql`
- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `supabase/tests/domain/80_school_local_roll_business_date.sql`
- `supabase/tests/domain/fixtures/enrollment_end_lock_prefix.sql`
- `supabase/tests/domain/fixtures/enrollment_move_approval.sql`
- `supabase/tests/domain/fixtures/enrollment_move_roll_union.sql`
- `tools/db03/document_review_ci.py`
- `tools/db03/schema_candidate_ci.py`
- `tools/db08/schema_candidate_ci.py`
- `tools/supabase/domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/domain_enrollment_move_approval_ci.py`
- `tools/supabase/domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/domain_roll_business_date_ci.py`
- `tools/supabase/tests/test_domain_db01_prerequisite_ci.py`
- `tools/supabase/tests/test_domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_approval_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## curriculum / receipt_scope: different final paths

- `docs/database/20261020_enrollment_db01_composed_integration.md`
- `docs/database/20261020_enrollment_end_lock_prefix_acceptance.md`
- `docs/database/20261020_enrollment_move_roll_union_review.md`
- `docs/database/20261020_owner_choices_and_dependency_resolution.md`
- `docs/database/218_student_photo_provider_neutral_delivery_recovery_candidate.md`
- `docs/database/219_student_photo_provider_neutral_delivery_recovery_ci_merge_freeze.md`
- `docs/database/220_student_photo_provider_adapter_trust_contract_candidate.md`
- `docs/database/221_student_photo_provider_adapter_trust_contract_ci_merge_freeze.md`
- `supabase/migrations/20260928000000_domain_package_01_effect37_01_db01_allocator_history.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect37_02_db01_end_source_prelock.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_01_db01_roll_lineage_nonself.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_02_db01_roll_correct_result_pair.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_03_db01_direct_receipt_provenance.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_01_enrollment_move_roll_union.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_02_enrollment_move_entry_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_03_enrollment_move_apply_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_04_enrollment_move_workflow_prelock_acl.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_05_enrollment_move_reviewer_projections.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_06_enrollment_move_application_replay.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_01_school_local_roll_date.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_02_school_local_roll_consumers.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_03_db01_apply_request_version.sql.draft`
- `supabase/tests/domain/75_db01_allocator_retained_history.sql`
- `supabase/tests/domain/76_db01_end_stored_policy_prelock.sql`
- `supabase/tests/domain/77_db01_retained_result_pair_private_acl.sql`
- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `supabase/tests/domain/80_school_local_roll_business_date.sql`
- `supabase/tests/domain/fixtures/enrollment_end_lock_prefix.sql`
- `supabase/tests/domain/fixtures/enrollment_move_approval.sql`
- `supabase/tests/domain/fixtures/enrollment_move_roll_union.sql`
- `tools/supabase/domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/domain_enrollment_move_approval_ci.py`
- `tools/supabase/domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/domain_roll_business_date_ci.py`
- `tools/supabase/tests/test_domain_db01_prerequisite_ci.py`
- `tools/supabase/tests/test_domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_approval_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## curriculum / receipt_bytes: different final paths

- `docs/database/20261020_enrollment_db01_composed_integration.md`
- `docs/database/20261020_enrollment_end_lock_prefix_acceptance.md`
- `docs/database/20261020_enrollment_move_roll_union_review.md`
- `docs/database/20261020_owner_choices_and_dependency_resolution.md`
- `docs/database/218_student_photo_provider_neutral_delivery_recovery_candidate.md`
- `docs/database/219_student_photo_provider_neutral_delivery_recovery_ci_merge_freeze.md`
- `docs/database/220_student_photo_provider_adapter_trust_contract_candidate.md`
- `docs/database/221_student_photo_provider_adapter_trust_contract_ci_merge_freeze.md`
- `supabase/migrations/20260928000000_domain_package_01_effect37_01_db01_allocator_history.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect37_02_db01_end_source_prelock.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_01_db01_roll_lineage_nonself.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_02_db01_roll_correct_result_pair.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_03_db01_direct_receipt_provenance.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_01_enrollment_move_roll_union.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_02_enrollment_move_entry_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_03_enrollment_move_apply_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_04_enrollment_move_workflow_prelock_acl.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_05_enrollment_move_reviewer_projections.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_06_enrollment_move_application_replay.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_01_school_local_roll_date.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_02_school_local_roll_consumers.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_03_db01_apply_request_version.sql.draft`
- `supabase/tests/domain/75_db01_allocator_retained_history.sql`
- `supabase/tests/domain/76_db01_end_stored_policy_prelock.sql`
- `supabase/tests/domain/77_db01_retained_result_pair_private_acl.sql`
- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `supabase/tests/domain/80_school_local_roll_business_date.sql`
- `supabase/tests/domain/fixtures/enrollment_end_lock_prefix.sql`
- `supabase/tests/domain/fixtures/enrollment_move_approval.sql`
- `supabase/tests/domain/fixtures/enrollment_move_roll_union.sql`
- `tools/supabase/domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/domain_enrollment_move_approval_ci.py`
- `tools/supabase/domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/domain_roll_business_date_ci.py`
- `tools/supabase/tests/test_domain_db01_prerequisite_ci.py`
- `tools/supabase/tests/test_domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_approval_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## curriculum / deferred_bank_signing: different final paths

- `docs/database/20261020_enrollment_db01_composed_integration.md`
- `docs/database/20261020_enrollment_end_lock_prefix_acceptance.md`
- `docs/database/20261020_enrollment_move_roll_union_review.md`
- `docs/database/20261020_owner_choices_and_dependency_resolution.md`
- `docs/database/218_student_photo_provider_neutral_delivery_recovery_candidate.md`
- `docs/database/219_student_photo_provider_neutral_delivery_recovery_ci_merge_freeze.md`
- `docs/database/220_student_photo_provider_adapter_trust_contract_candidate.md`
- `docs/database/221_student_photo_provider_adapter_trust_contract_ci_merge_freeze.md`
- `supabase/migrations/20260928000000_domain_package_01_effect37_01_db01_allocator_history.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect37_02_db01_end_source_prelock.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_01_db01_roll_lineage_nonself.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_02_db01_roll_correct_result_pair.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_03_db01_direct_receipt_provenance.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_01_enrollment_move_roll_union.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_02_enrollment_move_entry_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_03_enrollment_move_apply_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_04_enrollment_move_workflow_prelock_acl.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_05_enrollment_move_reviewer_projections.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_06_enrollment_move_application_replay.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_01_school_local_roll_date.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_02_school_local_roll_consumers.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_03_db01_apply_request_version.sql.draft`
- `supabase/tests/domain/75_db01_allocator_retained_history.sql`
- `supabase/tests/domain/76_db01_end_stored_policy_prelock.sql`
- `supabase/tests/domain/77_db01_retained_result_pair_private_acl.sql`
- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `supabase/tests/domain/80_school_local_roll_business_date.sql`
- `supabase/tests/domain/fixtures/enrollment_end_lock_prefix.sql`
- `supabase/tests/domain/fixtures/enrollment_move_approval.sql`
- `supabase/tests/domain/fixtures/enrollment_move_roll_union.sql`
- `tools/supabase/domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/domain_enrollment_move_approval_ci.py`
- `tools/supabase/domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/domain_roll_business_date_ci.py`
- `tools/supabase/tests/test_domain_db01_prerequisite_ci.py`
- `tools/supabase/tests/test_domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_approval_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## receipt_scope / receipt_bytes: different final paths

- `docs/database/20261020_enrollment_db01_composed_integration.md`
- `docs/database/20261020_enrollment_end_lock_prefix_acceptance.md`
- `docs/database/20261020_enrollment_move_roll_union_review.md`
- `docs/database/20261020_owner_choices_and_dependency_resolution.md`
- `docs/database/218_student_photo_provider_neutral_delivery_recovery_candidate.md`
- `docs/database/219_student_photo_provider_neutral_delivery_recovery_ci_merge_freeze.md`
- `docs/database/220_student_photo_provider_adapter_trust_contract_candidate.md`
- `docs/database/221_student_photo_provider_adapter_trust_contract_ci_merge_freeze.md`
- `services/payment_evidence/service.py`
- `supabase/migrations/20260928000000_domain_package_01_effect37_01_db01_allocator_history.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect37_02_db01_end_source_prelock.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_01_db01_roll_lineage_nonself.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_02_db01_roll_correct_result_pair.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_03_db01_direct_receipt_provenance.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_01_enrollment_move_roll_union.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_02_enrollment_move_entry_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_03_enrollment_move_apply_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_04_enrollment_move_workflow_prelock_acl.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_05_enrollment_move_reviewer_projections.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_06_enrollment_move_application_replay.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_01_school_local_roll_date.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_02_school_local_roll_consumers.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_03_db01_apply_request_version.sql.draft`
- `supabase/tests/domain/75_db01_allocator_retained_history.sql`
- `supabase/tests/domain/76_db01_end_stored_policy_prelock.sql`
- `supabase/tests/domain/77_db01_retained_result_pair_private_acl.sql`
- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `supabase/tests/domain/80_school_local_roll_business_date.sql`
- `supabase/tests/domain/fixtures/enrollment_end_lock_prefix.sql`
- `supabase/tests/domain/fixtures/enrollment_move_approval.sql`
- `supabase/tests/domain/fixtures/enrollment_move_roll_union.sql`
- `tools/supabase/domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/domain_enrollment_move_approval_ci.py`
- `tools/supabase/domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/domain_roll_business_date_ci.py`
- `tools/supabase/tests/test_domain_db01_prerequisite_ci.py`
- `tools/supabase/tests/test_domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_approval_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## receipt_scope / deferred_bank_signing: different final paths

- `docs/database/20261020_enrollment_db01_composed_integration.md`
- `docs/database/20261020_enrollment_end_lock_prefix_acceptance.md`
- `docs/database/20261020_enrollment_move_roll_union_review.md`
- `docs/database/20261020_owner_choices_and_dependency_resolution.md`
- `docs/database/218_student_photo_provider_neutral_delivery_recovery_candidate.md`
- `docs/database/219_student_photo_provider_neutral_delivery_recovery_ci_merge_freeze.md`
- `docs/database/220_student_photo_provider_adapter_trust_contract_candidate.md`
- `docs/database/221_student_photo_provider_adapter_trust_contract_ci_merge_freeze.md`
- `docs/database/db08_f6_student_discount_choice_20261027.md`
- `docs/requirements/School_OS_SaaS_Master_Specification_v0.2.md`
- `supabase/migrations/20260928000000_domain_package_01_effect37_01_db01_allocator_history.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect37_02_db01_end_source_prelock.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_01_db01_roll_lineage_nonself.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_02_db01_roll_correct_result_pair.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_03_db01_direct_receipt_provenance.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_01_enrollment_move_roll_union.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_02_enrollment_move_entry_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_03_enrollment_move_apply_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_04_enrollment_move_workflow_prelock_acl.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_05_enrollment_move_reviewer_projections.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_06_enrollment_move_application_replay.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_01_school_local_roll_date.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_02_school_local_roll_consumers.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_03_db01_apply_request_version.sql.draft`
- `supabase/proposals/db08/06_01_discount_storage.sql.draft`
- `supabase/proposals/db08/06_03_discount_commands.sql.draft`
- `supabase/proposals/db08/06_04_discount_review.sql.draft`
- `supabase/proposals/db08/06_05_discount_application.sql.draft`
- `supabase/tests/db03/14_applicant_official_payment.sql`
- `supabase/tests/db08/06_student_discounts.sql`
- `supabase/tests/domain/75_db01_allocator_retained_history.sql`
- `supabase/tests/domain/76_db01_end_stored_policy_prelock.sql`
- `supabase/tests/domain/77_db01_retained_result_pair_private_acl.sql`
- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `supabase/tests/domain/80_school_local_roll_business_date.sql`
- `supabase/tests/domain/fixtures/enrollment_end_lock_prefix.sql`
- `supabase/tests/domain/fixtures/enrollment_move_approval.sql`
- `supabase/tests/domain/fixtures/enrollment_move_roll_union.sql`
- `tools/db03/schema_candidate_ci.py`
- `tools/db08/schema_candidate_ci.py`
- `tools/supabase/domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/domain_enrollment_move_approval_ci.py`
- `tools/supabase/domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/domain_roll_business_date_ci.py`
- `tools/supabase/tests/test_domain_db01_prerequisite_ci.py`
- `tools/supabase/tests/test_domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_approval_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`

## receipt_bytes / deferred_bank_signing: different final paths

- `docs/database/20261020_enrollment_db01_composed_integration.md`
- `docs/database/20261020_enrollment_end_lock_prefix_acceptance.md`
- `docs/database/20261020_enrollment_move_roll_union_review.md`
- `docs/database/20261020_owner_choices_and_dependency_resolution.md`
- `docs/database/218_student_photo_provider_neutral_delivery_recovery_candidate.md`
- `docs/database/219_student_photo_provider_neutral_delivery_recovery_ci_merge_freeze.md`
- `docs/database/220_student_photo_provider_adapter_trust_contract_candidate.md`
- `docs/database/221_student_photo_provider_adapter_trust_contract_ci_merge_freeze.md`
- `docs/database/db08_f6_student_discount_choice_20261027.md`
- `docs/requirements/School_OS_SaaS_Master_Specification_v0.2.md`
- `services/payment_evidence/service.py`
- `supabase/migrations/20260928000000_domain_package_01_effect37_01_db01_allocator_history.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect37_02_db01_end_source_prelock.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_01_db01_roll_lineage_nonself.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_02_db01_roll_correct_result_pair.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_03_db01_direct_receipt_provenance.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect38_04_db01_apply_application_receipt_guard.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_01_enrollment_move_roll_union.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_02_enrollment_move_entry_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_03_enrollment_move_apply_order.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_04_enrollment_move_workflow_prelock_acl.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_05_enrollment_move_reviewer_projections.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect39_06_enrollment_move_application_replay.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_01_school_local_roll_date.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_02_school_local_roll_consumers.sql.draft`
- `supabase/migrations/20260928000000_domain_package_01_effect40_03_db01_apply_request_version.sql.draft`
- `supabase/proposals/db08/06_01_discount_storage.sql.draft`
- `supabase/proposals/db08/06_03_discount_commands.sql.draft`
- `supabase/proposals/db08/06_04_discount_review.sql.draft`
- `supabase/proposals/db08/06_05_discount_application.sql.draft`
- `supabase/tests/db03/14_applicant_official_payment.sql`
- `supabase/tests/db08/06_student_discounts.sql`
- `supabase/tests/domain/75_db01_allocator_retained_history.sql`
- `supabase/tests/domain/76_db01_end_stored_policy_prelock.sql`
- `supabase/tests/domain/77_db01_retained_result_pair_private_acl.sql`
- `supabase/tests/domain/78_db01_direct_receipt_provenance_private_acl.sql`
- `supabase/tests/domain/79_db01_approval_application_receipt_guard.sql`
- `supabase/tests/domain/80_school_local_roll_business_date.sql`
- `supabase/tests/domain/fixtures/enrollment_end_lock_prefix.sql`
- `supabase/tests/domain/fixtures/enrollment_move_approval.sql`
- `supabase/tests/domain/fixtures/enrollment_move_roll_union.sql`
- `tools/db03/schema_candidate_ci.py`
- `tools/db08/schema_candidate_ci.py`
- `tools/supabase/domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/domain_enrollment_move_approval_ci.py`
- `tools/supabase/domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/domain_roll_business_date_ci.py`
- `tools/supabase/tests/test_domain_db01_prerequisite_ci.py`
- `tools/supabase/tests/test_domain_enrollment_end_lock_prefix_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_approval_ci.py`
- `tools/supabase/tests/test_domain_enrollment_move_roll_union_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_adapter_contract_ci.py`
- `tools/supabase/tests/test_domain_photo_provider_neutral_recovery_ci.py`
- `tools/supabase/tests/test_domain_roll_business_date_ci.py`
