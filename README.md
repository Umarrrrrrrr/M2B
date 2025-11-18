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
 ├─ chat/chat_screen.dart
 ├─ patient/patient_dashboard.dart
 ├─ doctor/doctor_dashboard.dart
 ├─ dev/sample_seeder.dart    # Utility to insert demo docs (optional)
 ├─ services/chat_service.dart
 ├─ services/push_token_service.dart
 ├─ services/device_token_registrar.dart
 ├─ services/doctor_verification_service.dart
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

## Seeding sample data

For quick demos you can populate Firestore with a demo doctor + patient:

1. Ensure you’re signed in to the Flutter app (any user with write access).
2. Temporarily call the seeder from `main.dart`:
   ```dart
   import 'dev/sample_seeder.dart';

   Future<void> main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp(
       options: DefaultFirebaseOptions.currentPlatform,
     );
     await SampleSeeder().seed(); // add this line once
     runApp(const MyApp());
   }
   ```
3. Run `flutter run`, wait for the console to show “Observatory listening…”, then stop the app and remove the seeder line.

This writes:
- `doctors/demoDoctor`
- `patients/demoPatient` with a sample health record
- `users/demoDoctor|demoPatient`
- `subscriptions/demoPatient_demoDoctor` plus the nested references

After removal, rebuild the app and you’ll see the demo data in Firestore.

## Next steps

- Build chat UI on top of `ChatService` and add notifications when new messages arrive.
- Hook up real UI/UX for browsing doctors and presenting subscription requests.
- Add Cloud Functions/HTTPS endpoints for payments, notifications, and chat.
- Flesh out doctor approval workflows and admin tooling.

## Push notifications

- Device tokens are stored under `users/{uid}/devices/{token}` with metadata (`platform`, `updatedAt`).
- `DeviceTokenRegistrar` automatically requests permission and invokes `PushTokenService.registerToken` after login.
- `notifyExpiringSubscriptions` sends an FCM alert when a sub is within 3 days of expiry.
- `onSubscriptionApproved` (below) notifies both patient and doctor when status flips to active.
- Cloud Functions:
  - `expireSubscriptions`: runs daily and marks overdue subscriptions as `expired` while syncing the nested documents.
  - `notifyExpiringSubscriptions`: runs daily, looks for subscriptions expiring within 3 days, and sends FCM notifications to both patient and doctor if device tokens exist.
