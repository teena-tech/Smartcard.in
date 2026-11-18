import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../models/app_contact.dart';
import '../../models/scanned_contact_model.dart';
import '../../viewmodels/contact_viewmodel.dart';

class NativeContactService {
  /// Opens the native device phone contact edit/insert screen.
  static Future<ScannedContactModel?> openNativeContactEdit(
    BuildContext context,
    ScannedContactModel contact,
  ) async {
    if (kIsWeb) return null;
    try {
      var status = await Permission.contacts.status;
      if (!status.isGranted && !status.isLimited) {
        status = await Permission.contacts.request();
      }
      if (!status.isGranted && !status.isLimited) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts permission is required to edit phone contacts.')),
          );
        }
        return null;
      }

      String? targetId;
      final rawId = contact.id.startsWith('phone_') ? contact.id.replaceFirst('phone_', '') : '';

      if (rawId.isNotEmpty) {
        try {
          final devC = await fc.FlutterContacts.get(rawId);
          if (devC != null) targetId = devC.id;
        } catch (_) {}
      }

      if (targetId == null) {
        final cleanPhone = contact.phone.replaceAll(RegExp(r'[^\d]'), '');
        final tailPhone = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
        final deviceContacts = await fc.FlutterContacts.getAll(
          properties: {fc.ContactProperty.phone, fc.ContactProperty.email},
        );
        for (final devC in deviceContacts) {
          if (contact.email.isNotEmpty &&
              devC.emails.any((e) => e.address.trim().toLowerCase() == contact.email.trim().toLowerCase())) {
            targetId = devC.id;
            break;
          }
          if (cleanPhone.isNotEmpty) {
            for (final p in devC.phones) {
              final devDigits = p.number.replaceAll(RegExp(r'[^\d]'), '');
              if (devDigits.isNotEmpty && (devDigits == cleanPhone || devDigits.endsWith(tailPhone))) {
                targetId = devC.id;
                break;
              }
            }
          }
          if (targetId != null) break;
        }
      }

      String? editedId;
      if (targetId != null) {
        editedId = await fc.FlutterContacts.native.showEditor(targetId);
      } else {
        final appContact = AppContact(
          id: '',
          displayName: contact.name,
          company: contact.company.isNotEmpty ? contact.company : null,
          jobTitle: contact.designation.isNotEmpty ? contact.designation : null,
          phones: contact.phone.isNotEmpty ? [ContactPhone(number: contact.phone, label: 'Mobile')] : [],
          emails: contact.email.isNotEmpty ? [ContactEmail(address: contact.email, label: 'Work')] : [],
          websites: contact.website.isNotEmpty ? [ContactWebsite(url: contact.website, label: 'Work')] : [],
          addresses: contact.address.isNotEmpty ? [ContactAddress(address: contact.address, label: 'Work')] : [],
        );
        editedId = await fc.FlutterContacts.native.showCreator(contact: appContact.toDeviceContact());
      }

      final finalId = editedId ?? targetId;
      if (finalId != null && finalId.isNotEmpty) {
        final updatedDevContact = await fc.FlutterContacts.get(finalId, properties: fc.ContactProperties.all);
        if (updatedDevContact != null) {
          final appC = AppContact.fromDeviceContact(updatedDevContact);

          String? photoPath;
          if (appC.photo != null && appC.photo!.isNotEmpty) {
            photoPath = 'data:image/jpeg;base64,${base64Encode(appC.photo!)}';
          }

          final updatedModel = contact.copyWith(
            name: appC.displayName,
            phone: appC.primaryPhone,
            alternativePhone: appC.phones.length > 1 ? appC.phones[1].number : contact.alternativePhone,
            email: appC.primaryEmail,
            company: appC.company ?? contact.company,
            designation: appC.jobTitle ?? contact.designation,
            address: appC.addresses.isNotEmpty ? appC.addresses.first.address : contact.address,
            website: appC.websites.isNotEmpty ? appC.websites.first.url : contact.website,
            profileImage: photoPath ?? contact.profileImage,
          );

          if (context.mounted) {
            context.read<ContactViewModel>().addScannedContact(updatedModel);
          }
          return updatedModel;
        }
      }
    } catch (e) {
      debugPrint('Error opening external native phone contact edit: $e');
    }

    return contact;
  }
}
