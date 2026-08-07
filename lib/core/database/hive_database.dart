import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/scanned_contact_model.dart';

class HiveDatabase {
  static const String _contactsBoxName = 'scanned_contacts_box';
  static const String _pendingDeletionsBoxName = 'pending_deletions_box';
  
  static Box? _contactsBox;
  static Box? _deletionsBox;

  /// Initializes Hive Database in the device's application documents directory.
  static Future<void> init() async {
    try {
      await Hive.initFlutter();
      _contactsBox = await Hive.openBox(_contactsBoxName);
      _deletionsBox = await Hive.openBox(_pendingDeletionsBoxName);
      debugPrint('📦 Hive Database initialized successfully.');
    } catch (e) {
      debugPrint('🚨 Failed to initialize Hive Database: $e');
    }
  }

  static String _cleanPhone(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  /// Saves or updates a scanned contact in the database cleanly, purging any matching duplicate keys.
  static Future<void> saveContact(ScannedContactModel contact) async {
    final box = _getContactsBox();
    final cleanP = _cleanPhone(contact.phone);
    final cleanE = contact.email.trim().toLowerCase();
    final cleanN = contact.name.trim().toLowerCase();

    String? existingProfileImage;
    String? existingImagePath;

    // Find and delete any old/legacy keys in Hive matching phone, email, name or ID
    final staleKeys = <dynamic>[];
    for (var key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        try {
          final json = Map<String, dynamic>.from(data as Map);
          final c = ScannedContactModel.fromJson(json);
          final p = _cleanPhone(c.phone);
          final e = c.email.trim().toLowerCase();
          final n = c.name.trim().toLowerCase();
          
          final isSameContact = key == contact.id ||
              (cleanP.isNotEmpty && cleanP.length >= 10 && p.endsWith(cleanP.substring(cleanP.length - 10))) ||
              (cleanE.isNotEmpty && e == cleanE) ||
              (cleanN.isNotEmpty && cleanN.length >= 3 && n == cleanN);

          if (isSameContact) {
            if (c.profileImage != null && c.profileImage!.trim().isNotEmpty) {
              existingProfileImage = c.profileImage;
            }
            if (c.imagePath != null && c.imagePath!.trim().isNotEmpty) {
              existingImagePath = c.imagePath;
            }
            if (key != contact.id) {
              staleKeys.add(key);
            }
          }
        } catch (_) {}
      }
    }

    if (staleKeys.isNotEmpty) {
      await box.deleteAll(staleKeys);
      debugPrint('🗑️ Purged ${staleKeys.length} stale duplicate local Hive entries.');
    }

    final finalContact = contact.copyWith(
      profileImage: (contact.profileImage != null && contact.profileImage!.trim().isNotEmpty)
          ? contact.profileImage
          : existingProfileImage,
      imagePath: (contact.imagePath != null && contact.imagePath!.trim().isNotEmpty)
          ? contact.imagePath
          : existingImagePath,
    );

    await box.put(finalContact.id, finalContact.toJson());
    debugPrint('💾 Saved contact locally: ${finalContact.name} (${finalContact.id}) [profileImage=${finalContact.profileImage}]');
  }

  /// Saves or updates a batch of contacts in the database efficiently.
  static Future<void> saveContacts(List<ScannedContactModel> contacts) async {
    for (var contact in contacts) {
      await saveContact(contact);
    }
    debugPrint('💾 Batch saved ${contacts.length} contacts locally.');
  }

  /// Deletes a contact by ID and phone/email/name from the local database.
  static Future<void> deleteContact(String id, {String? phone, String? email, String? name}) async {
    final box = _getContactsBox();
    final cleanP = _cleanPhone(phone ?? '');
    final cleanE = (email ?? '').trim().toLowerCase();
    final cleanN = (name ?? '').trim().toLowerCase();

    final keysToDelete = <dynamic>[id];
    for (var key in box.keys) {
      if (key == id) continue;
      final data = box.get(key);
      if (data != null) {
        try {
          final json = Map<String, dynamic>.from(data as Map);
          final c = ScannedContactModel.fromJson(json);
          final p = _cleanPhone(c.phone);
          final e = c.email.trim().toLowerCase();
          final n = c.name.trim().toLowerCase();

          if ((cleanP.isNotEmpty && cleanP.length >= 10 && p.endsWith(cleanP.substring(cleanP.length - 10))) ||
              (cleanE.isNotEmpty && e == cleanE) ||
              (cleanN.isNotEmpty && cleanN.length >= 3 && n == cleanN)) {
            keysToDelete.add(key);
          }
        } catch (_) {}
      }
    }

    await box.deleteAll(keysToDelete);
    debugPrint('❌ Deleted ${keysToDelete.length} matching contact keys locally.');
  }

  /// Adds a contact ID to the offline pending deletions box, storing phone+email
  /// so that reconcile can filter by those fields even when the server id differs.
  static Future<void> addPendingDeletion(String id, {String? phone, String? email}) async {
    try {
      final box = await _getDeletionsBoxAsync();
      await box.put(id, {
        'id': id,
        'phone': phone ?? '',
        'email': email ?? '',
        'ts': DateTime.now().toIso8601String(),
      });
      debugPrint('📋 Added $id to offline pending deletions queue (phone=$phone, email=$email).');
    } catch (e) {
      debugPrint('🚨 Error adding pending deletion: $e');
    }
  }

  /// Gets all pending deletion IDs.
  static List<String> getPendingDeletions() {
    try {
      final box = _getDeletionsBoxOrNull();
      if (box == null) return [];
      return box.keys.map((k) => k.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Gets all pending deletion tombstones with details (id, phone, email).
  static List<Map<String, String>> getPendingDeletionTombstones() {
    try {
      final box = _getDeletionsBoxOrNull();
      if (box == null) return [];
      final List<Map<String, String>> list = [];
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw is Map) {
          list.add({
            'id': key.toString(),
            'phone': raw['phone']?.toString() ?? '',
            'email': raw['email']?.toString() ?? '',
          });
        } else {
          list.add({
            'id': key.toString(),
            'phone': '',
            'email': '',
          });
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Removes a contact ID from the offline pending deletions box once synced with server.
  static Future<void> removePendingDeletion(String id) async {
    try {
      final box = await _getDeletionsBoxAsync();
      await box.delete(id);
      debugPrint('✅ Cleared $id from pending deletions queue.');
    } catch (e) {
      debugPrint('🚨 Error removing pending deletion: $e');
    }
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
    
    return list;
  }

  /// Retrieves all contacts that have pending backend uploads.
  static List<ScannedContactModel> getPendingContacts() {
    return getAllContacts()
        .where((contact) => contact.syncStatus == 'pending')
        .toList();
  }

  /// Reconciles SmartCard contacts in Hive box with authoritative server contacts list.
  /// Preserves device phonebook contacts (source == 'phone').
  /// Skips re-adding any server contact that matches a pending deletion tombstone.
  static Future<void> reconcileSmartCardContacts(List<ScannedContactModel> serverContacts) async {
    final box = _getContactsBox();

    // ── Load pending deletions tombstones ──────────────────────────────────────
    // The pending_deletions_box stores: key=id, value=JSON string with id/phone/email
    // We use these to block re-adding a contact that was deleted but not yet
    // confirmed deleted on the server (race condition guard).
    final pendingDeletionPhones = <String>{};
    final pendingDeletionEmails = <String>{};
    final pendingDeletionIds = <String>{};
    try {
      final delBox = _getDeletionsBoxOrNull();
      if (delBox != null) {
        for (final key in delBox.keys) {
          pendingDeletionIds.add(key.toString());
          final raw = delBox.get(key);
          if (raw is Map) {
            final p = _cleanPhone(raw['phone']?.toString() ?? '');
            final e = (raw['email']?.toString() ?? '').trim().toLowerCase();
            if (p.length >= 10) pendingDeletionPhones.add(p.substring(p.length - 10));
            if (e.isNotEmpty) pendingDeletionEmails.add(e);
          }
        }
      }
    } catch (_) {}

    // ── Filter server contacts, removing any that are tombstoned ──────────────
    final filteredServerContacts = serverContacts.where((c) {
      if (pendingDeletionIds.contains(c.id)) return false;
      final p = _cleanPhone(c.phone);
      final e = c.email.trim().toLowerCase();
      if (p.length >= 10 && pendingDeletionPhones.contains(p.substring(p.length - 10))) return false;
      if (e.isNotEmpty && pendingDeletionEmails.contains(e)) return false;
      return true;
    }).toList();

    final serverIds = filteredServerContacts.map((c) => c.id).toSet();
    final serverPhones = <String>{};
    final serverEmails = <String>{};
    for (var sc in filteredServerContacts) {
      final p = _cleanPhone(sc.phone);
      final e = sc.email.trim().toLowerCase();
      if (p.isNotEmpty && p.length >= 10) serverPhones.add(p.substring(p.length - 10));
      if (e.isNotEmpty) serverEmails.add(e);
    }

    final keysToDelete = <dynamic>[];

    for (var key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        try {
          final Map<String, dynamic> json = Map<String, dynamic>.from(data as Map);
          final contact = ScannedContactModel.fromJson(json);
          final p = _cleanPhone(contact.phone);
          final e = contact.email.trim().toLowerCase();

          final matchesPhone = p.isNotEmpty && p.length >= 10 && serverPhones.contains(p.substring(p.length - 10));
          final matchesEmail = e.isNotEmpty && serverEmails.contains(e);
          final matchesId = serverIds.contains(contact.id);

          if (contact.source != 'phone' && contact.syncStatus == 'synced') {
            if (!matchesId && !matchesPhone && !matchesEmail) {
              keysToDelete.add(key);
            }
          }
        } catch (_) {}
      }
    }

    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
      debugPrint('🗑️ Removed ${keysToDelete.length} stale/deleted SmartCard contacts from Hive.');
    }

    for (var contact in filteredServerContacts) {
      await saveContact(contact);
    }
    debugPrint('🔄 Reconciled ${filteredServerContacts.length} SmartCard contacts in Hive (filtered from ${serverContacts.length} server contacts).');
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

  /// Returns the contacts box, ensuring it is initialized.
  static Box _getContactsBox() {
    if (_contactsBox != null && _contactsBox!.isOpen) {
      return _contactsBox!;
    }
    if (Hive.isBoxOpen(_contactsBoxName)) {
      _contactsBox = Hive.box(_contactsBoxName);
      return _contactsBox!;
    }
    throw StateError('HiveDatabase has not been initialized. Please call HiveDatabase.init() in main().');
  }

  /// Returns the pending deletions box asynchronously, opening if needed.
  static Future<Box> _getDeletionsBoxAsync() async {
    if (_deletionsBox != null && _deletionsBox!.isOpen) {
      return _deletionsBox!;
    }
    if (Hive.isBoxOpen(_pendingDeletionsBoxName)) {
      _deletionsBox = Hive.box(_pendingDeletionsBoxName);
      return _deletionsBox!;
    }
    _deletionsBox = await Hive.openBox(_pendingDeletionsBoxName);
    return _deletionsBox!;
  }

  /// Returns the pending deletions box or null if not yet initialized.
  static Box? _getDeletionsBoxOrNull() {
    if (_deletionsBox != null && _deletionsBox!.isOpen) {
      return _deletionsBox!;
    }
    if (Hive.isBoxOpen(_pendingDeletionsBoxName)) {
      _deletionsBox = Hive.box(_pendingDeletionsBoxName);
      return _deletionsBox;
    }
    return null;
  }
}
