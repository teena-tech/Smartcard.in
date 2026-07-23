import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/scanned_contact_model.dart';

class HiveDatabase {
  static const String _contactsBoxName = 'scanned_contacts_box';
  
  static Box? _contactsBox;

  /// Initializes Hive Database in the device's application documents directory.
  static Future<void> init() async {
    try {
      // Hive.initFlutter() automatically resolves the correct storage path
      // on all platforms (Android, iOS, Web, Desktop) — no manual path needed.
      await Hive.initFlutter();
      _contactsBox = await Hive.openBox(_contactsBoxName);
      debugPrint('📦 Hive Database initialized successfully.');
    } catch (e) {
      debugPrint('🚨 Failed to initialize Hive Database: $e');
    }
  }

  /// Saves or updates a scanned contact in the database.
  static Future<void> saveContact(ScannedContactModel contact) async {
    final box = _getContactsBox();
    await box.put(contact.id, contact.toJson());
    debugPrint('💾 Saved contact locally: ${contact.name} (${contact.id})');
  }

  /// Saves or updates a batch of contacts in the database efficiently.
  static Future<void> saveContacts(List<ScannedContactModel> contacts) async {
    final box = _getContactsBox();
    final Map<String, dynamic> data = {
      for (var contact in contacts) contact.id: contact.toJson()
    };
    await box.putAll(data);
    debugPrint('💾 Batch saved ${contacts.length} contacts locally.');
  }

  /// Deletes a contact by its ID from the local database.
  static Future<void> deleteContact(String id) async {
    final box = _getContactsBox();
    await box.delete(id);
    debugPrint('❌ Deleted contact locally: $id');
  }

  /// Retrieves all contacts sorted by newest first.
  static List<ScannedContactModel> getAllContacts() {
    final box = _getContactsBox();
    final List<ScannedContactModel> list = [];
    
    for (var key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        try {
          final Map<String, dynamic> json = Map<String, dynamic>.from(data as Map);
          list.add(ScannedContactModel.fromJson(json));
        } catch (e) {
          debugPrint('🚨 Error decoding contact $key: $e');
        }
      }
    }
    
    // Return unsorted. The ViewModel is responsible for sorting.
    return list;
  }

  /// Retrieves all contacts that have pending backend uploads.
  static List<ScannedContactModel> getPendingContacts() {
    return getAllContacts()
        .where((contact) => contact.syncStatus == 'pending')
        .toList();
  }

  /// Updates the synchronization status of a contact.
  static Future<void> updateSyncStatus(String id, String status) async {
    final box = _getContactsBox();
    final data = box.get(id);
    if (data != null) {
      try {
        final Map<String, dynamic> json = Map<String, dynamic>.from(data as Map);
        final contact = ScannedContactModel.fromJson(json);
        final updated = contact.copyWith(syncStatus: status);
        await box.put(id, updated.toJson());
        debugPrint('🔄 Updated contact sync status ($id): $status');
      } catch (e) {
        debugPrint('🚨 Error updating sync status: $e');
      }
    }
  }

  /// Returns the contacts box, asserting that it was initialized.
  static Box _getContactsBox() {
    if (_contactsBox == null) {
      throw StateError('HiveDatabase has not been initialized. Please call HiveDatabase.init() in main().');
    }
    return _contactsBox!;
  }
}
