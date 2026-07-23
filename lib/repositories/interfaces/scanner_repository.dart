import '../../models/scanned_contact_model.dart';

abstract class IScannerRepository {
  Future<ScannedContactModel> fetchAndCacheScannedContact(String qrValue);
  Future<List<ScannedContactModel>> getAllLocalScannedContacts();
  Stream<List<ScannedContactModel>> get scannedContactsStream;
}
