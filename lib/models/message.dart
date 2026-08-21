class Message {
  final String id;
  final String jobId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.jobId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['id'] as String,
        jobId: map['job_id'] as String,
        senderId: map['sender_id'] as String,
        body: map['body'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
