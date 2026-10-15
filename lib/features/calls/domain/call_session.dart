class CallSession {
  const CallSession({
    required this.id,
    required this.status,
    required this.roomId,
    required this.channelName,
    this.callerName,
    this.receiverName,
    this.token,
    this.appId,
    this.uid,
  });

  final String id;
  final String status;
  final String roomId;
  final String channelName;
  final String? callerName;
  final String? receiverName;
  final String? token;
  final String? appId;
  final int? uid;

  factory CallSession.fromJson(Map<String, dynamic> json) {
    final caller = json['caller'];
    final receiver = json['receiver'];
    return CallSession(
      id: json['id'] as String,
      status: json['status'] as String,
      roomId: json['roomId'] as String,
      channelName: json['channelName'] as String? ?? '',
      callerName: caller is Map<String, dynamic>
          ? caller['fullName'] as String?
          : null,
      receiverName: receiver is Map<String, dynamic>
          ? receiver['fullName'] as String?
          : null,
      token: json['token'] as String?,
      appId: json['appId'] as String?,
      uid: (json['uid'] as num?)?.toInt(),
    );
  }

  bool get hasAgoraCredentials =>
      token != null && appId != null && uid != null && channelName.isNotEmpty;
}
