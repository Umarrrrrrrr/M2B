import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorVerificationService {
  DoctorVerificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('doctor_verification');

  Future<void> submitDocuments({
    required String doctorId,
    required Map<String, dynamic> payload,
  }) async {
    final ref = _requests.doc(doctorId);
    await ref.set({
      ...payload,
      'doctorId': doctorId,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> approveDoctor({
    required String doctorId,
    required String adminId,
  }) async {
    await _firestore.runTransaction((transaction) async {
      transaction.update(_firestore.collection('doctors').doc(doctorId), {
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': adminId,
      });
      transaction.update(_requests.doc(doctorId), {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': adminId,
      });
    });
  }

  Future<void> rejectDoctor({
    required String doctorId,
    required String adminId,
    String? reason,
  }) async {
    await _requests.doc(doctorId).set({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': adminId,
      if (reason != null) 'reason': reason,
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRequests({
    String status = 'pending',
  }) {
    return _requests.where('status', isEqualTo: status).snapshots();
  }
}
