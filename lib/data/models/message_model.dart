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

  static int _parseInt(dynamic val, [int fallback = 0]) {
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val != null) return int.tryParse(val.toString()) ?? fallback;
    return fallback;
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: _parseInt(json['id']),
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      details: json['details']?.toString() ?? json['message_text']?.toString() ?? json['text']?.toString() ?? json['message']?.toString() ?? '',
      source: json['source']?.toString() ?? json['sender']?.toString() ?? json['sender_type']?.toString() ?? 'user',
      createdAt: (json['created_at'] ?? json['createdAt'] ?? json['created'] ?? json['time'] ?? json['date'] ?? '').toString().isNotEmpty
          ? (json['created_at'] ?? json['createdAt'] ?? json['created'] ?? json['time'] ?? json['date']).toString()
          : DateTime.now().toIso8601String(),
      readAt: (json['user_action'] is Map) ? json['user_action']['read_at']?.toString() : null,
      reaction: (json['user_action'] is Map) ? (json['user_action']['reaction']?.toString() ?? 'none') : 'none',
      likeCount: (json['stats'] is Map) ? _parseInt(json['stats']['like_count']) : 0,
      dislikeCount: (json['stats'] is Map) ? _parseInt(json['stats']['dislike_count']) : 0,
    );
  }

  bool get isRead => readAt != null;
}