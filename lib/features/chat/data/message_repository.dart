import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/conversation.dart';
import '../domain/message.dart';
import 'chat_api.dart';

class MessageRepository {
  MessageRepository(this.api, this._firestore);

  final ChatApi api;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('conversations');

  Future<List<ChatConversation>> conversations() async =>
      (await api.conversations()).map(ChatConversation.fromJson).toList();

  // Sinh viên mở chat từ card phòng: id hội thoại do Postgres cấp, doc
  // Firestore đầu tiên do một trong hai phía tạo.
  Future<String> openConversation({
    required String roomId,
    required String landlordId,
    required String myUid,
  }) async {
    final id = await api.openConversation(roomId);
    await ensureConversationDoc(
      id,
      participantIds: [myUid, landlordId],
      roomId: roomId,
    );
    return id;
  }

  Future<void> ensureConversationDoc(
    String conversationId, {
    required List<String> participantIds,
    required String roomId,
  }) async {
    final doc = _conversations.doc(conversationId);
    final snapshot = await doc.get();
    if (snapshot.exists) return;
    await doc.set({'participantIds': participantIds, 'roomId': roomId});
  }

  Stream<List<Message>> messages(String conversationId) => _conversations
      .doc(conversationId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots(includeMetadataChanges: true)
      .map((query) => query.docs.map(Message.fromDoc).toList());

  Future<void> send(String conversationId, String senderId, String text) =>
      _conversations.doc(conversationId).collection('messages').add({
        'senderId': senderId,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
}
