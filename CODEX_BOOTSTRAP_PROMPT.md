# Codex Bootstrap Prompt

Use this when starting a new Codex chat/session in the School OS repository if Codex has not already loaded repository instructions:

> Read `AGENTS.md` and the linked project documentation before changing architecture or database schema. This is the School OS SaaS project. The authoritative requirements are in `docs/requirements/School_OS_SaaS_Master_Specification_v0.2.md`. Preserve the one-school-per-Supabase-project architecture, historical data rules, granular permission/scope model, approval/audit requirements, financial immutability, result locking/corrections, offline conflict handling, and future attendance capture adapter architecture. Do not implement deferred biometric/camera/RFID/GPS/WhatsApp/payment-gateway features unless specifically requested. For schema work, first propose entity boundaries, relationships, history, constraints, indexes, RLS, workflow/audit hooks, offline implications, and migration order before writing production SQL.
