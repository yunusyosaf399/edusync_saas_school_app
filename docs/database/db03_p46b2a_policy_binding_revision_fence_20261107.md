# DB03 P46B-2A — Protected policy binding revision fence

**7 November 2026 — inactive structural prerequisite, not a positive policy-binding writer.**

The existing P46A read-only source identifies the exact Forward and policy. P46B-1 proves its retained Intake lineage. This increment prevents a future snapshot writer from skipping a revision, using a predecessor from another application, or binding the same Forward twice.

For a first snapshot, revision must be 1 with no predecessor. For revision 2, the predecessor must be revision 1 **of the same application**, and so on. The new composite FK prevents references to the wrong predecessor. A unique application/Forward pair prevents a retry from silently creating a second binding for the same Forward.

**No policy-binding operation is enabled.** P44 deny-all mutation trigger and forced RLS, S5 NULL policy projection, and Principal APPROVE / Student creation blocks remain. No direct client/worker write grants. The full P46B-2 protected command still needs a fresh actor grant and Principal review check, correct lock order, version/epoch and current Forward validation, idempotent receipt/audit/outbox, S3/S5 projection reconciliation, and atomic D1 handoff before activation. The admission fee UNPAID/SKIPPED/MARKED_PAID decision must remain separate from official Finance payment evidence.

16 pgTAP assertions plus injected failed-install rollback are added to the disposable DB03 CI. Draft-only: do not apply to production.
