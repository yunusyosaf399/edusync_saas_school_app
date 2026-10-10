# D1 Effect 30 — primary replacement and alternative relationship-basis acceptance

Date: 2026-10-10  
Verdict: **PASS — exact-source incremental disposable local D1C2A acceptance; full D1 OPEN.**  
PR: [#16](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/16)

## Exact-source evidence

- Baseline main `7239a127efa6cc816153c4ef25f9447552390de1`; tested PR SHA `ee6706b41a99947081654a39daef93329dec24ed`; merged second-parent as `e867480c1b8e73f47fb714964fd7704be98ea1a9`.
- [D1 disposable runtime #164](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38024296296): **41/41** new rollback-only suite17, **723/723 business assertions across 17 suites**, **220/220 Foundation regression assertions**, 21/21 Python runner unit tests, and six two-session races with observed database lock wait (Employee 3; Family P1 membership ADD, END and CORRECT 3). Both local SQL lint levels PASS, local stack stopped.
- [Foundation #363](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38024296287): 9 frozen Foundation migrations and 220/220 TAP assertions PASS.
- Runtime assembled and locally applied **199 unchanged non-executable SQL draft fragments**, 34/34 forced-RLS D1 relations, 540 final functions (522 SECURITY DEFINER), 0 executable private helper functions granted to authenticated, anon or service_role. Standalone draft-static workflow not triggered by test-only paths; unchanged last-accepted [static #105](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/37964583943) PASS.

## Approved frozen behavior tested

- `family.relationship.change` has explicit `ADD` and `END` domain commands separate from `family.child_access.change`, both guarded by current principal authorization. The added test creates two valid, distinct relations for the same Student and Family; relationship creation alone does not create a child entitlement. Exactly one explicit child access is then granted.
- While a second relationship independently covers the access interval, ending only the first does not close the retained child entitlement; `access_closed_count=0` and no additional `family.child_access_changed` event. Ending the final remaining relationship closes precisely one retained entitlement with exclusive effective end, `access_closed_count=1`, stable exact-key END replay and no duplicated child-access change event.
- A separate Student has two valid candidate relationships in **two ACTIVE Families**, with a synthetic preexisting selected primary display context. Attempting to END that source with no replacement raises the typed `D1_FAMILY_RELATIONSHIP_PRIMARY_REPLACEMENT_REQUIRED` preflight reason. Another Student's relationship cannot be used as a replacement. Both denied attempts preserve the selected context and open source.
- Explicit END specifying the valid alternate Family/Student relationship succeeds; closes the original relationship and primary context at the same exclusive date, adds one new selected primary context with `supersedes_id` pointing to retained predecessor, keeps exactly one current selected context, preserves typed idempotent replay and does **not** grant Student B access.

## Isolation and what remains

New files changed only `supabase/tests/domain/17_family_relationship_primary_multibasis.sql` (41 pgTAP assertions, all fixtures rolled back) and `tools/supabase/domain_business_ci.py` (suite registration). No SQL draft, frozen Foundation migration, Flutter client, service worker, production permission or hosted database mutation. Migration 10 remains **199 non-executable `.sql.draft` fragments**.

This closes the tested Effect 30 alternative basis and explicit primary replacement gap, not cross-campus reviewer scope, P1 replacement approval race paths, every future containment variation, Family portal checked projections, populated upgrade, Admissions/Finance or full D1 acceptance.

**Checkpoint: `D1_EFFECT30_PRIMARY_MULTIBASIS_PASS — 723/723 BUSINESS — 220/220 FOUNDATION — 6/6 RACES — FULL D1 OPEN`.**
