-- FOUNDATION DRAFT 3/8. Files only; SQL HAS NOT BEEN EXECUTED.
-- Structural DDL only. No school data, bootstrap or runtime entry points.
SET ROLE schoolos_schema_owner;

CREATE TABLE app_private.roles (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  code text NOT NULL,
  label text NOT NULL,
  family_only boolean NOT NULL DEFAULT false,
  state text NOT NULL DEFAULT 'DRAFT',
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT roles_pkey PRIMARY KEY (id),
  CONSTRAINT roles_code_key UNIQUE (code),
  CONSTRAINT roles_id_family_only_key UNIQUE (id,family_only),
  CONSTRAINT roles_ck_01 CHECK (length(btrim(code)) > 0),
  CONSTRAINT roles_ck_02 CHECK (length(btrim(label)) > 0),
  CONSTRAINT roles_ck_03 CHECK (state IN ('DRAFT', 'ACTIVE', 'RETIRED')),
  CONSTRAINT roles_ck_04 CHECK (row_version > 0),
  CONSTRAINT roles_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.roles FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.permissions (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  code text NOT NULL,
  family_safe boolean NOT NULL DEFAULT false,
  state text NOT NULL DEFAULT 'DISABLED',
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT permissions_pkey PRIMARY KEY (id),
  CONSTRAINT permissions_code_key UNIQUE (code),
  CONSTRAINT permissions_id_family_safe_key UNIQUE (id,family_safe),
  CONSTRAINT permissions_ck_01 CHECK (length(btrim(code)) > 0),
  CONSTRAINT permissions_ck_02 CHECK (state IN ('ENABLED', 'DISABLED', 'RETIRED')),
  CONSTRAINT permissions_ck_03 CHECK (row_version > 0),
  CONSTRAINT permissions_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.permissions FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.role_permission_grants (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  role_id uuid NOT NULL,
  role_family_only boolean NOT NULL,
  permission_id uuid NOT NULL,
  permission_family_safe boolean NOT NULL,
  valid_from timestamptz NOT NULL,
  valid_until timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT role_permission_grants_pkey PRIMARY KEY (id),
  CONSTRAINT role_permission_grants_id_role_id_permission_id_key UNIQUE (id,role_id,permission_id),
  CONSTRAINT role_permission_grants_ck_01 CHECK (NOT role_family_only OR permission_family_safe),
  CONSTRAINT role_permission_grants_ck_02 CHECK (revoked_at IS NULL OR revoked_at >= created_at),
  CONSTRAINT role_permission_grants_ck_03 CHECK (valid_until IS NULL OR valid_until > valid_from),
  CONSTRAINT role_permission_grants_ck_04 CHECK (isfinite(valid_from)),
  CONSTRAINT role_permission_grants_ck_05 CHECK (valid_until IS NULL OR isfinite(valid_until)),
  CONSTRAINT role_permission_grants_ck_06 CHECK (row_version > 0),
  CONSTRAINT role_permission_grants_role_id_role_family_only_fkey FOREIGN KEY (role_id,role_family_only) REFERENCES app_private.roles (id,family_only) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT rpg_permission_family_safe_fkey FOREIGN KEY (permission_id,permission_family_safe) REFERENCES app_private.permissions (id,family_safe) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT role_permission_grants_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.role_permission_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.role_permission_grants FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.principal_role_assignments (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  principal_id uuid NOT NULL,
  principal_kind text NOT NULL,
  role_id uuid NOT NULL,
  role_family_only boolean NOT NULL,
  context_kind text NOT NULL,
  valid_from timestamptz NOT NULL,
  valid_until timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT principal_role_assignments_pkey PRIMARY KEY (id),
  CONSTRAINT principal_role_assignments_id_role_id_key UNIQUE (id,role_id),
  CONSTRAINT principal_role_assignments_ck_01 CHECK (context_kind = principal_kind),
  CONSTRAINT principal_role_assignments_ck_02 CHECK (principal_kind <> 'FAMILY' OR role_family_only),
  CONSTRAINT principal_role_assignments_ck_03 CHECK (valid_until IS NULL OR valid_until > valid_from),
  CONSTRAINT principal_role_assignments_ck_04 CHECK (revoked_at IS NULL OR revoked_at >= created_at),
  CONSTRAINT principal_role_assignments_ck_05 CHECK (isfinite(valid_from)),
  CONSTRAINT principal_role_assignments_ck_06 CHECK (valid_until IS NULL OR isfinite(valid_until)),
  CONSTRAINT principal_role_assignments_ck_07 CHECK (row_version > 0),
  CONSTRAINT principal_role_assignments_principal_id_principal_kind_fkey FOREIGN KEY (principal_id,principal_kind) REFERENCES app_private.principals (id,kind) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT principal_role_assignments_role_id_role_family_only_fkey FOREIGN KEY (role_id,role_family_only) REFERENCES app_private.roles (id,family_only) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT principal_role_assignments_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.principal_role_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.principal_role_assignments FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.permission_scope_contracts (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  permission_id uuid NOT NULL,
  scope_kind text NOT NULL,
  resolver_key text NOT NULL,
  contract_version integer NOT NULL DEFAULT 1,
  enabled boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT permission_scope_contracts_pkey PRIMARY KEY (id),
  CONSTRAINT psc_identity_version_key UNIQUE (permission_id,scope_kind,resolver_key,contract_version),
  CONSTRAINT psc_composite_parent_key UNIQUE (id,permission_id,scope_kind,resolver_key),
  CONSTRAINT permission_scope_contracts_ck_01 CHECK (scope_kind IN ('ALL', 'CAMPUS', 'OWN', 'ASSIGNED')),
  CONSTRAINT permission_scope_contracts_ck_02 CHECK (contract_version > 0),
  CONSTRAINT permission_scope_contracts_ck_03 CHECK (length(btrim(resolver_key)) > 0),
  CONSTRAINT permission_scope_contracts_ck_04 CHECK (((scope_kind IN ('ALL','CAMPUS')) = (resolver_key = 'DIRECT'))),
  CONSTRAINT permission_scope_contracts_ck_05 CHECK (row_version > 0),
  CONSTRAINT permission_scope_contracts_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES app_private.permissions (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT permission_scope_contracts_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.permission_scope_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.permission_scope_contracts FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.assignment_permission_scopes (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  assignment_id uuid NOT NULL,
  grant_id uuid NOT NULL,
  role_id uuid NOT NULL,
  permission_id uuid NOT NULL,
  scope_contract_id uuid NOT NULL,
  scope_kind text NOT NULL,
  resolver_key text NOT NULL,
  campus_id uuid,
  valid_from timestamptz NOT NULL,
  valid_until timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT assignment_permission_scopes_pkey PRIMARY KEY (id),
  CONSTRAINT assignment_permission_scopes_ck_01 CHECK (scope_kind IN ('ALL', 'CAMPUS', 'OWN', 'ASSIGNED')),
  CONSTRAINT assignment_permission_scopes_ck_02 CHECK ((scope_kind = 'CAMPUS') = (campus_id IS NOT NULL)),
  CONSTRAINT assignment_permission_scopes_ck_03 CHECK (valid_until IS NULL OR valid_until > valid_from),
  CONSTRAINT assignment_permission_scopes_ck_04 CHECK (revoked_at IS NULL OR revoked_at >= created_at),
  CONSTRAINT assignment_permission_scopes_ck_05 CHECK (isfinite(valid_from)),
  CONSTRAINT assignment_permission_scopes_ck_06 CHECK (valid_until IS NULL OR isfinite(valid_until)),
  CONSTRAINT assignment_permission_scopes_ck_07 CHECK (row_version > 0),
  CONSTRAINT assignment_permission_scopes_assignment_id_role_id_fkey FOREIGN KEY (assignment_id,role_id) REFERENCES app_private.principal_role_assignments (id,role_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT aps_grant_chain_fkey FOREIGN KEY (grant_id,role_id,permission_id) REFERENCES app_private.role_permission_grants (id,role_id,permission_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT aps_scope_contract_chain_fkey FOREIGN KEY (scope_contract_id,permission_id,scope_kind,resolver_key) REFERENCES app_private.permission_scope_contracts (id,permission_id,scope_kind,resolver_key) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT assignment_permission_scopes_campus_id_fkey FOREIGN KEY (campus_id) REFERENCES app.campuses (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT assignment_permission_scopes_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.assignment_permission_scopes ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.assignment_permission_scopes FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.operation_contracts (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  code text NOT NULL,
  contract_version integer NOT NULL DEFAULT 1,
  handler_key text NOT NULL,
  request_permission_id uuid NOT NULL,
  review_permission_id uuid,
  payload_schema_version integer NOT NULL DEFAULT 1,
  requires_approval boolean NOT NULL DEFAULT false,
  enabled boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT operation_contracts_pkey PRIMARY KEY (id),
  CONSTRAINT operation_contracts_code_contract_version_key UNIQUE (code,contract_version),
  CONSTRAINT operation_contracts_id_payload_schema_version_key UNIQUE (id,payload_schema_version),
  CONSTRAINT operation_contracts_ck_01 CHECK (length(btrim(code)) > 0),
  CONSTRAINT operation_contracts_ck_02 CHECK (length(btrim(handler_key)) > 0),
  CONSTRAINT operation_contracts_ck_03 CHECK (contract_version > 0),
  CONSTRAINT operation_contracts_ck_04 CHECK (payload_schema_version > 0),
  CONSTRAINT operation_contracts_ck_05 CHECK (NOT requires_approval OR review_permission_id IS NOT NULL),
  CONSTRAINT operation_contracts_ck_06 CHECK (row_version > 0),
  CONSTRAINT operation_contracts_request_permission_id_fkey FOREIGN KEY (request_permission_id) REFERENCES app_private.permissions (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT operation_contracts_review_permission_id_fkey FOREIGN KEY (review_permission_id) REFERENCES app_private.permissions (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT operation_contracts_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.operation_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.operation_contracts FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.approval_policy_versions (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  policy_key text NOT NULL,
  version integer NOT NULL,
  operation_id uuid NOT NULL,
  campus_id uuid,
  state text NOT NULL DEFAULT 'DRAFT',
  effective_from timestamptz,
  effective_until timestamptz,
  activated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT approval_policy_versions_pkey PRIMARY KEY (id),
  CONSTRAINT approval_policy_versions_policy_key_version_key UNIQUE (policy_key,version),
  CONSTRAINT approval_policy_versions_id_operation_id_key UNIQUE (id,operation_id),
  CONSTRAINT approval_policy_versions_ck_01 CHECK (length(btrim(policy_key)) > 0),
  CONSTRAINT approval_policy_versions_ck_02 CHECK (version > 0),
  CONSTRAINT approval_policy_versions_ck_03 CHECK (state IN ('DRAFT', 'ACTIVE', 'RETIRED')),
  CONSTRAINT approval_policy_versions_ck_04 CHECK (activated_at IS NULL OR effective_from IS NOT NULL),
  CONSTRAINT approval_policy_versions_ck_05 CHECK (effective_until IS NULL OR effective_from IS NULL OR effective_until > effective_from),
  CONSTRAINT approval_policy_versions_ck_06 CHECK (row_version > 0),
  CONSTRAINT approval_policy_versions_operation_id_fkey FOREIGN KEY (operation_id) REFERENCES app_private.operation_contracts (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_policy_versions_campus_id_fkey FOREIGN KEY (campus_id) REFERENCES app.campuses (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_policy_versions_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.approval_policy_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.approval_policy_versions FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.approval_step_templates (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  policy_id uuid NOT NULL,
  step_number integer NOT NULL,
  reviewer_role_id uuid NOT NULL,
  required_reviews integer NOT NULL DEFAULT 1,
  selection_resolver_key text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT approval_step_templates_pkey PRIMARY KEY (id),
  CONSTRAINT approval_step_templates_policy_id_step_number_key UNIQUE (policy_id,step_number),
  CONSTRAINT approval_step_templates_id_policy_id_key UNIQUE (id,policy_id),
  CONSTRAINT approval_step_templates_ck_01 CHECK (step_number > 0),
  CONSTRAINT approval_step_templates_ck_02 CHECK (required_reviews = 1),
  CONSTRAINT approval_step_templates_ck_03 CHECK (length(btrim(selection_resolver_key)) > 0),
  CONSTRAINT approval_step_templates_ck_04 CHECK (row_version > 0),
  CONSTRAINT approval_step_templates_policy_id_fkey FOREIGN KEY (policy_id) REFERENCES app_private.approval_policy_versions (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_step_templates_reviewer_role_id_fkey FOREIGN KEY (reviewer_role_id) REFERENCES app_private.roles (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_step_templates_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.approval_step_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.approval_step_templates FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.approval_requests (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  operation_id uuid NOT NULL,
  payload_schema_version integer NOT NULL,
  policy_id uuid NOT NULL,
  requester_id uuid NOT NULL,
  campus_id uuid,
  target_ref uuid,
  expected_target_version bigint,
  reason text NOT NULL,
  old_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  requested_payload jsonb NOT NULL,
  state text NOT NULL DEFAULT 'DRAFT',
  submitted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT approval_requests_pkey PRIMARY KEY (id),
  CONSTRAINT approval_requests_id_policy_id_key UNIQUE (id,policy_id),
  CONSTRAINT approval_requests_id_operation_id_key UNIQUE (id,operation_id),
  CONSTRAINT approval_requests_ck_01 CHECK (length(btrim(reason)) > 0),
  CONSTRAINT approval_requests_ck_02 CHECK (jsonb_typeof(old_snapshot) = 'object'),
  CONSTRAINT approval_requests_ck_03 CHECK (jsonb_typeof(requested_payload) = 'object'),
  CONSTRAINT approval_requests_ck_04 CHECK (payload_schema_version > 0),
  CONSTRAINT approval_requests_ck_05 CHECK (expected_target_version IS NULL OR expected_target_version > 0),
  CONSTRAINT approval_requests_ck_06 CHECK (state IN ('DRAFT', 'SUBMITTED', 'PENDING', 'APPROVED', 'REJECTED', 'CANCELLED', 'EXECUTED', 'INVALIDATED')),
  CONSTRAINT approval_requests_ck_07 CHECK (state IN ('DRAFT','CANCELLED') OR submitted_at IS NOT NULL),
  CONSTRAINT approval_requests_ck_08 CHECK (row_version > 0),
  CONSTRAINT approval_requests_policy_id_operation_id_fkey FOREIGN KEY (policy_id,operation_id) REFERENCES app_private.approval_policy_versions (id,operation_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_requests_operation_id_payload_schema_version_fkey FOREIGN KEY (operation_id,payload_schema_version) REFERENCES app_private.operation_contracts (id,payload_schema_version) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_requests_requester_id_fkey FOREIGN KEY (requester_id) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_requests_campus_id_fkey FOREIGN KEY (campus_id) REFERENCES app.campuses (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_requests_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.approval_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.approval_requests FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.approval_request_files (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  request_id uuid NOT NULL,
  file_id uuid NOT NULL,
  purpose text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  CONSTRAINT approval_request_files_pkey PRIMARY KEY (id),
  CONSTRAINT approval_request_files_request_id_file_id_key UNIQUE (request_id,file_id),
  CONSTRAINT approval_request_files_ck_01 CHECK (length(btrim(purpose)) > 0),
  CONSTRAINT approval_request_files_request_id_fkey FOREIGN KEY (request_id) REFERENCES app_private.approval_requests (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_request_files_file_id_fkey FOREIGN KEY (file_id) REFERENCES app_private.file_objects (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_request_files_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.approval_request_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.approval_request_files FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.approval_request_steps (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  request_id uuid NOT NULL,
  policy_id uuid NOT NULL,
  template_id uuid NOT NULL,
  step_number integer NOT NULL,
  required_reviews integer NOT NULL,
  state text NOT NULL DEFAULT 'WAITING',
  opened_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT approval_request_steps_pkey PRIMARY KEY (id),
  CONSTRAINT approval_request_steps_request_id_step_number_key UNIQUE (request_id,step_number),
  CONSTRAINT approval_request_steps_id_request_id_key UNIQUE (id,request_id),
  CONSTRAINT approval_request_steps_ck_01 CHECK (step_number > 0),
  CONSTRAINT approval_request_steps_ck_02 CHECK (required_reviews = 1),
  CONSTRAINT approval_request_steps_ck_03 CHECK (state IN ('WAITING', 'OPEN', 'APPROVED', 'REJECTED', 'CANCELLED')),
  CONSTRAINT approval_request_steps_ck_04 CHECK (closed_at IS NULL OR opened_at IS NULL OR closed_at >= opened_at),
  CONSTRAINT approval_request_steps_ck_05 CHECK (row_version > 0),
  CONSTRAINT approval_request_steps_request_id_policy_id_fkey FOREIGN KEY (request_id,policy_id) REFERENCES app_private.approval_requests (id,policy_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_request_steps_template_id_policy_id_fkey FOREIGN KEY (template_id,policy_id) REFERENCES app_private.approval_step_templates (id,policy_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_request_steps_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.approval_request_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.approval_request_steps FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.approval_step_reviewers (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  step_id uuid NOT NULL,
  reviewer_id uuid NOT NULL,
  assigned_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  withdrawn_at timestamptz,
  assignment_reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT approval_step_reviewers_pkey PRIMARY KEY (id),
  CONSTRAINT approval_step_reviewers_id_step_id_reviewer_id_key UNIQUE (id,step_id,reviewer_id),
  CONSTRAINT approval_step_reviewers_ck_01 CHECK (withdrawn_at IS NULL OR withdrawn_at >= assigned_at),
  CONSTRAINT approval_step_reviewers_ck_02 CHECK (length(btrim(assignment_reason)) > 0),
  CONSTRAINT approval_step_reviewers_ck_03 CHECK (row_version > 0),
  CONSTRAINT approval_step_reviewers_step_id_fkey FOREIGN KEY (step_id) REFERENCES app_private.approval_request_steps (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_step_reviewers_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_step_reviewers_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.approval_step_reviewers ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.approval_step_reviewers FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.approval_reviews (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  reviewer_assignment_id uuid NOT NULL,
  step_id uuid NOT NULL,
  reviewer_id uuid NOT NULL,
  decision text NOT NULL,
  reason text NOT NULL,
  expected_request_version bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  CONSTRAINT approval_reviews_pkey PRIMARY KEY (id),
  CONSTRAINT approval_reviews_reviewer_assignment_id_key UNIQUE (reviewer_assignment_id),
  CONSTRAINT approval_reviews_step_id_key UNIQUE (step_id),
  CONSTRAINT approval_reviews_ck_01 CHECK (decision IN ('APPROVE', 'REJECT')),
  CONSTRAINT approval_reviews_ck_02 CHECK (length(btrim(reason)) > 0),
  CONSTRAINT approval_reviews_ck_03 CHECK (expected_request_version > 0),
  CONSTRAINT approval_reviews_reviewer_chain_fkey FOREIGN KEY (reviewer_assignment_id,step_id,reviewer_id) REFERENCES app_private.approval_step_reviewers (id,step_id,reviewer_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_reviews_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.approval_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.approval_reviews FORCE ROW LEVEL SECURITY;

RESET ROLE;
