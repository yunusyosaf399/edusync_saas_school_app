# DB02 G02 — exact owner/main composition candidate

This integration candidate composes the actual observed main and latest DB01/DB02 owner inputs with the Academic pool hook and G01 registry. It is a disposable engineering candidate; independent review, approved merge sequencing and hosted release remain separate.

## Exact observed inputs

| Input | Ref / PR | SHA |
| --- | --- | --- |
| Main | `main` | `df1c98d5c2d19424946986fc6ba7615202b0a443` |
| DB01 | #141 `db/db-01-roll-correct-p1-apply` | `c8800dcfa8f2a4439c989f6d37bc25da611227d4` |
| DB02 | #164 `db/db02-t08-privacy-acl` | `794bb999e726a9893bd6b774de23a579d11039f0` |
| Shared receipt | #122 `integration/db02-roll-policy-receipt-allowlist` | `df8caf9162d41d4eb4868b42abc582d042ec8441` |
| Academic hook | #166 | `327ccb7c1f557b2a619f2e0cd737fc3832c37eca` |
| Complete suite registry | #167 | `3d0c8df8c93118554599d53965cb16318b610a6e` |

The main branch was resolved by both the commit and compare APIs. The older `e526de3...` base shown in historical PR metadata and the G01 review is an ancestor, not the freshly resolved main ref. Main, DB01 #141 and receipt #122 are ancestors of #167. DB02 #164 diverges from #167's history because #165 imported its exact source tree instead of adding that branch as a merge parent. This candidate explicitly records both #167 and #164 as parents, preserving both histories without rewriting either owner branch.

## Source reconciliation

The DB02 #164 Git tree is `38731bdf2a5f3c69232d2819542a8c538fd8bbb9`, identical to the locally available verified T08 source tree. Every one of its 286 migration-directory files remains byte-identical in the composition. The only migration additions relative to T08 are the 14 DB01 effect41 fragments and the Academic effect61 hook. DB02 SQL suites, fixtures and race drivers remain unchanged. DB01's 117-assertion APPLY suite and all DB01 races from #165 are retained. Shared runner/registry/catalog updates already reconciled in #165–#167 remain intact; no numeric-prefix test selection or whole-file owner-side replacement is used.

The effective shared receipt lookup is still the evidence-writer-owned definition in `effect58_01_db02_review_apply_receipt_allowlist.sql.draft`, with the six existing internal executor call edges and no client EXECUTE. Later Academic provisioning does not override it. Its final ownership/ACLs, exact last-definition fragment and all required owner race invocations before runtime PASS have dedicated source gates.

`supabase/config/db02_g02_composition_manifest.json` pins the input SHAs, exact ordered 291-fragment digest, complete 112-suite registry / 4,292 assertion budget, expected runtime catalog and required race calls. Changes to those sources require an explicit manifest update and new acceptance; old CI cannot certify changed sources.

## Required acceptance

Local tooling: 392 tests PASS, including three composition gates. Draft static validation PASS. Full CI must confirm the candidate's exact SHA, Foundation 220/220, all 4,292 domain assertions, all original and added DB01/DB02/Academic observed-lock races, and catalog 599 functions / 581 definers / 167 app / 432 private / 34/34 forced RLS / zero forbidden client private EXECUTE. Exact completed workflow links and code SHA are recorded in this candidate's PR and issue #69 only after completion. Input heads must be rechecked before accepting G02.

## Remaining gates

G02 proves this pinned composed code only. P03/G03 still require an eligible independent non-author reviewer and explicit compatibility/security decisions. G04 approved review/integration/merge, G05 final contract freeze and G06 executable migration/hosted activation authorization remain open. Installed DB03 Student-create/Finance and DB04 consumer handoffs remain necessary for full DB01 closure. No owner PR is merged, Foundation migration changed or protected operation enabled by this candidate.
