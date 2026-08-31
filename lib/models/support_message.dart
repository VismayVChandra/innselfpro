class SupportMessage {
  final String id;
  final String userId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.userId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  factory SupportMessage.fromMap(Map<String, dynamic> map) => SupportMessage(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        senderId: map['sender_id'] as String,
        body: map['body'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

/// One row of the admin's support inbox (admin_list_support_threads).
class SupportThreadSummary {
  final String userId;
  final String fullName;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;

  const SupportThreadSummary({
    required this.userId,
    required this.fullName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  factory SupportThreadSummary.fromMap(Map<String, dynamic> map) => SupportThreadSummary(
        userId: map['user_id'] as String,
        fullName: map['full_name'] as String? ?? '',
        lastMessage: map['last_message'] as String? ?? '',
        lastMessageAt: DateTime.parse(map['last_message_at'] as String),
        unreadCount: map['unread_count'] as int? ?? 0,
      );
}
