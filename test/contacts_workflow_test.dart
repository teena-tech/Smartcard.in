import 'package:flutter_test/flutter_test.dart';

// ── Contact Helper Logic for Testing ──────────────────────────
String formatTitleCase(String text) {
  if (text.trim().isEmpty) return '';
  return text.trim().split(RegExp(r'\s+')).map((word) {
    if (word.isEmpty) return '';
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

List<String> extractItems(List<String?> inputs) {
  final Set<String> items = {};
  for (final raw in inputs) {
    if (raw == null || raw.trim().isEmpty) continue;
    final parts = raw.split(RegExp(r'[\n/,;]'));
    for (final p in parts) {
      final clean = p.trim();
      if (clean.isNotEmpty) {
        items.add(clean);
      }
    }
  }
  return items.toList();
}

List<List<T>> batchList<T>(List<T> list, int chunkSize) {
  final List<List<T>> chunks = [];
  for (var i = 0; i < list.length; i += chunkSize) {
    var end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
    chunks.add(list.sublist(i, end));
  }
  return chunks;
}

void main() {
  group('Contacts Page Workflow & Data Processing Unit Tests', () {

    test('1. Title Case Formatting: Capitalizes names correctly regardless of input case', () {
      expect(formatTitleCase('labeeb karippakulam'), equals('Labeeb Karippakulam'));
      expect(formatTitleCase('ANAS AYOOB'), equals('Anas Ayoob'));
      expect(formatTitleCase('gobi krishnan m'), equals('Gobi Krishnan M'));
      expect(formatTitleCase('   '), equals(''));
    });

    test('2. 50-Item Batching: 3000 Phone Contacts chunked into 60 batches of 50', () {
      final mockContacts = List.generate(3000, (index) => 'Contact #$index');
      final batches = batchList(mockContacts, 50);

      expect(batches.length, equals(60));
      expect(batches.first.length, equals(50));
      expect(batches.last.length, equals(50));
      expect(batches.first.first, equals('Contact #0'));
    });

    test('3. Multi-Value Extractor: Correctly parses multiple WhatsApp/Phone/Email options', () {
      final rawInputs = [
        '9048662502 / 9746332999',
        '6381834873',
        null,
        '  ',
        '9048662502' // duplicate
      ];

      final result = extractItems(rawInputs);
      expect(result.length, equals(3));
      expect(result, containsAll(['9048662502', '9746332999', '6381834873']));
    });

    test('4. Hide Unknown Company: Empty or null company names return false for display', () {
      bool shouldShowCompany(String? company) {
        if (company == null || company.trim().isEmpty) return false;
        if (company.trim().toLowerCase() == 'unknown company') return false;
        return true;
      }

      expect(shouldShowCompany(null), isFalse);
      expect(shouldShowCompany(''), isFalse);
      expect(shouldShowCompany('Unknown Company'), isFalse);
      expect(shouldShowCompany('unknown company'), isFalse);
      expect(shouldShowCompany('SCard Pvt Ltd'), isTrue);
    });

    test('5. Multi-Option Dialog Trigger Condition: Show popup if count > 1', () {
      bool shouldShowPopup(List<String> items) => items.length > 1;

      expect(shouldShowPopup(['9048662502']), isFalse);
      expect(shouldShowPopup(['9048662502', '9746332999']), isTrue);
      expect(shouldShowPopup([]), isFalse);
    });

  });
}
