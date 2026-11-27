 import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/app_contact.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Device Contact Models & Phone Layout Formatting Unit Tests', () {
    test('1. AppContact should parse and maintain straight-line phone number & action metadata', () {
      final contact = AppContact(
        id: '123',
        displayName: 'Sundar Pichai',
        givenName: 'Sundar',
        familyName: 'Pichai',
        company: 'Alphabet & Google',
        jobTitle: 'Chief Executive Officer',
        phones: [
          ContactPhone(number: '+1 650 253 0000', label: 'Work'),
          ContactPhone(number: '+1 650 253 1111', label: 'Mobile'),
        ],
        emails: [
          ContactEmail(address: 'sundar@google.com', label: 'Work'),
        ],
        websites: [
          ContactWebsite(url: 'https://google.com', label: 'Homepage'),
        ],
        addresses: [
          ContactAddress(address: '1600 Amphitheatre Pkwy, Mountain View, CA', label: 'Work'),
        ],
        groupNames: ['Executive', 'Tech'],
        groupIds: ['grp_1', 'grp_2'],
        isFavorite: true,
      );

      expect(contact.id, equals('123'));
      expect(contact.displayName, equals('Sundar Pichai'));
      expect(contact.initials, equals('SP'));
      expect(contact.primaryPhone, equals('+1 650 253 0000'));
      expect(contact.primaryEmail, equals('sundar@google.com'));
      expect(contact.groupNames.length, equals(2));
      expect(contact.isFavorite, isTrue);

      // Verify toMap & fromMap
      final map = contact.toMap();
      final fromMap = AppContact.fromMap(map);
      expect(fromMap.displayName, equals('Sundar Pichai'));
      expect(fromMap.phones.length, equals(2));
      expect(fromMap.phones.first.label, equals('Work'));
      expect(fromMap.isFavorite, isTrue);
    });

    test('2. Initials extraction handles single words and multi-word names correctly', () {
      final c1 = AppContact(id: '1', displayName: 'Elon Musk');
      expect(c1.initials, equals('EM'));

      final c2 = AppContact(id: '2', displayName: 'Apple');
      expect(c2.initials, equals('AP'));

      final c3 = AppContact(id: '3', displayName: '');
      expect(c3.initials, equals('?'));
    });

    test('3. copyWith maintains integrity of group assignments and phone modifications', () {
      final original = AppContact(
        id: '10',
        displayName: 'Test User',
        phones: [ContactPhone(number: '9876543210', label: 'Mobile')],
        groupNames: ['Friends'],
        groupIds: ['g1'],
      );

      final modified = original.copyWith(
        displayName: 'Test User Updated',
        isFavorite: true,
        groupNames: ['Friends', 'Colleagues'],
        groupIds: ['g1', 'g2'],
      );

      expect(modified.displayName, equals('Test User Updated'));
      expect(modified.isFavorite, isTrue);
      expect(modified.groupNames, contains('Colleagues'));
      expect(modified.groupIds.length, equals(2));
    });
  });
}
