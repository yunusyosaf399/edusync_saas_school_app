# Future Architecture Roadmap

These features are **not current implementation commitments**. They are listed so today's architecture does not unnecessarily block them.

## 1. Attendance hardware ecosystem

### Fingerprint / biometric terminals

Future requirement. Likely integration through vendor/device adapters. The canonical attendance service should accept validated identity/time events without depending on the vendor schema.

Do not decide now where biometric templates live. That requires a separate privacy, legal, retention and security design.

### Camera / face-recognition attendance

Future high-complexity feature. Possible architecture:

`camera/edge device -> recognition/anti-spoof service -> confidence + identity event -> validation policy -> attendance service`

Potential requirements later:

- device registry
- camera location/campus mapping
- consent/legal policy
- retention policy for images/video
- face-template/model governance
- false positive/negative handling
- anti-spoofing
- human override/review
- confidence thresholds
- audit of automated attendance decisions

None of these should be implemented simply by adding a `face_vector` column to students.

### RFID / NFC

Future medium-complexity feature. Student card/token mapping should be separable from student identity so cards can be issued/replaced/revoked.

### Advanced QR anti-fraud

Possible future improvements: rotating/signed tokens, device confirmation, photo confirmation, token expiry/versioning.

## 2. Transport GPS

Keep vehicle/route/student-assignment core independent from GPS provider. Future telemetry should be provider-adapted and not required for basic transport operations.

## 3. Messaging channels

Notification engine should have channel/provider abstraction so WhatsApp or other future channels do not require changing domain events.

## 4. Payment gateways

Payment ledger/evidence model should accept future gateway webhook confirmations using idempotency and provider transaction references. Do not model today's bank screenshot workflow in a way that prevents automated payment confirmation later.

## 5. Inventory/assets

Large optional future domain covering procurement, assets, assignments, location, maintenance and disposal. Keep it modular rather than adding asset columns to unrelated tables.

## 6. IoT/smart classroom/CCTV

Treat as external device/event domains. Use device registry/integration adapters where necessary. CCTV integrations introduce substantial privacy/security requirements and should not be mixed into ordinary school records.

## 7. Government/accounting integrations

Prefer canonical internal models plus mapping/export/integration adapters. Do not reshape core student/finance data around a single external government's or accountant's schema.

## 8. Localization

English initially. Keep UI strings localizable and avoid using translated display text as database identifiers. Future Arabic/Urdu may require RTL layouts.

## 9. AI evolution

Future possibilities include voice interfaces, advanced tutoring, teaching-plan generation, predictive analytics and early-warning models. Preserve clean historical data and explicit authorization; do not make AI model output the authoritative business record without review/workflow where needed.

## 10. Certificate verification

Stable certificate/document identifiers can support future verification mechanisms. Blockchain is only one possible implementation and should not be assumed now.
