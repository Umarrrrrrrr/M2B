import 'package:cloud_firestore/cloud_firestore.dart';

class PushTokenService {
  PushTokenService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Registers or updates a device token for the current user.
  Future<void> registerToken({
    required String uid,
    required String token,
    required String platform,
  }) async {
    final devicesRef =
        _firestore.collection('users').doc(uid).collection('devices');
    await devicesRef.doc(token).set({
      'token': token,
      'platform': platform,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeToken({
    required String uid,
    required String token,
  }) async {
    final devicesRef =
        _firestore.collection('users').doc(uid).collection('devices');
    await devicesRef.doc(token).delete();
  }
}
