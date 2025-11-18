import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionService {
  SubscriptionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Duration defaultDuration = const Duration(days: 30);

  Duration get gracePeriod => const Duration(days: 5);

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
    Duration? duration,
  }) async {
    final subRef = _firestore.collection('subscriptions').doc(subscriptionId);
    final effectiveDuration = duration ?? defaultDuration;

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
      final end = Timestamp.fromDate(DateTime.now().add(effectiveDuration));

      transaction.update(subRef, {
        'status': 'active',
        'startDate': start,
        'endDate': end,
        'expiresAt': end,
        'graceEndsAt':
            Timestamp.fromDate(end.toDate().add(gracePeriod)),
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
        'startDate': start,
        'endDate': end,
        'expiresAt': end,
        'graceEndsAt':
            Timestamp.fromDate(end.toDate().add(gracePeriod)),
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
        'expiresAt': end,
        'graceEndsAt':
            Timestamp.fromDate(end.toDate().add(gracePeriod)),
      }, SetOptions(merge: true));
    });
  }

  Future<void> markExpiredSubscriptions() async {
    final now = Timestamp.now();
    final snapshots = await _firestore
        .collection('subscriptions')
        .where('status', isEqualTo: 'active')
        .where('endDate', isLessThanOrEqualTo: now)
        .get();
    final batch = _firestore.batch();
    for (final doc in snapshots.docs) {
      final data = doc.data();
      final patientId = data['patientId'] as String;
      final doctorId = data['doctorId'] as String;
      batch.update(doc.reference, {'status': 'expired'});
      batch.update(
        _firestore
            .collection('patients')
            .doc(patientId)
            .collection('subscriptions')
            .doc(doc.id),
        {'status': 'expired'},
      );
      batch.update(
        _firestore
            .collection('doctors')
            .doc(doctorId)
            .collection('patients')
            .doc(patientId),
        {'status': 'expired'},
      );
    }
    if (snapshots.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  Future<bool> hasActiveSubscription({
    required String patientId,
    required String doctorId,
  }) async {
    final snapshot = await _firestore
        .collection('subscriptions')
        .where('patientId', isEqualTo: patientId)
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}
