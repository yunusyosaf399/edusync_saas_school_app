# DB08 F6 — Student discount choice (owner decision, design gate)

The school can assign a discount to one Student after the full fee has been selected. It chooses **one value type** for that assignment: a fixed amount in the School currency's minor units, or a percentage of the selected gross fee. It also chooses **one application scope**: recurring monthly tuition, or one specifically identified assessed charge. A recurring assignment applies to eligible monthly tuition periods within its retained effective dates; the charge-specific assignment is consumed by that charge only. These are independent choices: either value type may be used with either scope.

| Selected gross | Configuration | Discount | Remaining fee |
| ---: | --- | ---: | ---: |
| 10,000 minor units | recurring tuition, 10% | 1,000 | 9,000 |
| 10,000 minor units | specific charge, fixed 2,000 minor units | 2,000 | 8,000 |

The percentage basis is the *selected published full fee* for the charge, including any F5 Student-specific full-price override. For example, a Student-specific gross fee of 15,000 with a 10% tuition discount produces 1,500 discount and 13,500 remaining. A fixed discount is denominated in the same currency as that charge. The resulting discount must be nonnegative and cannot exceed the gross fee. A 100% or equal fixed discount can yield zero remaining fee, but it does not by itself mark the charge paid or authorize admission clearance.

## Source and lifecycle

The configuration is a Finance-owned, Student-bound, immutable versioned instruction with its scope, value type/value, currency, effective period or single charge target, reason, requester, approval identity, and audit/outbox receipt. Activation requires the School's configured independent Finance approval; an unapproved instruction has no billing effect. Corrections and termination create later retained decisions, never overwrite an assessed charge. The specific-charge target must exist and belong to the same Student and School; a recurring instruction applies only to `TUITION`/`MONTHLY` charges, not transport, admission or other categories. A charge records a separate immutable discount adjustment linked to its configuration version and gross obligation. The gross obligation remains unchanged. A missing or conflicting effective instruction fails closed; the client cannot supply a net amount or mark a discount as payment.

The initial executable increment should permit at most one effective discount per Student/eligible obligation; stacking, combining multiple scholarships, and precedence between concurrent discounts are not implied by this decision. Repeating an assessment or application key must return the same charge and discount, with no duplicate adjustment. Subsequent fee revisions affect only future gross assessments; previously assessed gross and discount facts stay retained. Billing, invoices, payment allocation, admission clearance and reversals will read the retained gross/adjustment facts rather than recalculate history from today's settings.

## Release and verification gate

F6 is a design decision only. Before an executable discount command or net-charge arithmetic is activated, record the school's percentage precision and minor-unit rounding rule, approval policy/threshold configuration, effective-date replacement behavior, and how a charge-specific adjustment interacts with an already applied recurring discount. The safe first increment should deny ambiguous overlapping discounts and require independent approval for every discount until a threshold policy is explicitly configured. Test fixed/percentage and recurring/single-charge paths, the F5 override basis, exact replay, caps, wrong Student/category/currency, permission and reviewer revocation, concurrent activation/assessment, retained history and failed-install rollback. The current F1–F5 SQL does not apply discounts, and no hosted School project is modified by this decision.
