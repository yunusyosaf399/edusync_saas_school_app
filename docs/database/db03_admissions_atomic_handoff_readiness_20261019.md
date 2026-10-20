# DB-03 — Admissions-to-D1 atomic single-use handoff: implementation-readiness contract

> **20 October reconciliation — read before using the below handoff contract in SQL.** Actual owner [decision record](20261020_owner_choices_and_dependency_resolution.md) selected **Finance-confirmed clearance OR an explicitly approved waiver**; no screenshot/manual `paid`/`waived` field. Earlier examples in this file that require `FINANCE_SATISFIED` only or accept `NOT_REQUIRED` alone are **historical candidate semantics and not current final-admission authority**. Waiver source/approval evidence, live verifier, revision, expiry, revocation/reversal fence and joint lock placement remain **SC-03/SC-06 blockers**. DB-02 selected School-local today-only INIT/REPLACE, permanent historic numeric ownership and independent review; D1 policy implementation/Student Create are still separate. **Important schema correction:** the prior proposed `UNIQUE(admission_number_allocation_id)` on handoffs conflicts with retaining a single permanent admission number when reissuing after INVALIDATED; [current physical plan](db03_admissions_physical_schema_and_staged_sql_plan_20261020.md) instead proposes checking that the number belongs to the same application while keeping one READY-or-CONSUMED handoff at a time. The previously suggested extra stage-binding child table is optional, not silently part of the fifteen: version-epoch plus complete locked stage-head revalidation must be proven or the 16th table independently approved. No SQL activation or owner signature implied.

**2026-10-19 | DESIGN READY FOR OWNER REVIEW; NOT APPROVED / NOT INSTALLED.** DB-03-only documentation. Existing draft PR #102. Source main `e526de3fd4668483623ef52cccc34d38d893c249`; predecessor PR head `acadecfa70004696419e1c87b408494f7e9d0206`. No D1, Finance, Foundation, Migration 10, registration or test edits. Every label prefixed **PROPOSED** below requires owner approval unless identified as **SOURCE**.

## 1. Sources, verified current facts, and final-definition audit

Read `AGENTS.md` first; repo requirements §§10–12,17–18,72.1 and invariant/security/guardrail precedence; DB-03 physical/review files on PR #102, proposed #79, frozen D1 Effect36 #76 and readiness #155. Current `main` and PR head were checked against exact refs above before this work. Reviewed D1 #27/#30/#31; SQL draft `effect25_19_enrollment_place_school_anchor`, `effect25_23_enrollment_place_persistent_lineage_binding`, `effect25_02_enrollment_place_capacity_roll`, `effect25_16_enrollment_place_academic_boundary`, and the **later final overriding definition** `effect35_15_enrollment_place_allocator_server_version`. Reviewed DB-02 PR #101 head `d4737c632b3c86454f8ca06cd3464d457c2b6e0a`, especially its allocator namespace integrity gate; its RP-01…RP-07 proposals are **NOT approved behavior**.

**SOURCE confirmed:** `student.create` is registered but disabled, requires authenticated current `student.create` **and** `student.enrollment.place` for the exact accepted destination, takes a genuine verified unused Admissions handoff, and atomically constructs Student, school Student ID, initial status, PRIMARY enrollment, roll, receipt and minimal `student.created` evidence. Foundation's D1 mutation prefix is advisory school authorization lock `(71001,1)` SHARED, command namespace `71002` idempotency lock, Foundation Principal/policy processing, then D1 school/config/allocator → Person/Student → academic Class → Campus → Year → Class Offering → Section Offering → child/history. D1 placement has `d1_enrollment_place_lock_school(uuid)` using `school_profiles FOR UPDATE`, and `d1_enrollment_place_prelock_roll(uuid,date)` that re-reads ancestry and locks effective roll-policy revision and matching allocator **before** Student/Offering locks. The final `d1_enrollment_place_allocate_roll(uuid,uuid,uuid,uuid,uuid,date)` from Effect35_15 updates allocator `next_value` only and is not equivalent to the earlier definition. `d1_enrollment_place_capacity` locks Class and Section offering and tests interval breakpoints. Neither an Admissions command nor future Student Creation may assume the **initial** Effect25 definition is final.

**Unresolved integrity finding (DB-02 evidence):** current persistent-number collision scan excludes allocations with a `supersedes_id` successor, while permanent historical ownership may require retaining those numeric values across corrections. DB-02 PR #101 flags RP-03 namespace/history and RP-07 possible MOVE/END prefix inversions. A new Student from Admissions MUST NOT paper over this; D1/DB-02 owner must prove final assembled allocator collision/lock behavior before SC-04/SC-06 sign-off. No empirical whole-system lock graph or complete final function compilation is claimed by this document.

## 2. Three separate state dimensions (do not compress into one misleading enum)

**SOURCE #79:** application stored states `DRAFT,SUBMITTED,IN_PROGRESS,ACCEPTED,REJECTED,WITHDRAWN,CONSUMED`; handoff states `READY,INVALIDATED,CONSUMED`. Policy stage kinds `DOCUMENT_VERIFICATION,ADMISSION_TEST,INTERVIEW,APPROVAL,ADMISSION_FEE`; stage outcomes `PENDING,PASSED,FAILED,SKIPPED,INVALIDATED`. **PROPOSED:** `CANCELED` as a retained pre-consumption application terminal outcome; `admission_application_transitions` append-only log; `admission_offers` append-only offer revision/decision; `admission_stage_exceptions`. The requested *under verification*, *testing/interview*, *offer issued/accepted/declined* and *enrollment ready* are **PROPOSED workflow phases / derived checked readiness**, not frozen additions to `admission_applications.state`. Never use an offer phase as an authorized Student-creation proof.

Application state diagram (SOURCE nodes uppercase, proposed edges/phase interpretation review-required):

```text
DRAFT -> SUBMITTED -> IN_PROGRESS [verification/testing/interview phase]
  |         |               |
  +---------+---------------+----> REJECTED / WITHDRAWN
                                  [CANCELED candidate before consumption]
IN_PROGRESS -> ACCEPTED -> CONSUMED
                   |             ^
                   +-- offer issues/responses and readiness checks
                   +-- server-issued READY handoff -- atomic D1 create --+
                   +-- invalidate READY on amendments/reversal/cancel;
                       re-acceptance/new revision requires owner-approved rule
```

A rejected/withdrawn/canceled application retains application identifier and all outcomes. CONSUMED is immutable for Admissions lifecycle; later student withdrawal uses D1, not rewriting Admissions. Offer DECLINED must not make a previously-issued handoff usable. If no offer stage is configured, ACCEPTED may reach READY only after the exact policy/stage/Finance gates. No admission seat reservation arises from an offer or handoff.

### Candidate transition ledger: actor, guard, snapshot, evidence, idempotency

All mutators require server-derived active Principal, live operation+scope+state, enabled deployment contract, Foundation authorization/shared school lock and typed same-intent receipt; every accepted transition has immutable event/command evidence and one projected row-version increment when relevant. **Actor permission codes below are proposed, not registered**. Version snapshots denote `expected_application_row_version` plus any named stage/policy/evidence revision; no client-provided actor or proof flag is trusted.

| From → to / phase | Actor (PROPOSED permission) | Guards and version snapshot | Retained evidence and replay |
|---|---|---|---|
| none → DRAFT | scoped Admissions clerk `admission.application.create` | same-school/year/campus candidate; no conflicting active intake; canonical applicant reference may be unresolved under SC-01 | application UUID, creator, initial transition/receipt; same key returns same DRAFT, different key cannot duplicate active Person/year |
| DRAFT → SUBMITTED | scoped submitter `admission.application.submit` | current draft version; resolved Person/identity revision as SC-01 decides; unique current published policy/stage snapshot; issue application number once | policy version, number ledger, submitted time, typed transition+receipt; exact key replay no second number |
| SUBMITTED → IN_PROGRESS | scoped reviewer `admission.stage.record` | current application version; policy stage roster and initial outcome heads | first stage progression evidence, actor+receipt; repeat key does not restart workflow |
| IN_PROGRESS verification outcome | document verifier `admission.document.verify` | policy DOCUMENT_VERIFICATION stage; private file purpose, hash/availability, expected link revision/version | immutable document verification and new stage outcome; replacement supersedes and invalidates dependent acceptance |
| IN_PROGRESS test/interview outcome | authorized assessor `admission.test.record` / `admission.interview.record` | matching configured stage, assessed revision, allowed score, correct placement scope | append-only assessment+stage outcome revision; same-key duplicate no new assessment |
| IN_PROGRESS stage skip | policy evaluator, not an unconstrained staff override | published stage `SKIPPED`; expected policy/app revision; mandatory stage cannot be skipped | explicit SKIPPED outcome with policy reference; no bypass |
| IN_PROGRESS required-stage exception (candidate) | requester + independent Foundation approver, configured `admission.exception.*` | specifically approved exception kind, exact stage/application/version, reviewed authorization and current approval | append immutable exception decision; stale policy/application/decision invalidates, same receipt replays |
| IN_PROGRESS → REJECTED | authorized admission decision reviewer `admission.application.decide` | current stage and application evidence; configured approval gate; not consumed | retained reason/code (restricted), actor/approval/transition; terminal same-key replay stable |
| DRAFT/SUBMITTED/IN_PROGRESS/ACCEPTED → WITHDRAWN | authorized applicant-facing withdrawal operator `admission.application.withdraw`; self-service not implied | not CONSUMED, live current version, no ambiguous competing handoff outcome | retained withdrawal and invalidation in same transaction if READY; identifier not reused; same key stable |
| DRAFT/SUBMITTED/IN_PROGRESS/ACCEPTED → CANCELED (candidate) | separately privileged cancellation actor `admission.application.cancel` | SC-01/02 owner chooses eligible origins, reason/approval, unused handoff | retained cancellation+READY invalidation; consumed Student not deleted; no duplicate terminal cancellation |
| IN_PROGRESS → ACCEPTED | `admission.accept` staff plus configured Foundation approval chain | verified Person+version, completed stage/skip/exception heads, policy version, current Finance if required, current destination, offer condition if mandatory | accepted transition+approval reference; duplicate key returns original accepted decision only after authorization |
| ACCEPTED → offer ISSUED (phase, not application enum) | `admission.offer.issue` | approved offering policy; expected app/version, placement and offer revision | immutable numbered/versioned offer snapshot and renderable letter identity, no seat/fee proof; replay stable |
| offer ISSUED → ACCEPTED / DECLINED / WITHDRAWN / EXPIRED (phase) | `admission.offer.respond` verified authorized participant; expiry server-evaluated | expected offer revision, terms, current app; applicant self-service eligibility unapproved | append decision/expiry outcome + receipt; decline invalidates/blocks unused READY if previously issued |
| ACCEPTED → ENROLLMENT_READY (derived phase) | trusted readiness evaluator under scoped `admission.accept` | fresh Person, stage, approval, current offer decision if mandatory, fee clearance, valid destination | read-only typed readiness decision/revision digest; **not** a client persisted boolean |
| ENROLLMENT_READY → READY handoff issued | protected Admissions issuance actor `admission.accept` | same fresh snapshots, no READY or CONSUMED sibling, reserved unique Admissions admission allocation, locked application | handoff UUID/revision and immutable bindings, number ledger, issuance receipt, audit/outbox IDs; same-key returns same handoff |
| READY → INVALIDATED | authorized amendment/withdraw/cancel handler or trusted Finance reversal notifier/fence, never arbitrary client toggle | READY only, exact application/handoff/Finance evidence; concurrent D1 consumption serialized | retained invalidation reason code and actor/system provenance (restricted); same key stable |
| READY → CONSUMED; ACCEPTED → CONSUMED | **future authenticated D1 `student.create` executor** (not an Admissions app user operation) | current dual D1 permissions, READY exact handoff/revision and all dependencies, duplicate Person denied, capacity/roll/Finance valid, typed key | one Student/status/PRIMARY enrollment/roll, consumption receipt + result + `student.created`; exact terminal key replay no new mutation |

For a **failed guarded** command: no transition, allocation, receipt of successful effect, outbox or counter advancement. Stale/conflicting same-key intent denies; terminal receipt read must still reauthorize the actor. All operational names/state-edge eligibility are owner-review candidates except existing enum nodes and D1 frozen dual-authority rule.

## 3. Durable server-issued handoff field matrix (candidate physical contract)

Base: `app_private.admission_handoffs` from #79. A READY row is created only by server-trusted Admissions issuance after validated application and policy evidence. All UUIDs must identify actual approved rows; no JSON evidence substitutes for relational FKs. Values are frozen on issuance, with state/consumption fields as one-way exceptions. Proposed additions are marked NEW and require separate migration approval.

| Field | SQL type / candidate constraint | Origin and verification |
|---|---|---|
| id | uuid PK, server default `gen_random_uuid()` | canonical handoff identity; never caller-chosen |
| application_id | uuid NOT NULL FK applications; UNIQUE(application_id,revision) | real same-school accepted application |
| revision | integer NOT NULL CHECK >0 | monotonic per application under locked aggregate; predecessor head invalidated first |
| application_version | bigint NOT NULL CHECK >0 | frozen submitted/accepted app `row_version`; compare at consume |
| identity_resolution_id | uuid NOT NULL FK identity_resolutions | exact current immutable head for application |
| person_id | uuid NOT NULL FK people | exact identity binding + current Person version |
| **person_version** NEW | bigint NOT NULL CHECK >0 | avoid using stale identity match when Person changed |
| policy_version_id | uuid NOT NULL FK admission_policy_versions | snapshotted effective published policy, not caller policy |
| **stage_evidence_revision / digest** NEW candidate | typed normalized revision rows preferred over unchecked `jsonb`; checksum optional only in addition to FK-covered evidence | latest required stage outcomes matched at issue and re-evaluated on consume |
| **stage_evidence_bindings** NEW proposed child relation | (handoff_id,policy_stage_id,stage_outcome_id) FK each; UNIQUE(handoff_id,policy_stage_id); stage policy/application ancestry check | exact all required/skipped stage-head IDs, immutable append, no ambiguity |
| school_id | uuid NOT NULL FK school_profiles | validated school of Person/policy/application |
| academic_year_id | uuid NOT NULL FK academic_years | accepted year; valid effective date |
| campus_id | uuid NOT NULL FK campuses | accepted campus/permission scope |
| class_offering_id | uuid NOT NULL FK class_offerings | active Class/year/campus ancestry |
| section_id | uuid NOT NULL FK section_offerings | same offering; exact D1 placement target |
| **placement_effective_on** NEW candidate | date NOT NULL | D1 as-of capacity/roll policy date; not issue timestamp; SC-04 must freeze |
| admission_number_allocation_id | uuid NOT NULL UNIQUE FK number_allocations | exactly ADMISSION kind, same application; immutable number |
| fee_clearance_id | uuid NOT NULL FK admission_fee_clearances | NOT_REQUIRED from policy or Finance-installed current verified evidence |
| **finance_clearance_revision** NEW candidate | bigint NULL | Finance current version at issuance; REQUIRED only; reverify on consume |
| acceptance_approval_application_id | uuid nullable FK Foundation approval_applications | exact approved configured reviewer outcome or policy-approved absence |
| **offer_revision_id** NEW conditional | uuid NULL FK proposed admission_offers | mandatory only if owner approves offer-gated readiness |
| issued_at / issued_by | timestamptz NOT NULL / uuid FK principals | trusted issuance provenance; issuer revalidated at issue |
| state | text NOT NULL CHECK IN ('READY','INVALIDATED','CONSUMED') | server-only terminal FSM |
| consumed_at / consumed_by | timestamptz / uuid FK principals, NULL unless consumed | consuming authenticated D1 actor and instant |
| student_id | uuid NULL FK D1 students; UNIQUE when nonnull | exactly one D1 Student created by this handoff |
| intake_receipt_id | uuid NULL FK Foundation command_receipts; UNIQUE when nonnull | terminal D1 typed receipt; same-transaction association |
| invalidation_reason | text NULL, restricted; recommend controlled reason code + private detail | READY→INVALIDATED only; no broad payload |
| **issued_command_receipt_id** NEW candidate | uuid UNIQUE FK Foundation command_receipts | one issuance receipt, distinct from D1 intake receipt |
| **row_version** if retained projection | bigint NOT NULL >0, server-maintained | optimistic terminal state/version recheck, no client UPDATE |

**Strong recommended SQL constraints, not yet applied:**

- `UNIQUE(application_id,revision)`; `UNIQUE(admission_number_allocation_id)`; partial unique `(application_id) WHERE state IN ('READY','CONSUMED')`; partial UNIQUE nonnull `student_id` and `intake_receipt_id`. The last partial READY/CONSUMED unique intentionally forbids reissuing a handoff after a consumed sibling.
- `CHECK` terminal pairing: READY has NULL consumed_at/by, student_id, intake_receipt_id and invalidation_reason; CONSUMED has all consumed_at/by, student_id and receipt nonnull and no invalidation_reason; INVALIDATED has nonnull controlled reason and no consumption fields. Enforce allowed transitions ONLY READY→INVALIDATED or READY→CONSUMED via guarded trigger; no UPDATE of frozen binding fields; no DELETE/truncate.
- A unique `students.person_id` and `students.admission_number` remain decisive D1 constraints. DB-03 recommends unique `(student_id, intake_receipt_id)` evidence consistency plus server-only command-effect association; uniqueness alone cannot guarantee atomic creation without one transaction and defense triggers.
- Composite FKs / deferred constraint triggers verify same application/policy/school/Person/number kind, exact latest stage outcome head and current approval. `stage_evidence_bindings` rows cover **every** policy stage, exactly once. A bare hash is insufficient and a stage outcome updated after issue is rejected at consume even if a digest matches.
- Enrollment destination ancestry is derived through section→class offering→campus/year, verified under D1 academic locks; avoid duplicate authoritative independent ancestry. `application.final_handoff_id` reverse FK from #79 creates installation cycle; owner should prefer deriving latest handoff by indexed application_id, or create deferred validated reverse FK after both tables exist.
- No direct authenticated/anon/service_role mutation grants on private handoff or binding relations. FORCE RLS. Only reviewed narrow executor may issue/invalidate/consume; D1 integration must have a specific trusted protected mutation path, not broad table OWNER/service-role shortcut. Return receipt identifiers/state/Student ID only through current-authority checked reads.

**Single-use proof obligation:** even with two parallel differing receipt keys, row-level `FOR UPDATE` on handoff, READY-only guarded transition, partial uniqueness, immutable Student Person/Admission unique keys and a *single database transaction* mean at most one transaction can observe and commit READY→CONSUMED. Loser, after blocking/re-reading the new committed state, returns only the authorized matching terminal replay result if its **original canonical intent/key** matches; with another key it fails as already consumed and creates zero artifacts. A crash before commit leaves READY and no Student; after commit only receipt ACK can be lost.

## 4. Finance-owned verification interface: strict three-way distinction

### Finance-installed facts (source-level only, not a deployed clearance bridge)

Repository guardrails/decisions require distinct assessed charges, verified payments, allocations, reversals, nondeletable financial history; bank/wallet screenshot is pending evidence, not verified payment. **No currently installed Admissions-specific obligation, clearance verifier RPC, FK names, Finance reversal fence or durable clearance schema was verified.** The proposed `admission_fee_clearances` in #79 is **not** a Finance ledger and is **not installed**.

### Proposed server-to-server typed interface (NOT implemented)

```text
finance.verify_admission_clearance(
  application_id uuid,
  policy_version_id uuid,
  expected_application_version bigint,
  admission_obligation_reference uuid,      -- if Finance owns exact typed identity
  verification_idempotency_key uuid
) -> {
  clearance_status: VERIFIED | NOT_CLEARED | REVERSED | STALE | UNAVAILABLE,
  finance_obligation_id: uuid,
  finance_verification_id: uuid,
  finance_revision: bigint,
  obligation_revision: bigint,
  observed_at: timestamptz,
  reversal_valid_through_revision: bigint,
  verified_application_id: uuid,
  verified_policy_version_id: uuid,
  verification_receipt_id: uuid
}
```

The entire name, enum, fields, types and response are **PROPOSED**, not a claim of existing Finance SQL. Finance must define whether clearance is settled-in-full, approved zero-balance credit, genuine exemption or another canonical state; exact amount/currency, validity window, charge version and applied reversal semantics live in Finance. Admissions stores only approved typed evidence references/version/checked_at and admission-specific decision with FK once Finance schema exists. For NOT_REQUIRED, an Admissions policy-revision-specific `NOT_REQUIRED` evidence row has all Finance reference columns NULL; it is not a bypass when the policy requires a fee. For REQUIRED, absence of installed Finance verified evidence **DENIES READY issuance and consumption**.

**Reversal-fence contract:** before READY issue and again in the D1 transaction, Finance and Admissions/D1 must agree on a serialization fence for (obligation/version, current verification). A reversal committed first must make the subsequent validation fail; creation committed first may be followed by a reversal but Student/Enrollment remain and Finance handles debt. One stale timestamp or version read *without a lock/shared validation fence* is insufficient. A signed verification capability or a Finance row lock are alternatives for owner review, but only if Finance proves TOCTOU resistance. Do not assign an arbitrary Finance lock rank relative to D1's School→allocator→Person→Offering hierarchy; DB-08/DB-09 must jointly approve the rank, canonical obligation IDs, actor delegation, reversal and correction semantics. No Finance tables or transactions are created by this design.

### Finance owner questions / required deliverables

DB-08/DB-09: exact obligation-to-application FK and currency/charge source; definition of VERIFIED including partial payment, credits, scholarships, discounts, overpayment and reversals; immutable verification receipt/version with checked timestamp; invalidation notification vs synchronous authoritative recheck; approved multi-writer lock and future-dated reversal order; whether expiry/fee exemption can ever be accepted; offline/proof denial; authorization/RLS and real two-session reversal race. Neither Finance permission nor Admissions admission.accept is permission to write a Finance balance.

## 5. Atomic future D1 student.create dependency: exact safe partial order

**SOURCE lock prefix:** transaction in READ COMMITTED; (1) acquire Foundation `pg_advisory_xact_lock_shared(71001,1)`; (2) Foundation registered command key advisory lock namespace 71002 and canonical-intent/terminal receipt validation (recheck present actor/grants before returning); (3) sorted actor/target Foundation Principal and operation/approval locks per frozen Foundation contract; (4) D1 hierarchy: School/config/Student ID allocator/roll policy/roll allocator → Person/Student → Academic Class → Campus → Academic Year → Class Offering → Section Offering → child/history. All parents must be discovered before locking; fresh validation statement after each wait. Never acquire a lower ranked lock while holding a higher ranked one.

**Proposed execution dependency DAG — not executable instruction until cross-owner lock graph approved:**

| Order boundary | Required effect / locks | Source certainty |
|---|---|---|
| A | Verify authenticated active staff and enablement; derive handoff UUID + canonical expected revision and intent; compute allowed destination without trusting payload | Frozen dual authority, proposed typed intent |
| B | Take Foundation authorization/receipt/principal prefix. Replay exact terminal same-key with *current* dual-authority recheck; other intent/key denied | Frozen Foundation/D1 |
| C | Under jointly approved Admissions lock rank, stabilize application and handoff **before** reading their immutable Person, policy, destination and Finance IDs; retain their serialization until commit | **BLOCKED SC-06:** exact placement of Admissions locks in global D1 ranking not frozen |
| D | At approved Finance rank/fence, serialize verified REQUIRED obligation and reversal against D1 consumption; reject stale/reversed/missing; NOT_REQUIRED verify frozen published policy | **BLOCKED SC-03/06:** Finance interface/rank missing |
| E | Acquire D1 School row / Student-ID allocator and prelock effective roll policy + allocator **before** Person and academic destination; validate policy uniquely effective on placement date and number historical ownership | Frozen rank, **DB-02 historical ownership policy unresolved**, cross-owner rank insertion C/D unresolved |
| F | Lock canonical Person, reject `students.person_id` existing Student, recheck identity_resolution Person/version; sort multi-Person IDs where involved | Frozen person uniqueness, proposed identity revision |
| G | Lock Academic Class → Campus → Year → Class Offering → Section Offering; revalidate offering states and same-school exact ancestry; check capacity over entire accepted enrollment effective interval | Frozen D1 rank/capacity, placement date SC-04 candidate |
| H | Revalidate *current* dual staff permissions, Admissions READY and policy/stage/approval/offer/Finance versions after waits, in fresh SQL statements; reject any mismatch before mutating authoritative data | Frozen recheck principle; joint read permissions pending |
| I | Allocate permanent school Student ID from already-locked D1 server allocator; create Student and first status history/projection; create accepted PRIMARY enrollment and use **final assembled** D1 roll allocator; attach existing approved capacity-override evidence iff needed | Frozen atomic business effect; **D1 implementation owner** must map internal call ordering and receipt binding |
| J | Guarded READY→CONSUMED handoff and ACCEPTED→CONSUMED application; atomically bind Student, actor, terminal receipt; write one identifier-only `student.created` audit/outbox and typed result; commit | Frozen atomicity, DB-03 candidate constraints |

**Critical nuance:** steps A–J describe **effect order**, not a false total order of SQL row locks: C/D must be placed in a single proven global lock DAG relative to E/F/G, and may need earlier FK-safe discovery prior to Foundation receipt flow. If locking Admissions application/handoff first would trigger later School/Person parent FK locks and invert D1, revise joint execution design, not D1's frozen order. In particular, no `FOR UPDATE` on Section followed by a first-time School/roll allocator lock, and no Finance reversal path that holds Finance row while waiting on Admissions/Student while D1 holds those in reverse. The frozen D1 `d1_enrollment_place_prelock_roll` is a required integration consideration; D1 owners must inspect the assembled final call tree of create/placement, MOVE/END and policy operations and verify there is **no** unexamined inverse edge.

**Important sequencing ambiguity:** candidate handoff `section_id` in #79 is Section Offering ID, not global logical class/section name. Verified `school_student_id` allocation is through D1's `student_id_allocator_states`, NOT Admissions `admission_number_series`. No future student.create argument may claim `capacity_override=true` or manually choose a roll. The effect-order list intentionally places capacity *evaluation* before Student/Enrollment creation and uses D1's validated override contract; SQL placement helper may perform these under approved locks after Student core is inserted inside the same transaction. Exact function nesting is SC-05/06 work.

## 6. Genuine two-session adversarial test schedule and durable outcomes

These are **future test specifications only**, not executed; tests must observe real pg_locks/blocked sessions, use deterministic barrier/release orchestration rather than sleeps as sole evidence, commit winner, force constraints IMMEDIATE and inspect final durable DB state in third session. Failed transaction is ROLLBACK, not fake simulated success. Record original/canonical intent, keys, receipts and event IDs; no privileged fabricated handoff as positive fixture.

| Test | Session A / Session B, observed contention | Expected durable result | Forbidden partial effect |
|---|---|---|---|
| H01 same handoff two consume keys | A locks READY after auth; B different key blocks on shared handoff/anchor; A commits | one CONSUMED, one Student/status/PRIMARY/roll/Student ID/admission number receipt and event; B already-used denial | second Student or successful second key; two `student.created` |
| H02 duplicate Person, two applications | A creates from handoff X; B attempts handoff Y resolved to same Person; Person uniqueness lock/write contention | one Student; losing application remains unconsumed or is invalidated under approved state rules; B rejection with no new allocation | duplicate Student for canonical Person, two permanent Student IDs committed for failed second intake |
| H03 READY invalidation vs create | A invalidates after locking candidate; B create waits; reverse interleaving repeated | invalidation first ⇒ INVALIDATED, no Student; create first ⇒ CONSUMED, invalidation loses without history erasure | both terminal statuses or Student with INVALIDATED handoff |
| H04 Finance reversal vs create | A Finance reverses verified obligation under agreed fence, B D1 consumes; repeat reversed priority | reversal first ⇒ stale clearance denial, unused invalidated/blocked READY; creation first ⇒ valid CONSUMED and post-create Finance remediation | Student committed against prior committed reversal; auto-delete Student after reversal |
| H05 final seat | A/B different Persons, same last effective slot, lock Class/Section aggregate | exactly one initial PRIMARY placement accepted; loser full-capacity unless its own preapproved D1 override applies | two ordinary placements beyond bound; missing capacity exception evidence |
| H06 roll policy cutover | A DB-02 replacement/END, B new intake prelocks school/roll pool; repeat order | policy winner serializes; intake uses exactly one currently effective policy & D1 namespace; deny if gap/invalid pool | invented allocator, historical persistent numeric reuse if RP-03 forbids it, mixed policy/roll ancestry |
| H07 cancellation vs create | A accepts cancellation and invalidates READY; B attempts consume; repeat opposite order | cancellation first ⇒ no Student; create first ⇒ CONSUMED and later cancellation denied in Admissions | CONSUMED then canceled application without D1 correction |
| H08 permission revoke vs create | A revokes student's create/place authority under Foundation EXCLUSIVE school auth lock; B create uses SHARED and rechecks | revocation first ⇒ denial/no effects; creation first ⇒ success authorized at serialization point, later grants revoked | success after revoke committed first; replay reveals past result to revoked actor |
| H09 lost response ACK | A commits successful intake but response dropped; B (same authenticated actor) retries exact same command-key/intent | same retained Student ID/receipt returned after current authorization, no new event/number/roll | second creation, different stored result or revoked-data leak |
| H10 backend failure before commit | A injects failpoint after Student/status or roll insertion prior to commit; B retries same key after A rollback | zero A effects and unchanged READY; B may succeed once if all current conditions still hold | stranded CONSUMED, counter gap from rolled-back transaction, orphan Student/roll/outbox |

**Additional hostile variants:** simultaneous offer DECLINE/READY issuance, post-issue document correction, stage revision or identity rebind, stale acceptance approval, future-dated capacity change, policy interval boundary, wrong-campus role-only actor, malformed handoff UUID, SQL owner-forged handoff denial at normal actor boundary, same-key changed intent, terminal replay after revocation, crash after commit before response, cross-school Person/number FK, number-profile collision/overflow, full-class and full-section separately. For H04/H06/H08, outcomes are **conditional contracts**: no exact integrated test can claim PASS until DB-08/DB-09, DB-02 and Foundation/D1 owners supply their corresponding lock/fence implementations.

## 7. SC-01…SC-07 decision sheet and concrete external prerequisites

Every SC gate remains **PENDING OWNER APPROVAL**. Choose APPROVE RECOMMENDATION / APPROVE ALTERNATIVE WITH ADR / REJECT. No silent approvals.

| ID | Exact owner-facing choice | Recommended candidate (NOT frozen) | Required external sign-off |
|---|---|---|---|
| SC-01 | Person bound at draft vs submit; what counts as final stage+offer readiness; can policy-required stage have an exception; withdrawal/cancellation state vocabulary | draft may be unresolved, Person must be resolved before SUBMITTED; typed outcome for each policy stage; offer mandatory only if published stage config says so; decline blocks READY; approval-only typed exceptions cannot waive identity/Finance | Admissions owner+security/product, exact policy table and reviewer rule |
| SC-02 | Is `READY→CONSUMED` / `READY→INVALIDATED` terminal-only, with one CONSUMED ever per application and retained issue/consume receipts? | yes; immutable snapshot + partial unique + guarded state transition; reissue only from INVALIDATED after full current reacceptance | Admissions owner / Foundation receipt schema / D1 consumer |
| SC-03 | What Finance clearance qualifies and which reversal serialization proof suffices? | policy NOT_REQUIRED requires no Finance refs; REQUIRED blocks without Finance-issued versioned verification; synchronous fenced recheck before D1 commit | **DB-08/DB-09 Finance**: obligation identity, verification typed API, ownership/RLS, adjustments/credits/refunds and reversal ordering |
| SC-04 | Placement effective business date, Class/Section capacity, override, Student ID format, roll ownership across revision/Student | exact accepted Section Offering and selected D1 business date; capacity always rechecked; Student ID/roll allocated only at D1 creation; no seat reservation by offer | **D1 owner and DB-02**: final allocator namespace & RP-03 historical reservation, RP-02 date/cutover, RP-07 current allocator locks |
| SC-05 | Fixed P0 input/result/receipt shape and signed actor/expected revision semantics | `(handoff_uuid,expected_app_version,expected_handoff_revision,command_key)`; minimal result `(student_uuid,school_student_id,admission_number,initial_enrollment_uuid,roll_uuid,receipt_uuid)`, server-derived actor/section | D1 student.create owner; Foundation exact typed receipt allowlists and permissions |
| SC-06 | Does single global order allow Admissions and Finance locks without School/Person/Offering inversion; what are winner/loser and stale responses? | prove joint lock DAG before any command; Foundation SHARED lock+receipt, School→policy/allocator→Person→Class→Campus→Year→Offering→Section; attach Admissions/Finance only at reviewed ranks | D1 owner, **DB-02 RP-07**, **DB-08/DB-09 reversal fence**, Foundation permission-lock owners |
| SC-07 | Which trusted fixture and independent CI/upgrade evidence demonstrate real package boundary? | Admissions protected ISSUE → current authenticated D1 CREATE; 10 true two-session races, negative ACL, rollback, replay, clean install and populated upgrade, exact-head CI; no owner-only forged proof | independent Admissions/D1/Finance review and deployment owner |

**DB-02 direct dependency:** PR #101 status PRODUCT DECISION REQUIRED, RP-03 permanent historic roll numeric ownership vs superseded collision filtering; RP-07 shared School→policy→allocator prefix including MOVE/END; RP-02 effective date; not an accepted change command. **DB-08/DB-09 direct dependency:** neither a verified admission obligation contract nor an atomic reversal lock/fence, versioned checked Finance proof or Finance FK names is installed/verified. **D1 owner direct dependency:** protected student.create still disabled; exact typed result/receipt, own Student ID allocator input and final actual function call graph are not implemented. **Foundation security dependency:** Admissions proposed operations/permissions, route reviewers, file purposes and new event vocabulary require controlled new registration and independent review, not this branch.

## 8. Migration/validation gate, approvals and stop line

Future allowed sequence only *after* sign-off: (1) Admissions own additive number/policy/application/history tables and receipt/strict FORCE RLS; (2) document/test/offer/exception stage evidence; (3) real Finance bridge after Finance owner approval; (4) protected READY issue/invalidate and stored evidence bindings; (5) separately authored and reviewed D1 student.create consumer; (6) combined FK validation, permission/approval/audit/outbox and truly independent accepted two-session tests; (7) populated-upgrade and clean-install with Foundation regressions and migration safety. No existing D1 SQL, Foundation, Finance, DB-01/DB-02 files, acceptance tracker, GitHub Actions or hosted database changes are allowed in DB-03.

**Decision:** DB-03 Admissions atomic handoff contract is ready for **owner review only**, not implementation readiness approval or student.create activation. Owner must approve SC-01…SC-07 and Finance/DB-02/D1 lock and authorization prerequisites first.
