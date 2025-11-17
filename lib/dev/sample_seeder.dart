import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility to insert demo doctors, patients, and sample data for local testing.
class SampleSeeder {
  SampleSeeder({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> seed() async {
    final doctorId = 'demoDoctor';
    final patientId = 'demoPatient';
    final subscriptionId = '${patientId}_$doctorId';

    final batch = _firestore.batch();

    final doctorRef = _firestore.collection('doctors').doc(doctorId);
    batch.set(doctorRef, {
      'fullName': 'Dr. Sana Ali',
      'email': 'demo-doctor@m2b.demo',
      'phone': '+92 123 4567890',
      'specialization': 'OB/GYN',
      'licenseNo': 'PMDC-12345',
      'experienceYears': 10,
      'isVerified': true,
      'subscriptionFee': 2500,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final patientRef = _firestore.collection('patients').doc(patientId);
    batch.set(patientRef, {
      'fullName': 'Sara Imran',
      'email': 'demo-patient@m2b.demo',
      'phone': '+92 987 6543210',
      'gestationalAgeWeeks': 24,
      'bloodType': 'B+',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(_firestore.collection('users').doc(doctorId), {
      'role': 'doctor',
      'email': 'demo-doctor@m2b.demo',
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(_firestore.collection('users').doc(patientId), {
      'role': 'patient',
      'email': 'demo-patient@m2b.demo',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final subscriptionRef =
        _firestore.collection('subscriptions').doc(subscriptionId);
    final now = Timestamp.now();
    final end = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 30)),
    );

    batch.set(subscriptionRef, {
      'patientId': patientId,
      'doctorId': doctorId,
      'status': 'active',
      'startDate': now,
      'endDate': end,
      'createdAt': now,
    });

    batch.set(
      _firestore
          .collection('patients')
          .doc(patientId)
          .collection('subscriptions')
          .doc(subscriptionId),
      {
        'doctorId': doctorId,
        'status': 'active',
        'startDate': now,
        'endDate': end,
      },
    );

    batch.set(
      _firestore
          .collection('doctors')
          .doc(doctorId)
          .collection('patients')
          .doc(patientId),
      {
        'patientId': patientId,
        'subscriptionId': subscriptionId,
        'status': 'active',
        'linkedAt': now,
      },
    );

    await batch.commit();

    await _firestore
        .collection('patients')
        .doc(patientId)
        .collection('healthRecords')
        .add({
      'source': 'manual',
      'heartRate': 82,
      'bloodPressure': {'systolic': 118, 'diastolic': 76},
      'temperature': 36.8,
      'notes': 'Feeling well, no complications reported.',
      'recordedAt': FieldValue.serverTimestamp(),
    });
  }
}
