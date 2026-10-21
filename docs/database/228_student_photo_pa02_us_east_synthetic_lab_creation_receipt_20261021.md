# Student Photo PA-02 — Approved dedicated U.S. Supabase project creation receipt

**Recorded:** 2026-10-21  
**Workstream:** Student Photo Storage PA-01/PA-02 — separate from DB-01 Roll, DB-02 policy, DB-03 Admissions, DB-04 Curriculum.  
**Classification:** Non-secret audit metadata only. **Storage IAM, buckets, image uploads, immutable final-byte proof and product activation NOT APPROVED / NOT PERFORMED.**

## Owner authorization and exact quote

- User approved creation of the **separate US-East, synthetic-only Free-plan test project** in the independently connected **SchoolAgent** Supabase organization after being shown Supabase's organization-scoped **$0/month** cost quote.
- Before creating, the live provider's `get_organization` confirmed **SchoolAgent** on the **Free** plan; `get_cost(type=project)` again returned **USD 0/month**.
- The first create request was rejected by Supabase's confirmation guard, which explicitly required `confirm_cost`. The recorded owner authorization covered the stated **$0/month**, so a zero-cost confirmation token was obtained and submitted through the provider connector; **no confirmation token or credential is stored here**.
- **No subscription upgrade or paid add-on** was requested.

## Post-creation read-only verification

| Property | Observed result |
|---|---|
| New dedicated project display name | `edusync-pa02-photo-synthetic-lab` |
| Owning organization | `SchoolAgent` |
| Primary region | `us-east-1` — United States (Northern Virginia) |
| Provider-reported new project status | `ACTIVE_HEALTHY` |
| New-project cost quotation | **$0/month**, as returned before creation |
| Existing project | Remains visible and `ACTIVE_HEALTHY` in its prior `ap-northeast-2` region; no action taken against it |
| Post-create project inventory | Exactly two visible projects (existing School staging + new synthetic photo lab) |
| Confirmation of created project | A separate `get_project` call returned the matching organization, project name, region and `ACTIVE_HEALTHY` state |
| Real images or Student data | **None uploaded or connected** |
| Storage buckets, IAM, SQL, signed tokens | **Not configured** |
| Project metadata secret handling | Account and project references omitted from public repo; controlled using authenticated Supabase connector |

**Provider status is an initial availability result, not a security acceptance test.** Region preference is satisfied for the *lab*, not automatically for each future School and its legal obligations. Real data and production services remain disconnected.

## Gate disposition following provisioning

| Gate | State |
|---|---|
| PA-02-R1 owner US-first provider geography | **Recorded** |
| PA-02-R2 designated separate Free-plan sandbox, owner creation and cost authorization | **Completed for dedicated US-East project creation ONLY** |
| PA-02-R3 private stage/final bucket names, deployment mapping and immutable seal controls | **OPEN: requires independent design approval** |
| PA-02-R4 backend-only role/credential separation, secret custody, IAM review | **OPEN: requires independent security approval** |
| PA-02-R5 read-back, privileged replacement, concurrent-create and revocation real-provider evidence | **NOT RUN** |
| PA-02-R6 retention, incident stop, test duration and controlled teardown | **OPEN: independent approval** |

## Next allowed activity and stops

1. Perform **read-only inspection** of the new project, its region, supported Storage features, default bucket inventory, and existing Storage policies.
2. Create a reviewed **proposed** IAM/bucket configuration and independent test/hardening checklist. No live buckets, broad Storage policies, keys, or user uploads until R3/R4/R6 receive an actual security-reviewed authorization.
3. Keep synthetic-only fixture boundaries; no School Principal, Student, Campus, Enrollment or F23 records. Do not insert F23 AVAILABLE, enable `STUDENT_PROFILE_PHOTO`/Photo SET or execute D1 Migration 10.
4. Once an authorized sandbox Storage test is run, collect provider-measured evidence for all applicable P01/P02 tests, not simulated PASS. Failure to ensure immutable sealed bytes against all effective trusted and client identities is **STOP**; retain provider-neutral ADR-003.

**Project creation completed; Student Photo activation remains DENY.**  
Companions: [#227 US sandbox preflight](227_student_photo_pa02_us_east_1_sandbox_provisioning_preflight_20261021.md), [#226 region/approval record](226_student_photo_pa02_region_sandbox_approval_and_residency_review_20261021.md), [#225 Supabase private Storage isolation](225_student_photo_supabase_storage_sandbox_isolation_contract_20261021.md).
