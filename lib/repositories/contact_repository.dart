import '../core/services/scanner_api_service.dart';
import 'base_repository.dart';

/// Repository for managing contacts.
class ContactRepository extends BaseRepository {
  final ScannerApiService _service = ScannerApiService.instance;

  /// Fetches the list of contacts for the current user.
  Future<List<dynamic>> getContacts() async {
    final Map<String, dynamic> response = await _service.getContacts();
    // Assuming the API returns a list under 'contacts' or 'items' or 'data'.
    if (response['contacts'] is List) {
      return response['contacts'] as List;
    }
    if (response['items'] is List) {
      return response['items'] as List;
    }
    if (response['data'] is List) {
      return response['data'] as List;
    }
    return [];
  }

  /// Saves a new contact or updates an existing one.
  Future<void> saveContact(Map<String, dynamic> data) async {
    await _service.saveContact(data);
  }

  /// Deletes a contact by its ID.
  Future<void> deleteContact(String contactId) async {
    await _service.deleteContact(int.parse(contactId));
  }
}
