import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard_flutter/data/models/message_model.dart';

void main() {
  group('Support MessageModel Unit Tests', () {
    test('MessageModel should correctly parse JSON with MySQL timestamp format', () {
      final json = {
        'id': 501,
        'title': 'Support Update',
        'summary': 'Hello, support team',
        'message_text': 'I need assistance with card setup.',
        'sender_type': 'user',
        'created_at': '2026-07-30 11:30:00',
        'user_action': {'read_at': '2026-07-30 11:35:00'},
      };

      final msg = MessageModel.fromJson(json);

      expect(msg.id, equals(501));
      expect(msg.details, equals('I need assistance with card setup.'));
      expect(msg.source, equals('user'));
      expect(msg.createdAt, equals('2026-07-30 11:30:00'));
      expect(msg.isRead, isTrue);
    });

    test('MessageModel should fallback to ISO timestamp when created_at is missing', () {
      final json = {
        'id': 502,
        'message_text': 'Quick question',
        'sender_type': 'user',
      };

      final msg = MessageModel.fromJson(json);

      expect(msg.id, equals(502));
      expect(msg.createdAt.isNotEmpty, isTrue);
    });

    test('MessageModel should correctly identify read vs unread messages', () {
      final unreadJson = {
        'id': 503,
        'text': 'Unread message',
        'sender_type': 'agent',
      };

      final unreadMsg = MessageModel.fromJson(unreadJson);
      expect(unreadMsg.isRead, isFalse);
    });
  });
}
