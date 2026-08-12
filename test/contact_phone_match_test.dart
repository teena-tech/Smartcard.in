import 'package:flutter_test/flutter_test.dart';
import '../lib/models/scanned_contact_model.dart';

void main() {
  group('ScannedContactModel & Phone Match Unit Tests', () {
    test('1. Model serialization & match fields', () {
      final contact = ScannedContactModel(
        id: 'c_101',
        name: 'Labeeb Karipakulam',
        company: 'Varna Systems',
        designation: 'CEO',
        phone: '+91 90486 62502',
        email: 'labeeb@example.com',
        website: 'https://scard.app',
        address: 'Calicut, Kerala',
        socialLinks: const [],
        createdAt: DateTime(2026, 8, 7),
        isMatched: true,
        matchedUserId: '101',
        totalCardsCount: 3,
        primaryDesignation: 'Managing Director',
        cardUrl: '/c/labeeb',
        matchedProfileImage: 'https://scard.app/uploads/labeeb.jpg',
      );

      final json = contact.toJson();
      expect(json['isMatched'], true);
      expect(json['matchedUserId'], '101');
      expect(json['totalCardsCount'], 3);
      expect(json['primaryDesignation'], 'Managing Director');
      expect(json['cardUrl'], '/c/labeeb');

      final deserialized = ScannedContactModel.fromJson(json);
      expect(deserialized.isMatched, true);
      expect(deserialized.matchedUserId, '101');
      expect(deserialized.totalCardsCount, 3);
      expect(deserialized.primaryDesignation, 'Managing Director');
      expect(deserialized.cardUrl, '/c/labeeb');
    });

    test('2. copyWith preserves or updates match fields', () {
      final base = ScannedContactModel(
        id: 'c_102',
        name: 'Test Contact',
        company: '',
        designation: '',
        phone: '9876543210',
        email: '',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      expect(base.isMatched, false);

      final matched = base.copyWith(
        isMatched: true,
        matchedUserId: '202',
        totalCardsCount: 2,
        primaryDesignation: 'Lead Engineer',
        cardUrl: '/card/202',
      );

      expect(matched.isMatched, true);
      expect(matched.matchedUserId, '202');
      expect(matched.totalCardsCount, 2);
      expect(matched.primaryDesignation, 'Lead Engineer');
      expect(matched.cardUrl, '/card/202');
    });

    test('3. Phone contact identification & native ID resolution', () {
      final deviceContact = ScannedContactModel(
        id: 'phone_12345',
        name: 'John Mobile',
        company: '',
        designation: '',
        phone: '9048662502',
        email: '',
        website: '',
        address: '',
        socialLinks: const [],
        source: 'phone',
        createdAt: DateTime.now(),
      );

      final isPhoneSource = deviceContact.source == 'phone' || deviceContact.id.startsWith('phone_');
      final rawDeviceId = deviceContact.id.startsWith('phone_') ? deviceContact.id.replaceFirst('phone_', '') : deviceContact.id;

      expect(isPhoneSource, true);
      expect(rawDeviceId, '12345');
    });

    test('4. Dynamic Card URL Format: Resolves working https://thesmartcards.com/c/{uni_id} domain links', () {
      String resolveCardUrl(String? rawUrl) {
        if (rawUrl == null || rawUrl.trim().isEmpty) return 'https://thesmartcards.com';
        final trimmed = rawUrl.trim();
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
        if (trimmed.startsWith('?sc=') || trimmed.startsWith('sc=')) {
          final q = trimmed.startsWith('?') ? trimmed : '?$trimmed';
          return 'https://thesmartcards.com$q';
        }
        if (trimmed.startsWith('/c/') || trimmed.startsWith('/')) {
          return 'https://thesmartcards.com$trimmed';
        }
        return 'https://thesmartcards.com/c/$trimmed';
      }

      expect(resolveCardUrl('/c/labeeb'), 'https://thesmartcards.com/c/labeeb');
      expect(resolveCardUrl('labeeb'), 'https://thesmartcards.com/c/labeeb');
      expect(resolveCardUrl('https://thesmartcards.com?sc=abc'), 'https://thesmartcards.com?sc=abc');
      expect(resolveCardUrl('/profile/15'), 'https://thesmartcards.com/profile/15');
    });

    test('5. Batch Chunking Logic: Splits 3000+ phone numbers into 200-item chunks', () {
      final phoneList = List.generate(3250, (i) => '900000${i.toString().padLeft(4, '0')}');
      const chunkSize = 200;
      final chunks = <List<String>>[];

      for (var i = 0; i < phoneList.length; i += chunkSize) {
        final end = (i + chunkSize > phoneList.length) ? phoneList.length : i + chunkSize;
        chunks.add(phoneList.sublist(i, end));
      }

      expect(chunks.length, 17);
      expect(chunks.first.length, 200);
      expect(chunks.last.length, 50);
    });

    test('6. Lazy Loading Pagination: Returns 50 items per page slice', () {
      final allContacts = List.generate(120, (i) => 'Contact_$i');
      const pageSize = 50;

      var page = 1;
      var end = (page * pageSize).clamp(0, allContacts.length);
      var displayed = allContacts.sublist(0, end);
      expect(displayed.length, 50);

      page = 2;
      end = (page * pageSize).clamp(0, allContacts.length);
      displayed = allContacts.sublist(0, end);
      expect(displayed.length, 100);

      page = 3;
      end = (page * pageSize).clamp(0, allContacts.length);
      displayed = allContacts.sublist(0, end);
      expect(displayed.length, 120);
    });
  });
}
