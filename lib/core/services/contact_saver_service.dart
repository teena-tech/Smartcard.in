import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
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

  /// Checks contacts permission status WITHOUT requesting — use for background saves.
  static Future<bool> checkContactsPermission() async {
    if (kIsWeb) return false;
    try {
      final status = await Permission.contacts.status;
      if (status.isGranted || status.isLimited) return true;
      // Fallback: check via flutter_contacts (no dialog shown)
      return await FlutterContacts.requestPermission(readonly: false);
    } catch (e) {
      debugPrint('🚨 Error checking contacts permission: $e');
      return false;
    }
  }

  /// Saves a [ScannedContactModel] directly into the device’s native address book.
  /// Prevents duplicates based on matching phone number or email address.
  static Future<bool> saveToDevice(ScannedContactModel scanned) async {
    if (kIsWeb) return true;
    try {
      // Only CHECK permission — never show dialog in background saves
      final permission = await checkContactsPermission();
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

      // Add profile photo if present (safely compressed to thumbnail to prevent Android IPC crashes)
      final photoSource = (scanned.profileImage != null && scanned.profileImage!.trim().isNotEmpty)
          ? scanned.profileImage!.trim()
          : '';

      if (photoSource.isNotEmpty) {
        try {
          Uint8List? rawBytes;
          if (photoSource.startsWith('data:image')) {
            final base64Str = photoSource.split(',').last;
            rawBytes = base64Decode(base64Str);
          } else if (!photoSource.startsWith('http://') && !photoSource.startsWith('https://')) {
            final file = File(photoSource);
            if (await file.exists()) {
              final length = await file.length();
              // Only load profile avatar photos under 300KB (skip full 4MB+ camera photos to prevent OOM crashes)
              if (length > 0 && length < 300000) {
                rawBytes = await file.readAsBytes();
              }
            }
          }

          if (rawBytes != null && rawBytes.isNotEmpty) {
            final compressed = _compressPhotoForNativeIpc(rawBytes);
            if (compressed != null && compressed.isNotEmpty) {
              contact.photo = compressed;
            }
          }
        } catch (photoErr) {
          debugPrint('⚠️ Error loading photo for contact insert: $photoErr');
        }
      }

      // Save contact to native database
      await contact.insert();
      debugPrint('✅ Successfully saved contact ${scanned.name} to native address book.');
      return true;
    } catch (e) {
      debugPrint('🚨 Failed to save contact to device contacts: $e');
      return false;
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

  /// Safely resizes and compresses raw photo bytes to a small thumbnail (<30KB)
  /// to prevent Android TransactionTooLargeException Binder IPC native crashes.
  static Uint8List? _compressPhotoForNativeIpc(Uint8List rawBytes) {
    try {
      if (rawBytes.length <= 30000) return rawBytes; // Under 30KB is already safe
      if (rawBytes.length > 300000) return null; // Skip large camera images to prevent OOM crashes
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return null;
      final resized = img.copyResize(decoded, width: 120, height: 120);
      final compressed = Uint8List.fromList(img.encodeJpg(resized, quality: 70));
      if (compressed.length <= 60000) return compressed;
    } catch (e) {
      debugPrint('⚠️ Error compressing photo for native IPC: $e');
    }
    return null;
  }
}
