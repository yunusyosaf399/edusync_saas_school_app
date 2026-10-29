# DB03 owner decisions — identity check, unresolved withdrawal and publication

**Owner-selected on 26 October 2026.** These are three actual product choices from the current conversation, not inferred from source tests or a blanket deployment approval. The exact questions and selections are retained in the [decision record](db03_owner_decisions_identity_drafts_publication_20261026.json).

| Question | Actual selection | Binding behavior |
|---|---|---|
| Who confirms an applicant's identity before submission? | **One authorized staff** | One currently authorized staff member checks the approved evidence and records an auditable verification. A second identity reviewer is not mandatory by default. Exact evidence source, current permission/scope and protected verification implementation remain required; a raw Person UUID/name or client boolean is not proof. |
| May an unverified unfinished application be withdrawn? | **Yes, retain history** | Authorized staff may withdraw an unresolved DRAFT without creating a Person just to close it. Retain the draft, history and reason; no hard delete or fabricated Person. This narrowly supersedes the older P2-D01 wording that permitted NULL Person only in DRAFT. It does not permit SUBMITTED without verified identity. |
| When do newly published admission rules start? | **Immediately** | Use a trusted server publication instant for new submissions. Existing submitted applications keep their original policy version and document requirements. No future/backdated publication or retroactive replacement of an application's rules follows from this selection. |

## Precise implementation consequences

P2-D01 still allows unresolved drafts and requires verified canonical identity **before SUBMITTED**. Its new terminal exception is WITHDRAWN reached directly from an unresolved DRAFT. A later schema must prove this edge from retained transition/provenance, not let any submitted application clear its Person because it now says WITHDRAWN. NULL Person is never a wildcard for submitted/in-progress/accepted/consumed intake. A withdrawn resolved or previously submitted application keeps its known Person and historical verification. Withdrawal authority, reason, expected version and canonical retry remain server checked.

Single-staff identity verification does not waive the independent reviewer for the separately approved `admission.test.skip` business command. It does not replace Finance-authorizer clearance, permit self-granted authority, create a Foundation Person adapter by declaration, or authorize staff matching solely by name. The same user may perform only actions for which their current configured permissions and target scope qualify.

Immediate publication and SUBMIT must serialize against the same approved publication/source locks. If old-policy submission wins first, it retains that immutable version; if new publication wins first, a new submission uses the new version or fails a stale expectation. Existing policy history is closed/retained consistently at the publication instant. Exact trusted SQL writer, publication route, profile retirement eligibility and temporal non-overlap implementation still require the P1 command increment; DB02's DATE-only Roll policy is not imported into this timestamptz policy contract.

## Simple school example

1. A receptionist starts Ali's Grade 1 application. Identity has not been checked yet, so it stays DRAFT.
2. One authorized staff member checks Ali's approved identity evidence and records the verification. Only then can the application be submitted.
3. If Ali's family stops before verification, staff can mark that draft WITHDRAWN. The record stays in history; no dummy Person or Student is created.
4. The school later publishes a new admission rule. It applies immediately to new submissions. An application already submitted under the old rule keeps the old rule.

These are selected intended business outcomes, not a claim that the full workflow is already executable. The first [S1 draft-configuration candidate](db03_s1_policy_draft_schema_candidate_20261026.md) creates only inactive configuration structures; it cannot publish, verify a Person, submit an application, clear Finance, issue READY or create a Student.

**Authorization scope:** product choices and the requested next implementation/review work. No executable hosted migration, production change, broad permission registration, operation enablement, new waiver of other workstreams' review requirements, or independent code acceptance is recorded here.
