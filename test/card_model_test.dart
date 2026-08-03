import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard_flutter/models/card_model.dart';

void main() {
  group('CardModel Unit Tests', () {
    test('CardModel should correctly parse JSON and map properties', () {
      final json = {
        'id': 101,
        'card_id': 101,
        'work_profile_id': 101,
        'account_user_id': 50,
        'name': 'Gobi Test Card',
        'company_name': 'Gobi Org',
        'company_logo': 'uploads/logo.png',
        'designation': 'Marketing Consultant',
        'phone': '9876543210',
        'email': 'gobi@example.com',
        'qr_data': 'https://thesmartcards.in?sc=V0J',
        'status': 'active',
      };

      final card = CardModel.fromJson(json, 0, 50, 'Gobi Test Card', '9876543210', 'gobi@example.com');

      expect(card.cardId, equals(101));
      expect(card.name, equals('Gobi Test Card'));
      expect(card.companyName, equals('Gobi Org'));
      expect(card.companyLogo, equals('uploads/logo.png'));
      expect(card.designation, equals('Marketing Consultant'));
      expect(card.isSuspended, isFalse);
    });

    test('CardProfileDetails default constructor initializes default values correctly', () {
      final details = CardProfileDetails(
        firstName: 'Gobi',
        lastName: 'Developer',
        companyName: 'Gobi Org',
        profileImageName: 'profile.jpg',
      );

      expect(details.firstName, equals('Gobi'));
      expect(details.lastName, equals('Developer'));
      expect(details.companyName, equals('Gobi Org'));
      expect(details.profileImageName, equals('profile.jpg'));
    });

    test('CardModel should support per-card templateId, templateKey, and workProfileId independence', () {
      final primaryCard = CardModel(
        userId: 10,
        cardId: 10,
        workProfileId: 10,
        accountUserId: 10,
        cardNo: 1,
        name: 'Primary Card',
        companyName: 'Company 1',
        phone: '1234567890',
        email: 'primary@example.com',
        qrCode: '',
        isPrimary: true,
        tabLabel: 'Card 1',
        captionName: 'Primary Card',
        templateId: '1',
        templateKey: 'template_01',
      );

      final secondaryCard = CardModel(
        userId: 10,
        cardId: 15,
        workProfileId: 15,
        accountUserId: 10,
        cardNo: 2,
        name: 'Secondary Card',
        companyName: 'Company 2',
        phone: '0987654321',
        email: 'secondary@example.com',
        qrCode: '',
        isPrimary: false,
        tabLabel: 'Card 2',
        captionName: 'Secondary Card',
        templateId: '2',
        templateKey: 'template_02',
        profileUrl: 'https://thesmartcards.com/profile/15',
      );

      expect(primaryCard.workProfileId, equals(10));
      expect(primaryCard.templateKey, equals('template_01'));
      expect(primaryCard.qrData, equals('https://thesmartcards.com/profile/10'));

      expect(secondaryCard.workProfileId, equals(15));
      expect(secondaryCard.templateKey, equals('template_02'));
      expect(secondaryCard.qrData, equals('https://thesmartcards.com/profile/15'));

      final updatedSecondary = secondaryCard.copyWith(
        templateId: '4',
        templateKey: 'template_04',
      );

      expect(updatedSecondary.templateKey, equals('template_04'));
      expect(primaryCard.templateKey, equals('template_01')); // Primary card remains unaffected
    });
  });
}
