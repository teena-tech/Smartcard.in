import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard_flutter/core/utils/upload_url_resolver.dart';
import 'package:smartcard_flutter/models/scanned_contact_model.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');
  });

  group('UploadUrlResolver Unit Tests', () {
    test('resolves http and https URLs unchanged', () {
      const httpUrl = 'http://example.com/photo.jpg';
      const httpsUrl = 'https://api.thesmartcards.com/uploads/photo.png';

      expect(UploadUrlResolver.resolve(httpUrl, type: 'profile'), equals(httpUrl));
      expect(UploadUrlResolver.resolve(httpsUrl, type: 'profile'), equals(httpsUrl));
    });

    test('resolves data:image base64 URIs unchanged', () {
      const dataUri = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      expect(UploadUrlResolver.resolve(dataUri, type: 'profile'), equals(dataUri));
    });

    test('resolves empty or null paths safely', () {
      expect(UploadUrlResolver.resolve('', type: 'profile'), equals(''));
      expect(UploadUrlResolver.resolve('null', type: 'profile'), equals(''));
    });
  });

  group('ScannedContactModel Unit Tests', () {
    test('creates model with defaults and parses json safely', () {
      final now = DateTime.now();
      final contact = ScannedContactModel(
        id: 'c_101',
        name: 'Alex Rivera',
        company: 'Antz Media',
        designation: 'Lead Architect',
        phone: '919995955999',
        email: 'alex@antzmedia.com',
        website: 'https://antzmedia.com',
        address: 'Silicon Valley, CA',
        socialLinks: const ['https://linkedin.com/in/alex'],
        createdAt: now,
      );

      expect(contact.id, equals('c_101'));
      expect(contact.name, equals('Alex Rivera'));
      expect(contact.phone, equals('919995955999'));
      expect(contact.email, equals('alex@antzmedia.com'));
    });
  });
}
