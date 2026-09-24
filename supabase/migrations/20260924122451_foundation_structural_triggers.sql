-- FOUNDATION DRAFT 6/8. Files only; SQL HAS NOT BEEN EXECUTED.
-- Structural guards. Protected application commands, bootstrap and external
-- service contracts are not activated by these triggers alone.
SET ROLE schoolos_schema_owner;

CREATE FUNCTION app_private.advance_row_version() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF NEW.row_version IS DISTINCT FROM OLD.row_version THEN
    RAISE EXCEPTION 'row_version is server maintained';
  END IF;
  NEW.row_version := OLD.row_version + 1;
  NEW.updated_at := pg_catalog.transaction_timestamp();
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.advance_row_version() FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION app_private.deny_evidence_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  RAISE EXCEPTION 'immutable foundation evidence';
END
$body$;
REVOKE ALL ON FUNCTION app_private.deny_evidence_change() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER principal_binding_events_immutable_guard BEFORE UPDATE OR DELETE ON app_private.principal_binding_events
FOR EACH ROW EXECUTE FUNCTION app_private.deny_evidence_change();
CREATE TRIGGER approval_request_files_immutable_guard BEFORE UPDATE OR DELETE ON app_private.approval_request_files
FOR EACH ROW EXECUTE FUNCTION app_private.deny_evidence_change();
CREATE TRIGGER approval_reviews_immutable_guard BEFORE UPDATE OR DELETE ON app_private.approval_reviews
FOR EACH ROW EXECUTE FUNCTION app_private.deny_evidence_change();
CREATE TRIGGER command_receipts_immutable_guard BEFORE UPDATE OR DELETE ON app_private.command_receipts
FOR EACH ROW EXECUTE FUNCTION app_private.deny_evidence_change();
CREATE TRIGGER approval_transitions_immutable_guard BEFORE UPDATE OR DELETE ON app_private.approval_transitions
FOR EACH ROW EXECUTE FUNCTION app_private.deny_evidence_change();
CREATE TRIGGER approval_applications_immutable_guard BEFORE UPDATE OR DELETE ON app_private.approval_applications
FOR EACH ROW EXECUTE FUNCTION app_private.deny_evidence_change();
CREATE TRIGGER audit_events_immutable_guard BEFORE UPDATE OR DELETE ON app_private.audit_events
FOR EACH ROW EXECUTE FUNCTION app_private.deny_evidence_change();
CREATE TRIGGER outbox_events_immutable_guard BEFORE UPDATE OR DELETE ON app_private.outbox_events
FOR EACH ROW EXECUTE FUNCTION app_private.deny_evidence_change();
CREATE TRIGGER setting_revisions_immutable_guard BEFORE UPDATE OR DELETE ON app_private.setting_revisions
FOR EACH ROW EXECUTE FUNCTION app_private.deny_evidence_change();

-- Explicit per-table immutable/frozen field guards; no dynamic target SQL.

CREATE FUNCTION app_private.guard_school_profiles() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.singleton IS DISTINCT FROM NEW.singleton
     OR OLD.code IS DISTINCT FROM NEW.code
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'school_profiles: immutable field changed'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_school_profiles() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_school_profiles_fields BEFORE UPDATE ON app_private.school_profiles
FOR EACH ROW EXECUTE FUNCTION app_private.guard_school_profiles();
CREATE TRIGGER zz_school_profiles_version BEFORE UPDATE ON app_private.school_profiles
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_campuses() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.school_id IS DISTINCT FROM NEW.school_id
     OR OLD.code IS DISTINCT FROM NEW.code
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'campuses: immutable field changed'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_campuses() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_campuses_fields BEFORE UPDATE ON app.campuses
FOR EACH ROW EXECUTE FUNCTION app_private.guard_campuses();
CREATE TRIGGER zz_campuses_version BEFORE UPDATE ON app.campuses
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_rooms() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.campus_id IS DISTINCT FROM NEW.campus_id
     OR OLD.code IS DISTINCT FROM NEW.code
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'rooms: immutable field changed'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_rooms() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_rooms_fields BEFORE UPDATE ON app.rooms
FOR EACH ROW EXECUTE FUNCTION app_private.guard_rooms();
CREATE TRIGGER zz_rooms_version BEFORE UPDATE ON app.rooms
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_academic_years() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.school_id IS DISTINCT FROM NEW.school_id
     OR OLD.code IS DISTINCT FROM NEW.code
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'academic_years: immutable field changed'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_academic_years() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_academic_years_fields BEFORE UPDATE ON app.academic_years
FOR EACH ROW EXECUTE FUNCTION app_private.guard_academic_years();
CREATE TRIGGER zz_academic_years_version BEFORE UPDATE ON app.academic_years
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_people() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'people: immutable field changed'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_people() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_people_fields BEFORE UPDATE ON app_private.people
FOR EACH ROW EXECUTE FUNCTION app_private.guard_people();
CREATE TRIGGER zz_people_version BEFORE UPDATE ON app_private.people
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_principals() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.kind IS DISTINCT FROM NEW.kind
     OR OLD.person_id IS DISTINCT FROM NEW.person_id
     OR OLD.system_purpose IS DISTINCT FROM NEW.system_purpose
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'principals: immutable field changed'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_principals() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_principals_fields BEFORE UPDATE ON app_private.principals
FOR EACH ROW EXECUTE FUNCTION app_private.guard_principals();
CREATE TRIGGER zz_principals_version BEFORE UPDATE ON app_private.principals
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_principal_auth_bindings() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.principal_id IS DISTINCT FROM NEW.principal_id
     OR OLD.principal_kind IS DISTINCT FROM NEW.principal_kind
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'principal_auth_bindings: immutable field changed'; END IF;
  IF NEW.binding_version IS DISTINCT FROM OLD.binding_version THEN
    IF NEW.binding_version <> OLD.binding_version + 1 OR NEW.tokens_valid_from <= OLD.tokens_valid_from THEN
      RAISE EXCEPTION 'binding revision/cutoff must advance';
    END IF;
  ELSE
    IF NEW.auth_user_id IS DISTINCT FROM OLD.auth_user_id OR NEW.tokens_valid_from IS DISTINCT FROM OLD.tokens_valid_from THEN
      RAISE EXCEPTION 'binding subject/cutoff cannot change without revision';
    END IF;
  END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_principal_auth_bindings() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_principal_auth_bindings_fields BEFORE UPDATE ON app_private.principal_auth_bindings
FOR EACH ROW EXECUTE FUNCTION app_private.guard_principal_auth_bindings();
CREATE TRIGGER zz_principal_auth_bindings_version BEFORE UPDATE ON app_private.principal_auth_bindings
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_login_aliases() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.principal_id IS DISTINCT FROM NEW.principal_id
     OR OLD.normalized_alias IS DISTINCT FROM NEW.normalized_alias
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'login_aliases: immutable field changed'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_login_aliases() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_login_aliases_fields BEFORE UPDATE ON app_private.login_aliases
FOR EACH ROW EXECUTE FUNCTION app_private.guard_login_aliases();
CREATE TRIGGER zz_login_aliases_version BEFORE UPDATE ON app_private.login_aliases
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_roles() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.code IS DISTINCT FROM NEW.code
     OR OLD.family_only IS DISTINCT FROM NEW.family_only
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'roles: immutable field changed'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_roles() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_roles_fields BEFORE UPDATE ON app_private.roles
FOR EACH ROW EXECUTE FUNCTION app_private.guard_roles();
CREATE TRIGGER zz_roles_version BEFORE UPDATE ON app_private.roles
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_permissions() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.code IS DISTINCT FROM NEW.code
     OR OLD.family_safe IS DISTINCT FROM NEW.family_safe
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'permissions: immutable field changed'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_permissions() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_permissions_fields BEFORE UPDATE ON app_private.permissions
FOR EACH ROW EXECUTE FUNCTION app_private.guard_permissions();
CREATE TRIGGER zz_permissions_version BEFORE UPDATE ON app_private.permissions
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_role_permission_grants() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.role_id IS DISTINCT FROM NEW.role_id
     OR OLD.role_family_only IS DISTINCT FROM NEW.role_family_only
     OR OLD.permission_id IS DISTINCT FROM NEW.permission_id
     OR OLD.permission_family_safe IS DISTINCT FROM NEW.permission_family_safe
     OR OLD.valid_from IS DISTINCT FROM NEW.valid_from
     OR OLD.valid_until IS DISTINCT FROM NEW.valid_until
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'role_permission_grants: immutable field changed'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_role_permission_grants() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_role_permission_grants_fields BEFORE UPDATE ON app_private.role_permission_grants
FOR EACH ROW EXECUTE FUNCTION app_private.guard_role_permission_grants();
CREATE TRIGGER zz_role_permission_grants_version BEFORE UPDATE ON app_private.role_permission_grants
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_principal_role_assignments() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.principal_id IS DISTINCT FROM NEW.principal_id
     OR OLD.principal_kind IS DISTINCT FROM NEW.principal_kind
     OR OLD.role_id IS DISTINCT FROM NEW.role_id
     OR OLD.role_family_only IS DISTINCT FROM NEW.role_family_only
     OR OLD.context_kind IS DISTINCT FROM NEW.context_kind
     OR OLD.valid_from IS DISTINCT FROM NEW.valid_from
     OR OLD.valid_until IS DISTINCT FROM NEW.valid_until
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'principal_role_assignments: immutable field changed'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_principal_role_assignments() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_principal_role_assignments_fields BEFORE UPDATE ON app_private.principal_role_assignments
FOR EACH ROW EXECUTE FUNCTION app_private.guard_principal_role_assignments();
CREATE TRIGGER zz_principal_role_assignments_version BEFORE UPDATE ON app_private.principal_role_assignments
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_permission_scope_contracts() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.permission_id IS DISTINCT FROM NEW.permission_id
     OR OLD.scope_kind IS DISTINCT FROM NEW.scope_kind
     OR OLD.resolver_key IS DISTINCT FROM NEW.resolver_key
     OR OLD.contract_version IS DISTINCT FROM NEW.contract_version
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'permission_scope_contracts: immutable field changed'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_permission_scope_contracts() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_permission_scope_contracts_fields BEFORE UPDATE ON app_private.permission_scope_contracts
FOR EACH ROW EXECUTE FUNCTION app_private.guard_permission_scope_contracts();
CREATE TRIGGER zz_permission_scope_contracts_version BEFORE UPDATE ON app_private.permission_scope_contracts
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_assignment_permission_scopes() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.assignment_id IS DISTINCT FROM NEW.assignment_id
     OR OLD.grant_id IS DISTINCT FROM NEW.grant_id
     OR OLD.role_id IS DISTINCT FROM NEW.role_id
     OR OLD.permission_id IS DISTINCT FROM NEW.permission_id
     OR OLD.scope_contract_id IS DISTINCT FROM NEW.scope_contract_id
     OR OLD.scope_kind IS DISTINCT FROM NEW.scope_kind
     OR OLD.resolver_key IS DISTINCT FROM NEW.resolver_key
     OR OLD.campus_id IS DISTINCT FROM NEW.campus_id
     OR OLD.valid_from IS DISTINCT FROM NEW.valid_from
     OR OLD.valid_until IS DISTINCT FROM NEW.valid_until
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'assignment_permission_scopes: immutable field changed'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_assignment_permission_scopes() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_assignment_permission_scopes_fields BEFORE UPDATE ON app_private.assignment_permission_scopes
FOR EACH ROW EXECUTE FUNCTION app_private.guard_assignment_permission_scopes();
CREATE TRIGGER zz_assignment_permission_scopes_version BEFORE UPDATE ON app_private.assignment_permission_scopes
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_operation_contracts() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.code IS DISTINCT FROM NEW.code
     OR OLD.contract_version IS DISTINCT FROM NEW.contract_version
     OR OLD.handler_key IS DISTINCT FROM NEW.handler_key
     OR OLD.request_permission_id IS DISTINCT FROM NEW.request_permission_id
     OR OLD.review_permission_id IS DISTINCT FROM NEW.review_permission_id
     OR OLD.payload_schema_version IS DISTINCT FROM NEW.payload_schema_version
     OR OLD.requires_approval IS DISTINCT FROM NEW.requires_approval
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'operation_contracts: immutable field changed'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_operation_contracts() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_operation_contracts_fields BEFORE UPDATE ON app_private.operation_contracts
FOR EACH ROW EXECUTE FUNCTION app_private.guard_operation_contracts();
CREATE TRIGGER zz_operation_contracts_version BEFORE UPDATE ON app_private.operation_contracts
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_approval_policy_versions() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.policy_key IS DISTINCT FROM NEW.policy_key
     OR OLD.version IS DISTINCT FROM NEW.version
     OR OLD.operation_id IS DISTINCT FROM NEW.operation_id
     OR OLD.campus_id IS DISTINCT FROM NEW.campus_id
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'approval_policy_versions: immutable field changed'; END IF;
  IF OLD.state <> 'DRAFT' AND (
     OLD.effective_from IS DISTINCT FROM NEW.effective_from
     OR OLD.effective_until IS DISTINCT FROM NEW.effective_until
  ) THEN RAISE EXCEPTION 'approval_policy_versions: submitted terms are frozen'; END IF;
  IF OLD.state = 'RETIRED' AND NEW.state <> 'RETIRED' THEN RAISE EXCEPTION 'retired policy cannot reactivate'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_approval_policy_versions() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_approval_policy_versions_fields BEFORE UPDATE ON app_private.approval_policy_versions
FOR EACH ROW EXECUTE FUNCTION app_private.guard_approval_policy_versions();
CREATE TRIGGER zz_approval_policy_versions_version BEFORE UPDATE ON app_private.approval_policy_versions
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_approval_step_templates() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'approval_step_templates: immutable field changed'; END IF;
  IF OLD.state <> 'DRAFT' AND (
     OLD.policy_id IS DISTINCT FROM NEW.policy_id
     OR OLD.step_number IS DISTINCT FROM NEW.step_number
     OR OLD.reviewer_role_id IS DISTINCT FROM NEW.reviewer_role_id
     OR OLD.required_reviews IS DISTINCT FROM NEW.required_reviews
     OR OLD.selection_resolver_key IS DISTINCT FROM NEW.selection_resolver_key
  ) THEN RAISE EXCEPTION 'approval_step_templates: submitted terms are frozen'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_approval_step_templates() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_approval_step_templates_fields BEFORE UPDATE ON app_private.approval_step_templates
FOR EACH ROW EXECUTE FUNCTION app_private.guard_approval_step_templates();
CREATE TRIGGER zz_approval_step_templates_version BEFORE UPDATE ON app_private.approval_step_templates
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_approval_requests() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.requester_id IS DISTINCT FROM NEW.requester_id
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'approval_requests: immutable field changed'; END IF;
  IF OLD.state <> 'DRAFT' AND (
     OLD.operation_id IS DISTINCT FROM NEW.operation_id
     OR OLD.payload_schema_version IS DISTINCT FROM NEW.payload_schema_version
     OR OLD.policy_id IS DISTINCT FROM NEW.policy_id
     OR OLD.campus_id IS DISTINCT FROM NEW.campus_id
     OR OLD.target_ref IS DISTINCT FROM NEW.target_ref
     OR OLD.expected_target_version IS DISTINCT FROM NEW.expected_target_version
     OR OLD.reason IS DISTINCT FROM NEW.reason
     OR OLD.old_snapshot IS DISTINCT FROM NEW.old_snapshot
     OR OLD.requested_payload IS DISTINCT FROM NEW.requested_payload
  ) THEN RAISE EXCEPTION 'approval_requests: submitted terms are frozen'; END IF;
  IF NOT (
    (OLD.state = 'DRAFT' AND NEW.state IN ('DRAFT','SUBMITTED','CANCELLED')) OR
    (OLD.state = 'SUBMITTED' AND NEW.state IN ('SUBMITTED','PENDING','INVALIDATED')) OR
    (OLD.state = 'PENDING' AND NEW.state IN ('PENDING','APPROVED','REJECTED','CANCELLED','INVALIDATED')) OR
    (OLD.state = 'APPROVED' AND NEW.state IN ('APPROVED','EXECUTED','INVALIDATED')) OR
    (OLD.state = NEW.state AND OLD.state IN ('REJECTED','CANCELLED','EXECUTED','INVALIDATED'))
  ) THEN RAISE EXCEPTION 'invalid approval request transition'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_approval_requests() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_approval_requests_fields BEFORE UPDATE ON app_private.approval_requests
FOR EACH ROW EXECUTE FUNCTION app_private.guard_approval_requests();
CREATE TRIGGER zz_approval_requests_version BEFORE UPDATE ON app_private.approval_requests
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_approval_request_steps() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.request_id IS DISTINCT FROM NEW.request_id
     OR OLD.policy_id IS DISTINCT FROM NEW.policy_id
     OR OLD.template_id IS DISTINCT FROM NEW.template_id
     OR OLD.step_number IS DISTINCT FROM NEW.step_number
     OR OLD.required_reviews IS DISTINCT FROM NEW.required_reviews
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'approval_request_steps: immutable field changed'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_approval_request_steps() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_approval_request_steps_fields BEFORE UPDATE ON app_private.approval_request_steps
FOR EACH ROW EXECUTE FUNCTION app_private.guard_approval_request_steps();
CREATE TRIGGER zz_approval_request_steps_version BEFORE UPDATE ON app_private.approval_request_steps
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_approval_step_reviewers() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.step_id IS DISTINCT FROM NEW.step_id
     OR OLD.reviewer_id IS DISTINCT FROM NEW.reviewer_id
     OR OLD.assigned_at IS DISTINCT FROM NEW.assigned_at
     OR OLD.assignment_reason IS DISTINCT FROM NEW.assignment_reason
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'approval_step_reviewers: immutable field changed'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_approval_step_reviewers() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_approval_step_reviewers_fields BEFORE UPDATE ON app_private.approval_step_reviewers
FOR EACH ROW EXECUTE FUNCTION app_private.guard_approval_step_reviewers();
CREATE TRIGGER zz_approval_step_reviewers_version BEFORE UPDATE ON app_private.approval_step_reviewers
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_event_consumer_deliveries() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.event_id IS DISTINCT FROM NEW.event_id
     OR OLD.consumer_key IS DISTINCT FROM NEW.consumer_key
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'event_consumer_deliveries: immutable field changed'; END IF;
  IF OLD.state = 'DELIVERED' AND NEW.state <> 'DELIVERED' THEN
    RAISE EXCEPTION 'delivered event cannot be reopened';
  END IF;
  IF OLD.state = 'LEASED' AND (OLD.lease_token IS NULL OR OLD.lease_until <= pg_catalog.clock_timestamp())
     AND NEW.state = 'DELIVERED' THEN RAISE EXCEPTION 'stale lease'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_event_consumer_deliveries() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_event_consumer_deliveries_fields BEFORE UPDATE ON app_private.event_consumer_deliveries
FOR EACH ROW EXECUTE FUNCTION app_private.guard_event_consumer_deliveries();
CREATE TRIGGER zz_event_consumer_deliveries_version BEFORE UPDATE ON app_private.event_consumer_deliveries
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_notifications() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.recipient_id IS DISTINCT FROM NEW.recipient_id
     OR OLD.recipient_kind IS DISTINCT FROM NEW.recipient_kind
     OR OLD.event_id IS DISTINCT FROM NEW.event_id
     OR OLD.category_code IS DISTINCT FROM NEW.category_code
     OR OLD.context_key IS DISTINCT FROM NEW.context_key
     OR OLD.summary IS DISTINCT FROM NEW.summary
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'notifications: immutable field changed'; END IF;
  IF OLD.read_at IS NOT NULL AND NEW.read_at IS DISTINCT FROM OLD.read_at THEN RAISE EXCEPTION 'read time immutable once set'; END IF;
  IF OLD.archived_at IS NOT NULL AND NEW.archived_at IS DISTINCT FROM OLD.archived_at THEN RAISE EXCEPTION 'archive time immutable once set'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_notifications() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_notifications_fields BEFORE UPDATE ON app.notifications
FOR EACH ROW EXECUTE FUNCTION app_private.guard_notifications();
CREATE TRIGGER zz_notifications_version BEFORE UPDATE ON app.notifications
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_notification_preferences() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.principal_id IS DISTINCT FROM NEW.principal_id
     OR OLD.category_code IS DISTINCT FROM NEW.category_code
     OR OLD.channel_code IS DISTINCT FROM NEW.channel_code
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'notification_preferences: immutable field changed'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_notification_preferences() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_notification_preferences_fields BEFORE UPDATE ON app.notification_preferences
FOR EACH ROW EXECUTE FUNCTION app_private.guard_notification_preferences();
CREATE TRIGGER zz_notification_preferences_version BEFORE UPDATE ON app.notification_preferences
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

CREATE FUNCTION app_private.guard_file_objects() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
BEGIN
  IF OLD.uploaded_by_principal_id IS DISTINCT FROM NEW.uploaded_by_principal_id
     OR OLD.campus_id IS DISTINCT FROM NEW.campus_id
     OR OLD.storage_location_key IS DISTINCT FROM NEW.storage_location_key
     OR OLD.purpose_code IS DISTINCT FROM NEW.purpose_code
     OR OLD.object_key IS DISTINCT FROM NEW.object_key
     OR OLD.content_type IS DISTINCT FROM NEW.content_type
     OR OLD.byte_size IS DISTINCT FROM NEW.byte_size
     OR OLD.content_hash IS DISTINCT FROM NEW.content_hash
     OR OLD.classification IS DISTINCT FROM NEW.classification
     OR OLD.replaces_file_id IS DISTINCT FROM NEW.replaces_file_id
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.created_by IS DISTINCT FROM NEW.created_by
     OR OLD.id IS DISTINCT FROM NEW.id THEN RAISE EXCEPTION 'file_objects: immutable field changed'; END IF;
  IF NOT (
    (OLD.state = 'PENDING' AND NEW.state IN ('PENDING','VALIDATED','QUARANTINED')) OR
    (OLD.state = 'VALIDATED' AND NEW.state IN ('VALIDATED','AVAILABLE','QUARANTINED')) OR
    (OLD.state = 'AVAILABLE' AND NEW.state IN ('AVAILABLE','ARCHIVED','QUARANTINED')) OR
    (OLD.state = 'QUARANTINED' AND NEW.state IN ('QUARANTINED','ARCHIVED')) OR
    (OLD.state = 'ARCHIVED' AND NEW.state IN ('ARCHIVED','PURGED')) OR
    (OLD.state = 'PURGED' AND NEW.state = 'PURGED')
  ) THEN RAISE EXCEPTION 'invalid file state transition'; END IF;
  RETURN NEW;
END
$body$;
REVOKE ALL ON FUNCTION app_private.guard_file_objects() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_file_objects_fields BEFORE UPDATE ON app_private.file_objects
FOR EACH ROW EXECUTE FUNCTION app_private.guard_file_objects();
CREATE TRIGGER zz_file_objects_version BEFORE UPDATE ON app_private.file_objects
FOR EACH ROW EXECUTE FUNCTION app_private.advance_row_version();

-- The effective interval is [valid_from, min(valid_until, revoked_at)).
-- Natural expiry leaves revoked_at NULL. A pre-start revocation is empty.
CREATE FUNCTION app_private.guard_role_permission_interval() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $body$
DECLARE end_at timestamptz;
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(71001, 1);
  end_at := LEAST(COALESCE(NEW.valid_until, 'infinity'::timestamptz),
                  COALESCE(NEW.revoked_at, 'infinity'::timestamptz));
  IF end_at <= NEW.valid_from THEN RETURN NEW; END IF;
  IF EXISTS (SELECT 1 FROM app_private.role_permission_grants x
      WHERE x.id <> NEW.id AND x.role_id = NEW.role_id
        AND x.permission_id = NEW.permission_id
        AND x.valid_from < end_at
        AND LEAST(COALESCE(x.valid_until,'infinity'::timestamptz),
                  COALESCE(x.revoked_at,'infinity'::timestamptz)) > NEW.valid_from)
  THEN RAISE EXCEPTION 'overlapping role permission grant'; END IF;
  RETURN NEW;
END $body$;
CREATE TRIGGER zz_role_permission_overlap BEFORE INSERT OR UPDATE ON app_private.role_permission_grants
FOR EACH ROW EXECUTE FUNCTION app_private.guard_role_permission_interval();

CREATE FUNCTION app_private.guard_principal_role_interval() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $body$
DECLARE end_at timestamptz;
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(71001, 1);
  end_at := LEAST(COALESCE(NEW.valid_until, 'infinity'::timestamptz),
                  COALESCE(NEW.revoked_at, 'infinity'::timestamptz));
  IF end_at <= NEW.valid_from THEN RETURN NEW; END IF;
  IF EXISTS (SELECT 1 FROM app_private.principal_role_assignments x
      WHERE x.id <> NEW.id AND x.principal_id = NEW.principal_id
        AND x.role_id = NEW.role_id AND x.context_kind = NEW.context_kind
        AND x.valid_from < end_at
        AND LEAST(COALESCE(x.valid_until,'infinity'::timestamptz),
                  COALESCE(x.revoked_at,'infinity'::timestamptz)) > NEW.valid_from)
  THEN RAISE EXCEPTION 'overlapping principal role assignment'; END IF;
  RETURN NEW;
END $body$;
CREATE TRIGGER zz_principal_role_overlap BEFORE INSERT OR UPDATE ON app_private.principal_role_assignments
FOR EACH ROW EXECUTE FUNCTION app_private.guard_principal_role_interval();

CREATE FUNCTION app_private.guard_scope_interval() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $body$
DECLARE end_at timestamptz;
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(71001, 1);
  end_at := LEAST(COALESCE(NEW.valid_until, 'infinity'::timestamptz),
                  COALESCE(NEW.revoked_at, 'infinity'::timestamptz));
  IF end_at <= NEW.valid_from THEN RETURN NEW; END IF;
  IF EXISTS (SELECT 1 FROM app_private.assignment_permission_scopes x
      WHERE x.id <> NEW.id AND x.assignment_id = NEW.assignment_id
        AND x.grant_id = NEW.grant_id
        AND x.scope_contract_id = NEW.scope_contract_id
        AND x.campus_id IS NOT DISTINCT FROM NEW.campus_id
        AND x.valid_from < end_at
        AND LEAST(COALESCE(x.valid_until,'infinity'::timestamptz),
                  COALESCE(x.revoked_at,'infinity'::timestamptz)) > NEW.valid_from)
  THEN RAISE EXCEPTION 'overlapping permission scope'; END IF;
  RETURN NEW;
END $body$;
CREATE TRIGGER zz_scope_overlap BEFORE INSERT OR UPDATE ON app_private.assignment_permission_scopes
FOR EACH ROW EXECUTE FUNCTION app_private.guard_scope_interval();

-- Managed Auth deletion invokes FK SET NULL. A purpose-bound SYSTEM
-- reconciliation actor is mandatory; missing actor or audit failure aborts
-- the Auth deletion transaction. Binding writes remain activation-gated.
CREATE FUNCTION app_private.prepare_auth_binding_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $body$
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(71001, 1);
  IF NEW.auth_user_id IS NULL AND OLD.auth_user_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF NEW.auth_user_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM app_private.principal_binding_events e
    WHERE e.new_auth_user_id = NEW.auth_user_id AND e.principal_id <> NEW.principal_id
  ) THEN RAISE EXCEPTION 'historical Auth subject cannot change principal'; END IF;
  NEW.binding_version := OLD.binding_version + 1;
  NEW.tokens_valid_from := GREATEST(
      pg_catalog.to_timestamp(pg_catalog.ceil(extract(epoch FROM pg_catalog.clock_timestamp()))),
      OLD.tokens_valid_from + interval '1 second');
  IF NEW.auth_user_id IS NOT NULL THEN NEW.bound_at := pg_catalog.clock_timestamp(); END IF;
  RETURN NEW;
END $body$;
REVOKE ALL ON FUNCTION app_private.prepare_auth_binding_change() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER a0_auth_binding_prepare
BEFORE UPDATE OF auth_user_id ON app_private.principal_auth_bindings
FOR EACH ROW EXECUTE FUNCTION app_private.prepare_auth_binding_change();

CREATE FUNCTION app_private.record_auth_binding_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $body$
DECLARE system_actor uuid; old_subject uuid; event_name text;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.auth_user_id IS NULL AND OLD.auth_user_id IS NULL THEN RETURN NEW; END IF;
    old_subject := OLD.auth_user_id;
  ELSE
    IF NEW.auth_user_id IS NULL THEN RETURN NEW; END IF;
    old_subject := NULL;
  END IF;
  SELECT p.id INTO STRICT system_actor FROM app_private.principals p
    WHERE p.kind = 'SYSTEM' AND p.state = 'ACTIVE'
      AND p.system_purpose = 'identity-reconciliation';
  event_name := CASE
    WHEN NEW.auth_user_id IS NULL THEN 'UNBOUND'
    WHEN old_subject IS NULL THEN 'BOUND'
    WHEN NEW.auth_user_id = old_subject THEN 'RECOVERED'
    ELSE 'RELINKED' END;
  INSERT INTO app_private.principal_binding_events (
    principal_id,binding_id,event_kind,old_auth_user_id,new_auth_user_id,
    binding_version,reason,created_by
  ) VALUES (
    NEW.principal_id,NEW.id,event_name,old_subject,NEW.auth_user_id,
    NEW.binding_version,'managed binding transition',system_actor
  );
  INSERT INTO app_private.audit_events (
    actor_id,actor_kind,auth_subject_snapshot,outcome,authority_evidence,
    event_type,target_kind,target_ref,source_kind,details,created_by
  ) VALUES (
    system_actor,'SYSTEM',old_subject,'SUCCEEDED','{}'::jsonb,
    'identity.binding_changed','principal_auth_binding',NEW.id,
    CASE WHEN NEW.auth_user_id IS NULL THEN 'AUTH_RECONCILIATION' ELSE 'WORKER' END,
    pg_catalog.jsonb_build_object('event_kind',event_name,'binding_version',NEW.binding_version),
    system_actor
  );
  RETURN NEW;
END $body$;
REVOKE ALL ON FUNCTION app_private.record_auth_binding_change() FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER zz_auth_binding_insert_evidence
AFTER INSERT ON app_private.principal_auth_bindings
FOR EACH ROW EXECUTE FUNCTION app_private.record_auth_binding_change();
CREATE TRIGGER zz_auth_binding_update_evidence
AFTER UPDATE OF auth_user_id ON app_private.principal_auth_bindings
FOR EACH ROW EXECUTE FUNCTION app_private.record_auth_binding_change();

-- Bootstrap must supply exactly one ACTIVE purpose-bound
-- identity-reconciliation SYSTEM principal before any live binding or Auth
-- deletion. The trigger deliberately fails closed if this is absent.

RESET ROLE;
