class MessageModel {
  final int id;
  final String title;
  final String summary;
  final String details;
  final String source;
  final String createdAt;
  final String? readAt;
  final String reaction;
  final int likeCount;
  final int dislikeCount;

  MessageModel({
    required this.id,
    required this.title,
    required this.summary,
    required this.details,
    required this.source,
    required this.createdAt,
    this.readAt,
    required this.reaction,
    required this.likeCount,
    required this.dislikeCount,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      details: json['details'] ?? json['message_text'] ?? json['text'] ?? json['message'] ?? '',
      source: json['source'] ?? json['sender'] ?? json['sender_type'] ?? 'user',
      createdAt: json['created_at'] ?? '',
      readAt: (json['user_action'] is Map) ? json['user_action']['read_at'] : null,
      reaction: (json['user_action'] is Map) ? (json['user_action']['reaction'] ?? 'none') : 'none',
      likeCount: (json['stats'] is Map) ? (json['stats']['like_count'] ?? 0) : 0,
      dislikeCount: (json['stats'] is Map) ? (json['stats']['dislike_count'] ?? 0) : 0,
    );
  }

  bool get isRead => readAt != null;
}