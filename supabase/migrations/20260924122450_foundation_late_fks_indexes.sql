-- FOUNDATION DRAFT 5/8. Files only; SQL HAS NOT BEEN EXECUTED.
-- Exact three late FKs; all validated while tables are still empty.
SET ROLE schoolos_schema_owner;

ALTER TABLE app_private.school_profiles ADD CONSTRAINT school_profiles_default_academic_year_id_id_fkey FOREIGN KEY (default_academic_year_id,id) REFERENCES app.academic_years (id,school_id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE app_private.school_profiles ADD CONSTRAINT school_profiles_logo_file_id_fkey FOREIGN KEY (logo_file_id) REFERENCES app_private.file_objects (id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE app_private.people ADD CONSTRAINT people_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- Reviewed non-PK indexes and partial uniqueness. No speculative domain indexes.
CREATE INDEX principal_binding_events_principal_id_created_at_idx ON app_private.principal_binding_events (principal_id,created_at);
CREATE INDEX principal_binding_events_new_auth_user_id_principal_id_idx ON app_private.principal_binding_events (new_auth_user_id,principal_id);
CREATE INDEX login_aliases_principal_id_idx ON app_private.login_aliases (principal_id);
CREATE INDEX campuses_school_id_state_idx ON app.campuses (school_id,state);
CREATE INDEX rooms_campus_id_state_idx ON app.rooms (campus_id,state);
CREATE INDEX academic_years_school_id_state_starts_on_idx ON app.academic_years (school_id,state,starts_on);
CREATE INDEX file_objects_uploaded_by_principal_id_state_idx ON app_private.file_objects (uploaded_by_principal_id,state);
CREATE INDEX file_objects_campus_id_state_idx ON app_private.file_objects (campus_id,state);
CREATE INDEX file_objects_replaces_file_id_idx ON app_private.file_objects (replaces_file_id);
CREATE INDEX role_permission_grants_permission_id_idx ON app_private.role_permission_grants (permission_id);
CREATE INDEX role_permission_grants_role_id_permission_id_valid_from_idx ON app_private.role_permission_grants (role_id,permission_id,valid_from);
CREATE INDEX pra_principal_role_context_valid_from_idx ON app_private.principal_role_assignments (principal_id,role_id,context_kind,valid_from);
CREATE INDEX principal_role_assignments_role_id_idx ON app_private.principal_role_assignments (role_id);
CREATE INDEX aps_assignment_permission_revoked_at_idx ON app_private.assignment_permission_scopes (assignment_id,permission_id,revoked_at);
CREATE INDEX assignment_permission_scopes_grant_id_role_id_permission_id_idx ON app_private.assignment_permission_scopes (grant_id,role_id,permission_id);
CREATE INDEX assignment_permission_scopes_scope_contract_id_idx ON app_private.assignment_permission_scopes (scope_contract_id);
CREATE INDEX assignment_permission_scopes_campus_id_idx ON app_private.assignment_permission_scopes (campus_id);
CREATE INDEX aps_interval_lookup_idx ON app_private.assignment_permission_scopes (assignment_id,grant_id,scope_contract_id,campus_id,valid_from);
CREATE INDEX operation_contracts_request_permission_id_idx ON app_private.operation_contracts (request_permission_id);
CREATE INDEX operation_contracts_review_permission_id_idx ON app_private.operation_contracts (review_permission_id);
CREATE INDEX apv_operation_campus_effective_from_idx ON app_private.approval_policy_versions (operation_id,campus_id,effective_from);
CREATE INDEX approval_step_templates_reviewer_role_id_idx ON app_private.approval_step_templates (reviewer_role_id);
CREATE INDEX approval_requests_requester_id_created_at_idx ON app_private.approval_requests (requester_id,created_at);
CREATE INDEX approval_requests_campus_id_state_idx ON app_private.approval_requests (campus_id,state);
CREATE INDEX approval_requests_policy_id_operation_id_idx ON app_private.approval_requests (policy_id,operation_id);
CREATE INDEX approval_request_files_file_id_idx ON app_private.approval_request_files (file_id);
CREATE INDEX approval_request_steps_template_id_policy_id_idx ON app_private.approval_request_steps (template_id,policy_id);
CREATE INDEX approval_step_reviewers_reviewer_id_withdrawn_at_step_id_idx ON app_private.approval_step_reviewers (reviewer_id,withdrawn_at,step_id);
CREATE INDEX command_receipts_request_id_idx ON app_private.command_receipts (request_id);
CREATE INDEX command_receipts_operation_id_idx ON app_private.command_receipts (operation_id);
CREATE INDEX approval_transitions_command_receipt_id_idx ON app_private.approval_transitions (command_receipt_id);
CREATE INDEX approval_applications_operation_id_idx ON app_private.approval_applications (operation_id);
CREATE INDEX audit_events_target_kind_target_ref_occurred_at_idx ON app_private.audit_events (target_kind,target_ref,occurred_at);
CREATE INDEX audit_events_actor_id_occurred_at_idx ON app_private.audit_events (actor_id,occurred_at);
CREATE INDEX audit_events_campus_id_occurred_at_idx ON app_private.audit_events (campus_id,occurred_at);
CREATE INDEX audit_events_command_receipt_id_idx ON app_private.audit_events (command_receipt_id);
CREATE INDEX audit_events_approval_request_id_idx ON app_private.audit_events (approval_request_id);
CREATE INDEX outbox_aggregate_version_idx ON app_private.outbox_events (aggregate_kind,aggregate_ref,aggregate_version);
CREATE INDEX outbox_events_causation_event_id_idx ON app_private.outbox_events (causation_event_id);
CREATE INDEX event_consumer_deliveries_consumer_key_next_attempt_at_idx ON app_private.event_consumer_deliveries (consumer_key,next_attempt_at) WHERE state IN ('PENDING','RETRY');
CREATE INDEX event_consumer_deliveries_consumer_key_lease_until_idx ON app_private.event_consumer_deliveries (consumer_key,lease_until) WHERE state = 'LEASED';
CREATE INDEX notifications_recipient_id_created_at_idx ON app.notifications (recipient_id,created_at) WHERE read_at IS NULL AND archived_at IS NULL;
CREATE INDEX setting_revisions_supersedes_id_idx ON app_private.setting_revisions (supersedes_id);

CREATE UNIQUE INDEX principals_individual_person_live_uidx
  ON app_private.principals (person_id)
  WHERE kind = 'INDIVIDUAL' AND state <> 'RETIRED';
CREATE UNIQUE INDEX approval_step_reviewers_active_uidx
  ON app_private.approval_step_reviewers (step_id, reviewer_id)
  WHERE withdrawn_at IS NULL;
CREATE UNIQUE INDEX setting_revisions_school_revision_uidx
  ON app_private.setting_revisions (setting_key, revision) WHERE campus_id IS NULL;
CREATE UNIQUE INDEX setting_revisions_campus_revision_uidx
  ON app_private.setting_revisions (setting_key, campus_id, revision) WHERE campus_id IS NOT NULL;
CREATE UNIQUE INDEX setting_revisions_school_effective_uidx
  ON app_private.setting_revisions (setting_key, effective_from) WHERE campus_id IS NULL;
CREATE UNIQUE INDEX setting_revisions_campus_effective_uidx
  ON app_private.setting_revisions (setting_key, campus_id, effective_from) WHERE campus_id IS NOT NULL;

RESET ROLE;
