-- FOUNDATION DRAFT 7/8. Files only; SQL HAS NOT BEEN EXECUTED.
-- Forced RLS stays on every table. These are narrow read foundations;
-- all business and privileged mutation RPCs remain disabled pending
-- registered operation handlers, bootstrap, tests and deployment review.
SET ROLE schoolos_schema_owner;
CREATE POLICY people_schema_maintenance ON app_private.people
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY principals_schema_maintenance ON app_private.principals
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY principal_auth_bindings_schema_maintenance ON app_private.principal_auth_bindings
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY principal_binding_events_schema_maintenance ON app_private.principal_binding_events
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY login_aliases_schema_maintenance ON app_private.login_aliases
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY school_profiles_schema_maintenance ON app_private.school_profiles
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY campuses_schema_maintenance ON app.campuses
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY rooms_schema_maintenance ON app.rooms
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY academic_years_schema_maintenance ON app.academic_years
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY file_objects_schema_maintenance ON app_private.file_objects
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY roles_schema_maintenance ON app_private.roles
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY permissions_schema_maintenance ON app_private.permissions
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY role_permission_grants_schema_maintenance ON app_private.role_permission_grants
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY principal_role_assignments_schema_maintenance ON app_private.principal_role_assignments
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY permission_scope_contracts_schema_maintenance ON app_private.permission_scope_contracts
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY assignment_permission_scopes_schema_maintenance ON app_private.assignment_permission_scopes
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY operation_contracts_schema_maintenance ON app_private.operation_contracts
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY approval_policy_versions_schema_maintenance ON app_private.approval_policy_versions
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY approval_step_templates_schema_maintenance ON app_private.approval_step_templates
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY approval_requests_schema_maintenance ON app_private.approval_requests
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY approval_request_files_schema_maintenance ON app_private.approval_request_files
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY approval_request_steps_schema_maintenance ON app_private.approval_request_steps
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY approval_step_reviewers_schema_maintenance ON app_private.approval_step_reviewers
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY approval_reviews_schema_maintenance ON app_private.approval_reviews
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY command_receipts_schema_maintenance ON app_private.command_receipts
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY approval_transitions_schema_maintenance ON app_private.approval_transitions
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY approval_applications_schema_maintenance ON app_private.approval_applications
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY audit_events_schema_maintenance ON app_private.audit_events
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY outbox_events_schema_maintenance ON app_private.outbox_events
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY event_consumer_deliveries_schema_maintenance ON app_private.event_consumer_deliveries
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY notifications_schema_maintenance ON app.notifications
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY notification_preferences_schema_maintenance ON app.notification_preferences
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY setting_revisions_schema_maintenance ON app_private.setting_revisions
  FOR ALL TO schoolos_schema_owner USING (true) WITH CHECK (true);
CREATE POLICY principals_authz_input ON app_private.principals
  FOR SELECT TO schoolos_authz_reader USING (true);
CREATE POLICY principal_auth_bindings_authz_input ON app_private.principal_auth_bindings
  FOR SELECT TO schoolos_authz_reader USING (true);
CREATE POLICY roles_authz_input ON app_private.roles
  FOR SELECT TO schoolos_authz_reader USING (true);
CREATE POLICY permissions_authz_input ON app_private.permissions
  FOR SELECT TO schoolos_authz_reader USING (true);
CREATE POLICY role_permission_grants_authz_input ON app_private.role_permission_grants
  FOR SELECT TO schoolos_authz_reader USING (true);
CREATE POLICY principal_role_assignments_authz_input ON app_private.principal_role_assignments
  FOR SELECT TO schoolos_authz_reader USING (true);
CREATE POLICY permission_scope_contracts_authz_input ON app_private.permission_scope_contracts
  FOR SELECT TO schoolos_authz_reader USING (true);
CREATE POLICY assignment_permission_scopes_authz_input ON app_private.assignment_permission_scopes
  FOR SELECT TO schoolos_authz_reader USING (true);
CREATE POLICY campuses_authz_input ON app.campuses
  FOR SELECT TO schoolos_authz_reader USING (true);
CREATE POLICY school_profiles_authz_input ON app_private.school_profiles
  FOR SELECT TO schoolos_authz_reader USING (true);
CREATE POLICY principals_checked_read_source ON app_private.principals
  FOR SELECT TO schoolos_read_executor USING (true);
RESET ROLE;

-- Ownership must be the authz_reader, not postgres/service_role/table owner.
GRANT USAGE, CREATE ON SCHEMA app_private TO schoolos_authz_reader;
SET ROLE schoolos_authz_reader;
CREATE FUNCTION app_private.current_principal_id() RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
DECLARE claims jsonb; subject uuid; actor uuid; issued numeric;
BEGIN
  subject := auth.uid();
  claims := auth.jwt();
  IF subject IS NULL OR claims IS NULL OR
     COALESCE(claims->>'is_anonymous','false') <> 'false' OR
     claims->>'iat' IS NULL OR claims->>'iat' !~ '^[0-9]{1,12}$'
  THEN RETURN NULL; END IF;
  issued := (claims->>'iat')::numeric;
  SELECT b.principal_id INTO actor
    FROM app_private.principal_auth_bindings b
    JOIN app_private.principals p ON p.id = b.principal_id
   WHERE b.auth_user_id = subject
     AND p.state = 'ACTIVE'
     AND p.kind IN ('INDIVIDUAL','FAMILY')
     AND b.principal_kind = p.kind
     AND issued >= extract(epoch FROM b.tokens_valid_from);
  RETURN actor;
END $body$;
REVOKE ALL ON FUNCTION app_private.current_principal_id() FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION app_private.has_complete_grant(
  wanted_code text, wanted_scope text, target_campus uuid DEFAULT NULL
) RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
DECLARE actor uuid; at_time timestamptz;
BEGIN
  actor := app_private.current_principal_id();
  IF actor IS NULL THEN RETURN false; END IF;
  at_time := pg_catalog.clock_timestamp();
  RETURN EXISTS (
    SELECT 1
      FROM app_private.assignment_permission_scopes s
      JOIN app_private.principal_role_assignments a ON a.id=s.assignment_id
      JOIN app_private.role_permission_grants g ON g.id=s.grant_id
      JOIN app_private.permission_scope_contracts c ON c.id=s.scope_contract_id
      JOIN app_private.permissions p ON p.id=s.permission_id
      JOIN app_private.roles r ON r.id=s.role_id
     WHERE a.principal_id=actor AND a.role_id=s.role_id
       AND g.role_id=s.role_id AND g.permission_id=s.permission_id
       AND c.permission_id=s.permission_id AND c.scope_kind=s.scope_kind
       AND c.resolver_key=s.resolver_key AND c.enabled
       AND p.code=wanted_code AND p.state='ENABLED'
       AND r.state='ACTIVE'
       AND a.valid_from <= at_time
       AND (a.valid_until IS NULL OR at_time < a.valid_until)
       AND (a.revoked_at IS NULL OR at_time < a.revoked_at)
       AND g.valid_from <= at_time
       AND (g.valid_until IS NULL OR at_time < g.valid_until)
       AND (g.revoked_at IS NULL OR at_time < g.revoked_at)
       AND s.valid_from <= at_time
       AND (s.valid_until IS NULL OR at_time < s.valid_until)
       AND (s.revoked_at IS NULL OR at_time < s.revoked_at)
       AND (
         (wanted_scope='ALL' AND s.scope_kind='ALL'
            AND s.resolver_key='DIRECT' AND s.campus_id IS NULL)
         OR
         (wanted_scope='CAMPUS' AND (
           (s.scope_kind='ALL' AND s.resolver_key='DIRECT' AND s.campus_id IS NULL)
           OR (s.scope_kind='CAMPUS' AND s.resolver_key='DIRECT'
               AND s.campus_id=target_campus)))
         OR
         (wanted_scope='OWN' AND s.scope_kind='OWN'
            AND s.resolver_key='SELF_PRINCIPAL' AND s.campus_id IS NULL)
       )
  );
END $body$;
REVOKE ALL ON FUNCTION app_private.has_complete_grant(text,text,uuid) FROM PUBLIC, anon, authenticated, service_role;

-- Fixed predicates only; no caller-selected actor, role, table or SQL.
CREATE FUNCTION app_private.can_campus_read(target_campus uuid) RETURNS boolean
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
  SELECT app_private.has_complete_grant('campus.view','CAMPUS',target_campus)
$body$;
CREATE FUNCTION app_private.can_room_read(target_campus uuid) RETURNS boolean
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
  SELECT app_private.has_complete_grant('room.view','CAMPUS',target_campus)
$body$;
CREATE FUNCTION app_private.can_year_read() RETURNS boolean
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
  SELECT app_private.has_complete_grant('academic_year.view','ALL',NULL)
$body$;
CREATE FUNCTION app_private.can_notification_read(recipient uuid) RETURNS boolean
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
  SELECT recipient = app_private.current_principal_id()
     AND app_private.has_complete_grant('notification.own','OWN',NULL)
$body$;
CREATE FUNCTION app_private.can_preference_read(recipient uuid) RETURNS boolean
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
  SELECT recipient = app_private.current_principal_id()
     AND app_private.has_complete_grant('notification.preference.own','OWN',NULL)
$body$;
REVOKE ALL ON FUNCTION app_private.can_campus_read(uuid),
  app_private.can_room_read(uuid), app_private.can_year_read(),
  app_private.can_notification_read(uuid),
  app_private.can_preference_read(uuid)
FROM PUBLIC, anon, service_role;
RESET ROLE;
REVOKE CREATE ON SCHEMA app_private FROM schoolos_authz_reader;

SET ROLE schoolos_schema_owner;
CREATE POLICY campuses_live_read ON app.campuses
  FOR SELECT TO authenticated USING (app_private.can_campus_read(id));
CREATE POLICY rooms_live_read ON app.rooms
  FOR SELECT TO authenticated USING (app_private.can_room_read(campus_id));
CREATE POLICY academic_years_live_read ON app.academic_years
  FOR SELECT TO authenticated USING (app_private.can_year_read());
CREATE POLICY notifications_live_read ON app.notifications
  FOR SELECT TO authenticated USING (app_private.can_notification_read(recipient_id));
CREATE POLICY notification_preferences_live_read ON app.notification_preferences
  FOR SELECT TO authenticated USING (app_private.can_preference_read(principal_id));
RESET ROLE;

-- Checked projection has no arbitrary principal/column selector. It is
-- enabled only after the matching principal.self scope contract is bootstrapped.
GRANT USAGE, CREATE ON SCHEMA app TO schoolos_read_executor;
SET ROLE schoolos_read_executor;
CREATE FUNCTION app.read_own_principal()
RETURNS TABLE (principal_id uuid, principal_kind text, display_label text)
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, pg_temp
AS $body$
  SELECT p.id, p.kind, p.label
    FROM app_private.principals p
   WHERE p.id = app_private.current_principal_id()
     AND app_private.has_complete_grant('principal.self','OWN',NULL)
$body$;
RESET ROLE;
REVOKE CREATE ON SCHEMA app FROM schoolos_read_executor;
REVOKE ALL ON FUNCTION app.read_own_principal() FROM PUBLIC, anon, authenticated, service_role;
