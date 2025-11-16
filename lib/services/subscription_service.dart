import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionService {
  SubscriptionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Creates a pending subscription request from patient to doctor.
  Future<String> requestSubscription({
    required String patientId,
    required String doctorId,
  }) async {
    final docRef = _firestore.collection('subscriptions').doc();
    final now = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      transaction.set(docRef, {
        'patientId': patientId,
        'doctorId': doctorId,
        'status': 'pending',
        'createdAt': now,
        'startDate': null,
        'endDate': null,
      });

      final doctorPatientRef = _firestore
          .collection('doctors')
          .doc(doctorId)
          .collection('patients')
          .doc(patientId);
      transaction.set(doctorPatientRef, {
        'patientId': patientId,
        'subscriptionId': docRef.id,
        'status': 'pending',
        'linkedAt': now,
      });

      final patientSubsRef = _firestore
          .collection('patients')
          .doc(patientId)
          .collection('subscriptions')
          .doc(docRef.id);
      transaction.set(patientSubsRef, {
        'doctorId': doctorId,
        'subscriptionId': docRef.id,
        'status': 'pending',
        'requestedAt': now,
      });
    });

    return docRef.id;
  }

  /// Marks a subscription as active when a doctor approves.
  Future<void> approveSubscription({
    required String subscriptionId,
    required String doctorId,
    Duration duration = const Duration(days: 30),
  }) async {
    final subRef = _firestore.collection('subscriptions').doc(subscriptionId);

    await _firestore.runTransaction((transaction) async {
      final subSnap = await transaction.get(subRef);
      if (!subSnap.exists) {
        throw Exception('Subscription not found');
      }
      final data = subSnap.data()!;
      if (data['doctorId'] != doctorId) {
        throw Exception('Doctor mismatch');
      }

      final patientId = data['patientId'] as String;
      final start = Timestamp.now();
      final end =
          Timestamp.fromDate(DateTime.now().add(duration));

      transaction.update(subRef, {
        'status': 'active',
        'startDate': start,
        'endDate': end,
      });

      final doctorPatientRef = _firestore
          .collection('doctors')
          .doc(doctorId)
          .collection('patients')
          .doc(patientId);
      transaction.set(doctorPatientRef, {
        'patientId': patientId,
        'subscriptionId': subscriptionId,
        'status': 'active',
        'linkedAt': start,
      }, SetOptions(merge: true));

      final patientSubsRef = _firestore
          .collection('patients')
          .doc(patientId)
          .collection('subscriptions')
          .doc(subscriptionId);
      transaction.set(patientSubsRef, {
        'doctorId': doctorId,
        'subscriptionId': subscriptionId,
        'status': 'active',
        'startDate': start,
        'endDate': end,
      }, SetOptions(merge: true));
    });
  }
}
