# DB03 S15 — owner choice: automatic or applicant-specific admission fee

**Owner selection, 29 October 2026.** The school administrator needs two supported ways to determine an applicant's admission fee:

1. **Automatic:** the school configures an admission-fee rule. The application selects the matching published, effective rule for its authorized destination and academic context. Finance records the assessed amount and exact rule revision.
2. **Manual for selected applicants:** an authorized school administrator may set or change the amount for an individual application. This is a retained, applicant-specific commercial decision with actor, scope, reason, prior value/revision, and current application version. Finance independently verifies the decision and records an assessment. It does not silently edit a published rule or rewrite an old assessment.

The school may use automatic fees generally and choose manual amounts for individual applicants. Manual selection must be explicit, not an inference from a missing automatic rule. A manual change after assessment requires a later Finance correction/reassessment with original facts retained. Any prior allocation or clearance must be revalidated and cannot remain current solely because a screen displays the changed amount.

## Required boundaries for implementation

- The parent-uploaded bank slip's claimed amount and an issued receipt are payment facts, never the fee to assess. A mismatch may be a partial payment, advance or overpayment, subject to a later Finance allocation policy.
- A fee of zero or an authorized waiver still needs an explicit Finance-authorizer clearance before final admission. A school administrator's mode choice or manual amount cannot issue that clearance.
- Automatic selection must bind a published rule revision, School, Campus, AcademicYear, permitted destination, effective interval and currency. There must be one unambiguous matching rule or assessment fails closed. Rule revisions remain retained.
- Manual selection must bind the exact application and version, School/Campus/year/currency, authorized administrator and current permission/scope, reason, previous decision, and idempotent audit/outbox. A new decision supersedes rather than updates the old record. Finance must attest the winning revision before assessment.
- Assessments require separate Finance authority and retain gross amount, any authorized waiver or adjustment, net amount, terms source and revision, application version, and currency. Do not use Student-bound DB08 obligations as a pre-Student substitute.
- Allocation to the same applicant obligation and current Finance clearance follow assessment. Receipt issuance alone leaves the payment unallocated and the DB03 S10 gate unavailable.

## Current implementation dependency

The executable DB03 draft currently stores only an unresolved `DRAFT` application; its `policy_version_id` and destination are absent. Therefore it cannot choose a published fee rule by grade or other destination yet. No numeric fee rule, manual pricing command, positive assessment, allocation or clearance is installed by this decision record. Before creating the automatic source, the product owner must select the rule's matching dimension (for example, a common Campus/AcademicYear amount versus destination grade/class), and the Admissions destination contract must exist. The manual path can then be modeled as an exceptional override of the selected automatic source or as the explicit source where no automatic rule applies, with both outcomes checked by Finance.
