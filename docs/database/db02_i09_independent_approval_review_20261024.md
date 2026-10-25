# DB-02 I09 — Independent Roll Policy APPROVAL REVIEW (draft-only)

**Base:** green I08 stacked draft PR #153, exact commit `7f84f4940ab8fb307ed26f670b6c672b6a614965`.  
**Change:** private `effect56_01` REVIEW receipt context, `effect56_02` terminal receipt/audit, `effect56_03` protected decision function. Rollback-only `97_db02_independent_review.sql` has 34 assertions.

## Public review

```sql
app.d1_review_student_roll_policy_change(
 p_request_id uuid,
 p_decision text, -- APPROVE or REJECT
 p_expected_request_version bigint,
 p_reason text,
 p_idempotency_key text
) RETURNS TABLE(request_id uuid,request_version bigint,request_state text)
```

Authenticated-only fixed signature, owned by NOLOGIN workflow executor, pinned `pg_catalog,pg_temp` SECURITY DEFINER. All calls require a real verified Individual Principal, current exact global Foundation APPROVAL P1 bound to the immutable School-wide request, LIVE assigned OPEN reviewer with a current role/School ALL grant verified via `d1_current_reviewer_eligible` and `d1_review_candidates`, different Person from the requester, exact expected request row version and `PENDING` state. No School authorization follows from the request ID or from historic reviewer assignment alone.

APPROVE creates a signed review row, closes the active step APPROVED, and opens the next sequential stage with new live independent reviewer candidates. The final step moves the request to APPROVED, **not EXECUTED**; REJECT closes active step REJECTED, cancels unused waiting steps and ends request REJECTED. Both increment the request version, write one immutable `request.review` terminal SUCCEEDED receipt (`D1_STUDENT_ROLL_POLICY_REVIEW`, result_ref=request, exact `request_version/state` two-key result), one minimized private audit and final transition (when terminal). Raw reason stays in `approval_reviews.reason` and the canonical JCS SHA256 digest, never in broadly visible receipt/audit/event. No policy, allocator, roll allocation or `student.roll_policy_changed` outbox write occurs at REVIEW.

## Phase separation and temporary replay policy

I09 introduces a DB-02 **private fixed four-element REVIEW receipt context**, using the same JCS v1 canonicalization, verified actor, operation, SHA256 intent, principal+operation+idempotency advisory lock and unique namespace as the shared receipt context. It does **not** widen shared `d1_command_receipt_lookup`. I11 remains the independent shared SQL-owner REVIEW/APPLY phase acceptance and historical terminal replay gate. A same-key matching review retry currently fails **closed** with a specific I11-pending error instead of re-running a decision. A reused key with different intent conflicts. Do not deploy I09 separately from the approved I11 replay integration.

## Acceptance and release boundary

Local-only rollback test covers: authenticated/anon/service ACLs, disabled operation default, requester self-review denial, revoked reviewer live School ALL scope, stale version, approved and rejected terminal state, one immutable decision, one receipt/audit/transition, private reason redaction, no policy/allocator/outbox effect, changed-key conflicts and fail-closed retry. Maintain legacy #37/#38 read tests excluding only *unimplemented APPLY*. Run D1 draft static, Foundation local and disposable D1 runtime for exact I09 head. Mark I09 implemented only if all pass.

No hosted migration, operation enablement, independent security signoff (#131), merge, shared phase change or I10 apply. I09 approval is a human decision, never a Roll Policy transition.
