import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/core/database/hive_scan_database.dart';
import 'package:smartcard_flutter/core/database/sqlite_database.dart';
import 'package:smartcard_flutter/core/utils/auth_session_resolver.dart';

/// Service managing cloud backup & restore for Scanned Contacts in Firebase Firestore & Storage.
/// Ensures all scanned cards (with photos) survive app uninstallation and device switches.
class FirebaseContactSyncService {
  static final FirebaseContactSyncService _instance = FirebaseContactSyncService._internal();
  factory FirebaseContactSyncService() => _instance;
  FirebaseContactSyncService._internal();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  FirebaseFirestore? get _firestore {
    try {
      if (_isFirebaseReady) return FirebaseFirestore.instance;
    } catch (_) {}
    return null;
  }

  FirebaseStorage? get _storage {
    try {
      if (_isFirebaseReady) return FirebaseStorage.instance;
    } catch (_) {}
    return null;
  }

  Future<bool> _ensureFirebaseInitialized() async {
    if (_isFirebaseReady) return true;
    try {
      await Firebase.initializeApp();
      return _isFirebaseReady;
    } catch (e) {
      debugPrint('⚠️ [FirebaseContactSync] Firebase not initialized: $e');
      return false;
    }
  }

  CollectionReference<Map<String, dynamic>>? _userScansCollection(String userId) {
    final fs = _firestore;
    if (fs == null) return null;
    return fs.collection('users').doc(userId).collection('scanned_contacts');
  }

  /// Automatically resolves the user ID from SecureStorage, SharedPreferences,
  /// JWT tokens, or persistent device ID so sync never fails due to missing ID.
  Future<String> getEffectiveUserId([String? passedUserId]) async {
    if (passedUserId != null && passedUserId.trim().isNotEmpty) {
      return passedUserId.trim();
    }

    // 1. Try FlutterSecureStorage (where AuthRepository saves user_id)
    try {
      final secureUserId = await _secureStorage.read(key: 'user_id');
      if (secureUserId != null && secureUserId.trim().isNotEmpty) {
        return secureUserId.trim();
      }
    } catch (_) {}

    // 2. Try SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefId = prefs.getString('user_id') ?? prefs.getString('auth_user_id');
      if (prefId != null && prefId.trim().isNotEmpty) {
        return prefId.trim();
      }

      // 3. Try cached user profile
      final cached = prefs.getString('cached_user_profile');
      if (cached != null && cached.isNotEmpty) {
        try {
          final map = jsonDecode(cached);
          final id = map['id']?.toString() ?? map['user_id']?.toString();
          if (id != null && id.trim().isNotEmpty) return id.trim();
        } catch (_) {}
      }
    } catch (_) {}

    // 4. Try AuthSessionResolver (JWT payload)
    try {
      final tokenUserId = await AuthSessionResolver.resolveUserId();
      if (tokenUserId != null && tokenUserId.trim().isNotEmpty) {
        return tokenUserId.trim();
      }
    } catch (_) {}

    // 5. Fallback: Stable persistent device identifier
    try {
      final prefs = await SharedPreferences.getInstance();
      var deviceId = prefs.getString('firebase_device_uid');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('firebase_device_uid', deviceId);
      }
      return deviceId;
    } catch (_) {
      return 'default_user';
    }
  }

  /// Uploads any local image file or base64 data to Firebase Storage and returns the public download URL.
  Future<String?> _uploadImageIfNeeded(String userId, String contactId, String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) return null;
    final trimmed = imagePath.trim();

    // Already a remote URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final storage = _storage;
    if (storage == null) return trimmed;

    // Base64 Data URL (e.g. data:image/jpeg;base64,...)
    if (trimmed.startsWith('data:image')) {
      try {
        final commaIdx = trimmed.indexOf(',');
        final base64Str = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
        final bytes = base64Decode(base64Str);
        final ref = storage.ref().child('users/$userId/scanned_photos/${contactId}_avatar.jpg');
        final uploadTask = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg')).timeout(const Duration(seconds: 7));
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        debugPrint('☁️ [FirebaseContactSync] Base64 image uploaded to Storage: $downloadUrl');
        return downloadUrl;
      } catch (e) {
        debugPrint('⚠️ [FirebaseContactSync] Failed to upload base64 image: $e');
        if (trimmed.length > 50000) return null; // Avoid exceeding Firestore 1MB document limit
        return trimmed;
      }
    }

    // Local file path
    try {
      final file = File(trimmed);
      if (await file.exists()) {
        final ref = storage.ref().child('users/$userId/scanned_photos/${contactId}_avatar.jpg');
        final uploadTask = await ref.putFile(file).timeout(const Duration(seconds: 7));
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        debugPrint('☁️ [FirebaseContactSync] File image uploaded to Storage: $downloadUrl');
        return downloadUrl;
      }
    } catch (e) {
      debugPrint('⚠️ [FirebaseContactSync] Failed to upload image to Firebase Storage: $e');
    }

    return trimmed;
  }

  /// Syncs a single scanned contact to Firestore (Runs in background).
  Future<void> syncContactToFirebase(ScannedContactModel contact, {String? userId}) async {
    if (contact.id.trim().isEmpty) return;

    try {
      final ready = await _ensureFirebaseInitialized();
      if (!ready) return;

      final fs = _firestore;
      if (fs == null) return;

      final effectiveUid = await getEffectiveUserId(userId);
      if (effectiveUid.isEmpty) return;

      // Safe document ID for Firestore (no slashes)
      final safeDocId = contact.id.replaceAll(RegExp(r'[/#\?\[\]]'), '_').trim();
      if (safeDocId.isEmpty) return;

      // Ensure user profile document exists so the collection lights up in Firestore Console
      try {
        await fs.collection('users').doc(effectiveUid).set({
          'last_active': FieldValue.serverTimestamp(),
          'user_id': effectiveUid,
        }, SetOptions(merge: true));
      } catch (_) {}

      // Upload images if needed
      String? remoteProfileImage = contact.profileImage;
      String? remoteImagePath = contact.imagePath;

      if (remoteProfileImage != null && !remoteProfileImage.startsWith('http')) {
        final uploaded = await _uploadImageIfNeeded(effectiveUid, safeDocId, remoteProfileImage);
        if (uploaded != null) remoteProfileImage = uploaded;
      }

      if (remoteImagePath != null && !remoteImagePath.startsWith('http')) {
        final uploaded = await _uploadImageIfNeeded(effectiveUid, '${safeDocId}_card', remoteImagePath);
        if (uploaded != null) remoteImagePath = uploaded;
      }

      final contactToSync = contact.copyWith(
        id: safeDocId,
        profileImage: remoteProfileImage,
        imagePath: remoteImagePath,
        syncStatus: 'synced',
      );

      final json = contactToSync.toJson();
      json['last_synced_at'] = FieldValue.serverTimestamp();

      // Guard against oversized base64 string directly in document
      if (json['profileImage'] is String && (json['profileImage'] as String).length > 60000) {
        json['profileImage'] = null;
      }

      final collection = _userScansCollection(effectiveUid);
      if (collection != null) {
        await collection.doc(safeDocId).set(json, SetOptions(merge: true));
        debugPrint('☁️ [FirebaseContactSync] ✅ Synced contact "${contact.name}" ($safeDocId) to Firestore users/$effectiveUid/scanned_contacts');
      }
    } catch (e) {
      debugPrint('🚨 [FirebaseContactSync] Error syncing contact to Firestore: $e');
    }
  }

  /// Bulk syncs all local Hive & SQLite scanned contacts to Firebase Firestore in background.
  Future<void> syncAllLocalScansToFirebase({String? userId}) async {
    try {
      final ready = await _ensureFirebaseInitialized();
      if (!ready) return;

      final effectiveUid = await getEffectiveUserId(userId);
      final hiveScans = HiveScanDatabase.getAllScannedRecords();
      final sqliteScans = await SqliteDatabase.getAllContactsAsync();

      final Map<String, ScannedContactModel> allScans = {};
      for (final c in sqliteScans) {
        if (c.id.isNotEmpty) allScans[c.id] = c;
      }
      for (final c in hiveScans) {
        if (c.id.isNotEmpty) allScans[c.id] = c;
      }

      if (allScans.isEmpty) return;

      debugPrint('☁️ [FirebaseContactSync] Bulk syncing ${allScans.length} local scanned cards to Firestore for user $effectiveUid...');
      for (final contact in allScans.values) {
        await syncContactToFirebase(contact, userId: effectiveUid);
      }
      debugPrint('☁️ [FirebaseContactSync] ✅ Finished bulk syncing ${allScans.length} cards to Firestore.');
    } catch (e) {
      debugPrint('⚠️ [FirebaseContactSync] Error during bulk sync to Firestore: $e');
    }
  }

  /// Deletes a contact from Firestore when deleted from app.
  Future<void> deleteContactFromFirebase(String contactId, {String? userId}) async {
    if (contactId.isEmpty) return;
    try {
      final ready = await _ensureFirebaseInitialized();
      if (!ready) return;

      final effectiveUid = await getEffectiveUserId(userId);
      final safeDocId = contactId.replaceAll(RegExp(r'[/#\?\[\]]'), '_').trim();
      final collection = _userScansCollection(effectiveUid);
      if (collection != null) {
        await collection.doc(safeDocId).delete();
        debugPrint('🗑️ [FirebaseContactSync] Deleted contact $safeDocId from Firestore users/$effectiveUid/scanned_contacts');
      }
    } catch (e) {
      debugPrint('⚠️ [FirebaseContactSync] Error deleting contact from Firestore: $e');
    }
  }

  /// Restores all scanned contacts from Firestore back into Hive & SQLite on fresh install / login.
  Future<List<ScannedContactModel>> restoreContactsFromFirebase({String? userId}) async {
    try {
      final ready = await _ensureFirebaseInitialized();
      if (!ready) return [];

      final effectiveUid = await getEffectiveUserId(userId);
      final collection = _userScansCollection(effectiveUid);
      if (collection == null) return [];

      debugPrint('📥 [FirebaseContactSync] Fetching contacts from Firestore for user $effectiveUid...');
      final snapshot = await collection.get();
      if (snapshot.docs.isEmpty) {
        debugPrint('ℹ️ [FirebaseContactSync] No contacts found in Firestore.');
        return [];
      }

      final List<ScannedContactModel> restoredList = [];
      final tombstones = await SqliteDatabase.getPendingDeletionTombstonesAsync();
      final tombstoneIds = tombstones.map((t) => t['id'] ?? '').where((s) => s.isNotEmpty).toSet();

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final contact = ScannedContactModel.fromJson(data);
          if (contact.id.isEmpty) continue;

          final docId = doc.id;
          final cId = contact.id;
          final cRawId = cId.replaceFirst('phone_', '').replaceFirst('matched_', '');

          // Check if contact matches any tombstone by ID
          final bool isTombstoned = tombstoneIds.contains(docId) ||
              tombstoneIds.contains(cId) ||
              (cRawId.isNotEmpty && tombstoneIds.contains(cRawId));

          if (isTombstoned) {
            debugPrint('🗑️ [FirebaseContactSync] Skipping and deleting tombstoned contact from Firestore: $cId ($docId)');
            try {
              await collection.doc(doc.id).delete();
            } catch (_) {}
            continue;
          }

          restoredList.add(contact);
          // Re-save into local persistent storage
          await HiveScanDatabase.saveScannedRecord(contact);
          await SqliteDatabase.saveContact(contact);
        } catch (e) {
          debugPrint('⚠️ [FirebaseContactSync] Error restoring contact doc ${doc.id}: $e');
        }
      }

      debugPrint('✅ [FirebaseContactSync] Successfully restored ${restoredList.length} contacts from Firestore to Hive & SQLite!');
      return restoredList;
    } catch (e) {
      debugPrint('🚨 [FirebaseContactSync] Error restoring contacts from Firestore: $e');
      return [];
    }
  }
}
