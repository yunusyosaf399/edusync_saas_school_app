# DB03 S1 — inactive policy-draft schema candidate

**Source implementation: first bounded DB03 schema candidate, 26 October 2026.** This is a new isolated proposal, not an executable migration or a completed Admissions workflow. The latest [three owner choices](db03_owner_decisions_identity_drafts_publication_20261026.md) are recorded separately from code acceptance.

## What this increment implements

`supabase/proposals/db03/01_policy_draft_schema.sql.draft` creates four of the already proposed DB03 relations: numbering profiles #01, policy versions #04, policy stages #05 and document requirements #16. It implements their concrete PK/UQ/FK/RESTRICT constraints, required field checks, typed application/admission profile references, exact DOCUMENT_VERIFICATION parent requirement, immutable structural identity and server-maintained row versions through the existing frozen Foundation trigger.

Every relation is owned by `schoolos_schema_owner`, ENABLE+FORCE RLS, with only an internal schema-owner policy and explicit revocation of client raw privileges. The single new private trigger is SECURITY INVOKER, fixed `pg_catalog,pg_temp`, not a privileged dispatcher, with PUBLIC/anon/authenticated/service-role EXECUTE revoked. No application endpoint, role, grant, permission catalog or operation is added. Ordinary draft edits retain structural keys and advance server versions; draft DELETE is denied.

Profile prefix, separator, session format, digit width and positive start are explicit configuration fields; no real School's prefix or numbering profile is seeded. Sequence width is 1–8 digits, start must fit, and a policy must bind APPLICATION and ADMISSION profiles from its exact School. Stage kinds use the existing five-kind design vocabulary. Document categories are stored only as inactive draft configuration, not treated as verified/approved file purposes or an operative document registry.

**Both profile and policy state are constrained to DRAFT.** There is no published/effective policy, public writer or route for this candidate to become operative. Publication metadata/lifecycle, immutable published snapshots, contiguous publish roster, exact permissions, type registrars and the newly selected immediate-publication command belong to the next protected-publication increment. This deliberately prevents incomplete publication guards or unresolved format choices from creating accepted admission rules.

Number series #02 and allocation ledger #03 are not created; no counter or permanent number can be issued. Application/identity/transition tables and commands, the newly allowed unresolved-draft withdrawal, actual single-staff identity verification, documents/file upload, assessment/independent test skip, Finance clearance, READY handoff and D1 Student creation remain separate. No missing parent is replaced by an unchecked UUID or placeholder table. The accepted P1/P2 parent-key preflight still governs those later references.

## Actual verification boundary

The isolated [DB03 workflow](../../.github/workflows/db03-policy-draft-candidate.yml) checks the exact candidate head and uses dependency commit `06c2be2412e1699f3fa8f2804969e9808eb16e09` solely for the already accepted disposable Supabase stack harness and frozen Foundation. It validates all nine Foundation migration hashes and the local CLI/image pin; it does not apply that dependency's D1 draft chain. The new workflow, runner and SQL tests are DB03-only additions; existing Foundation/D1 CI files, registries, migration files and acceptance manifests are unchanged.

The runner is restricted to GitHub disposable CI, rejects an already-running stack, resets only the fixed local project and always stops the stack. There is no hosted connection or deployment code. It first checks the real frozen Foundation catalog, injects a failure after all four candidate tables/function are created inside one transaction and proves they are absent on reconnection, then commits the same candidate locally and runs 40 pgTAP structural/ACL assertions. The test fixture rolls back; it is a synthetic schema-owner fixture, **not** a genuine authenticated Admissions business command.

The 40 cases cover table ownership/RLS, denied client privileges/private trigger call, RESTRICT foreign keys, format bounds and row versions, denied publication, typed profile ancestry, policy/stage/document uniqueness and exact document-stage linkage, structural key immutability, raw authenticated/service-role denials, zero command registration/business receipts and no DB03 public API. They do not claim concurrency/publication/Person/Finance/Student acceptance. SCHEMA-03's planned K01–K28 and R01–R06 remain a separate future catalogue; this candidate does not mark them all passed.

Source checks and compilation are run locally; actual PostgreSQL runtime status, exact tested SHA and workflow link are recorded in PR #102 only after the workflow finishes. A prepared test is not a pass. Failure-injected local installation rollback is not a populated Foundation→D1 upgrade or post-commit backup restore and does not close G06.

## Plain example of the next working behavior

This slice is the empty filing structure in which the school will prepare rules such as “Grade 1 needs a birth certificate” and an application-number format such as `APP-2026-00001`. The example is illustrative, not a seeded School value. Staff cannot publish or use these drafts yet. Next, the protected policy writer must safely publish one complete version immediately, while older submitted applications keep their original version. Person verification and withdrawal follow in their own protected application commands.

**Release boundary:** proposal `.sql.draft` outside executable migrations; no hosted changes, main merge, permission enablement or production approval. P1 format/correction/retirement details and actual verifier/source, privacy, Finance and SC-06/D1 integration remain separately gated. Do not call this P1/P2 or full DB03 completion.
