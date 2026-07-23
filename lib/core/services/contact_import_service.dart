import 'package:flutter_contacts/flutter_contacts.dart';
import '../../models/scanned_contact_model.dart';

class ContactImportService {
  /// Request permissions and load phone contacts.
  /// Deduplicates based on exact phone number or email match with existing contacts.
  static Future<List<ScannedContactModel>> importPhoneContacts(List<ScannedContactModel> existingContacts) async {
    final bool permissionGranted = await FlutterContacts.requestPermission(readonly: true);
    if (!permissionGranted) {
      throw Exception('Contacts permission denied. Please enable it in Settings.');
    }

    // Get all contacts fully populated
    final List<Contact> phoneContacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: true,
      withAccounts: false,
    );

    final List<ScannedContactModel> newContacts = [];
    final existingPhones = existingContacts.map((e) => _cleanPhone(e.phone)).where((p) => p.isNotEmpty).toSet();
    final existingEmails = existingContacts.map((e) => e.email.toLowerCase()).where((e) => e.isNotEmpty).toSet();

    for (final contact in phoneContacts) {
      if (contact.phones.isEmpty && contact.emails.isEmpty) continue; // Skip empty contacts

      final phone = contact.phones.isNotEmpty ? contact.phones.first.normalizedNumber : '';
      final altPhone = contact.phones.length > 1 ? contact.phones[1].normalizedNumber : '';
      final email = contact.emails.isNotEmpty ? contact.emails.first.address : '';
      
      final cleanedPhone = _cleanPhone(phone);
      final cleanedEmail = email.toLowerCase();

      // Duplicate Prevention
      if ((cleanedPhone.isNotEmpty && existingPhones.contains(cleanedPhone)) ||
          (cleanedEmail.isNotEmpty && existingEmails.contains(cleanedEmail))) {
        continue;
      }

      final name = contact.displayName;
      final company = contact.organizations.isNotEmpty ? contact.organizations.first.company : '';
      final designation = contact.organizations.isNotEmpty ? contact.organizations.first.title : '';
      final website = contact.websites.isNotEmpty ? contact.websites.first.url : '';
      final address = contact.addresses.isNotEmpty ? contact.addresses.first.address : '';
      
      // We aren't doing base64 image decoding directly here, we could save it to disk, 
      // but to keep it lightweight we'll skip the image or process it later.

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
        socialLinks: const [],
        source: 'phone',
        syncStatus: 'pending',
        isFavorite: false,
        createdAt: DateTime.now(),
      );

      newContacts.add(model);
      
      if (cleanedPhone.isNotEmpty) existingPhones.add(cleanedPhone);
      if (cleanedEmail.isNotEmpty) existingEmails.add(cleanedEmail);
    }

    return newContacts;
  }

  static String _cleanPhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), ''); // Strip non-numeric
  }
}
