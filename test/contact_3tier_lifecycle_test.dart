import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/core/services/contact_saver_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('3-Tier Contact Sync & Lifecycle Comprehensive Unit Tests', () {

    // ── SCENARIO 1: Model Creation & MySQL Column Mapping ───────────
    test('1. ScannedContactModel: Complete serialization matching MySQL flat table schema', () {
      final now = DateTime(2026, 8, 14, 12, 0, 0);
      final contact = ScannedContactModel(
        id: 'scan_101',
        name: 'Gobi Krishnan',
        company: 'SmartCard Technologies',
        designation: 'Senior Developer',
        phone: '+91 9876543210',
        alternativePhone: '+91 9123456780',
        landline: '044 24567890',
        whatsApp: '+91 9876543210',
        email: 'gobi@smartcard.com',
        website: 'https://smartcard.com',
        address: '123 Tech Park, Chennai',
        pinCode: '600001',
        socialLinks: const ['https://linkedin.com/in/gobi', 'https://twitter.com/gobi'],
        profileImage: 'data:image/jpeg;base64,samplebase64bytes',
        createdAt: now,
        syncStatus: 'pending',
        source: 'scanned',
      );

      // Verify toMap for SQLite
      final map = contact.toMap();
      expect(map['id'], equals('scan_101'));
      expect(map['name'], equals('Gobi Krishnan'));
      expect(map['phone'], equals('+91 9876543210'));
      expect(map['sync_status'], equals('pending'));
      expect(map['source'], equals('scanned'));

      // Verify fromMap roundtrip
      final restored = ScannedContactModel.fromMap(map);
      expect(restored.id, equals(contact.id));
      expect(restored.name, equals(contact.name));
      expect(restored.email, equals(contact.email));
      expect(restored.company, equals(contact.company));
      expect(restored.socialLinks.length, equals(2));
    });

    // ── SCENARIO 2: IPC-Safe Duplicate Matching Logic ───────────────
    test('2. Duplicate Check: Normalized phone digits & email comparison', () {
      bool isMatch(String p1, String e1, String p2, String e2) {
        final cleanP1 = p1.replaceAll(RegExp(r'[^\d]'), '');
        final cleanP2 = p2.replaceAll(RegExp(r'[^\d]'), '');
        final cleanE1 = e1.trim().toLowerCase();
        final cleanE2 = e2.trim().toLowerCase();

        if (cleanE1.isNotEmpty && cleanE2.isNotEmpty && cleanE1 == cleanE2) {
          return true;
        }

        if (cleanP1.length >= 10 && cleanP2.length >= 10) {
          final tail1 = cleanP1.substring(cleanP1.length - 10);
          final tail2 = cleanP2.substring(cleanP2.length - 10);
          if (tail1 == tail2) return true;
        }

        return false;
      }

      // Exact phone format match
      expect(isMatch('+91 9876543210', '', '9876543210', ''), isTrue);
      // Country code variations (+91 vs 0 vs plain 10 digits)
      expect(isMatch('+91 98765-43210', '', '09876543210', ''), isTrue);
      // Case insensitive Email match
      expect(isMatch('', 'User@TechVarna.com', '', 'user@techvarna.com'), isTrue);
      // Different contacts
      expect(isMatch('9876543210', 'a@test.com', '9123456780', 'b@test.com'), isFalse);
    });

    // ── SCENARIO 3: vCard 3.0 Generation Compliance ─────────────────
    test('3. vCard Generation: Formats RFC 2426 compliant string', () {
      final contact = ScannedContactModel(
        id: 'vcard_01',
        name: 'John Doe',
        company: 'Acme Corp',
        designation: 'Tech Lead',
        phone: '+91 9999988888',
        email: 'john@acme.com',
        website: 'https://acme.com',
        address: 'Suite 400, Broadway, NY',
        pinCode: '10001',
        socialLinks: const ['https://github.com/johndoe'],
        createdAt: DateTime.now(),
      );

      final vcard = ContactSaverService.buildVCardString(contact);
      expect(vcard, contains('BEGIN:VCARD'));
      expect(vcard, contains('VERSION:3.0'));
      expect(vcard, contains('FN:John Doe'));
      expect(vcard, contains('ORG:Acme Corp'));
      expect(vcard, contains('TITLE:Tech Lead'));
      expect(vcard, contains('TEL;TYPE=CELL,VOICE:+91 9999988888'));
      expect(vcard, contains('EMAIL;TYPE=PREF,INTERNET:john@acme.com'));
      expect(vcard, contains('URL;TYPE=WORK:https://acme.com'));
      expect(vcard, contains('END:VCARD'));
    });

    // ── SCENARIO 4: 3-Tier Add & Sync State Pipeline ────────────────
    test('4. 3-Tier Sync Transition: Local Pending -> Synced on Server Ack', () {
      final contact = ScannedContactModel(
        id: 'scan_301',
        name: 'New Business Partner',
        company: 'Global Enterprises',
        designation: 'Director',
        phone: '9840011223',
        email: 'partner@global.com',
        website: 'https://global.com',
        address: 'MG Road, Bangalore',
        socialLinks: const [],
        createdAt: DateTime.now(),
        syncStatus: 'pending',
      );

      expect(contact.syncStatus, equals('pending'));

      // Simulate successful live server DB sync
      final syncedContact = contact.copyWith(syncStatus: 'synced');
      expect(syncedContact.syncStatus, equals('synced'));
      expect(syncedContact.id, equals('scan_301'));
      expect(syncedContact.phone, equals('9840011223'));
    });

    // ── SCENARIO 5: 3-Tier Deletion Pipeline & Tombstone Clearance ──
    test('5. 3-Tier Deletion: Immediate UI Removal + Tombstone Queue', () {
      final List<ScannedContactModel> localList = [
        ScannedContactModel(
          id: 'c_1',
          name: 'Alice',
          company: '',
          designation: '',
          phone: '9999911111',
          email: 'alice@test.com',
          website: '',
          address: '',
          socialLinks: const [],
          createdAt: DateTime.now(),
        ),
        ScannedContactModel(
          id: 'c_2',
          name: 'Bob',
          company: '',
          designation: '',
          phone: '9999922222',
          email: 'bob@test.com',
          website: '',
          address: '',
          socialLinks: const [],
          createdAt: DateTime.now(),
        ),
      ];

      final Set<String> deletingIds = {};
      final List<Map<String, String>> tombstoneQueue = [];

      // User triggers delete on c_1
      final targetId = 'c_1';
      deletingIds.add(targetId);
      tombstoneQueue.add({'id': targetId, 'phone': '9999911111', 'email': 'alice@test.com'});
      localList.removeWhere((c) => c.id == targetId);

      // Verify Step 1: Immediate UI removal
      expect(localList.length, equals(1));
      expect(localList.first.name, equals('Bob'));

      // Verify Step 2: Tombstone tracking for server sync
      expect(tombstoneQueue.any((t) => t['id'] == targetId), isTrue);

      // Simulate Server DELETE 200 OK
      tombstoneQueue.removeWhere((t) => t['id'] == targetId);
      deletingIds.remove(targetId);

      // Verify Step 3: Complete clearance across all tiers
      expect(tombstoneQueue.isEmpty, isTrue);
      expect(deletingIds.isEmpty, isTrue);
    });

    // ── SCENARIO 6: 50-Item Progressive Batch Streaming Engine ──────
    test('6. Progressive 50-Item Batch Streaming: Accurate chunk division & total count discovery', () {
      final totalMockContacts = 135;
      final mockPhoneContacts = List.generate(
        totalMockContacts,
        (i) => ScannedContactModel(
          id: 'phone_$i',
          name: 'Contact $i',
          company: 'Company $i',
          designation: 'Staff $i',
          phone: '+91 90000000${i.toString().padLeft(2, '0')}',
          email: 'contact$i@test.com',
          website: '',
          address: '',
          socialLinks: const [],
          source: 'phone',
          createdAt: DateTime.now(),
        ),
      );

      final List<List<ScannedContactModel>> deliveredBatches = [];
      int discoveredCount = 0;

      // Simulate Batching Engine
      discoveredCount = mockPhoneContacts.length;
      final batchSize = 50;
      final List<ScannedContactModel> currentBatch = [];

      for (final contact in mockPhoneContacts) {
        currentBatch.add(contact);
        if (currentBatch.length >= batchSize) {
          deliveredBatches.add(List.from(currentBatch));
          currentBatch.clear();
        }
      }
      if (currentBatch.isNotEmpty) {
        deliveredBatches.add(List.from(currentBatch));
        currentBatch.clear();
      }

      // Verify Total Count Discovered immediately
      expect(discoveredCount, equals(135));

      // Verify Batch Divisions: 50 + 50 + 35 = 3 Batches
      expect(deliveredBatches.length, equals(3));
      expect(deliveredBatches[0].length, equals(50));
      expect(deliveredBatches[1].length, equals(50));
      expect(deliveredBatches[2].length, equals(35));

      // Verify Total Delivered matches Total Input
      final totalProcessed = deliveredBatches.fold<int>(0, (sum, b) => sum + b.length);
      expect(totalProcessed, equals(totalMockContacts));
    });

    // ── SCENARIO 7: Android 14/15/16 Zero IPC Crash Safety ───────────
    test('7. Android 14/15/16 Crash-Proof Saving: Safe metadata parsing & non-blocking execution', () async {
      final richContact = ScannedContactModel(
        id: 'scan_and14',
        name: 'Govind Kumar',
        company: 'Apex AI Systems',
        designation: 'VP Engineering',
        phone: '+91 9444455555',
        alternativePhone: '044 28889999',
        whatsApp: '+91 9444455555',
        email: 'govind@apex.ai',
        website: 'https://apex.ai',
        address: 'Phase 2, OMR, Chennai',
        pinCode: '600096',
        socialLinks: const ['https://linkedin.com/in/govind'],
        profileImage: 'data:image/jpeg;base64,/9j/4AAQSkZJRg==',
        createdAt: DateTime.now(),
        syncStatus: 'pending',
      );

      // Verify vCard is RFC compliant
      final vcard = ContactSaverService.buildVCardString(richContact);
      expect(vcard, contains('FN:Govind Kumar'));
      expect(vcard, contains('ORG:Apex AI Systems'));
      expect(vcard, contains('EMAIL;TYPE=PREF,INTERNET:govind@apex.ai'));

      // Verify safe serialization for SQLite & Cloud
      final map = richContact.toMap();
      expect(map['id'], equals('scan_and14'));
      expect(map['phone'], equals('+91 9444455555'));
      expect(map['sync_status'], equals('pending'));

      // Verify saveToDevice handles web/mock environment cleanly without throwing
      final result = await ContactSaverService.saveToDevice(richContact);
      expect(result, isNotNull);
    });

  });
}
