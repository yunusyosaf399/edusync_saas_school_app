# 01 - Identity and Authentication Model

**Status:** PROPOSED technical model, 2026-09-22. Product rules labelled CONFIRMED are existing requirements. No Auth configuration or account creation is performed.  
**Sources:** [AGENTS.md](../../AGENTS.md), [project context](../../CODEX_PROJECT_CONTEXT.md), [master specification](../requirements/School_OS_SaaS_Master_Specification_v0.2.md) sections 10-16, 55, 58 and 76.

## 1. Four separate concepts

| Concept | Meaning | Proposed cardinality |
|---|---|---|
| Person | A human identity independent of employment, student enrollment and login. May exist without credentials. | One person can participate in multiple later domain roles. |
| Supabase Auth user | Managed credential/session identity inside one school's project. | At most one live application-principal binding per Auth user. |
| Application principal | Stable accountable actor for an account or a specifically identified system process; survives credential retirement. | One active Auth binding per ACCOUNT principal; SYSTEM principals have no interactive Auth binding. |
| Access context | The verified capacity in which a principal acts: individual staff/student, shared family, or constrained system execution. | One active server-validated context per command; switching dashboards alone grants nothing. |

An account profile is part of the proposed principal concept, not a second copy of passwords or the full person record. A person may have several historical account associations; PROPOSED default is one active individual account per person. Duplicate/merged identities require controlled review (T03), not email/name matching.

The [entity map](../database/02_foundation_entity_map.md) describes F05-F08. Employee, student, family and guardian relationship records are postponed; they will reference these foundations.

## 2. Confirmed account behavior

- One person/account may have multiple application roles, including teacher and parent.
- Parent access uses one shared family login for its linked children. Separate father/mother credentials are not required by this design.
- Student and employee records can exist before a login is activated.
- An internal person UUID, Auth UUID and school-visible number have different meanings.
- An account's role does not imply access to every person, campus or record.

Parent permissions resolve current approved family-child links in the later Student & Family domain. The principal foundation reserves that contract but does not fabricate family/student entities or return any child before those links exist. Relationship labels such as father/mother/guardian describe the family situation; they are not verified proof of which adult used a shared login.

## 3. Shared family login and staff privileges: explicit unresolved boundary

CONFIRMED shared credentials limit individual attribution. Merely linking a family account to a teacher's Person record must not cause every adult using that password to inherit teaching, salary or approval permissions.

PROPOSED safeguard (P04 in [ADR-001](../decisions/ADR-001-foundation-database-principles.md)): permissions on the same account are evaluated within a verified context. A shared-family session can use only FAMILY-context grants. An individual staff context requires separate, nonshared proof of the associated person, validated server-side and bound to that session/command. The UI cannot assert this context, and an ordinary shared credential refresh cannot mint staff authority.

**TBD T01:** choose and validate that proof, enrollment/recovery process, assurance lifetime and how it is enforced through both direct data access and command APIs. A person-bound factor or equivalent stronger reauthentication is a candidate, not a selected technology. Generic MFA does not solve the problem if its factor is shared. Until T01 is accepted and tested, do not activate privileged staff grants on a shared-family credential.

This preserves the requirement for a multi-role account while exposing the unresolved security mechanics. Requiring separate parent logins would change the product baseline and is not silently adopted. Audits in family context identify the account/family; staff context can identify a person only to the extent of the verified proof.

## 4. School routing and authentication

PROPOSED sequence:

1. Resolve a school code using minimal control-plane routing data.
2. Use only that school's trusted project endpoint and permitted public client configuration.
3. Authenticate through Supabase Auth with email/password or a future protected username flow.
4. Map the verified school-project Auth subject to an active principal.
5. Resolve allowed context, current assignments and school/module state; then authorize the requested action.
6. Keep tokens, caches and subscriptions separated when changing school or account. Do not trust a user-supplied project URL as authoritative routing.

Cross-school UUID coincidence does not make an account portable between projects. School operators and SaaS platform operators are different authorities; control-plane login is not automatic school-record access.

Email and admin-created username login are CONFIRMED; the alias mechanism is **TBD T03**. PROPOSED option: a protected server endpoint resolves a normalized school-local alias internally and invokes the supported Auth flow without returning the mapped email or granting alias-table reads. Apply generic failure messages, rate limiting and protected recovery. A synthetic internal email is an alternative with recovery/delivery consequences. No public alias lookup, password copy, invented Auth schema extension or username-as-authorization rule is permitted.

F08 is a conditional foundation candidate: the final alias entity is selected only after this flow is designed. Exact case folding, Unicode/confusable rules and alias reuse remain TBD.

## 5. Provisioning and account lifecycle

PROPOSED lifecycle: pending -> active -> suspended -> retired. Activation requires a verified principal binding, valid context and reviewed grants. Creating an Auth account does not grant a role, create a student or activate family access. Self-service signup policy remains TBD; unprovisioned subjects fail closed.

Auth provisioning and application provisioning are separate service operations. Use a recoverable/idempotent process with a pending state; do not expose partial accounts. A reconciliation task detects Auth users lacking an application binding and bindings referencing missing credentials.

Suspension immediately blocks application authorization using server-side principal/grant state, then follows the chosen Auth/session revocation procedure. Retiring credentials preserves Person, principal, grants' history, reviews and audit evidence. Proposed live FK behavior clears the current Auth reference without deleting the principal; binding-change history retains minimal identifiers and reason. Recovery/relinking does not silently reactivate old staff/family grants and must verify ownership.

Supabase Auth references should use the managed user's primary key. Previously issued JWTs may remain usable until expiry even after user deletion; application deactivation therefore cannot rely only on removing credentials. [Supabase user management](https://supabase.com/docs/guides/auth/managing-user-data). Exact session-revocation checks and key lifecycle are T04.

## 6. Authorization source and privileged execution

Resolve current roles, scopes, assignment dates and context from controlled records. Client-editable profile/JWT metadata is not authority. JWT-held membership can be stale; security-critical commands must consult current server state. [Supabase RLS guidance](https://supabase.com/docs/guides/database/postgres/row-level-security).

An ACCOUNT principal is the initiating actor. A background job is a distinct SYSTEM executor with an allowlisted purpose, minimum permissions, and causation reference. For an approval application, the job checks the still-valid request and policy; it does not inherit an unrestricted role from its credential. Recheck required approver authority and target validity at application time as specified in [workflow design](../workflows/01_approval_engine_design.md).

Credential material, SMTP/app passwords and provider secrets do not belong in profiles, JSON settings, logs or Flutter. Break-glass/platform maintenance is separately constrained and auditable, not a hidden “Super Admin ignores checks” branch.

## 7. Attribution, privacy and verification

Record principal, verified context, optional proven person, executor and initiated-by principal separately. Session/device labels are corroborating metadata, not evidence of a specific adult using shared credentials. Keep enough identity anchors for history while leaving retention/anonymization policy unresolved (T10).

Required checks include shared-family attempts at staff escalation, teacher-plus-parent context isolation, suspended users with still-valid tokens, missing bindings, deprovisioning without history loss, cross-school routing/caches, alias enumeration and Auth-provisioning failure. See [test strategy](../testing/01_foundation_test_strategy.md) and [RBAC model](02_rbac_permission_scope_model.md).

