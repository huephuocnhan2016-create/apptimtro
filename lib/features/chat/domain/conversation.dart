class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.roomId,
    required this.roomTitle,
    required this.participantId,
    this.roomImageUrl,
    this.participantName,
    this.participantAvatarUrl,
    this.createdAt,
  });

  final String id;
  final String roomId;
  final String roomTitle;
  final String participantId;
  final String? roomImageUrl;
  final String? participantName;
  final String? participantAvatarUrl;
  final DateTime? createdAt;

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'];
    return ChatConversation(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      roomTitle: json['roomTitle'] as String? ?? '',
      participantId: json['participantId'] as String,
      roomImageUrl: json['roomImageUrl'] as String?,
      participantName: json['participantName'] as String?,
      participantAvatarUrl: json['participantAvatarUrl'] as String?,
      createdAt: rawCreatedAt is String
          ? DateTime.tryParse(rawCreatedAt)
          : null,
    );
  }
}
