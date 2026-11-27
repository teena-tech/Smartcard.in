import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';

class SqliteDatabase {
  static const String _dbName = 'smartcards_app.db';
  static const int _dbVersion = 4;

  static const String tableContacts = 'scanned_contacts';
  static const String tablePendingDeletions = 'pending_deletions';

  static Database? _db;
  static const String _webStorageKey = 'web_cached_contacts_json';
  static const String _webPendingDeletionsKey = 'web_cached_pending_deletions_json';
  static List<ScannedContactModel> _webMemoryContacts = [];
  static List<Map<String, String>> _webMemoryPendingDeletions = [];
  static bool _webInitialized = false;

  /// Initializes SQLite Database on device application storage or Web in-memory/SharedPreferences fallback.
  static Future<void> init() async {
    if (kIsWeb) {
      if (!_webInitialized) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final rawJson = prefs.getString(_webStorageKey);
          if (rawJson != null && rawJson.isNotEmpty) {
            final decoded = jsonDecode(rawJson);
            if (decoded is List) {
              _webMemoryContacts = decoded.map((e) => ScannedContactModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
            }
          }
          final rawDelJson = prefs.getString(_webPendingDeletionsKey);
          if (rawDelJson != null && rawDelJson.isNotEmpty) {
            final decodedDel = jsonDecode(rawDelJson);
            if (decodedDel is List) {
              _webMemoryPendingDeletions = decodedDel.map((e) => Map<String, String>.from(e as Map)).toList();
            }
          }
        } catch (e) {
          debugPrint('Web storage init warning: $e');
        }
        _webInitialized = true;
      }
      return;
    }

    try {
      if (_db != null && _db!.isOpen) return;

      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _dbName);

      _db = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $tableContacts (
              id TEXT PRIMARY KEY,
              name TEXT,
              company TEXT,
              designation TEXT,
              phone TEXT,
              alternative_phone TEXT,
              additional_phones TEXT,
              additional_companies TEXT,
              landline TEXT,
              whatsapp TEXT,
              email TEXT,
              website TEXT,
              address TEXT,
              district TEXT,
              state_name TEXT,
              pin_code TEXT,
              social_links TEXT,
              source TEXT,
              sync_status TEXT,
              card_url TEXT,
              profile_image TEXT,
              image_path TEXT,
              matched_cards_json TEXT,
              matched_user_id TEXT,
              total_cards_count INTEGER,
              is_matched INTEGER,
              is_favorite INTEGER,
              created_at TEXT,
              is_corporate INTEGER DEFAULT 0,
              corporate_group TEXT,
              corporate_department TEXT,
              corporate_tags TEXT,
              company_id TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE $tablePendingDeletions (
              id TEXT PRIMARY KEY,
              phone TEXT,
              email TEXT,
              ts TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS share_history (
              id TEXT PRIMARY KEY,
              title TEXT,
              method TEXT,
              timestamp TEXT
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // v1 → v2: add additional_phones column for multi-phone merge support
          if (oldVersion < 2) {
            try {
              await db.execute('ALTER TABLE $tableContacts ADD COLUMN additional_phones TEXT');
              debugPrint('📦 SQLite migration v1→v2: added additional_phones column.');
            } catch (e) {
              debugPrint('⚠️ Migration v1→v2 warning: $e');
            }
          }
          // v2 → v3: add additional_companies column for multi-company support
          if (oldVersion < 3) {
            try {
              await db.execute('ALTER TABLE $tableContacts ADD COLUMN additional_companies TEXT');
              debugPrint('📦 SQLite migration v2→v3: added additional_companies column.');
            } catch (e) {
              debugPrint('⚠️ Migration v2→v3 warning: $e');
            }
          }
          // v3 → v4: add corporate lead support columns
          if (oldVersion < 4) {
            try {
              await db.execute('ALTER TABLE $tableContacts ADD COLUMN is_corporate INTEGER DEFAULT 0');
              await db.execute('ALTER TABLE $tableContacts ADD COLUMN corporate_group TEXT');
              await db.execute('ALTER TABLE $tableContacts ADD COLUMN corporate_department TEXT');
              await db.execute('ALTER TABLE $tableContacts ADD COLUMN corporate_tags TEXT');
              await db.execute('ALTER TABLE $tableContacts ADD COLUMN company_id TEXT');
              debugPrint('📦 SQLite migration v3→v4: added corporate lead columns.');
            } catch (e) {
              debugPrint('⚠️ Migration v3→v4 warning: $e');
            }
          }
        },
      );
      debugPrint('📦 SQLite Database initialized successfully at: $path');
    } catch (e) {
      debugPrint('🚨 Failed to initialize SQLite Database: $e');
    }
  }

  static Future<Database> _getDatabaseAsync() async {
    if (kIsWeb) {
      throw UnsupportedError('Native SQLite database not available on Web Chrome.');
    }
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    await init();
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    throw StateError('SqliteDatabase failed to auto-initialize.');
  }

  static String _cleanPhone(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  static Future<void> _persistWebStorage() async {
    if (!kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final listMap = _webMemoryContacts.map((c) => c.toJson()).toList();
      await prefs.setString(_webStorageKey, jsonEncode(listMap));
      await prefs.setString(_webPendingDeletionsKey, jsonEncode(_webMemoryPendingDeletions));
    } catch (e) {
      debugPrint('Error persisting Web Contacts storage: $e');
    }
  }

  /// Converts a ScannedContactModel into a Map suitable for SQLite database storage.
  static Map<String, dynamic> _contactToMap(ScannedContactModel c) {
    return {
      'id': c.id,
      'name': c.name,
      'company': c.company,
      'designation': c.designation,
      'phone': c.phone,
      'alternative_phone': c.alternativePhone,
      'additional_phones': c.additionalPhones.isNotEmpty ? jsonEncode(c.additionalPhones) : null,
      'additional_companies': c.additionalCompanies.isNotEmpty ? jsonEncode(c.additionalCompanies) : null,
      'landline': c.landline,
      'whatsapp': c.whatsApp,
      'email': c.email,
      'website': c.website,
      'address': c.address,
      'district': c.district,
      'state_name': c.stateName,
      'pin_code': c.pinCode,
      'social_links': jsonEncode(c.socialLinks),
      'source': c.source,
      'sync_status': c.syncStatus,
      'card_url': c.cardUrl,
      'profile_image': c.profileImage,
      'image_path': c.imagePath,
      'matched_cards_json': c.matchedCards != null ? jsonEncode(c.matchedCards) : null,
      'matched_user_id': c.matchedUserId,
      'total_cards_count': c.totalCardsCount,
      'is_matched': c.isMatched ? 1 : 0,
      'is_favorite': c.isFavorite ? 1 : 0,
      'created_at': c.createdAt.toIso8601String(),
      'is_corporate': c.isCorporate ? 1 : 0,
      'corporate_group': c.corporateGroup,
      'corporate_department': c.corporateDepartment,
      'corporate_tags': c.corporateTags.isNotEmpty ? jsonEncode(c.corporateTags) : null,
      'company_id': c.companyId,
    };
  }

  /// Converts a SQLite row Map into a ScannedContactModel.
  static ScannedContactModel _mapToContact(Map<String, dynamic> map) {
    List<Map<String, dynamic>>? matchedCards;
    if (map['matched_cards_json'] != null && map['matched_cards_json'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(map['matched_cards_json'].toString());
        if (decoded is List) {
          matchedCards = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
    }

    List<String> socialLinks = [];
    if (map['social_links'] != null && map['social_links'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(map['social_links'].toString());
        if (decoded is List) {
          socialLinks = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    List<String> parsedCorpTags = [];
    if (map['corporate_tags'] != null && map['corporate_tags'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(map['corporate_tags'].toString());
        if (decoded is List) {
          parsedCorpTags = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return ScannedContactModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      company: map['company']?.toString() ?? '',
      designation: map['designation']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      alternativePhone: map['alternative_phone']?.toString(),
      additionalPhones: () {
        final raw = map['additional_phones'];
        if (raw == null || raw.toString().isEmpty) return <String>[];
        try {
          final decoded = jsonDecode(raw.toString());
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
        return <String>[];
      }(),
      additionalCompanies: () {
        final raw = map['additional_companies'];
        if (raw == null || raw.toString().isEmpty) return <Map<String, dynamic>>[];
        try {
          final decoded = jsonDecode(raw.toString());
          if (decoded is List) return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (_) {}
        return <Map<String, dynamic>>[];
      }(),
      landline: map['landline']?.toString(),
      whatsApp: map['whatsapp']?.toString(),
      email: map['email']?.toString() ?? '',
      website: map['website']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      district: map['district']?.toString(),
      stateName: map['state_name']?.toString(),
      pinCode: map['pin_code']?.toString(),
      socialLinks: socialLinks,
      source: (map['source'] != null && map['source'].toString().trim().isNotEmpty)
          ? map['source'].toString().trim()
          : (map['id']?.toString().startsWith('phone_') == true
              ? 'phone'
              : (map['is_matched'] == 1 || map['matched_user_id'] != null
                  ? 'smart_card'
                  : 'scanned')),
      syncStatus: map['sync_status']?.toString() ?? 'synced',
      cardUrl: map['card_url']?.toString(),
      profileImage: map['profile_image']?.toString(),
      imagePath: map['image_path']?.toString(),
      matchedCards: matchedCards,
      matchedUserId: map['matched_user_id']?.toString(),
      totalCardsCount: map['total_cards_count'] != null ? int.tryParse(map['total_cards_count'].toString()) : null,
      isMatched: map['is_matched'] == 1,
      isFavorite: map['is_favorite'] == 1,
      createdAt: map['created_at'] != null ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()) : DateTime.now(),
      isCorporate: map['is_corporate'] == 1,
      corporateGroup: map['corporate_group']?.toString(),
      corporateDepartment: map['corporate_department']?.toString(),
      corporateTags: parsedCorpTags,
      companyId: map['company_id']?.toString(),
    );
  }

  /// Saves or updates a scanned contact in the SQLite database / Web cache.
  static Future<void> saveContact(ScannedContactModel contact) async {
    if (kIsWeb) {
      await init();
      _webMemoryContacts.removeWhere((c) => c.id == contact.id);
      _webMemoryContacts.add(contact);
      _webMemoryContacts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _persistWebStorage();
      return;
    }

    final db = await _getDatabaseAsync();

    String? existingProfileImage;
    String? existingImagePath;

    // Check if a row with this exact ID already exists to preserve existing photo if not provided
    final existingRow = await db.query(
      tableContacts,
      where: 'id = ?',
      whereArgs: [contact.id],
      limit: 1,
    );

    if (existingRow.isNotEmpty) {
      final existing = _mapToContact(existingRow.first);
      if (existing.profileImage != null && existing.profileImage!.trim().isNotEmpty) {
        existingProfileImage = existing.profileImage;
      }
      if (existing.imagePath != null && existing.imagePath!.trim().isNotEmpty) {
        existingImagePath = existing.imagePath;
      }
    }

    final effectiveProfileImg = (contact.profileImage != null &&
            contact.profileImage!.trim().isNotEmpty &&
            contact.profileImage!.trim().toLowerCase() != 'null')
        ? contact.profileImage
        : ((contact.matchedProfileImage != null &&
                contact.matchedProfileImage!.trim().isNotEmpty &&
                contact.matchedProfileImage!.trim().toLowerCase() != 'null')
            ? contact.matchedProfileImage
            : existingProfileImage);

    final finalContact = contact.copyWith(
      profileImage: effectiveProfileImg,
      imagePath: (contact.imagePath == null || contact.imagePath!.trim().isEmpty) ? existingImagePath : contact.imagePath,
    );

    await db.insert(
      tableContacts,
      _contactToMap(finalContact),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Batch saves a list of contacts into SQLite or Web cache using high-speed transaction batch.
  static Future<void> saveContacts(List<ScannedContactModel> contacts) async {
    if (contacts.isEmpty) return;
    if (kIsWeb) {
      await init();
      for (final contact in contacts) {
        await saveContact(contact);
      }
      return;
    }
    final db = await _getDatabaseAsync();
    final batch = db.batch();
    for (final contact in contacts) {
      batch.insert(
        tableContacts,
        _contactToMap(contact),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Retrieves all contacts that have pending backend uploads.
  static Future<List<ScannedContactModel>> getPendingContactsAsync() async {
    if (kIsWeb) {
      await init();
      return _webMemoryContacts.where((c) => c.syncStatus == 'pending').toList();
    }
    final db = await _getDatabaseAsync();
    final rows = await db.query(tableContacts, where: 'sync_status = ?', whereArgs: ['pending']);
    return rows.map((r) => _mapToContact(r)).toList();
  }

  /// Deletes a contact permanently by its ID and direct ID variants ONLY.
  /// Never purges separate profiles sharing the same phone number or name.
  static Future<void> deleteContact(
    String id, {
    String? phone,
    String? email,
    String? name,
    String? company,
  }) async {
    final cleanId = id.trim();
    final rawId = cleanId.replaceFirst('phone_', '').replaceFirst('matched_', '');

    if (kIsWeb) {
      await init();
      _webMemoryContacts.removeWhere((c) {
        if (cleanId.isNotEmpty && (c.id == cleanId || c.id == rawId || c.id == 'phone_$rawId' || c.id == 'matched_$rawId')) {
          return true;
        }
        if (c.deviceContactId != null && rawId.isNotEmpty && c.deviceContactId == rawId &&
            (c.id == rawId || c.id == 'phone_$rawId' || c.id == 'matched_$rawId')) {
          return true;
        }
        return false;
      });
      await _persistWebStorage();
      return;
    }

    final db = await _getDatabaseAsync();
    final Set<String> idsToDelete = {};

    if (cleanId.isNotEmpty) {
      idsToDelete.add(cleanId);
    }
    if (rawId.isNotEmpty) {
      idsToDelete.add(rawId);
      idsToDelete.add('phone_$rawId');
      idsToDelete.add('matched_$rawId');
    }

    // Direct deletion by known ID variations ONLY
    for (final targetId in idsToDelete) {
      await db.delete(tableContacts, where: 'id = ?', whereArgs: [targetId]);
    }
    debugPrint('🗑️ [SqliteDatabase] Deleted contact $cleanId (variants: $idsToDelete) from SQLite.');
  }

  /// Clears all contacts and pending deletions from the database.
  /// Typically used during logout, account switch, or test teardowns.
  static Future<void> clearAllContacts() async {
    if (kIsWeb) {
      _webMemoryContacts.clear();
      _webMemoryPendingDeletions.clear();
      await _persistWebStorage();
      return;
    }
    try {
      final db = await _getDatabaseAsync();
      await db.delete(tableContacts);
      await db.delete(tablePendingDeletions);
      debugPrint('🧹 Cleared all contacts and pending deletions from SQLite.');
    } catch (e) {
      debugPrint('🚨 Failed to clear SQLite contacts: $e');
    }
  }

  /// Adds a contact ID to offline pending deletions table.
  static Future<void> addPendingDeletion(String id, {String? phone, String? email}) async {
    if (kIsWeb) {
      await init();
      _webMemoryPendingDeletions.removeWhere((t) => t['id'] == id);
      _webMemoryPendingDeletions.add({
        'id': id,
        'phone': phone ?? '',
        'email': email ?? '',
        'ts': DateTime.now().toIso8601String(),
      });
      await _persistWebStorage();
      return;
    }

    try {
      final db = await _getDatabaseAsync();
      await db.insert(
        tablePendingDeletions,
        {
          'id': id,
          'phone': phone ?? '',
          'email': email ?? '',
          'ts': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('📋 Added $id to offline pending deletions table in SQLite.');
    } catch (e) {
      debugPrint('🚨 Error adding pending deletion in SQLite: $e');
    }
  }

  /// Gets all pending deletion tombstones with details.
  static Future<List<Map<String, String>>> getPendingDeletionTombstonesAsync() async {
    if (kIsWeb) {
      await init();
      return List<Map<String, String>>.from(_webMemoryPendingDeletions);
    }
    try {
      final db = await _getDatabaseAsync();
      final rows = await db.query(tablePendingDeletions);
      return rows.map((r) => {
        'id': r['id']?.toString() ?? '',
        'phone': r['phone']?.toString() ?? '',
        'email': r['email']?.toString() ?? '',
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Removes a contact ID from the offline pending deletions table once synced.
  static Future<void> removePendingDeletion(String id) async {
    if (kIsWeb) {
      await init();
      _webMemoryPendingDeletions.removeWhere((t) => t['id'] == id);
      await _persistWebStorage();
      return;
    }
    try {
      final db = await _getDatabaseAsync();
      await db.delete(tablePendingDeletions, where: 'id = ?', whereArgs: [id]);
      debugPrint('✅ Cleared $id from SQLite pending deletions table.');
    } catch (e) {
      debugPrint('🚨 Error removing pending deletion from SQLite: $e');
    }
  }

  /// Async fetch of all contacts sorted by newest created_at.
  static Future<List<ScannedContactModel>> getAllContactsAsync() async {
    if (kIsWeb) {
      await init();
      final list = List<ScannedContactModel>.from(_webMemoryContacts);
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
    final db = await _getDatabaseAsync();
    final rows = await db.query(tableContacts, orderBy: 'created_at DESC');
    return rows.map((r) => _mapToContact(r)).toList();
  }

  /// Offline-First: Fetches all corporate contacts/leads with optional search query & group filter
  static Future<List<ScannedContactModel>> getCorporateContacts({String? query, String? group}) async {
    final all = await getAllContactsAsync();
    return all.where((c) {
      if (!c.isCorporate) return false;
      if (group != null && group.isNotEmpty && group.toUpperCase() != 'ALL') {
        if (c.corporateGroup?.toLowerCase() != group.toLowerCase()) return false;
      }
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchName = c.name.toLowerCase().contains(q);
        final matchCompany = c.company.toLowerCase().contains(q);
        final matchPhone = c.phone.contains(q);
        final matchDept = c.corporateDepartment?.toLowerCase().contains(q) ?? false;
        final matchGroup = c.corporateGroup?.toLowerCase().contains(q) ?? false;
        return matchName || matchCompany || matchPhone || matchDept || matchGroup;
      }
      return true;
    }).toList();
  }

  /// Offline-First: Fetches all personal contacts
  static Future<List<ScannedContactModel>> getPersonalContacts({String? query}) async {
    final all = await getAllContactsAsync();
    return all.where((c) {
      if (c.isCorporate) return false;
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchName = c.name.toLowerCase().contains(q);
        final matchCompany = c.company.toLowerCase().contains(q);
        final matchPhone = c.phone.contains(q);
        return matchName || matchCompany || matchPhone;
      }
      return true;
    }).toList();
  }

  /// Fetches a single contact by its ID.
  /// Falls back to phone-number matching if ID is empty or not found.
  static Future<ScannedContactModel?> getContactByIdOrPhone(String id, {String? phone}) async {
    if (kIsWeb) {
      await init();
      final cleanId = id.trim();
      final cleanP = _cleanPhone(phone ?? '');
      final p10 = cleanP.length >= 10 ? cleanP.substring(cleanP.length - 10) : cleanP;

      for (final c in _webMemoryContacts) {
        if (cleanId.isNotEmpty && c.id == cleanId) return c;
        if (p10.length >= 7) {
          final cp = _cleanPhone(c.phone);
          if (cp.isNotEmpty && cp.endsWith(p10)) return c;
        }
      }
      return null;
    }

    try {
      final db = await _getDatabaseAsync();

      // Try direct ID lookup first (fastest)
      if (id.isNotEmpty) {
        final rows = await db.query(tableContacts, where: 'id = ?', whereArgs: [id], limit: 1);
        if (rows.isNotEmpty) return _mapToContact(rows.first);
      }

      // Fallback: phone-number match
      if (phone != null && phone.isNotEmpty) {
        final cleanP = _cleanPhone(phone);
        if (cleanP.length >= 7) {
          final allRows = await db.query(tableContacts);
          for (final row in allRows) {
            final rowPhone = _cleanPhone(row['phone']?.toString() ?? '');
            final tail = cleanP.length >= 10 ? cleanP.substring(cleanP.length - 10) : cleanP;
            if (rowPhone.endsWith(tail)) return _mapToContact(row);
          }
        }
      }
    } catch (e) {
      debugPrint('Error in getContactByIdOrPhone: $e');
    }
    return null;
  }

  /// Reconciles SmartCard contacts in SQLite database with server contacts list.
  static Future<void> reconcileSmartCardContacts(List<ScannedContactModel> serverContacts) async {
    if (kIsWeb) {
      await init();
      final pendingTombstones = await getPendingDeletionTombstonesAsync();
      final pendingDeletionIds = <String>{};

      for (final t in pendingTombstones) {
        if (t['id']!.isNotEmpty) pendingDeletionIds.add(t['id']!);
      }

      final filtered = serverContacts.where((c) {
        if (pendingDeletionIds.contains(c.id)) return false;
        return true;
      }).toList();

      for (var contact in filtered) {
        await saveContact(contact);
      }
      debugPrint('🌐 Reconciled ${filtered.length} SmartCard contacts in Web Memory Storage.');
      return;
    }

    await _getDatabaseAsync();

    final pendingTombstones = await getPendingDeletionTombstonesAsync();
    final pendingDeletionIds = <String>{};

    for (final t in pendingTombstones) {
      if (t['id']!.isNotEmpty) pendingDeletionIds.add(t['id']!);
    }

    final filteredServerContacts = serverContacts.where((c) {
      if (pendingDeletionIds.contains(c.id)) return false;
      return true;
    }).toList();

    if (serverContacts.isEmpty) {
      debugPrint('ℹ️ Server contacts response is empty. Skipping reconcile in SQLite.');
      return;
    }

    // Only upsert valid server contacts — NEVER delete local scanned contacts or matched phone contacts!
    for (var contact in filteredServerContacts) {
      await saveContact(contact);
    }
    debugPrint('🔄 Reconciled ${filteredServerContacts.length} SmartCard contacts in SQLite (local scanned and matched contacts safely preserved).');
  }

  /// Updates the synchronization status of a contact in SQLite / Web.
  static Future<void> updateSyncStatus(String id, String status) async {
    if (kIsWeb) {
      await init();
      final idx = _webMemoryContacts.indexWhere((c) => c.id == id);
      if (idx >= 0) {
        _webMemoryContacts[idx] = _webMemoryContacts[idx].copyWith(syncStatus: status);
        await _persistWebStorage();
      }
      return;
    }
    final db = await _getDatabaseAsync();
    await db.update(
      tableContacts,
      {'sync_status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('🔄 Updated contact sync status ($id) in SQLite: $status');
  }

  static Future<void> saveShareLog(String title, String method) async {
    final entry = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'method': method,
      'timestamp': DateTime.now().toIso8601String(),
    };
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('web_share_history') ?? '[]';
        final list = List<Map<String, dynamic>>.from(jsonDecode(raw));
        list.insert(0, entry);
        await prefs.setString('web_share_history', jsonEncode(list));
      } catch (_) {}
      return;
    }
    try {
      final db = await _getDatabaseAsync();
      await db.execute('''
        CREATE TABLE IF NOT EXISTS share_history (
          id TEXT PRIMARY KEY,
          title TEXT,
          method TEXT,
          timestamp TEXT
        )
      ''');
      await db.insert('share_history', entry, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('Error saving share log: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getShareLogsAsync() async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('web_share_history') ?? '[]';
        final list = List<Map<String, dynamic>>.from(jsonDecode(raw));
        return list;
      } catch (_) {
        return [];
      }
    }
    try {
      final db = await _getDatabaseAsync();
      await db.execute('''
        CREATE TABLE IF NOT EXISTS share_history (
          id TEXT PRIMARY KEY,
          title TEXT,
          method TEXT,
          timestamp TEXT
        )
      ''');
      final maps = await db.query('share_history', orderBy: 'timestamp DESC');
      return List<Map<String, dynamic>>.from(maps);
    } catch (e) {
      debugPrint('Error fetching share logs: $e');
      return [];
    }
  }
}
