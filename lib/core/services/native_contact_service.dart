import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../models/scanned_contact_model.dart';
import '../../viewmodels/contact_viewmodel.dart';

class NativeContactService {
  /// Opens ONLY the native device phone contact edit/insert screen.
  /// Does NOT open any custom in-app edit screen.
  static Future<ScannedContactModel?> openNativeContactEdit(
    BuildContext context,
    ScannedContactModel contact,
  ) async {
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

      final bool perm = await FlutterContacts.requestPermission(readonly: false);
      if (perm) {
        String? targetId;
        final rawId = contact.id.startsWith('phone_') ? contact.id.replaceFirst('phone_', '') : '';

        if (rawId.isNotEmpty) {
          try {
            final devC = await FlutterContacts.getContact(rawId);
            if (devC != null) targetId = devC.id;
          } catch (_) {}
        }

        if (targetId == null) {
          final cleanPhone = contact.phone.replaceAll(RegExp(r'[^\d]'), '');
          final deviceContacts = await FlutterContacts.getContacts(withProperties: true);
          for (final devC in deviceContacts) {
            if (contact.email.isNotEmpty &&
                devC.emails.any((e) => e.address.trim().toLowerCase() == contact.email.trim().toLowerCase())) {
              targetId = devC.id;
              break;
            }
            if (cleanPhone.isNotEmpty) {
              for (final p in devC.phones) {
                final devDigits = p.number.replaceAll(RegExp(r'[^\d]'), '');
                if (devDigits.isNotEmpty && devDigits == cleanPhone) {
                  targetId = devC.id;
                  break;
                }
              }
            }
            if (targetId != null) break;
          }
        }

        if (targetId != null) {
          await FlutterContacts.openExternalEdit(targetId);
        } else {
          final newContact = Contact();
          final parts = contact.name.split(' ');
          if (parts.length > 1) {
            newContact.name.first = parts.first;
            newContact.name.last = parts.sublist(1).join(' ');
          } else {
            newContact.name.first = contact.name;
          }
          if (contact.company.isNotEmpty || contact.designation.isNotEmpty) {
            newContact.organizations = [
              Organization(company: contact.company, title: contact.designation)
            ];
          }
          if (contact.phone.isNotEmpty) {
            newContact.phones.add(Phone(contact.phone, label: PhoneLabel.mobile));
          }
          if (contact.alternativePhone?.isNotEmpty == true) {
            newContact.phones.add(Phone(contact.alternativePhone!, label: PhoneLabel.other));
          }
          if (contact.email.isNotEmpty) {
            newContact.emails.add(Email(contact.email, label: EmailLabel.work));
          }
          if (contact.website.isNotEmpty) {
            newContact.websites.add(Website(contact.website, label: WebsiteLabel.work));
          }
          if (contact.address.isNotEmpty) {
            newContact.addresses.add(Address(contact.address, label: AddressLabel.work));
          }

          await FlutterContacts.openExternalInsert(newContact);
        }

        // After returning from native phone edit/insert screen, fetch updated contact details
        ScannedContactModel? updatedModel;
        if (targetId != null) {
          final updatedDevContact = await FlutterContacts.getContact(
            targetId,
            withPhoto: true,
            withThumbnail: true,
          );
          if (updatedDevContact != null) {
            String? photoPath;
            final photoBytes = updatedDevContact.photo ?? updatedDevContact.photoOrThumbnail;
            if (photoBytes != null && photoBytes.isNotEmpty) {
              photoPath = 'data:image/jpeg;base64,${base64Encode(photoBytes)}';
            }

            final name = updatedDevContact.displayName.isNotEmpty
                ? updatedDevContact.displayName
                : '${updatedDevContact.name.first} ${updatedDevContact.name.last}'.trim();
            final mainPhone = updatedDevContact.phones.isNotEmpty
                ? updatedDevContact.phones.first.normalizedNumber
                : contact.phone;
            final altPhone = updatedDevContact.phones.length > 1
                ? updatedDevContact.phones[1].normalizedNumber
                : contact.alternativePhone;
            final email = updatedDevContact.emails.isNotEmpty
                ? updatedDevContact.emails.first.address
                : contact.email;
            final company = updatedDevContact.organizations.isNotEmpty
                ? updatedDevContact.organizations.first.company
                : contact.company;
            final designation = updatedDevContact.organizations.isNotEmpty
                ? updatedDevContact.organizations.first.title
                : contact.designation;
            final address = updatedDevContact.addresses.isNotEmpty
                ? updatedDevContact.addresses.first.address
                : contact.address;
            final website = updatedDevContact.websites.isNotEmpty
                ? updatedDevContact.websites.first.url
                : contact.website;

            updatedModel = contact.copyWith(
              name: name.isNotEmpty ? name : contact.name,
              phone: mainPhone,
              alternativePhone: altPhone,
              email: email,
              company: company,
              designation: designation,
              address: address,
              website: website,
              profileImage: photoPath ?? contact.profileImage,
            );

            if (context.mounted) {
              context.read<ContactViewModel>().addScannedContact(updatedModel);
            }
          }
        }
        return updatedModel ?? contact;
      }
    } catch (e) {
      debugPrint('Error opening external native phone contact edit: $e');
    }

    return contact;
  }
}
