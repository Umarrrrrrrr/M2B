# Mother to Be (M2B)

Flutter client for the Mother to Be FYP. The app currently supports:

- Firebase email/password authentication for patients and doctors.
- Patient dashboard with profile summary, health-record timeline, and the ability to log new vitals.
- Doctor dashboard listing doctor profile data and subscribed patients with their latest readings.
- Subscription service layer that stores patient↔doctor relationships in Firestore.

## Project structure

```
lib/
 ├─ app.dart                  # MaterialApp + auth gate routing
 ├─ main.dart                 # Firebase bootstrap
 ├─ auth/auth_form.dart       # Combined login / signup flow
 ├─ patient/patient_dashboard.dart
 ├─ doctor/doctor_dashboard.dart
 ├─ services/subscription_service.dart
 └─ widgets/info_chip.dart
```

## Subscription data flow

Subscriptions connect a patient to a doctor through three collections:

| Collection | Document | Notes |
|------------|----------|-------|
| `subscriptions/{id}` | `patientId`, `doctorId`, `status (pending/active/expired)`, `startDate`, `endDate` | Canonical record for billing/auditing. |
| `patients/{patientId}/subscriptions/{subscriptionId}` | `doctorId`, `status`, `requestedAt`, `startDate`, `endDate` | Patient‑side view of all requests. |
| `doctors/{doctorId}/patients/{patientId}` | `subscriptionId`, `status`, `linkedAt` | Doctor’s roster + quick lookup for dashboards. |

### Flow
1. Patient taps “Request doctor” and enters a doctor ID. `SubscriptionService.requestSubscription` creates the pending documents above.
2. Doctor sees the request in the doctor dashboard and taps “Approve”, which calls `SubscriptionService.approveSubscription`. The service flips the status to `active` and stamps the start/end dates (30 days by default).
3. Active subscriptions unlock access to patient health records (enforced via Firestore rules discussed in the SDD).

## Next steps

- Hook up real UI/UX for browsing doctors and presenting subscription requests.
- Add Cloud Functions/HTTPS endpoints for payments, notifications, and chat.
- Flesh out doctor approval workflows and admin tooling.
