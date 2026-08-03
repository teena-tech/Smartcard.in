import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/scanned_contact_model.dart';

class ContactSaverService {
  /// Checks and automatically requests system contacts write permission.
  static Future<bool> requestContactsPermission() async {
    if (kIsWeb) return false;
    try {
      // Use permission_handler first since it has native setup and avoid QuisApp missing plugin exception
      final status = await Permission.contacts.request();
      if (status.isGranted) return true;

      // Fallback to flutter_contacts request method
      return await FlutterContacts.requestPermission(readonly: false);
    } catch (e) {
      debugPrint('🚨 Error requesting contacts permission: $e');
      return false;
    }
  }

  /// Saves a [ScannedContactModel] directly into the device's native address book.
  /// Prevents duplicates based on matching phone number or email address.
  static Future<bool> saveToDevice(ScannedContactModel scanned) async {
    if (kIsWeb) return true;
    try {
      final permission = await requestContactsPermission();
      if (!permission) {
        debugPrint('🚫 Contacts permission not granted.');
        return false;
      }

      // Check if duplicate already exists
      final isDup = await isDuplicate(scanned.phone, scanned.email);
      if (isDup) {
        debugPrint('⚠️ Duplicate contact already exists in device contacts.');
        return true; // Already exists, so we consider it a success and proceed
      }

      // Create new Flutter Contact
      final contact = Contact();
      final nameParts = scanned.name.split(' ');
      if (nameParts.length > 1) {
        contact.name.first = nameParts.first;
        contact.name.last = nameParts.sublist(1).join(' ');
      } else {
        contact.name.first = scanned.name;
      }

      contact.organizations = [
        Organization(
          company: scanned.company,
          title: scanned.designation,
        )
      ];

      // Add main phone
      if (scanned.phone.isNotEmpty) {
        contact.phones.add(Phone(scanned.phone, label: PhoneLabel.mobile));
      }

      // Add alternative phone
      if (scanned.alternativePhone != null && scanned.alternativePhone!.isNotEmpty) {
        contact.phones.add(Phone(scanned.alternativePhone!, label: PhoneLabel.other));
      }

      // Add landline
      if (scanned.landline != null && scanned.landline!.isNotEmpty) {
        contact.phones.add(Phone(scanned.landline!, label: PhoneLabel.work));
      }

      // Add WhatsApp number
      if (scanned.whatsApp != null && scanned.whatsApp!.isNotEmpty) {
        contact.phones.add(Phone(
          scanned.whatsApp!,
          label: PhoneLabel.custom,
          customLabel: 'WhatsApp',
        ));
      }

      // Add email
      if (scanned.email.isNotEmpty) {
        contact.emails.add(Email(scanned.email, label: EmailLabel.work));
      }

      // Add website
      if (scanned.website.isNotEmpty) {
        contact.websites.add(Website(scanned.website, label: WebsiteLabel.work));
      }

      // Add address with postal code
      if (scanned.address.isNotEmpty || (scanned.pinCode != null && scanned.pinCode!.isNotEmpty)) {
        contact.addresses.add(Address(
          scanned.address,
          label: AddressLabel.work,
          postalCode: scanned.pinCode ?? '',
        ));
      }

      // Add profile photo if present
      if (scanned.imagePath != null && scanned.imagePath!.isNotEmpty) {
        final file = File(scanned.imagePath!);
        if (await file.exists()) {
          contact.photo = await file.readAsBytes();
        }
      }

      // Save contact to native database
      await contact.insert();
      debugPrint('✅ Successfully saved contact ${scanned.name} to native address book.');
      return true;
    } catch (e) {
      debugPrint('🚨 Failed to save contact to device contacts: $e');
      rethrow;
    }
  }

  /// Checks if a duplicate contact exists in the device address book.
  static Future<bool> isDuplicate(String phone, String email) async {
    if (kIsWeb || (phone.isEmpty && email.isEmpty)) return false;

    try {
      final permission = await FlutterContacts.requestPermission(readonly: true);
      if (!permission) return false;

      final List<Contact> deviceContacts = await FlutterContacts.getContacts(
        withProperties: true,
      );

      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      
      for (var c in deviceContacts) {
        // Match Email
        if (email.isNotEmpty) {
          final matchedEmail = c.emails.any((e) => e.address.trim().toLowerCase() == email.trim().toLowerCase());
          if (matchedEmail) return true;
        }

        // Match Phone (normalized digits comparison)
        if (phone.isNotEmpty) {
          for (var p in c.phones) {
            final devPhoneDigits = p.number.replaceAll(RegExp(r'[^\d]'), '');
            if (devPhoneDigits.isNotEmpty && devPhoneDigits == cleanPhone) {
              return true;
            }
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('🚨 Error checking duplicate native contacts: $e');
      return false;
    }
  }

  /// Generates a standard vCard v3.0 string representation of the scanned contact.
  static String buildVCardString(ScannedContactModel scanned) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCARD');
    buffer.writeln('VERSION:3.0');
    buffer.writeln('FN:${scanned.name}');
    buffer.writeln('ORG:${scanned.company}');
    buffer.writeln('TITLE:${scanned.designation}');
    
    if (scanned.phone.isNotEmpty) {
      buffer.writeln('TEL;TYPE=CELL,VOICE:${scanned.phone}');
    }
    if (scanned.alternativePhone != null && scanned.alternativePhone!.isNotEmpty) {
      buffer.writeln('TEL;TYPE=WORK,VOICE:${scanned.alternativePhone}');
    }
    if (scanned.landline != null && scanned.landline!.isNotEmpty) {
      buffer.writeln('TEL;TYPE=WORK,LANDLINE:${scanned.landline}');
    }
    if (scanned.whatsApp != null && scanned.whatsApp!.isNotEmpty) {
      buffer.writeln('TEL;TYPE=CELL,WHATSAPP:${scanned.whatsApp}');
    }
    if (scanned.email.isNotEmpty) {
      buffer.writeln('EMAIL;TYPE=PREF,INTERNET:${scanned.email}');
    }
    if (scanned.website.isNotEmpty) {
      buffer.writeln('URL;TYPE=WORK:${scanned.website}');
    }
    if (scanned.address.isNotEmpty) {
      // Escape commas for vCard compliance
      final escapedAddress = scanned.address.replaceAll(',', '\\,');
      final pin = scanned.pinCode ?? '';
      buffer.writeln('ADR;TYPE=WORK:;;$escapedAddress;;;;$pin');
    }
    
    // Add social links if present
    for (var link in scanned.socialLinks) {
      buffer.writeln('X-SOCIALPROFILE;TYPE=other:$link');
    }
    
    buffer.writeln('END:VCARD');
    return buffer.toString();
  }
}
