# Enrollment and DB-01 composed integration candidate

## Purpose and exact inputs

Compose the tested Enrollment fixes (#106 → #114 → #115, head `2ce6aa3bbe47aa9324c508c4726813adbcc12d34`) with the nonactivating DB-01 lineage/provenance stack (#107 → #109 → #111 → #113, head `b09f19f098ec685aad9675dd74ab6ea2d41ef354`). Both share prerequisite #106. Main is `d82cd678fc3e1c03ed832b5b1be5897ffc48642a`.

The merge is source-conflict-free. No business SQL was rewritten for composition. The merged runtime runner retains END, MOVE DIRECT and MOVE APPROVAL concurrency gates while adopting the three DB-01 private-function inventory additions and structural suites 77–79. The DB-01 application trigger must pass through real Enrollment MOVE applications and immutable APPLY replay; this combined run verifies that interaction.

## Validation contract

The composed disposable runtime must apply 240 draft fragments, pass 79 business suites / 3,232 assertions, all frozen Foundation assertions, existing photo and concurrency gates, six END waits, ten MOVE DIRECT waits and four MOVE approval waits. Required catalog: 34 FORCE-RLS relations, 545 functions / 527 definers / 157 app / 388 private; authenticated-private, anon and service-role function EXECUTE remain zero. Local tooling and both draft/final guards passed before submission. Exact-head CI evidence belongs in the PR description after completion; earlier individual branch results do not certify this composition.

## Review and activation boundary

This is a review candidate, not independent security approval. None of #106/#114/#115 has a submitted review at preparation time. DB-01 review issues #108/#110/#112 remain open; their additional private definers and operation-scoped Foundation trigger still require independent assessment. The MOVE internal policies and helper permission require review as well. Original PRs remain separate for reviewing their individual deltas; this candidate provides the composed diff and runtime evidence. Do not merge both this whole candidate and each original stack separately.

All Migration 10 fragments remain `.sql.draft`; Foundation migrations 1–9 and database tests 01–09 remain unchanged. Roll CORRECT and Roll Policy Change remain disabled. No hosted deployment or activation is performed.

DB-02 #101 still requires explicit RP-01–RP-07 product selections, including RP-06 event/result literals; generic permission to continue engineering does not select those values. The protected Roll Correction RPCs, current-authority checked history/replay, School-local apply-date contract and further correction concurrency acceptance remain outstanding. Synthetic DB-01 structural evidence is not protected command acceptance. Flutter follows database acceptance.
