> **Policy update, 26 October 2026:** The mandatory non-author mechanism in this historical packet is superseded for DB02 P03/G03 by [ADR-006](../decisions/ADR-006-db02-solo-maintainer-review.md). Use the [solo-maintainer technical review](db02_solo_maintainer_technical_review_20261026.md) and its owner-acceptance record. Source links/evidence below are retained; they are not independent approval.

# DB02 P03/G03 independent SQL/security review packet

Prepared 26 October 2026. **Status: READY FOR REVIEW; reviewer not identified; decision pending.** This packet is authored preparation, not a non-author review or approval. It updates the obsolete DIRECT/SUBMIT-only scope in issue #131 to the final composed implementation.

## Exact review target and eligibility

Review [PR #168](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/168), code commit `f472f2abf3303ffef10d4744a4dd6af5735acc5e`, tree `5b531865278bbb66b5b1c2fcbc022db9d95074a2`. The PR author is `yunusyosaf399`. An eligible reviewer must be an actual authorized non-author SQL/security reviewer; a different login alone does not establish independence or authority. Record who is reviewing and how their access/authority and non-author status were confirmed. Do not submit an approval under the author's account or treat another author's automated analysis as independent approval.

PR #122 (`df8caf9162d41d4eb4868b42abc582d042ec8441`) is a historical DIRECT/SUBMIT candidate. Its effect46 arm is not the final effective shared lookup. The current subject includes effect58 REVIEW/APPLY and effect61 Academic provisioning. A review restricted to #122 does not approve the complete #168 composition.

As observed on 26 October: PRs #122, #141, #164, #166 and #168 have no submitted reviews; #168 has no requested reviewer. Issue #131 is assigned to the author and names no eligible reviewer. The connector cannot enumerate repository collaborators through its approved Fetch endpoint. These observations establish that a reviewer has not been identified in accessible evidence; they do not establish that no eligible collaborator exists.

## Review map

### Shared receipt boundary

[20260928000000_domain_package_01_effect58_01_db02_review_apply_receipt_allowlist.sql.draft](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/f472f2abf3303ffef10d4744a4dd6af5735acc5e/supabase/migrations/20260928000000_domain_package_01_effect58_01_db02_review_apply_receipt_allowlist.sql.draft)

- [ ] Compare the entire final lookup with effect35_18 and intermediate effect46. Preserve earlier operation arms, verified actor, READ COMMITTED, Foundation SHARED auth lock, JCS/SHA-256, intent conflict and per-key lock. Accept only exact Roll Policy DIRECT/SUBMIT 12 slots, REVIEW 4 slots and APPLY 2 slots; reject unknown phases and malformed/null values. Confirm evidence-writer owner, fixed search path and private executor-only grants.

### Authenticated DIRECT

[20260928000000_domain_package_01_effect54_01_db02_authenticated_direct.sql.draft](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/f472f2abf3303ffef10d4744a4dd6af5735acc5e/supabase/migrations/20260928000000_domain_package_01_effect54_01_db02_authenticated_direct.sql.draft)

- [ ] Trace current verified Principal, School ALL scope, one server-selected global NULL-Campus P1 DIRECT UUID, today-only INIT/REPLACE, expected source and future commitment checks, atomic revision/pools/receipt/audit/outbox, then persisted replay proof. A client never selects authority or cutover date.

### Approval submission and checked read

[20260928000000_domain_package_01_effect55_03_db02_approval_submit.sql.draft](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/f472f2abf3303ffef10d4744a4dd6af5735acc5e/supabase/migrations/20260928000000_domain_package_01_effect55_03_db02_approval_submit.sql.draft)

- [ ] Trace PENDING submission with immutable source/P1/requester binding and distinct-Person reviewer selection. Confirm no policy/pool/event effect at SUBMIT or APPROVED. Inspect effect55_04 participant-only checked read and reason/receipt/audit/intent non-disclosure.

### Independent REVIEW and replay

[20260928000000_domain_package_01_effect58_04_db02_review_replay_entry.sql.draft](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/f472f2abf3303ffef10d4744a4dd6af5735acc5e/supabase/migrations/20260928000000_domain_package_01_effect58_04_db02_review_replay_entry.sql.draft)

- [ ] Trace APPROVE/REJECT with current independent reviewer role, School ALL scope, exact request version and global policy UUID. Verify immutable decision history and canonical replay with current authorization. No Student policy effect at REVIEW.

### Separately authorized APPLY

[20260928000000_domain_package_01_effect58_05_db02_apply_replay_entry.sql.draft](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/f472f2abf3303ffef10d4744a4dd6af5735acc5e/supabase/migrations/20260928000000_domain_package_01_effect58_05_db02_apply_replay_entry.sql.draft)

- [ ] Trace requester/reviewer authority and exact P1/source recheck after waits; one application or terminal INVALIDATED with no success effect. Verify persisted application, receipt, historical revision/pools, audit/transition and minimized outbox before replay.

### Academic pool hook

[20260928000000_domain_package_01_effect61_01_academic_roll_pool_hook.sql.draft](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/f472f2abf3303ffef10d4744a4dd6af5735acc5e/supabase/migrations/20260928000000_domain_package_01_effect61_01_academic_roll_pool_hook.sql.draft)

- [ ] Inspect PRELOCK/PROVISION inside protected Offering CREATE/UPDATE, School/policy/pool before academic ancestry, exact School-local revision and eligible parents, existing counter preservation and missing-counter provenance denial. Review the internal schema-owner date-resolver edge; clients gain no private execution or table access.

### Applied catalog/privacy audit

[101_db02_t08_privacy_acl_rls.sql](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/f472f2abf3303ffef10d4744a4dd6af5735acc5e/supabase/tests/domain/101_db02_t08_privacy_acl_rls.sql)

- [ ] Inspect actual owner, NOLOGIN/BYPASSRLS, search_path and effective grants on all 32 DB02 functions and five endpoints; forced RLS/raw read denial; participant/result minimization. These automated assertions support the independent review but do not constitute it.

### Pinned composition

[db02_g02_composition_manifest.json](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/f472f2abf3303ffef10d4744a4dd6af5735acc5e/supabase/config/db02_g02_composition_manifest.json)

- [ ] Check exact input SHAs, ordered 291-fragment digest, all 112 suite names/plans, final shared lookup and required runtime call list. Parent histories are both preserved; any source change requires renewed proof.

## Independent compatibility decisions

- [ ] DB01/Enrollment owner records whether the approved correction, retained policy and allocator behavior is compatible at this exact commit. REPLACE-first invalidates waiting correction APPLY; correction-first creates a today-effective Roll and blocks REPLACE. No silent rebasing of retained history.
- [ ] Academic/DB02 owner records acceptance of Offering pool eligibility, counter retention, rollback and both CREATE/REPLACE winner orders. Preserve current lock order and exact School ownership.
- [ ] Record findings with file/function, scenario, severity, requested change and regression expectation. A blocker stays open until fixed and independently rechecked at the new code commit.
- [ ] Keep installed DB03 Student-create/Finance and DB04 consumer handoffs outside this acceptance. Their design-only branches do not constitute positive installed runtime evidence.

## Existing author-side verification

At this exact code commit, all three workflows passed:

- [Static #40216318614](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/40216318614).
- [Foundation #40216318661](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/40216318661), 220/220.
- [D1 runtime #40216318627](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/40216318627), 112 suites / 4,292 assertions, all inherited DB01/DB02 races, two canonical cross-domain replay cases and both Academic Offering/REPLACE observed-lock cases.

Catalog: 291 inactive fragments, 599 functions / 581 definers / 167 app / 432 private, 34/34 forced RLS, zero forbidden private client EXECUTE. Local Python tooling: 392 tests. All six main/owner input heads were rechecked after G02 CI and were unchanged/ancestors of the tested commit. This is reproducible author-side evidence, not an independent decision.

Useful commands in a disposable local checkout of the exact commit:

```bash
python -m unittest discover -s tools/supabase/tests -q
python tools/supabase/domain_draft_guard.py
python tools/supabase/domain_function_final_guard.py
python tools/supabase/domain_local_ci.py
```

The runtime requires the repository's pinned local Supabase/PostgreSQL tooling and Docker. Follow the workflows' dependency pins; run only against the disposable local container. Read the manifest input SHAs and live refs before accepting an evolved composition. Do not rerun against a hosted School project.

## Decision record to complete

1. Reviewer GitHub login and verified non-author/authorization evidence.
2. Exact reviewed code SHA and PR URL; date of the actual review.
3. Findings and their dispositions, with rechecked commits after fixes.
4. Actual submitted GitHub APPROVED or CHANGES_REQUESTED review URL/ID on #168 (or a precisely identified successor), bound to the reviewed commit.
5. Separate DB01/Enrollment and Academic/DB02 compatibility acknowledgments at that commit, with identities and evidence links.
6. Final exact-code CI after any requested source changes.

`db02_g03_review_decision_template.json` provides an unfilled structured record. Nulls and pending flags are intentional; an author must not fill them with inferred approvals.

## Gate and release state

P03 cannot close until an actual eligible reviewer is identified. G03 cannot close until independent review and compatibility decisions are recorded. G04 review/integration/merge, G05 final accepted-contract freeze and G06 migration/activation remain open. The latest engineering target is still a draft PR; preparing this packet does not change its review state, merge it, install Migration 10 or enable a protected operation.
