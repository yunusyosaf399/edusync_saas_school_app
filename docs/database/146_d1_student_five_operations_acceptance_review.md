# D1 Student protected operations #56–#60 — source and runtime acceptance review

Date: 2026-10-15. **Status: PASSING ACCEPTANCE CANDIDATE; final merge/freeze pending exact post-documentation CI and PR review.** Full Migration 10 remains OPEN and inactive.

## Reviewed candidate and exact runtime evidence

- Before this batch, the frozen `main` checkpoint was `067de4d5b13260678815a0f2b91c235fd83d0491`: **55 suites / 2,696 pgTAP assertions, 22/35 distinct protected operations accepted**. Its nine Foundation migrations are unchanged.
- [PR #60](https://github.com/yunusyosaf399/edusync_saas_school_app/pull/60), tested head **`43cd8cd883af5038b4e01115fdc625dd2adffaf6`**, has **three exact-head PASS workflows**: [D1 local runtime #573](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38675105555), [Foundation #692](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38675105413), and [D1 draft static #198](https://github.com/yunusyosaf399/edusync_saas_school_app/actions/runs/38675105423).
- The local runtime log explicitly reports **all 60/60 business suites, 2,751/2,751 assertions**, all pre-existing true observed-lock race cases, **220/220** Foundation SQL assertions, clean warning/error-level database lint, and successful teardown. It applied only **220 inactive `.sql.draft` fragments** to a disposable local database, not a hosted Supabase instance.
- The D1 job ran **68/68 Python tests**; Foundation ran **224/224 Python tests** and **220/220 SQL assertions**. Source audit confirms **34/34 D1 relations** under enforced RLS, **542 total functions**, **524 SECURITY DEFINER**, **157 app**, **385 private**, **zero client/anon/service-role EXECUTE on private functions**. The previous runtime's hard-coded success-message totals were stale at 541/523/384 even though the exact runtime probe validated 542/524/385; the branch follow-up uses the validated observed metrics when reporting.
- The **source audit and review below are limited to the five incremental suites and associated fixes**, not independent proof of all 35 operations or all Student lifecycle paths. Final review and post-documentation CI must use one exact source head; a green earlier SHA does not authorize merging a later SHA.

## Newly demonstrated protected operations

| pgTAP suite | Contract and route | Assertions | Tested core behavior |
|---|---|---:|---|
| `56_student_status_p1_direct_lifecycle.sql` | `student.status.change`, P1 DIRECT | 11/11 | Authenticated typed status change, source/version and idempotent replay, changed-key intent rejection, denied raw history SELECT, retained sequence, one receipt and event |
| `57_student_emergency_contact_p1_direct_history.sql` | `student.emergency_contact.change`, P1 DIRECT | 12/12 | Authorized ADD and CORRECT, same-key replay, rejected raw private SELECT, distinct retained successor and source, closed predecessor, two intended events |
| `58_student_identity_p2_approval_history.sql` | `student.identity.correct`, P2 review | 11/11 | Private identity SELECT denied, invalid request denied, authorized submit, different-Person reviewer, approved apply/replay, source retained, successor fact, one application |
| `59_student_special_p2_approval_history.sql` | `student.special.correct`, P2 review | 11/11 | Private special SELECT denied, invalid request and premature apply rejected, different-Person reviewer, approved apply/replay, retained special facts and successor, one application |
| `60_student_status_correct_p2_approval_history.sql` | `student.status.correct`, P2 review | 10/10 | Direct history SELECT and factual no-op denied, submit, unassigned independent-reviewer denial, approved apply, immutable original and superseding event, one application |

The five test files create independent, rollback-only synthetic authenticated fixtures, preserve current verified Foundation permission/role/assignment/scope chains, and complete `SET CONSTRAINTS ALL IMMEDIATE`. Identity and Special fixtures explicitly include an accepted PRIMARY enrollment and matching retained roll policy/allocator/allocation: enrollment ↔ roll commit-time completeness is *not bypassed* merely to get the Student test running. The five suite counts add **55** to the previous 2,696.

## Reviewed append-only SQL continuation and integrity controls

Twelve inactive corrective fragments `effect35_03` through `effect35_14` were added (not executable `.sql` files). They retain the previously frozen structural and Effect21–24 sources while making the *assembled final draft* executable:

1. `35_03`, `35_08`: unplaced Student's ALL/DIRECT permission path is valid, but absence of placement cannot silently confer CAMPUS/CLASS/SECTION authority. An unassigned PL/pgSQL record must not crash first-time operation or replay.
2. `35_04`: bind Student Identity/Special P2 SUBMIT/REVIEW/APPLY to the existing verified-actor, typed intent and receipt mechanism; do not give other operations a generic allowlist bypass.
3. `35_05`, `35_06`, `35_11`: Student aggregate row locking serializes same-Student writes. Status transition rows are immutable retained history and are read without extraneous `FOR UPDATE` or `FOR SHARE` privileges. No general history UPDATE grant.
4. `35_07`: Student `row_version` and `updated_at` remain server-trigger-owned, including correction effects; no direct version counter assignment bypass.
5. `35_09`: grant internal schema-owner application guard only the exact private Identity/Special payload-validator EXECUTE signatures; no client grant.
6. `35_10`: reconcile old physical eight *short* blood group CHECK tokens with the later frozen Effect22 eight canonical *full* codes (e.g. `O_POSITIVE`), **replacing, not widening**, the allowable values. Preserve nonblank reason and all end-marker/effective-interval CHECK requirements. Earlier physical constraint prose still reflects the old short codes and must not be taken as the deployed final assembled catalog.
7. `35_12`: Workflow-owned Status CORRECT SUBMIT does not receive broad status-history SELECT; Student-owned private fixed two-UUID helper exposes only five typed facts for the exact Student/source transition, executable only by the internal Workflow role after existing authorization/preflight.
8. `35_13`: reviewer/participant authz-reader receives necessary **column-limited** request, step and evidence reads and **operation-scoped** request/operation RLS for `student.status.correct`. All three status reviewer/participant helpers use narrow projections, configured live role, Person separation, and matching affected-date authorization.
9. `35_14`: Status CORRECT approval-application trigger remains the same exact integrity body and trigger but runs under the established `schoolos_schema_owner` integrity-guard role. The narrow evidence-writer is **not** granted broad Foundation request or Student history reads.

Scope guard: no changes to the nine frozen Foundation migrations; no hosted deployment; no public/authenticated/anon/service-role app_private relation or private-function grants; no RLS disabling, status-history destructive mutation, weaker approval gating, or cross-school authority. Source guards in `tools/supabase/tests/test_domain_acceptance_ci.py` exercise SQL form, operation limitations, helper owner/ACL and fixture completeness. Runtime probe's inventory adjusts by **one internal private source function** and no new public RPC.

## Boundaries and next acceptance gate

This is **incremental** protected-operation evidence, not exhaustive multi-campus, policy-replacement, identity/special privacy-oracle, concurrent Status CORRECT approval, or all stale-role race coverage. Existing race suite PASS is a regression check, **not** proof of a new operation-specific race test for #56–#60. Student creation still depends on Admissions and Student roll policy change remains separately blocked. New accepted *distinct* operations would be **27/35** with **8 remaining**, *only after freeze/merge*; prior main is still 22/35 until then.

**Next gate:** source-level review and this evidence note need clean **exact new HEAD** D1 local runtime, D1 draft static and Foundation local-stack runs; then inspect the full run summaries and only then merge/freeze PR #60 if no fresh issues. Do not deploy Migration 10. No production schema activation is authorized.
