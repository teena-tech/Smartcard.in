import 'dart:io';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../models/scanned_contact_model.dart';

class ContactImportService {
  /// Request permissions and load phone contacts in batches of 50.
  /// Deduplicates based on exact phone number or email match with existing contacts.
  static Future<List<ScannedContactModel>> importPhoneContacts(
    List<ScannedContactModel> existingContacts, {
    Function(List<ScannedContactModel> batch)? onBatchLoaded,
    int batchSize = 50,
  }) async {
    final bool permissionGranted = await FlutterContacts.requestPermission(readonly: true);
    if (!permissionGranted) {
      throw Exception('Contacts permission denied. Please enable it in Settings.');
    }

    // Get contacts with properties & photos
    final List<Contact> phoneContacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: true,
      withAccounts: false,
    );

    final List<ScannedContactModel> allNewContacts = [];
    final List<ScannedContactModel> currentBatch = [];

    final existingPhones = existingContacts.map((e) {
      final p = _cleanPhone(e.phone);
      return p.length >= 10 ? p.substring(p.length - 10) : p;
    }).where((p) => p.isNotEmpty).toSet();
    final existingEmails = existingContacts.map((e) => e.email.toLowerCase()).where((e) => e.isNotEmpty).toSet();

    for (final contact in phoneContacts) {
      if (contact.phones.isEmpty && contact.emails.isEmpty) continue; // Skip empty contacts

      final phone = contact.phones.isNotEmpty ? contact.phones.first.normalizedNumber : '';
      final altPhone = contact.phones.length > 1 ? contact.phones[1].normalizedNumber : '';
      final email = contact.emails.isNotEmpty ? contact.emails.first.address : '';
      
      final cleanedPhone = _cleanPhone(phone);
      final tailPhone = cleanedPhone.length >= 10 ? cleanedPhone.substring(cleanedPhone.length - 10) : cleanedPhone;
      final cleanedEmail = email.toLowerCase();

      // Duplicate Prevention
      if ((tailPhone.isNotEmpty && existingPhones.contains(tailPhone)) ||
          (cleanedEmail.isNotEmpty && existingEmails.contains(cleanedEmail))) {
        continue;
      }

      final name = contact.displayName;
      final company = contact.organizations.isNotEmpty ? contact.organizations.first.company : '';
      final designation = contact.organizations.isNotEmpty ? contact.organizations.first.title : '';
      final website = contact.websites.isNotEmpty ? contact.websites.first.url : '';
      final address = contact.addresses.isNotEmpty ? contact.addresses.first.address : '';

      String? photoPath;
      if (contact.photo != null && contact.photo!.isNotEmpty) {
        try {
          final file = File('${Directory.systemTemp.path}/phone_photo_${contact.id}.jpg');
          await file.writeAsBytes(contact.photo!, flush: true);
          photoPath = file.path;
        } catch (_) {}
      }

      final model = ScannedContactModel(
        id: 'phone_${contact.id}', // Prefix to identify source ID
        name: name,
        company: company,
        designation: designation,
        phone: phone,
        alternativePhone: altPhone.isNotEmpty ? altPhone : null,
        email: email,
        website: website,
        address: address,
        profileImage: photoPath,
        socialLinks: const [],
        source: 'phone',
        syncStatus: 'pending',
        isFavorite: false,
        createdAt: DateTime.now(),
      );

      currentBatch.add(model);
      allNewContacts.add(model);

      if (cleanedPhone.isNotEmpty) existingPhones.add(cleanedPhone);
      if (cleanedEmail.isNotEmpty) existingEmails.add(cleanedEmail);

      // Deliver first 50 contacts immediately, then subsequent 50-contact batches
      if (currentBatch.length >= batchSize) {
        if (onBatchLoaded != null) {
          onBatchLoaded(List.from(currentBatch));
        }
        currentBatch.clear();
        // Brief pause to allow Flutter UI thread to render first batch instantly
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    // Deliver remaining contacts in final batch
    if (currentBatch.isNotEmpty && onBatchLoaded != null) {
      onBatchLoaded(List.from(currentBatch));
      currentBatch.clear();
    }

    return allNewContacts;
  }

  static String _cleanPhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), ''); // Strip non-numeric
  }
}
