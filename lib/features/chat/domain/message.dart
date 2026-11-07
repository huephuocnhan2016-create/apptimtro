import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    this.createdAt,
    this.pending = false,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;
  final bool pending;

  factory Message.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final createdAt = data['createdAt'];
    return Message(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      pending: doc.metadata.hasPendingWrites,
    );
  }
}
