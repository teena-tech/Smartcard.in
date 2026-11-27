import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smartcard_flutter/core/services/contact_photo_resolver.dart';
import 'package:smartcard_flutter/core/services/contact_saver_service.dart';
import 'package:smartcard_flutter/core/services/qr_extraction_service.dart';
import 'package:smartcard_flutter/core/services/vcard_photo_service.dart';
import 'package:smartcard_flutter/core/utils/contact_parser.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/contact_model.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/features/contact_preview_screen/presentation/view/contact_preview_screen.dart';
import 'package:smartcard_flutter/features/my_cards_screen/presentation/view/mycards.dart';
import 'package:smartcard_flutter/core/widgets/app_profile_avatar.dart';
import 'package:smartcard_flutter/core/widgets/circular_profile_avatar.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.loadFromString(
      envString:
          'USE_LOCAL_BACKEND=false\nAPI_URL=https://thesmartcards.in\nSHARED_UPLOADS_URL=https://thesmartcards.in/shared-uploads\n',
    );
  });

  group('ContactModel vCard 3.0 & Share Tests', () {
    test('generates valid vCard 3.0 with all fields', () {
      final contact = ContactModel(
        name: 'Rahul Sharma',
        jobTitle: 'Senior Software Architect',
        company: 'SmartCard Solutions',
        phone: '+919876543210',
        email: 'rahul@example.com',
        website: 'https://thesmartcards.in',
        address: '123 Tech Park, Bangalore, India',
      );

      final vCard = contact.toVCard();

      expect(vCard, contains('BEGIN:VCARD'));
      expect(vCard, contains('VERSION:3.0'));
      expect(vCard, contains('FN:Rahul Sharma'));
      expect(vCard, contains('N:Sharma;Rahul;;;'));
      expect(vCard, contains('ORG:SmartCard Solutions'));
      expect(vCard, contains('TITLE:Senior Software Architect'));
      expect(vCard, contains('TEL;TYPE=CELL,VOICE:+919876543210'));
      expect(vCard, contains('EMAIL;TYPE=WORK,INTERNET:rahul@example.com'));
      expect(vCard, contains('URL:https://thesmartcards.in'));
      expect(vCard, contains(r'ADR;TYPE=WORK:;;123 Tech Park\, Bangalore\, India;;;;'));
      expect(vCard, contains('END:VCARD'));
    });

    test('generates vCard with minimal fields without null crash', () {
      final contact = ContactModel(name: 'Aditi');
      final vCard = contact.toVCard();

      expect(vCard, contains('BEGIN:VCARD'));
      expect(vCard, contains('VERSION:3.0'));
      expect(vCard, contains('FN:Aditi'));
      expect(vCard, contains('N:;Aditi;;;'));
      expect(vCard, isNot(contains('TEL;')));
      expect(vCard, isNot(contains('EMAIL;')));
      expect(vCard, contains('END:VCARD'));
    });

    test('generates clean plain text summary', () {
      final contact = ContactModel(
        name: 'Rahul Sharma',
        jobTitle: 'Architect',
        company: 'SmartCard',
        phone: '+919876543210',
      );

      final text = contact.toPlainText();
      expect(text, contains('Rahul Sharma'));
      expect(text, contains('Architect @ SmartCard'));
      expect(text, contains('+919876543210'));
    });

    test('encodes and parses profileImage URI cleanly in vCard 3.0', () {
      final contact = ContactModel(
        name: 'Jeena Remakanth',
        jobTitle: 'Founder, Director',
        company: 'Antz Media',
        phone: '9995655999',
        website: 'https://thesmartcards.in?sc=abc',
        profileImageName: 'shared-uploads/users/profile/1745411455.png',
      );

      final vCard = contact.toVCard();
      expect(vCard, contains('PHOTO;VALUE=URI:https://thesmartcards.in/shared-uploads/users/profile/1745411455.png'));

      final scanned = ContactParser.parseVCard(vCard);
      expect(scanned.name, 'Jeena Remakanth');
      expect(scanned.designation, 'Founder, Director');
      expect(scanned.phone, '9995655999');
      expect(
        scanned.profileImage,
        'https://thesmartcards.in/shared-uploads/users/profile/1745411455.png',
      );
    });

    test('downloads profileImage bytes for native device contact saving', () async {
      final pngSample = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      final mockClient = MockClient(
        (_) async => http.Response.bytes(
          pngSample,
          200,
          headers: {'content-type': 'image/png'},
        ),
      );

      final scanned = ContactParser.parseVCard(
        'BEGIN:VCARD\n'
        'VERSION:3.0\n'
        'FN:Kunju Wjaiiz\n'
        'TEL;TYPE=CELL,VOICE:8086750402\n'
        'PHOTO;VALUE=URI:https://thesmartcards.in/shared-uploads/users/profile/avatar.png\n'
        'END:VCARD',
      );

      final bytes = await ContactSaverService.resolvePhotoBytes(
        scanned,
        httpClient: mockClient,
      );
      expect(bytes, isNotNull);
      expect(bytes, pngSample);
    });

    test('skips SVG URLs when resolving bitmap photo bytes for device contacts', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          '<svg></svg>',
          200,
          headers: {'content-type': 'image/svg+xml'},
        ),
      );

      final scanned = ContactParser.parseVCard(
        'BEGIN:VCARD\n'
        'VERSION:3.0\n'
        'FN:Antz Media\n'
        'TEL;TYPE=CELL,VOICE:8086750402\n'
        'PHOTO;VALUE=URI:https://thesmartcards.in/logo.svg\n'
        'END:VCARD',
      );

      final bytes = await ContactSaverService.resolvePhotoBytes(
        scanned,
        httpClient: mockClient,
      );
      expect(bytes, isNull);
    });

    test('formats Contact QR copy text with icons and card URL without profile image link', () {
      final copied = MyCardsScreen.buildContactCopyText(
        name: 'Kunju Wjaiiz',
        designation: 'Mobile App Developer',
        company: 'antzmedia',
        phone: '+91 80867 50402',
        cardUrl: 'https://smartcards.antzmedia.com/kunju',
      );

      expect(
        copied,
        '👤 Kunju Wjaiiz\n'
        '💻 Mobile App Developer\n'
        '🏢 antzmedia\n'
        '📞 +91 80867 50402\n'
        '\n'
        '🔗 View Digital Card: https://smartcards.antzmedia.com/kunju',
      );
      expect(copied, isNot(contains('Profile Image')));
    });

    test('QrExtractionService extracts Contact QR PHOTO URI, cardUrl, and unwrapped email', () async {
      const sampleVCard = 'BEGIN:VCARD\n'
          'VERSION:3.0\n'
          'FN:Kunju Wjaiiz\n'
          'N:Wjaiiz;Kunju;;;\n'
          'ORG:antzmedia\n'
          'TITLE:Mobile app developer\n'
          'TEL;TYPE=CELL,VOICE:8086750402\n'
          'EMAIL;TYPE=WORK,INTERNET:["teenuloves123@gmail.com"]\n'
          'URL:https://thesmartcards.in?sc=VFl3M3h0NmUzbjY1QjNPWnFGWStTdzhpR3JiNWdFako4aVJkYldNUnRQQT0%3D\n'
          'PHOTO;VALUE=URI:https://thesmartcards.in/shared-uploads/users/profile/profile_1069_1794377570321_47070.webp\n'
          'END:VCARD';

      final scanned = await QrExtractionService.extract(sampleVCard);

      expect(scanned.name, 'Kunju Wjaiiz');
      expect(scanned.company, 'antzmedia');
      expect(scanned.designation, 'Mobile app developer');
      expect(scanned.phone, '8086750402');
      expect(scanned.email, 'teenuloves123@gmail.com');
      expect(
        scanned.cardUrl,
        'https://thesmartcards.in?sc=VFl3M3h0NmUzbjY1QjNPWnFGWStTdzhpR3JiNWdFako4aVJkYldNUnRQQT0%3D',
      );
      expect(
        scanned.profileImage,
        'https://thesmartcards.in/shared-uploads/users/profile/profile_1069_1794377570321_47070.webp',
      );
      expect(
        scanned.matchedProfileImage,
        'https://thesmartcards.in/shared-uploads/users/profile/profile_1069_1794377570321_47070.webp',
      );
    });

    test('ContactParser unfolds folded Base64 PHOTO and resolves bytes cleanly', () async {
      final rawBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4]);
      final b64 = base64Encode(rawBytes);
      final part1 = b64.substring(0, 6);
      final part2 = b64.substring(6);

      final foldedVCard = 'BEGIN:VCARD\r\n'
          'VERSION:3.0\r\n'
          'FN:Folded Photo\r\n'
          'TEL:+919999999999\r\n'
          'PHOTO;ENCODING=b;TYPE=JPEG:$part1\r\n'
          ' $part2\r\n'
          'END:VCARD';

      final parsed = ContactParser.parseVCard(foldedVCard);
      expect(parsed.profileImage, 'data:image/jpeg;base64,$b64');

      final bytes = await ContactSaverService.resolvePhotoBytes(parsed);
      expect(bytes, equals(rawBytes));
    });

    test('ContactPhotoResolver skips empty matchedProfileImage and empty matchedCards', () {
      final contact = ScannedContactModel(
        id: 'c_1',
        name: 'Kunju Wjaiiz',
        company: 'antzmedia',
        designation: 'Mobile App Developer',
        phone: '8086750402',
        email: '',
        website: '',
        address: '',
        socialLinks: const [],
        matchedProfileImage: '',
        profileImage: 'shared-uploads/users/profile/kunju.webp',
        matchedCards: const [
          {'company': 'antzmedia', 'profileImageName': ''},
        ],
        createdAt: DateTime(2026),
      );

      expect(
        ContactPhotoResolver.resolveScannedPhotoSource(contact),
        'shared-uploads/users/profile/kunju.webp',
      );
    });

    testWidgets('ContactPreviewScreen shows CircularProfileAvatar even if matchedProfileImage is empty', (tester) async {
      final contact = ScannedContactModel(
        id: 'scan_1',
        name: 'Kunju Wjaiiz',
        company: 'antzmedia',
        designation: 'Mobile App Developer',
        phone: '8086750402',
        email: 'teenuloves123@gmail.com',
        website: 'https://thesmartcards.in?sc=abc',
        address: '',
        socialLinks: const [],
        matchedProfileImage: '',
        profileImage: 'https://thesmartcards.in/shared-uploads/users/profile/profile_1069_1794377570321_47070.webp',
        createdAt: DateTime(2026),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ContactPreviewScreen(contact: contact),
          ),
        ),
      );
      await tester.pump();

      final avatarFinder = find.byType(CircularProfileAvatar);
      expect(avatarFinder, findsOneWidget);
      final avatar = tester.widget<CircularProfileAvatar>(avatarFinder);
      expect(
        avatar.imageUrl,
        'https://thesmartcards.in/shared-uploads/users/profile/profile_1069_1794377570321_47070.webp',
      );
    });

    testWidgets('AppProfileAvatar resolves relative server paths into CachedNetworkImage URLs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppProfileAvatar(
              id: 'u_1',
              name: 'Kunju',
              avatarUrl: 'shared-uploads/users/profile/kunju.webp',
              enableHero: false,
            ),
          ),
        ),
      );
      await tester.pump();

      final netImg = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(
        netImg.imageUrl,
        'https://thesmartcards.in/shared-uploads/users/profile/kunju.webp',
      );
    });

    test('transcodes oversized PNG profile image to compact JPEG bytes for native Contacts', () async {
      final pngImage = img.Image(width: 640, height: 640);
      final pngBytes = Uint8List.fromList(img.encodePng(pngImage));
      final mockClient = MockClient(
        (_) async => http.Response.bytes(
          pngBytes,
          200,
          headers: {'content-type': 'image/png'},
        ),
      );
      final scanned = ContactParser.parseVCard(
        'BEGIN:VCARD\nVERSION:3.0\nFN:Kunju\nTEL:8086750402\nPHOTO;VALUE=URI:https://thesmartcards.in/shared-uploads/users/profile/kunju.png\nEND:VCARD',
      );

      final result = await ContactSaverService.resolvePhotoBytes(
        scanned,
        httpClient: mockClient,
      );
      expect(result, isNotNull);
      expect(result!.length, greaterThan(4));
      expect(result[0], equals(0xFF));
      expect(result[1], equals(0xD8));
      final decoded = img.decodeJpg(result);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(512));
      expect(decoded.height, lessThanOrEqualTo(512));
    });

    test('toVCardWithPhoto embeds compact JPEG Base64 inside QR-ready vCard and valid VCF', () async {
      VCardPhotoService.clearCache();
      final sourceImg = img.Image(width: 400, height: 400);
      img.fill(sourceImg, color: img.ColorRgb8(210, 40, 40));
      final pngBytes = Uint8List.fromList(img.encodePng(sourceImg));

      final mockClient = MockClient(
        (_) async => http.Response.bytes(
          pngBytes,
          200,
          headers: {'content-type': 'image/png'},
        ),
      );

      final contact = ContactModel(
        name: 'Kunju Wjaiiz',
        jobTitle: 'Mobile app developer',
        company: 'antzmedia',
        phone: '["8086750402"]',
        email: '["teenuloves123@gmail.com"]',
        website: 'https://thesmartcards.in?sc=VFl3M3h0',
        profileImageName: 'shared-uploads/users/profile/kunju.webp',
      );

      final qrVCard = await contact.toVCardWithPhoto(
        forQrCode: true,
        httpClient: mockClient,
      );
      expect(qrVCard, contains('PHOTO;ENCODING=b;TYPE=JPEG:'));
      expect(qrVCard, isNot(contains('PHOTO;VALUE=URI:')));
      expect(qrVCard.length, lessThanOrEqualTo(2200));

      // Verify QR code validates cleanly at Level L
      final qr = QrCode.fromData(
        data: qrVCard,
        errorCorrectLevel: QrErrorCorrectLevel.L,
      );
      expect(qr.moduleCount, lessThanOrEqualTo(145));

      // Verify ContactParser round-trips the inline JPEG photo
      final reparsed = ContactParser.parseVCard(qrVCard);
      expect(reparsed.name, 'Kunju Wjaiiz');
      expect(reparsed.phone, '8086750402');
      expect(reparsed.email, 'teenuloves123@gmail.com');
      expect(reparsed.profileImage, startsWith('data:image/jpeg;base64,'));

      // Verify .vcf share format uses CRLF + folded 256px inline JPEG Base64
      final vcfContent = await contact.toVCardWithPhoto(
        forQrCode: false,
        httpClient: mockClient,
      );
      expect(vcfContent, contains('\r\n'));
      expect(vcfContent, contains('PHOTO;ENCODING=b;TYPE=JPEG:'));
      final parsedVcf = ContactParser.parseVCard(vcfContent);
      expect(parsedVcf.profileImage, startsWith('data:image/jpeg;base64,'));
      final vcfPhotoBytes = await ContactSaverService.resolvePhotoBytes(parsedVcf);
      expect(vcfPhotoBytes, isNotNull);
      expect(img.decodeJpg(vcfPhotoBytes!)?.width, lessThanOrEqualTo(256));
    });

    test('normalizes relative /uploads path with baseUrl and omits PHOTO when empty or null', () {
      final resolved = VCardPhotoService.normalizePhotoSource('/uploads/pic.jpg');
      expect(resolved, endsWith('/uploads/pic.jpg'));
      expect(resolved, startsWith('http'));
      expect(resolved, isNot(contains('//uploads/pic.jpg')));
      expect(
        VCardPhotoService.normalizePhotoSource('/data/user/0/pkg/cache/pic.jpg'),
        equals('/data/user/0/pkg/cache/pic.jpg'),
      );

      final nullPhotoContact = ContactModel(
        name: 'No Photo',
        profileImageName: null,
      );
      expect(nullPhotoContact.toVCard(), isNot(contains('PHOTO')));

      final emptyPhotoContact = ContactModel(
        name: 'Empty Photo',
        profileImageName: '   ',
      );
      expect(emptyPhotoContact.toVCard(), isNot(contains('PHOTO')));
    });
  });
}
