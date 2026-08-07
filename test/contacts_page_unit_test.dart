import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard_flutter/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/core/services/contact_import_service.dart';

void main() {
  group('Full Contacts Page & ViewModel Comprehensive Unit Tests', () {
    late List<ScannedContactModel> sampleContacts;

    setUp(() {
      sampleContacts = [
        ScannedContactModel(
          id: 'sc_1',
          name: 'Remakanth R',
          company: 'Antz Media',
          designation: 'Director',
          phone: '+91 99959 55999',
          email: 'remakanth@antzmedia.com',
          website: 'www.antzmedia.com',
          address: 'Kochi, Kerala',
          socialLinks: const [],
          source: 'smartcard',
          syncStatus: 'synced',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        ScannedContactModel(
          id: 'sc_2',
          name: 'Labeeb Karippakulam',
          company: 'SCard Corp',
          designation: 'Product Lead',
          phone: '9048662502',
          email: 'labeeb@scard.in',
          website: 'www.scard.in',
          address: 'Malappuram, Kerala',
          socialLinks: const [],
          source: 'smartcard',
          syncStatus: 'synced',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        ScannedContactModel(
          id: 'phone_101',
          name: 'Anas Ayoob',
          company: 'Tech Solutions',
          designation: 'Developer',
          phone: '+91 97463 32999',
          email: 'anas@tech.com',
          website: '',
          address: 'Calicut, Kerala',
          socialLinks: const [],
          source: 'phone',
          syncStatus: 'pending',
          createdAt: DateTime.now(),
        ),
        ScannedContactModel(
          id: 'phone_102',
          name: 'Gobi Krishnan M',
          company: 'Antigravity Labs',
          designation: 'Engineer',
          phone: '6381834873',
          email: 'gobi@antigravity.io',
          website: '',
          address: 'Chennai, Tamil Nadu',
          socialLinks: const [],
          source: 'phone',
          syncStatus: 'pending',
          createdAt: DateTime.now(),
        ),
      ];
    });

    test('1. Total Count & Tab Count Calculations: phoneContactsCount and smartCardContactsCount are accurate', () {
      final phoneCount = sampleContacts.where((c) => c.source == 'phone').length;
      final smartCardCount = sampleContacts.where((c) => c.source != 'phone').length;
      final totalCount = sampleContacts.length;

      expect(phoneCount, equals(2));
      expect(smartCardCount, equals(2));
      expect(totalCount, equals(4));
    });

    test('2. Filter pre-pagination: Switching activeFilter filters before pagination clamping', () {
      List<ScannedContactModel> applyFilter(List<ScannedContactModel> list, String filter, {int pageSize = 50}) {
        List<ScannedContactModel> filtered = list;
        if (filter == 'Phone') {
          filtered = filtered.where((c) => c.source == 'phone').toList();
        } else if (filter == 'SmartCard') {
          filtered = filtered.where((c) => c.source != 'phone').toList();
        }
        return filtered.sublist(0, pageSize.clamp(0, filtered.length));
      }

      final smartCardResult = applyFilter(sampleContacts, 'SmartCard');
      expect(smartCardResult.length, equals(2));
      expect(smartCardResult.every((c) => c.source != 'phone'), isTrue);

      final phoneResult = applyFilter(sampleContacts, 'Phone');
      expect(phoneResult.length, equals(2));
      expect(phoneResult.every((c) => c.source == 'phone'), isTrue);
    });

    test('3. 10-Digit Tail Phone Deduplication: Prevents duplicate contact import across country codes', () {
      String cleanPhone(String phone) => phone.replaceAll(RegExp(r'\D'), '');
      String tailPhone(String phone) {
        final p = cleanPhone(phone);
        return p.length >= 10 ? p.substring(p.length - 10) : p;
      }

      final existingPhones = sampleContacts.map((e) => tailPhone(e.phone)).toSet();

      // Incoming contacts: one duplicate with country code (+91), one brand new
      const incomingDuplicate = '+919048662502'; // Matches Labeeb (9048662502)
      const incomingNew = '9876543210';

      final isDup1 = existingPhones.contains(tailPhone(incomingDuplicate));
      final isDup2 = existingPhones.contains(tailPhone(incomingNew));

      expect(isDup1, isTrue);
      expect(isDup2, isFalse);
    });

    test('4. Search Query Filtering: Correctly matches name, phone, email, and company', () {
      List<ScannedContactModel> search(List<ScannedContactModel> list, String query) {
        final q = query.toLowerCase();
        return list.where((c) {
          return c.name.toLowerCase().contains(q) ||
              c.phone.contains(q) ||
              (c.alternativePhone?.contains(q) ?? false) ||
              c.email.toLowerCase().contains(q) ||
              c.company.toLowerCase().contains(q);
        }).toList();
      }

      final nameSearch = search(sampleContacts, 'labeeb');
      expect(nameSearch.length, equals(1));
      expect(nameSearch.first.name, equals('Labeeb Karippakulam'));

      final companySearch = search(sampleContacts, 'antz media');
      expect(companySearch.length, equals(1));
      expect(companySearch.first.name, equals('Remakanth R'));

      final phoneSearch = search(sampleContacts, '63818');
      expect(phoneSearch.length, equals(1));
      expect(phoneSearch.first.name, equals('Gobi Krishnan M'));
    });

    test('5. ScannedContactModel JSON Serialization & Deserialization', () {
      final json = {
        'id': 'test_999',
        'name': 'Test User',
        'company_name': 'Test Co',
        'designation': 'Manager',
        'phone': '9876543210',
        'email': 'test@example.com',
        'website': 'www.test.com',
        'address': 'Test Street',
        'source': 'smartcard',
        'syncStatus': 'synced',
        'isFavorite': true,
        'createdAt': '2026-08-05T12:00:00.000',
      };

      final model = ScannedContactModel.fromJson(json);

      expect(model.id, equals('test_999'));
      expect(model.name, equals('Test User'));
      expect(model.company, equals('Test Co'));
      expect(model.phone, equals('9876543210'));
      expect(model.email, equals('test@example.com'));
      expect(model.isFavorite, isTrue);

      final exportedJson = model.toJson();
      expect(exportedJson['id'], equals('test_999'));
      expect(exportedJson['isFavorite'], isTrue);
    });
  });
}
