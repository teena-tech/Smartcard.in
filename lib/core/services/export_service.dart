import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/scanned_contact_model.dart';
import 'contact_photo_resolver.dart';
import 'vcard_photo_service.dart';

class ExportService {
  /// Exports contacts as a CSV and opens system share dialog
  static Future<void> exportAsCsv(List<ScannedContactModel> contacts) async {
    StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln('Name,Company,Designation,Phone,Email,Website,Address,Source');

    for (var contact in contacts) {
      final row = [
        contact.name,
        contact.company,
        contact.designation,
        contact.phone,
        contact.email,
        contact.website,
        contact.address.replaceAll(',', ' ').replaceAll('\n', ' '),
        contact.source,
      ];
      csvBuffer.writeln(row.map((e) => '"${(e ?? "").toString().replaceAll('"', '""')}"').join(','));
    }

    String csvString = csvBuffer.toString();
    if (kIsWeb) return;
    Directory directory;
    try {
      directory = await getTemporaryDirectory();
    } catch (_) {
      try {
        directory = Directory.systemTemp;
      } catch (_) {
        return;
      }
    }
    final path = '${directory.path}/contacts_export.csv';
    final file = File(path);
    await file.writeAsString(csvString);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: 'Exported Contacts CSV'),
    );
  }

  /// Exports contacts as a single VCF (vCard) and opens system share dialog
  static Future<void> exportAsVcf(List<ScannedContactModel> contacts) async {
    StringBuffer vcfBuffer = StringBuffer();

    for (var contact in contacts) {
      vcfBuffer.write('BEGIN:VCARD\r\n');
      vcfBuffer.write('VERSION:3.0\r\n');
      vcfBuffer.write('FN:${contact.name}\r\n');
      if (contact.company.isNotEmpty) vcfBuffer.write('ORG:${contact.company}\r\n');
      if (contact.designation.isNotEmpty) vcfBuffer.write('TITLE:${contact.designation}\r\n');
      if (contact.phone.isNotEmpty) vcfBuffer.write('TEL;TYPE=CELL:${contact.phone}\r\n');
      if (contact.alternativePhone != null && contact.alternativePhone!.isNotEmpty) {
        vcfBuffer.write('TEL;TYPE=HOME:${contact.alternativePhone}\r\n');
      }
      if (contact.email.isNotEmpty) vcfBuffer.write('EMAIL;TYPE=WORK:${contact.email}\r\n');
      if (contact.website.isNotEmpty) vcfBuffer.write('URL:${contact.website}\r\n');
      if (contact.address.isNotEmpty) {
        vcfBuffer.write('ADR:;;${contact.address.replaceAll('\n', ';')}\r\n');
      }
      final photoSource = ContactPhotoResolver.resolveScannedPhotoSource(contact);
      final photoB64 = await VCardPhotoService.getVcfPhotoBase64(photoSource);
      if (photoB64 != null && photoB64.isNotEmpty) {
        vcfBuffer.write(
          '${VCardPhotoService.foldVCardLine('PHOTO;ENCODING=b;TYPE=JPEG:$photoB64')}\r\n',
        );
      }
      vcfBuffer.write('END:VCARD\r\n');
      vcfBuffer.write('\r\n');
    }

    if (kIsWeb) return;
    Directory directory;
    try {
      directory = await getTemporaryDirectory();
    } catch (_) {
      try {
        directory = Directory.systemTemp;
      } catch (_) {
        return;
      }
    }
    final path = '${directory.path}/contacts_export.vcf';
    final file = File(path);
    await file.writeAsString(vcfBuffer.toString());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'text/vcard')],
        text: 'Exported Contacts VCF',
      ),
    );
  }
}
