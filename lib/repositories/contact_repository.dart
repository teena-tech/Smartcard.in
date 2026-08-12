import '../core/services/scanner_api_service.dart';
import 'base_repository.dart';

/// Repository for managing contacts.
class ContactRepository extends BaseRepository {
  final ScannerApiService _service = ScannerApiService.instance;

  /// Fetches the list of contacts for the current user.
  Future<List<dynamic>> getContacts({int page = 1, int limit = 50}) async {
    final Map<String, dynamic> response = await _service.getContacts(page: page, limit: limit);
    if (response['data'] is List) {
      return response['data'] as List;
    }
    if (response['contacts'] is List) {
      return response['contacts'] as List;
    }
    if (response['items'] is List) {
      return response['items'] as List;
    }
    return [];
  }

  /// Saves a new contact or updates an existing one.
  Future<void> saveContact(Map<String, dynamic> data) async {
    await _service.saveContact(data);
  }

  /// Deletes a contact permanently by its ID, phone, email, or name.
  Future<void> deleteContact(
    String contactId, {
    String? phone,
    String? email,
    String? name,
  }) async {
    await _service.deleteContact(
      contactId,
      phone: phone,
      email: email,
      name: name,
    );
  }

  /// Batch match phone numbers with system SmartCards
  Future<List<dynamic>> matchPhoneContacts(List<String> phoneNumbers) async {
    return await _service.matchPhoneContacts(phoneNumbers);
  }
}

