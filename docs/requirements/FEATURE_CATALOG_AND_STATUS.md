# Feature Catalog and Status

Legend: **CORE** = intended core product; **OPTIONAL** = can be enabled/disabled; **FUTURE** = deferred; **CROSS-CUTTING** = applies to many modules.

| Domain | Feature | Status | Important rule |
|---|---|---|---|
| Client | Android | CORE / CONFIRMED | First-class current target of one Flutter codebase; implementation follows phased delivery |
| Client | Windows | CORE / CONFIRMED | First-class current target of the same codebase |
| Client | Web | CORE / CONFIRMED | First-class authenticated application target; browser capability restrictions apply |
| Client | Responsive/adaptive presentation | CORE / CONFIRMED | Shared logic, width/interaction-based layouts; exact breakpoints TBD |
| SaaS | Control plane / school routing | CORE | Store customer/deployment metadata, not school operational records |
| SaaS | One Supabase project per customer school | CORE | Primary tenant isolation boundary |
| School | School profile/configuration | CORE | Configurable name/code/logo/address/currency/timezone/numbering |
| School | Multiple campuses | CORE | Campus-scoped operations with senior cross-campus access |
| Academic | Academic years | CORE | Custom dates; historical access retained |
| Academic | Configurable levels/classes/sections/rooms/capacity | CORE | Do not hard-code Play Group -> Grade 12 list |
| Student | Student profile/status | CORE | Preserve important history |
| Student | Family/shared parent account | CORE | One family login may see multiple linked children |
| Student | Enrollment history | CORE | Year/campus/class/section/roll history is authoritative |
| Admission | Configurable application workflow | CORE | Verification/test/interview may be skipped |
| Academic | Curriculum/subjects/electives | CORE | Class/year-specific and student optional subjects |
| Staff | Teacher/employee profiles | CORE | Teacher may also be parent |
| Academic | Teacher assignments | CORE | Different teacher per section/subject; multiple campuses possible |
| Timetable | Manual timetable | CORE | Prevent conflicts |
| Timetable | Automatic generation | CORE/ADVANCED | Manual adjustment remains possible |
| Attendance | Manual attendance | CORE | Morning/first-class primary pattern |
| Attendance | QR attendance | CORE | Same canonical attendance truth |
| Attendance | Correction approvals | CORE | History + reason + approver |
| Attendance | Biometric/fingerprint devices | FUTURE | Adapter/event into canonical attendance |
| Attendance | Camera/face recognition | FUTURE | Adapter/vision service + validation; privacy-heavy |
| Attendance | RFID/NFC | FUTURE | External token mapping + reader adapter |
| Learning | Homework/assignments/projects/worksheets | CORE | Submission, marks, feedback, late state |
| Learning | Online tests | CORE/ADVANCED | MCQ/T-F/short/essay, timer, attempts |
| Exams | Custom assessment/exam types | CORE | Unlimited/custom per year |
| Exams | Grading/GPA/pass rules | CORE | School-defined |
| Results | Review/publish/lock/correction | CORE | Exam Controller gate |
| Finance | Fee types/structures/frequencies | CORE | Campus/class/student/year configurable |
| Finance | Discounts/scholarships | CORE | Policy + custom/recurring |
| Finance | Partial/advance/overpayment | CORE | Allocation/credit/refund support |
| Finance | Bank/wallet evidence | CORE | Pending verification before official payment |
| Finance | Dynamic invoice/receipt | CORE | Do not auto-store PDFs |
| Finance | Direct payment gateway | FUTURE | Webhook/provider adapter |
| Parent | Parent portal | CORE | Linked children only |
| Student | Student portal | CORE | Personal academic information |
| HR | Employees/departments/designations/contracts | CORE | Configurable |
| Payroll | Monthly payroll | CORE | Bonus/overtime/manual deduction; lock final payroll |
| Leave | Student and employee leave | CORE | Configurable approval chains |
| Library | Catalog/borrow/return/purchase | OPTIONAL | Students + teachers |
| Transport | Routes/vehicles/drivers/stops | OPTIONAL | GPS deferred |
| Transport | Live GPS | FUTURE | Provider adapter |
| Hostel | Buildings/rooms/beds/allocation | OPTIONAL | Can be disabled |
| Medical | Student health/nurse incidents | OPTIONAL/SENSITIVE | Stronger permissions |
| Documents | Source document uploads | CORE | Private structured Storage, <=1 MB target |
| Documents | Dynamic certificates/cards/PDFs | CORE | Generate on demand |
| Notifications | In-app | CORE | Read/unread/history |
| Notifications | Push | CORE | Provider implementation TBD |
| Notifications | Email | CORE | App password initially; abstraction recommended |
| Notifications | WhatsApp | FUTURE | Provider/channel adapter |
| Calendar | Events/holidays/exams/PTM/etc. | CORE | Notifications supported |
| Reporting | PDF/Excel/CSV/print/custom reports | CORE | Permission-aware |
| Search | Global search | CORE | Permission-aware |
| Audit | Sensitive action audit | CROSS-CUTTING | Super Admin also audited |
| Workflow | Generic approval engine | CROSS-CUTTING | Typed workflows, configurable chains |
| Automation | Immediate/scheduled/event rules | CROSS-CUTTING | Avoid hard-coded notification spaghetti |
| Offline | Encrypted local cache and sync | CROSS-CUTTING | Shared conflict/idempotency/reauthorization contracts; storage technology TBD per target; no unencrypted sensitive fallback |
| Backup | DB/config/deployment recovery | CROSS-CUTTING | Restore rehearsal before GA |
| AI | Teacher assistant | CORE/ADVANCED | Permission-aware |
| AI | Student tutor/homework assistant | CORE/ADVANCED | Permission-aware |
| AI | Parent/principal assistants | CORE/ADVANCED | Permission-aware |
| AI | Predictive analytics/early warning | FUTURE/ADVANCED | Historical data quality + explainability |
| Operations | Inventory/assets | FUTURE | Large optional domain |
| Platform | IoT/smart classroom/CCTV | FUTURE | Provider-neutral integration only |
| Localization | English | CORE | Initial language |
| Localization | Urdu/Arabic/RTL/others | FUTURE | Keep UI localizable |
