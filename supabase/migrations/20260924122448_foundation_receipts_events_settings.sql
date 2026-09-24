-- FOUNDATION DRAFT 4/8. Files only; SQL HAS NOT BEEN EXECUTED.
-- Structural DDL only. No school data, bootstrap or runtime entry points.
SET ROLE schoolos_schema_owner;

CREATE TABLE app_private.command_receipts (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  principal_id uuid NOT NULL,
  operation_id uuid NOT NULL,
  command_kind text NOT NULL,
  idempotency_key text NOT NULL,
  canonical_payload_hash bytea NOT NULL,
  canonicalization_version integer NOT NULL DEFAULT 1,
  expected_target_version bigint,
  request_id uuid,
  expected_request_version bigint,
  state text NOT NULL,
  result_kind text,
  result_ref uuid,
  result_summary jsonb,
  error_code text,
  completed_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  CONSTRAINT command_receipts_pkey PRIMARY KEY (id),
  CONSTRAINT command_receipts_principal_id_operation_id_idempotency_key_key UNIQUE (principal_id,operation_id,idempotency_key),
  CONSTRAINT command_receipts_id_operation_id_key UNIQUE (id,operation_id),
  CONSTRAINT command_receipts_id_operation_id_request_id_key UNIQUE (id,operation_id,request_id),
  CONSTRAINT command_receipts_ck_01 CHECK (char_length(idempotency_key) BETWEEN 1 AND 200),
  CONSTRAINT command_receipts_ck_02 CHECK (octet_length(canonical_payload_hash) = 32),
  CONSTRAINT command_receipts_ck_03 CHECK (canonicalization_version > 0),
  CONSTRAINT command_receipts_ck_04 CHECK (expected_target_version IS NULL OR expected_target_version > 0),
  CONSTRAINT command_receipts_ck_05 CHECK (expected_request_version IS NULL OR expected_request_version > 0),
  CONSTRAINT command_receipts_ck_06 CHECK (state IN ('SUCCEEDED', 'REJECTED')),
  CONSTRAINT command_receipts_ck_07 CHECK (completed_at >= created_at),
  CONSTRAINT command_receipts_ck_08 CHECK (state <> 'SUCCEEDED' OR (result_kind IS NOT NULL AND error_code IS NULL)),
  CONSTRAINT command_receipts_ck_09 CHECK (state <> 'REJECTED' OR (error_code IS NOT NULL AND result_ref IS NULL)),
  CONSTRAINT command_receipts_ck_10 CHECK (result_summary IS NULL OR jsonb_typeof(result_summary) = 'object'),
  CONSTRAINT command_receipts_ck_11 CHECK (command_kind ~ '^[A-Za-z][A-Za-z0-9._-]{0,63}$'),
  CONSTRAINT command_receipts_request_id_operation_id_fkey FOREIGN KEY (request_id,operation_id) REFERENCES app_private.approval_requests (id,operation_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT command_receipts_principal_id_fkey FOREIGN KEY (principal_id) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT command_receipts_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.command_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.command_receipts FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.approval_transitions (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  request_id uuid NOT NULL,
  sequence_number bigint NOT NULL,
  from_state text,
  to_state text NOT NULL,
  reason text NOT NULL,
  command_receipt_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  CONSTRAINT approval_transitions_pkey PRIMARY KEY (id),
  CONSTRAINT approval_transitions_request_id_sequence_number_key UNIQUE (request_id,sequence_number),
  CONSTRAINT approval_transitions_ck_01 CHECK (sequence_number > 0),
  CONSTRAINT approval_transitions_ck_02 CHECK (from_state IS NOT NULL OR sequence_number = 1),
  CONSTRAINT approval_transitions_ck_03 CHECK (to_state IN ('DRAFT', 'SUBMITTED', 'PENDING', 'APPROVED', 'REJECTED', 'CANCELLED', 'EXECUTED', 'INVALIDATED')),
  CONSTRAINT approval_transitions_ck_04 CHECK (from_state IS NULL OR from_state IN ('DRAFT', 'SUBMITTED', 'PENDING', 'APPROVED', 'REJECTED', 'CANCELLED', 'EXECUTED', 'INVALIDATED')),
  CONSTRAINT approval_transitions_ck_05 CHECK (length(btrim(reason)) > 0),
  CONSTRAINT approval_transitions_request_id_fkey FOREIGN KEY (request_id) REFERENCES app_private.approval_requests (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_transitions_command_receipt_id_fkey FOREIGN KEY (command_receipt_id) REFERENCES app_private.command_receipts (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_transitions_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.approval_transitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.approval_transitions FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.approval_applications (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  request_id uuid NOT NULL,
  command_receipt_id uuid NOT NULL,
  operation_id uuid NOT NULL,
  applied_target_version bigint,
  result_ref uuid,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  CONSTRAINT approval_applications_pkey PRIMARY KEY (id),
  CONSTRAINT approval_applications_request_id_key UNIQUE (request_id),
  CONSTRAINT approval_applications_command_receipt_id_key UNIQUE (command_receipt_id),
  CONSTRAINT approval_applications_ck_01 CHECK (applied_target_version IS NULL OR applied_target_version > 0),
  CONSTRAINT approval_applications_request_id_operation_id_fkey FOREIGN KEY (request_id,operation_id) REFERENCES app_private.approval_requests (id,operation_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_applications_receipt_chain_fkey FOREIGN KEY (command_receipt_id,operation_id,request_id) REFERENCES app_private.command_receipts (id,operation_id,request_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT approval_applications_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.approval_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.approval_applications FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.audit_events (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  actor_id uuid NOT NULL,
  actor_kind text NOT NULL,
  auth_subject_snapshot uuid,
  outcome text NOT NULL,
  reason text,
  authority_evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
  target_version bigint,
  event_type text NOT NULL,
  target_kind text NOT NULL,
  target_ref uuid,
  campus_id uuid,
  command_receipt_id uuid,
  approval_request_id uuid,
  source_kind text NOT NULL,
  correlation_id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  occurred_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  CONSTRAINT audit_events_pkey PRIMARY KEY (id),
  CONSTRAINT audit_events_ck_01 CHECK (length(btrim(event_type)) > 0),
  CONSTRAINT audit_events_ck_02 CHECK (length(btrim(target_kind)) > 0),
  CONSTRAINT audit_events_ck_03 CHECK (length(btrim(outcome)) > 0),
  CONSTRAINT audit_events_ck_04 CHECK (source_kind IN ('API', 'WORKER', 'AUTH_RECONCILIATION', 'DEPLOYMENT')),
  CONSTRAINT audit_events_ck_05 CHECK (jsonb_typeof(details) = 'object'),
  CONSTRAINT audit_events_ck_06 CHECK (jsonb_typeof(authority_evidence) = 'object'),
  CONSTRAINT audit_events_ck_07 CHECK (actor_kind IN ('INDIVIDUAL', 'FAMILY', 'SYSTEM')),
  CONSTRAINT audit_events_ck_08 CHECK (target_version IS NULL OR target_version > 0),
  CONSTRAINT audit_events_actor_id_actor_kind_fkey FOREIGN KEY (actor_id,actor_kind) REFERENCES app_private.principals (id,kind) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT audit_events_campus_id_fkey FOREIGN KEY (campus_id) REFERENCES app.campuses (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT audit_events_command_receipt_id_fkey FOREIGN KEY (command_receipt_id) REFERENCES app_private.command_receipts (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT audit_events_approval_request_id_fkey FOREIGN KEY (approval_request_id) REFERENCES app_private.approval_requests (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT audit_events_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.audit_events FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.outbox_events (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  event_type text NOT NULL,
  schema_version integer NOT NULL DEFAULT 1,
  aggregate_kind text NOT NULL,
  causation_event_id uuid,
  aggregate_ref uuid NOT NULL,
  aggregate_version bigint NOT NULL,
  command_receipt_id uuid NOT NULL,
  event_ordinal integer NOT NULL,
  correlation_id uuid NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  CONSTRAINT outbox_events_pkey PRIMARY KEY (id),
  CONSTRAINT outbox_events_command_receipt_id_event_ordinal_key UNIQUE (command_receipt_id,event_ordinal),
  CONSTRAINT outbox_events_ck_01 CHECK (schema_version > 0),
  CONSTRAINT outbox_events_ck_02 CHECK (aggregate_version > 0),
  CONSTRAINT outbox_events_ck_03 CHECK (event_ordinal > 0),
  CONSTRAINT outbox_events_ck_04 CHECK (length(btrim(event_type)) > 0),
  CONSTRAINT outbox_events_ck_05 CHECK (length(btrim(aggregate_kind)) > 0),
  CONSTRAINT outbox_events_ck_06 CHECK (jsonb_typeof(payload) = 'object'),
  CONSTRAINT outbox_events_ck_07 CHECK (causation_event_id IS NULL OR causation_event_id <> id),
  CONSTRAINT outbox_events_causation_event_id_fkey FOREIGN KEY (causation_event_id) REFERENCES app_private.outbox_events (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT outbox_events_command_receipt_id_fkey FOREIGN KEY (command_receipt_id) REFERENCES app_private.command_receipts (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT outbox_events_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.outbox_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.outbox_events FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.event_consumer_deliveries (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  event_id uuid NOT NULL,
  consumer_key text NOT NULL,
  state text NOT NULL DEFAULT 'PENDING',
  attempt_count integer NOT NULL DEFAULT 0,
  next_attempt_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  lease_token uuid,
  lease_until timestamptz,
  last_error_code text,
  delivered_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT event_consumer_deliveries_pkey PRIMARY KEY (id),
  CONSTRAINT event_consumer_deliveries_event_id_consumer_key_key UNIQUE (event_id,consumer_key),
  CONSTRAINT event_consumer_deliveries_ck_01 CHECK (length(btrim(consumer_key)) > 0),
  CONSTRAINT event_consumer_deliveries_ck_02 CHECK (attempt_count >= 0),
  CONSTRAINT event_consumer_deliveries_ck_03 CHECK (state IN ('PENDING', 'LEASED', 'RETRY', 'DELIVERED', 'DEAD')),
  CONSTRAINT event_consumer_deliveries_ck_04 CHECK ((lease_token IS NOT NULL) = (state = 'LEASED')),
  CONSTRAINT event_consumer_deliveries_ck_05 CHECK ((lease_until IS NOT NULL) = (state = 'LEASED')),
  CONSTRAINT event_consumer_deliveries_ck_06 CHECK ((delivered_at IS NOT NULL) = (state = 'DELIVERED')),
  CONSTRAINT event_consumer_deliveries_ck_07 CHECK (row_version > 0),
  CONSTRAINT event_consumer_deliveries_event_id_fkey FOREIGN KEY (event_id) REFERENCES app_private.outbox_events (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT event_consumer_deliveries_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.event_consumer_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.event_consumer_deliveries FORCE ROW LEVEL SECURITY;

CREATE TABLE app.notifications (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  recipient_id uuid NOT NULL,
  recipient_kind text NOT NULL,
  event_id uuid NOT NULL,
  category_code text NOT NULL,
  context_key text NOT NULL,
  summary jsonb NOT NULL,
  read_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_event_recipient_context_category_key UNIQUE (event_id,recipient_id,context_key,category_code),
  CONSTRAINT notifications_id_recipient_id_key UNIQUE (id,recipient_id),
  CONSTRAINT notifications_ck_01 CHECK (recipient_kind IN ('INDIVIDUAL', 'FAMILY')),
  CONSTRAINT notifications_ck_02 CHECK (length(btrim(category_code)) > 0),
  CONSTRAINT notifications_ck_03 CHECK (length(btrim(context_key)) > 0),
  CONSTRAINT notifications_ck_04 CHECK (jsonb_typeof(summary) = 'object'),
  CONSTRAINT notifications_ck_05 CHECK (row_version > 0),
  CONSTRAINT notifications_recipient_id_recipient_kind_fkey FOREIGN KEY (recipient_id,recipient_kind) REFERENCES app_private.principals (id,kind) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT notifications_event_id_fkey FOREIGN KEY (event_id) REFERENCES app_private.outbox_events (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT notifications_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.notifications FORCE ROW LEVEL SECURITY;

CREATE TABLE app.notification_preferences (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  principal_id uuid NOT NULL,
  category_code text NOT NULL,
  channel_code text NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  quiet_hours jsonb,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  row_version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  CONSTRAINT notification_preferences_pkey PRIMARY KEY (id),
  CONSTRAINT notification_preferences_principal_category_channel_key UNIQUE (principal_id,category_code,channel_code),
  CONSTRAINT notification_preferences_ck_01 CHECK (length(btrim(category_code)) > 0),
  CONSTRAINT notification_preferences_ck_02 CHECK (channel_code = 'IN_APP'),
  CONSTRAINT notification_preferences_ck_03 CHECK (quiet_hours IS NULL),
  CONSTRAINT notification_preferences_ck_04 CHECK (row_version > 0),
  CONSTRAINT notification_preferences_principal_id_fkey FOREIGN KEY (principal_id) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT notification_preferences_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.notification_preferences FORCE ROW LEVEL SECURITY;

CREATE TABLE app_private.setting_revisions (
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  setting_key text NOT NULL,
  campus_id uuid,
  revision integer NOT NULL,
  value_schema_version integer NOT NULL DEFAULT 1,
  value jsonb NOT NULL,
  effective_from timestamptz NOT NULL,
  supersedes_id uuid,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  created_by uuid NOT NULL,
  CONSTRAINT setting_revisions_pkey PRIMARY KEY (id),
  CONSTRAINT setting_revisions_ck_01 CHECK (length(btrim(setting_key)) > 0),
  CONSTRAINT setting_revisions_ck_02 CHECK (revision > 0),
  CONSTRAINT setting_revisions_ck_03 CHECK (value_schema_version > 0),
  CONSTRAINT setting_revisions_ck_04 CHECK (jsonb_typeof(value) = 'object'),
  CONSTRAINT setting_revisions_ck_05 CHECK (supersedes_id IS NULL OR supersedes_id <> id),
  CONSTRAINT setting_revisions_campus_id_fkey FOREIGN KEY (campus_id) REFERENCES app.campuses (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT setting_revisions_supersedes_id_fkey FOREIGN KEY (supersedes_id) REFERENCES app_private.setting_revisions (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT setting_revisions_created_by_fkey FOREIGN KEY (created_by) REFERENCES app_private.principals (id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
ALTER TABLE app_private.setting_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.setting_revisions FORCE ROW LEVEL SECURITY;

RESET ROLE;
