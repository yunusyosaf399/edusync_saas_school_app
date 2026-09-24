-- FOUNDATION DRAFT 2/8. Corrected after the first disposable local apply failed;
-- this corrected revision has not been executed.
-- Structural DDL only. No school data, bootstrap or runtime entry points.
SET ROLE schoolos_schema_owner;

CREATE TABLE app_private.people (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  display_name text NOT NULL,
  state text NOT NULL DEFAULT 'ACTIVE',
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT people_pkey PRIMARY KEY (id),
  CONSTRAINT people_ck_01 CHECK (length(btrim(display_name)) > 0),
  CONSTRAINT people_ck_02 CHECK (state IN ('ACTIVE', 'INACTIVE', 'ARCHIVED')),
  CONSTRAINT people_ck_03 CHECK (row_version > 0)
);
ALTER TABLE app_private.people ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.people FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.principals (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  kind text NOT NULL,
  person_id uuid,
  label text NOT NULL,
  system_purpose text,
  state text NOT NULL DEFAULT 'PENDING',
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT principals_pkey PRIMARY KEY (id),
  CONSTRAINT principals_id_kind_key UNIQUE (id,kind),
  CONSTRAINT principals_ck_01 CHECK (kind IN ('INDIVIDUAL', 'FAMILY', 'SYSTEM')),
  CONSTRAINT principals_ck_02 CHECK ((kind = 'INDIVIDUAL') = (person_id IS NOT NULL)),
  CONSTRAINT principals_ck_03 CHECK ((kind = 'SYSTEM') = (system_purpose IS NOT NULL)),
  CONSTRAINT principals_ck_04 CHECK (length(btrim(label)) > 0),
  CONSTRAINT principals_ck_05 CHECK (state IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'RETIRED')),
  CONSTRAINT principals_ck_06 CHECK (row_version > 0),
  CONSTRAINT principals_person_id_fkey FOREIGN KEY (person_id) REFERENCES app_private.people (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT principals_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.principals ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.principals FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.principal_auth_bindings (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  principal_id uuid NOT NULL,
  principal_kind text NOT NULL,
  auth_user_id uuid,
  binding_version bigint NOT NULL DEFAULT 1,
  bound_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  tokens_valid_from timestamptz NOT NULL,
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT principal_auth_bindings_pkey PRIMARY KEY (id),
  CONSTRAINT principal_auth_bindings_principal_id_key UNIQUE (principal_id),
  CONSTRAINT principal_auth_bindings_auth_user_id_key UNIQUE (auth_user_id),
  CONSTRAINT principal_auth_bindings_id_principal_id_key UNIQUE (id,principal_id),
  CONSTRAINT principal_auth_bindings_ck_01 CHECK (principal_kind IN ('INDIVIDUAL', 'FAMILY')),
  CONSTRAINT principal_auth_bindings_ck_02 CHECK (binding_version > 0),
  CONSTRAINT principal_auth_bindings_ck_03 CHECK (auth_user_id IS NULL OR bound_at IS NOT NULL),
  CONSTRAINT principal_auth_bindings_ck_04 CHECK (extract(epoch FROM tokens_valid_from) = floor(extract(epoch FROM tokens_valid_from))),
  CONSTRAINT principal_auth_bindings_ck_05 CHECK (isfinite(tokens_valid_from)),
  CONSTRAINT principal_auth_bindings_ck_06 CHECK (row_version > 0),
  CONSTRAINT principal_auth_bindings_principal_id_principal_kind_fkey FOREIGN KEY (principal_id,principal_kind) REFERENCES app_private.principals (id,kind) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT principal_auth_bindings_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.principal_auth_bindings ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.principal_auth_bindings FORCE ROW LEVEL SECURITY;

-- The first local apply proved postgres cannot re-grant managed Auth privileges
-- to the application owner. Keep table ownership with schoolos_schema_owner;
-- provisionally install only this external FK as the trusted deployment role.
-- The next separately authorized local execution must prove this role can ALTER
-- the application-owned table and reference auth.users(id).
RESET ROLE;
ALTER TABLE app_private.principal_auth_bindings
  ADD CONSTRAINT principal_auth_bindings_auth_user_id_fkey
  FOREIGN KEY (auth_user_id) REFERENCES auth.users (id)
  ON DELETE SET NULL ON UPDATE RESTRICT;
SET ROLE schoolos_schema_owner;

CREATE TABLE app_private.principal_binding_events (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  principal_id uuid NOT NULL,
  binding_id uuid NOT NULL,
  event_kind text NOT NULL,
  old_auth_user_id uuid,
  new_auth_user_id uuid,
  binding_version bigint NOT NULL,
  reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  CONSTRAINT principal_binding_events_pkey PRIMARY KEY (id),
  CONSTRAINT principal_binding_events_binding_id_binding_version_key UNIQUE (binding_id,binding_version),
  CONSTRAINT principal_binding_events_ck_01 CHECK (event_kind IN ('BOUND', 'UNBOUND', 'RELINKED', 'RECOVERED', 'RECONCILED')),
  CONSTRAINT principal_binding_events_ck_02 CHECK (binding_version > 0),
  CONSTRAINT principal_binding_events_ck_03 CHECK (length(btrim(reason)) > 0),
  CONSTRAINT principal_binding_events_binding_id_principal_id_fkey FOREIGN KEY (binding_id,principal_id) REFERENCES app_private.principal_auth_bindings (id,principal_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT principal_binding_events_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.principal_binding_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.principal_binding_events FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.login_aliases (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  principal_id uuid NOT NULL,
  normalized_alias text COLLATE "C" NOT NULL,
  state text NOT NULL DEFAULT 'RESERVED',
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT login_aliases_pkey PRIMARY KEY (id),
  CONSTRAINT login_aliases_normalized_alias_key UNIQUE (normalized_alias),
  CONSTRAINT login_aliases_ck_01 CHECK (normalized_alias ~ '^[a-z][a-z0-9._-]{2,31}$'),
  CONSTRAINT login_aliases_ck_02 CHECK (state IN ('RESERVED', 'ACTIVE', 'RETIRED')),
  CONSTRAINT login_aliases_ck_03 CHECK (row_version > 0),
  CONSTRAINT login_aliases_principal_id_fkey FOREIGN KEY (principal_id) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT login_aliases_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.login_aliases ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.login_aliases FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.school_profiles (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  singleton boolean NOT NULL DEFAULT true,
  code text NOT NULL,
  name text NOT NULL,
  timezone text NOT NULL,
  currency_code text NOT NULL,
  locale text NOT NULL,
  contact_details jsonb NOT NULL DEFAULT '{}'::jsonb,
  state text NOT NULL DEFAULT 'SETUP',
  default_academic_year_id uuid,
  logo_file_id uuid,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT school_profiles_pkey PRIMARY KEY (id),
  CONSTRAINT school_profiles_singleton_key UNIQUE (singleton),
  CONSTRAINT school_profiles_ck_01 CHECK (length(btrim(code)) > 0),
  CONSTRAINT school_profiles_ck_02 CHECK (length(btrim(name)) > 0),
  CONSTRAINT school_profiles_ck_03 CHECK (length(btrim(timezone)) > 0),
  CONSTRAINT school_profiles_ck_04 CHECK (length(btrim(locale)) > 0),
  CONSTRAINT school_profiles_ck_05 CHECK (singleton IS TRUE),
  CONSTRAINT school_profiles_ck_06 CHECK (currency_code ~ '^[A-Z]{3}$'),
  CONSTRAINT school_profiles_ck_07 CHECK (jsonb_typeof(contact_details) = 'object'),
  CONSTRAINT school_profiles_ck_08 CHECK (state IN ('SETUP', 'ACTIVE', 'INACTIVE')),
  CONSTRAINT school_profiles_ck_09 CHECK (row_version > 0),
  CONSTRAINT school_profiles_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.school_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.school_profiles FORCE ROW LEVEL SECURITY;

CREATE TABLE app.campuses (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  school_id uuid NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  address text,
  state text NOT NULL DEFAULT 'PLANNED',
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT campuses_pkey PRIMARY KEY (id),
  CONSTRAINT campuses_school_id_code_key UNIQUE (school_id,code),
  CONSTRAINT campuses_ck_01 CHECK (length(btrim(code)) > 0),
  CONSTRAINT campuses_ck_02 CHECK (length(btrim(name)) > 0),
  CONSTRAINT campuses_ck_03 CHECK (state IN ('PLANNED', 'ACTIVE', 'ARCHIVED')),
  CONSTRAINT campuses_ck_04 CHECK (row_version > 0),
  CONSTRAINT campuses_school_id_fkey FOREIGN KEY (school_id) REFERENCES app_private.school_profiles (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT campuses_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app.campuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.campuses FORCE ROW LEVEL SECURITY;

CREATE TABLE app.rooms (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  campus_id uuid NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  kind_code text NOT NULL,
  capacity integer,
  state text NOT NULL DEFAULT 'ACTIVE',
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT rooms_pkey PRIMARY KEY (id),
  CONSTRAINT rooms_campus_id_code_key UNIQUE (campus_id,code),
  CONSTRAINT rooms_ck_01 CHECK (length(btrim(code)) > 0),
  CONSTRAINT rooms_ck_02 CHECK (length(btrim(name)) > 0),
  CONSTRAINT rooms_ck_03 CHECK (length(btrim(kind_code)) > 0),
  CONSTRAINT rooms_ck_04 CHECK (capacity IS NULL OR capacity > 0),
  CONSTRAINT rooms_ck_05 CHECK (state IN ('ACTIVE', 'UNAVAILABLE', 'ARCHIVED')),
  CONSTRAINT rooms_ck_06 CHECK (row_version > 0),
  CONSTRAINT rooms_campus_id_fkey FOREIGN KEY (campus_id) REFERENCES app.campuses (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT rooms_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.rooms FORCE ROW LEVEL SECURITY;

CREATE TABLE app.academic_years (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  school_id uuid NOT NULL,
  code text NOT NULL,
  label text NOT NULL,
  starts_on date NOT NULL,
  ends_on date NOT NULL,
  state text NOT NULL DEFAULT 'PLANNED',
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT academic_years_pkey PRIMARY KEY (id),
  CONSTRAINT academic_years_school_id_code_key UNIQUE (school_id,code),
  CONSTRAINT academic_years_id_school_id_key UNIQUE (id,school_id),
  CONSTRAINT academic_years_ck_01 CHECK (starts_on <= ends_on),
  CONSTRAINT academic_years_ck_02 CHECK (length(btrim(code)) > 0),
  CONSTRAINT academic_years_ck_03 CHECK (length(btrim(label)) > 0),
  CONSTRAINT academic_years_ck_04 CHECK (state IN ('PLANNED', 'ACTIVE', 'CLOSED', 'ARCHIVED')),
  CONSTRAINT academic_years_ck_05 CHECK (row_version > 0),
  CONSTRAINT academic_years_school_id_fkey FOREIGN KEY (school_id) REFERENCES app_private.school_profiles (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT academic_years_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app.academic_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.academic_years FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.file_objects (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  uploaded_by_principal_id uuid NOT NULL,
  campus_id uuid,
  storage_location_key text NOT NULL,
  purpose_code text NOT NULL,
  object_key text NOT NULL,
  content_type text NOT NULL,
  byte_size bigint NOT NULL,
  content_hash bytea NOT NULL,
  classification text NOT NULL DEFAULT 'PRIVATE',
  state text NOT NULL DEFAULT 'PENDING',
  validated_at timestamptz,
  replaces_file_id uuid,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT file_objects_pkey PRIMARY KEY (id),
  CONSTRAINT file_objects_storage_location_key_object_key_key UNIQUE (storage_location_key,object_key),
  CONSTRAINT file_objects_ck_01 CHECK (byte_size BETWEEN 1 AND 1048576),
  CONSTRAINT file_objects_ck_02 CHECK (octet_length(content_hash) = 32),
  CONSTRAINT file_objects_ck_03 CHECK (length(btrim(storage_location_key)) > 0),
  CONSTRAINT file_objects_ck_04 CHECK (length(btrim(object_key)) > 0),
  CONSTRAINT file_objects_ck_05 CHECK (length(btrim(content_type)) > 0),
  CONSTRAINT file_objects_ck_06 CHECK (length(btrim(classification)) > 0),
  CONSTRAINT file_objects_ck_07 CHECK (purpose_code ~ '^[A-Z][A-Z0-9_]{0,63}$'),
  CONSTRAINT file_objects_ck_08 CHECK (state IN ('PENDING', 'VALIDATED', 'AVAILABLE', 'QUARANTINED', 'ARCHIVED', 'PURGED')),
  CONSTRAINT file_objects_ck_09 CHECK (state <> 'AVAILABLE' OR validated_at IS NOT NULL),
  CONSTRAINT file_objects_ck_10 CHECK (replaces_file_id IS NULL OR replaces_file_id <> id),
  CONSTRAINT file_objects_ck_11 CHECK (row_version > 0),
  CONSTRAINT file_objects_ck_12 CHECK (state <> 'PENDING' OR validated_at IS NULL),
  CONSTRAINT file_objects_ck_13 CHECK (state <> 'VALIDATED' OR validated_at IS NOT NULL),
  CONSTRAINT file_objects_uploaded_by_principal_id_fkey FOREIGN KEY (uploaded_by_principal_id) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT file_objects_campus_id_fkey FOREIGN KEY (campus_id) REFERENCES app.campuses (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT file_objects_replaces_file_id_fkey FOREIGN KEY (replaces_file_id) REFERENCES app_private.file_objects (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT file_objects_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.file_objects ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.file_objects FORCE ROW LEVEL SECURITY;

RESET ROLE;
