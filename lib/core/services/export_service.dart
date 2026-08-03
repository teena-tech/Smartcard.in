import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/scanned_contact_model.dart';

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

    await Share.shareXFiles([XFile(path)], text: 'Exported Contacts CSV');
  }

  /// Exports contacts as a single VCF (vCard) and opens system share dialog
  static Future<void> exportAsVcf(List<ScannedContactModel> contacts) async {
    StringBuffer vcfBuffer = StringBuffer();
    
    for (var contact in contacts) {
      vcfBuffer.writeln('BEGIN:VCARD');
      vcfBuffer.writeln('VERSION:3.0');
      vcfBuffer.writeln('FN:${contact.name}');
      if (contact.company.isNotEmpty) vcfBuffer.writeln('ORG:${contact.company}');
      if (contact.designation.isNotEmpty) vcfBuffer.writeln('TITLE:${contact.designation}');
      if (contact.phone.isNotEmpty) vcfBuffer.writeln('TEL;TYPE=CELL:${contact.phone}');
      if (contact.alternativePhone != null && contact.alternativePhone!.isNotEmpty) {
        vcfBuffer.writeln('TEL;TYPE=HOME:${contact.alternativePhone}');
      }
      if (contact.email.isNotEmpty) vcfBuffer.writeln('EMAIL;TYPE=WORK:${contact.email}');
      if (contact.website.isNotEmpty) vcfBuffer.writeln('URL:${contact.website}');
      if (contact.address.isNotEmpty) vcfBuffer.writeln('ADR:;;${contact.address.replaceAll('\n', ';')}');
      vcfBuffer.writeln('END:VCARD');
      vcfBuffer.writeln('');
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

    await Share.shareXFiles([XFile(path)], text: 'Exported Contacts VCF');
  }
}
