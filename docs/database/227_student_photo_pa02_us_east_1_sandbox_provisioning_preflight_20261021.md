# Student Photo PA-02 — U.S. Supabase sandbox preflight and conditional execution runbook

**Prepared:** 2026-10-21  
**Gate:** **PREPROVISIONING READ-ONLY AUDIT COMPLETE; LIVE SANDBOX PROVISIONING BLOCKED PENDING R2–R6 SECURITY / COST SIGNOFF**  
**Scope:** PA-01/PA-02 *synthetic-only* real-provider acceptance rehearsal. No Student data, application rollout, IAM changes, SQL activation or production authorization.  
**PR:** #120 (draft, documentation only).  
**Inputs:** [owner's US-first choice and regional review](226_student_photo_pa02_region_sandbox_approval_and_residency_review_20261021.md), [private location and negative checks](225_student_photo_supabase_storage_sandbox_isolation_contract_20261021.md), [PA gates](222_student_photo_pa01_pa08_owner_security_decision_packet_20261020.md), [test matrix](223_student_photo_provider_activation_dependency_and_test_matrix_20261020.md), [provider selection](224_student_photo_pa01_provider_selection_evidence_and_sandbox_gate_20261020.md), [ADR-003](../decisions/ADR-003-provider-neutral-object-storage.md).


## 0A. Superseding connected-account verification — 2026-10-21

**Current designated account/organization:** the user connected a separate **SchoolAgent** Supabase account, confirmed that its organization was formerly named **Ilmora**, and renamed that organization to **SchoolAgent**. A subsequent authorized read-only check verifies the organization displays **SchoolAgent** and is on the **Free** plan. The provider's **actual organization-scoped project price quote is $0/month** for the proposed new project, subject to the account's eligibility and no paid add-ons, plan upgrades, or quota changes. A quote is not a deployed project.

One pre-existing **inactive** project is visible in this SchoolAgent organization, with its primary region **`ap-northeast-2` (Seoul, South Korea)**. Its name and identifiers are intentionally excluded from public operational evidence. This pre-existing project is **not** the dedicated U.S. lab and **must not be reused, resumed, transferred or modified** under this PA-02 task.

**Supersession:** Section 1's `ap-southeast-2` inventory and Section 1A's unknown-organization/unknown-quote observations describe the *earlier* Supabase connection and must **not** be used as current target selection or cost evidence. The SchoolAgent organization identity and $0/month quote are now verified. The owner has not yet explicitly authorized **creation** of the new disposable project, and independent security approval for any bucket, credential, policy or real-provider tests remains open. **No create_project call, purchase, migration, Storage policy change, image upload or production endpoint activation has occurred.**

**Next controlled action:** request confirmation to create **one new** `edusync-pa02-photo-synthetic-lab` project in SchoolAgent, **`us-east-1`**, conditioned on the quote remaining **$0/month** and without any paid options. The provider could still reject creation due to quota or account policy. Once provisioned, keep Storage buckets and IAM unconfigured until separately reviewed and authorized; the project itself is not evidence of PA-01/02 PASS.

## 1. Verified account and repository preflight — READ ONLY

| Observation | Evidence on 2026-10-21 | Disposition |
|---|---|---|
| Owner's provider and country preference | Supabase Storage first; any supported hosting country acceptable, **United States preferred** | **RECORDED OWNER PREFERENCE** (not production signoff) |
| First specific-region candidate | `us-east-1` (Northern Virginia, United States); `us-east-2` (Ohio) backup | **ENGINEERING RECOMMENDATION**, confirm project-creation selector/availability before provisioning |
| Supabase account inventory | One visible preexisting project, status **INACTIVE**, primary region `ap-southeast-2` (Sydney); project/org identifiers intentionally withheld | **DO NOT REUSE**, modify, resume or transfer existing project; it is not the approved U.S. disposable PA-02 lab |
| Distinct U.S. PA-02 project | No dedicated U.S. synthetic-only project was visible in this read-only inventory | **NOT PROVISIONED**; no project ID or credentials assumed |
| GitHub branch/head at preflight | PR #120, `b21ded62e84f84d03803970cf67335df6afebd43`; base `main` `df1c98d5c2d19424946986fc6ba7615202b0a443` | Draft and mergeable as of inspection; recheck exact heads before later execution |
| Existing acceptance evidence | #104/#105 mock provider and DB receipts; #223/#225 test specifications | **NOT real Supabase Storage bytes, private IAM or immutable seal proof** |

The preexisting project's **name, organization and identifying references are intentionally withheld** from this public operational decision record. No project reference, organization ID, endpoint, access key, private URL or file path is published. The account inventory is a point-in-time read; a fresh nonmutating inventory is required before any further step.

The initial PA-02 sandbox must be a **different, disposable project** for exactly one simulated School, with generated **nonpersonal** fixtures and no connection to production systems. The existing School project and databases remain out of scope.

## 1A. Confirmed Free-plan eligibility and billing boundary — 2026-10-21 (read-only)

The connected Supabase organization currently reports **plan = `free`**. The project inventory still exposes **one preexisting inactive project**, and no dedicated U.S. sandbox project. This is a point-in-time *read-only* inventory, not confirmation of the organization's available project slot or permission to use a particular org for this lab.

According to Supabase's current [billing guide](https://supabase.com/docs/guides/platform/billing-on-supabase#free-plan) and [billing FAQ](https://supabase.com/docs/guides/platform/billing-faq), Free accounts are permitted **two active Free projects** subject to account-wide Owner/Admin membership quota; *paused* projects do not count. The provider's project inventory state **INACTIVE** is not enough by itself to establish whether the existing project counts as *paused* for quota purposes. Check the provider's real project creation decision/quoted price instead of assuming an open slot. `Free` does not establish a contractual forever-zero-cost commitment and is not permission to upgrade to Pro or enable billed add-ons.

Cost caveat: [Supabase cost controls](https://supabase.com/docs/guides/platform/cost-control) says its spend-cap feature applies to **Pro**, only protects certain usage items, and [compute billing](https://supabase.com/docs/guides/platform/manage-your-usage/compute) says compute hours are **not** covered by the Spend Cap on paid plans. A no-charge sandbox therefore requires an actual project price of **$0** as quoted for the chosen organization, no paid add-ons, no implicit plan upgrade, and no purchases. A nonzero quote or capacity limitation triggers **STOP / user approval required**; the owner must see and explicitly accept the amount/recurrence, with no assistant-selected budget.

**Unresolved organization/creation authorization:** Although one organization is visible, the owner has **not explicitly designated which organization should own the disposable sandbox**. The Supabase project-creation workflow requires this designation separately from general U.S.-hosting preference. Consequently **DO NOT call create_project** until the owner chooses the organization and the provider's cost-confirmation conditions are satisfied. An independent security approver must separately sign off on R3/R4/R6 private Storage, credentials, retention, and test-lab isolation before any bucket or secret is provisioned. `us-east-1` remains recommended, not an account-verified completed action.

### Deterministic account and cost decision

| Condition in selected account | Allowed response | Disallowed shortcut |
|---|---|---|
| Named organization explicitly selected by owner, price quoted **$0**, free project capacity confirmed | May *separately* request authorization for a disposable **synthetic-only** project in a specific U.S. region; provider may still require interactive confirmation | Reuse preexisting School project; assume INACTIVE = paused |
| Provider requires a plan upgrade or quotes **more than $0** | **STOP**; report amount and billing recurrence and obtain explicit user acceptance | Guess a spending cap or silently upgrade plan |
| Owner's exact organization / project jurisdiction or independent reviewer unspecified | Remain at nonmutating PA-02 preflight | Treat “complete next task” as automatic payer/security approval |
| Project created after required authorizations | Track creation status and exact chosen region in restricted evidence; private Storage remains gated on separate IAM review | Claim PA-02 security acceptance or activate Student Photo uploads |

No live project price was obtained during this review, since the organization-choice gate has not been met. Published pricing/quotas are *not* a per-organization quote.

## 2. Provisioning target — NOT YET AN APPROVED LIVE CHANGE

| Parameter | Proposed value | Pre-write gate |
|---|---|---|
| Provider | Supabase Storage candidate via provider-neutral adapter | PA-01 independent trial approval still open |
| Project type | Separate disposable **nonproduction**, synthetic-only project | Product/infra owner signs account/project and spending limit |
| Primary region | **`us-east-1`** preferred; **`us-east-2`** fallback | Specific code appears for selected account at creation time; reviewer confirms region; product approves actual region |
| Suggested human label | `edusync-pa02-photo-synthetic-lab` | Name provisional; no actual identifier/slug created |
| Logical locations | Deployment-owned versioned allowlist | Security reviews mapping and immutable key/version strategy; never user-supplied |
| Storage zones | Two **private** candidate zones: stage and sealed/final | Names/mapping/privilege design to be independently reviewed; no public flag |
| Test fixtures | Synthetic, generated, nonpersonal image and corrupted-byte cases only | No real Student, family, employee, school or copied user photos |
| Size invariant | **1–1,048,576 measured final bytes inclusive** | Read back persisted content; cannot trust client declared size/content type |
| Key custody | Approved secret manager / backend-only sandbox identities | No credentials in app/Flutter/PR/repo, database fields, CI logs or public test outputs |
| Duration, teardown | Owner-set bounded lifetime, spending ceiling, incident stop and evidence retention | PA-02-R6 still OPEN; no invented default or auto-destruction of held evidence |
| App runtime | **Disconnected** from production app and F23/Photo SET | Migration 10 stays `.sql.draft`; purpose/upload/SET stay DENY |

**Why two private zones?** Stage handles temporary creation; final handles **reviewed sealed bytes**. This is only a candidate decomposition: Supabase Storage does not promise immutable sealed bytes merely because `upsert:false` or RLS is configured. A service role can bypass RLS, and effective worker privileges, MOVE/COPY/DELETE, replacement, signed tokens, stale writes and read-back must all be exercised. If final immutability cannot be established against *all effective principals* without unacceptable exceptions, halt and return to PA-01 provider/architecture selection.

## 3. Security approval ledger — fail closed

| ID | Missing approval / proof | Required independent evidence | Current disposition |
|---|---|---|---|
| R1 | Owner geographic preference | Supabase-supported country; US preferred | **RECORDED**; customer-specific privacy/law still separate |
| R2 | Dedicated lab authorization and cost owner | Approved nonproduction project, payer and spending ceiling; no reuse of existing project | **BLOCKED** |
| R3 | Exact region and private physical mappings | Approved `us-east-1` or fallback for the actual account, exact private stage/final architecture and stable deployment mapping | **BLOCKED** |
| R4 | Operator permissions and secrets | Named independent security reviewer, separation of roles, service-key bypass risk/compensating measures, secret storage/rotation and redacted IAM policy review | **BLOCKED** |
| R5 | SDK/API and immutable-final provider proof | Versioned real-provider run with negative races, current credential behavior and stored-byte SHA-256 attestations | **NOT TESTED** |
| R6 | Teardown, hold and incident bounds | Explicit budget cap, expiration, stop switch, account owner, retention authority, redacted immutable evidence location | **BLOCKED** |

**No-go rule:** A message saying “complete next task”, agreement with the region, an account connection, a green mock workflow, or a draft PR does **not** fill an independent security signature or approve incurring a cost. Do not invoke Supabase project creation, make buckets, generate privileged keys or modify a configured School until R2–R4 and R6 signoff is independently recorded. R5 necessarily awaits the authorized lab run. Never manufacture a reviewer identity or approval.

## 4. Ordered execution playbook (only AFTER the signoffs above)

The steps below are *conditional instructions*, not work performed. Use the Supabase dashboard/management API and versioned SDK documented on the day of execution; check `supabase --help` before CLI use. Do not hard-code a mutable release command here.

1. **Reinspect:** Confirm current GitHub branch/base, live project inventory, Supabase region catalog, organization quota/billing, and product/security signatures. Reject existing-project reuse.
2. **Allocate:** Provision one new, isolated U.S.-region project **only after** account/payment ownership and spending authorization. Record project ref in **restricted operations evidence**, not public GitHub.
3. **Contain:** Create only independently approved **private** stage/final buckets and least-privilege access policies. Lock bucket privacy and write operations; deny public access; keep clients unconnected. Record policy fingerprints and reviewer identity *without secrets*.
4. **Bind:** Validate exact current School simulator→project→allowed logical location→private bucket mapping version. Use server-issued UUID/file keys only. Forbid client-selected target/project/bucket/key.
5. **Test:** Run the version-pinned synthetic negative and concurrency matrix in §5 with independent observer and test evidence. Never connect live Student/Enrollment rows. If an expected denial succeeds, freeze credentials and mark **STOP**.
6. **Verify:** Read back independently authorized stored *synthetic* bytes and hash/measure final content; reject mismatched digest/size, unverified source, mutated final version or replay. Confirm no permanent public URLs or leaked bearer.
7. **Recover:** Inject timeouts, duplicate requests, lost acknowledgements and worker restarts; reconcile by trusted identity, no blind overwrite or optimistic AVAILABLE metadata.
8. **Close:** Independently check private-bucket/policy drift, any privileged bypass, exact SDK version, logs, leaks, signed token lifetimes and evidence holds. Archive only **redacted** artifacts with test run/commit IDs.
9. **Decide:** Product + independent security review results. **A sandbox PA-01/PA-02 PASS cannot activate PA-03..PA-08, F23, `STUDENT_PROFILE_PHOTO` or `student.photo.set`.** Production release requires separate subsequent review.
10. **Teardown:** Follow R6 retention/hold policy, revoke lab credentials and deallocate the *approved disposable* project with owner consent. No automatic delete of retained evidence or unowned account resources.

## 5. Executable-trial evidence contract (not a claim tests ran)

Test operator fills the following for **each** P02-01…P02-16 and P01-01…P01-12. A missing mandatory item = **NOT RUN**, not PASS.

| Evidence key | Required value (redacted only) |
|---|---|
| `case_id` | Stable case ID from #225/#224, plus exact variant (principal/action/concurrency) |
| `run_id` / `commit_sha` | Immutable test-run identifier and exact test harness commit |
| `region_code` / `mapping_rev` | Specific approved region and nonsecret deployment mapping revision |
| `provider_version` | Version-pinned API/SDK + policy fingerprint, never secret |
| `actor_role` | Role **classification** such as client, stage writer, worker, sealer, verifier, reconciler (no token/account identifiers) |
| `expected_result` | Explicit denial / conflict / exact result; include required unchanged sealed-byte identity |
| `observed_result` | Status/error category, redacted timing/sequence, number of successful concurrent creates |
| `content_evidence` | Synthetic fixture ID, actual server-measured final-byte length and SHA-256 (no raw personal data or URL) |
| `postcondition` | Final/private object unchanged or quarantined, no unauthorized AVAILABLE, no cross-project visibility |
| `review` | Independent reviewer decision and open issue; evidence retention/hold authority |

| Scenario group | Exact cases | Lab acceptance |
|---|---|---|
| Anonymous/public/private checks | P02-01, P02-09, P02-14 | Public access denied; no policy drift or leaked URL/key |
| Wrong School/Campus/key/provider | P02-02, P02-03, P02-13 | Foreign selection denied with canonical deployment mapping |
| Same-key and seal replacement | P02-04..P02-08 | Concurrent create result bounded; **no** reachable route can change final bytes |
| Verify and uncertain result | P02-10, P02-11, P02-15 | Actual byte read-back wins over ACK/ETag; uncertain bytes private |
| Revocation and retention | P02-12, P02-16 | Stale authority denied with synthetic current-state test; holds not purged |
| Provider-specific prerequisites | P01-01..P01-12 | Separate provider run required, never treated as mock pass |

The more extensive **live** Enrollment END / Campus Transfer / entitlement downgrade integration requires a later separately approved PA-05/PA-08 composed database environment; a disconnected PA-02 lab **must not falsely mark those integrated tests PASS**. If a test depends on that integration, record it as `DEFERRED — PA-05/PA-08`, while still testing the provider-only mock-injected denial component as appropriate.

### Trial record template (copy to an access-controlled evidence system, NOT public repository)

```yaml
run_id: null
github_commit_sha: null
supabase_region: us-east-1        # recommended, not proof of provisioning
project_identity_verified: false  # store reference separately in restricted controls
synthetic_fixtures_only: true
owner_project_cost_approval: null
independent_security_approval: null
credential_rotation_evidence: null
private_stage_policy_fingerprint: null
private_final_policy_fingerprint: null
provider_sdk_and_version: null
seal_replacement_test_passed: false
all_applicable_p01_p02_cases_passed: false
deferred_domain_cases: []
redacted_evidence_manifest_reference: null
release_state: BLOCKED
```

Any missing mandatory approval or test remains **BLOCKED**. Do not copy real credentials, endpoints, signed URLs, bearer tokens, private object paths or sensitive evidence into this template.

## 6. Noncollision / completion accounting

**Completed in this task:** inspected GitHub/main/PR state and linked Supabase project inventory without mutation; established that the only visible existing project is Australian and inactive, **not the U.S. lab**; pinned an operator-ready U.S. target, strict pre-provisioning checklist, IAM reviewer responsibilities, real-provider evidence contract and teardown plan.

**Not performed:** provisioning a U.S. Supabase project, incurring costs, activating another project, issuing credentials, changing bucket/policy permissions, uploading bytes, image decoding, SQL/Flutter changes, CI provider tests, DB-01/02/03/04 edits, migration 10 activation or Student Photo SET.

The next action after this document is **distinct product authorization of the lab's budget/account and independent security design review (R2–R4/R6)**. After approval, actual safe synthetic-only provider testing can begin; `PA-02` remains open until evidence is produced.
