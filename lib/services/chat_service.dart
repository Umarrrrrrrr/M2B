import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  ChatService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Returns the chat document ID for a patient/doctor pair.
  String chatId(String patientId, String doctorId) =>
      '${patientId}_$doctorId';

  Future<void> ensureChatExists({
    required String patientId,
    required String doctorId,
  }) async {
    final id = chatId(patientId, doctorId);
    final chatRef = _firestore.collection('chats').doc(id);
    final snapshot = await chatRef.get();
    if (!snapshot.exists) {
      await chatRef.set({
        'patientId': patientId,
        'doctorId': doctorId,
        'lastMessage': null,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> sendMessage({
    required String patientId,
    required String doctorId,
    required String senderId,
    required String senderRole,
    required String text,
  }) async {
    final id = chatId(patientId, doctorId);
    final chatRef = _firestore.collection('chats').doc(id);

    await ensureChatExists(patientId: patientId, doctorId: doctorId);

    final messageRef = chatRef.collection('messages').doc();

    await _firestore.runTransaction((transaction) async {
      transaction.set(messageRef, {
        'senderId': senderId,
        'senderRole': senderRole,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [senderId],
      });
      transaction.update(chatRef, {
        'lastMessage': text,
        'lastTimestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messageStream({
    required String patientId,
    required String doctorId,
  }) {
    final id = chatId(patientId, doctorId);
    return _firestore
        .collection('chats')
        .doc(id)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }
}
