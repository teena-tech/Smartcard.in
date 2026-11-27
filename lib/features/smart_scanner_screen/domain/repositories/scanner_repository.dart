import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';

abstract class IScannerRepository {
  Future<ScannedContactModel> fetchAndCacheScannedContact(String qrValue);
  Future<List<ScannedContactModel>> getAllLocalScannedContacts();
  Stream<List<ScannedContactModel>> get scannedContactsStream;
}
