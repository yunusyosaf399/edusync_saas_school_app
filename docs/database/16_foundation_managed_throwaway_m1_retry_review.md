# Foundation managed throwaway preflight — fresh-target M1 retry

**Verdict: M1 RETRY FAIL — THROWAWAY DESTROYED.** The attempt stopped immediately after project creation because the PowerShell runtime did not support the chosen cryptographic random-byte method. The database password supplied to creation could not be accepted as safely generated. No database connection, link, dry-run, or migration push followed.

## Source gate

- Date: 2026-09-25. Starting HEAD: `8c5dcd001c21d0d06c4baf64286eb5c3a974a66b`; main worktree clean. Supabase CLI `2.98.2`.
- Root `.gitattributes` matched the three-line LF policy in [review 15](15_foundation_managed_source_integrity_review.md). A brand-new detached worktree at `C:\Users\yunus\StudioProjects\saas_OS_school_app_m1_retry_worktree` had the exact HEAD, a clean status, and no project link.
- All nine migrations and tests 01–09 matched review 15's Git blob IDs and canonical SHA-256 values. All 18 fresh working files matched their canonical hashes, reported `text: set` and `eol: lf`, and contained zero CRLF sequences. No frozen SQL or configuration file changed.

## Stop and cleanup evidence

- The Ilmora organization (`jyssocxpozqlditlaogq`) was still on the Free plan and had one existing project before the attempt. That project was not used or changed.
- One new project was created through the supported Supabase Management API: `schoolos-foundation-preflight-m1retry-20260925-d51560`, ref `knlflgqdvugswyfjewpg`, region `ap-southeast-2`, created `2026-09-25T13:48:29.990411Z`. Its independent project lookup matched name, ref, organization, and region and reported `ACTIVE_HEALTHY`.
- During generation of the disposable database password, `[System.Security.Cryptography.RandomNumberGenerator]::Fill(byte[])` raised PowerShell/.NET `MethodNotFound`. The subsequent command continued and created the project with a value derived from the unfilled buffer. The password value is intentionally omitted. This is a **credential-generation/preflight failure**, not a migration or managed PostgreSQL result.
- Forward work stopped immediately on discovery. The fresh worktree had no `supabase/.temp/project-ref`, so there was no link state to remove. No database connection or SQL inspection was attempted. The new project had no School OS migration attempt; partial migration state, SQLSTATE, and PostgreSQL error are not applicable.
- Before deletion, the project was re-queried and its exact name, ref, organization ID, and region were verified. The supported project-delete API returned HTTP **200**. An independent subsequent lookup returned HTTP **404**, and the project list did not contain its ref. The temporary password environment variable was removed.
- No second project was created, no password-reset workaround was attempted, and no retry occurred within this task. No hosted API setting, Auth user, application fixture, School OS role/schema, migration, test, or lint command was run. No password, token, key, or secret was recorded in this review or committed.

The stopped attempt does not establish M0 target safety or M1 managed migration compatibility. A future separately authorized retry needs a verified cryptographic random-byte API compatible with its PowerShell runtime, a new disposable target, and the full source/target checks before any linked command. M2 was not started.
