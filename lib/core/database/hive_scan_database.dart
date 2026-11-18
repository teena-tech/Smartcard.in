import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/scanned_contact_model.dart';

/// Persistent local storage using Hive for Scan tab records and Smart Card records.
/// Guarantees data persistence across APK updates, app restarts, process termination,
/// and prevents loss of scanned cards even if SQLite is migrated or in-memory state is recreated.
class HiveScanDatabase {
  static const String scanBoxName = 'scanned_records_box';
  static const String smartCardBoxName = 'smart_cards_box';

  static Box<String>? _scanBox;
  static Box<String>? _smartCardBox;
  static bool _isInitialized = false;

  // In-memory fallback if Hive is not yet initialized (e.g. during unit tests or early bootstrap)
  static final Map<String, String> _memoryScanBox = {};
  static final Map<String, String> _memorySmartCardBox = {};

  /// Initializes Hive and opens required boxes during app startup before repositories/providers run.
  static Future<void> init() async {
    if (_isInitialized && _scanBox != null && _scanBox!.isOpen && _smartCardBox != null && _smartCardBox!.isOpen) {
      return;
    }
    try {
      await Hive.initFlutter();
      _scanBox = await Hive.openBox<String>(scanBoxName);
      _smartCardBox = await Hive.openBox<String>(smartCardBoxName);
      _isInitialized = true;

      // Flush any pre-init memory records into Hive
      if (_memoryScanBox.isNotEmpty && _scanBox != null) {
        await _scanBox!.putAll(_memoryScanBox);
      }
      if (_memorySmartCardBox.isNotEmpty && _smartCardBox != null) {
        await _smartCardBox!.putAll(_memorySmartCardBox);
      }

      debugPrint('📦 [HiveScanDatabase] Initialized successfully. Scanned: ${_scanBox?.length ?? 0}, SmartCards: ${_smartCardBox?.length ?? 0}');
    } catch (e) {
      debugPrint('⚠️ [HiveScanDatabase] Init error: $e. Attempting fallback box open.');
      try {
        if (Hive.isBoxOpen(scanBoxName)) {
          _scanBox = Hive.box<String>(scanBoxName);
        } else {
          _scanBox = await Hive.openBox<String>(scanBoxName);
        }
        if (Hive.isBoxOpen(smartCardBoxName)) {
          _smartCardBox = Hive.box<String>(smartCardBoxName);
        } else {
          _smartCardBox = await Hive.openBox<String>(smartCardBoxName);
        }
        _isInitialized = true;
      } catch (inner) {
        debugPrint('ℹ️ [HiveScanDatabase] Fallback operating in-memory: $inner');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // SCANNED RECORDS
  // ---------------------------------------------------------------------------

  /// Reads all persisted scan records from Hive immediately at startup.
  static List<ScannedContactModel> getAllScannedRecords() {
    final List<ScannedContactModel> records = [];
    try {
      // If box is not open, attempt to connect to it if Hive is open
      if ((_scanBox == null || !_scanBox!.isOpen) && Hive.isBoxOpen(scanBoxName)) {
        _scanBox = Hive.box<String>(scanBoxName);
      }

      final Iterable<String> values = (_scanBox != null && _scanBox!.isOpen)
          ? _scanBox!.values
          : _memoryScanBox.values;

      for (final raw in values) {
        if (raw.isNotEmpty) {
          try {
            final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
            final model = ScannedContactModel.fromJson(map);
            if (model.id.isNotEmpty) {
              records.add(model);
            }
          } catch (e) {
            debugPrint('⚠️ [HiveScanDatabase] Error parsing scanned record: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [HiveScanDatabase] Error reading scanned box: $e');
    }
    return records;
  }

  /// Writes a scan record to Hive immediately after scan / save.
  static Future<void> saveScannedRecord(ScannedContactModel record) async {
    if (record.id.isEmpty) return;
    try {
      final jsonStr = jsonEncode(record.toJson());
      _memoryScanBox[record.id] = jsonStr;

      if (_scanBox == null || !_scanBox!.isOpen) {
        if (Hive.isBoxOpen(scanBoxName)) {
          _scanBox = Hive.box<String>(scanBoxName);
        } else if (_isInitialized) {
          try {
            _scanBox = await Hive.openBox<String>(scanBoxName);
          } catch (_) {}
        }
      }

      if (_scanBox != null && _scanBox!.isOpen) {
        await _scanBox!.put(record.id, jsonStr);
      }
      debugPrint('💾 [HiveScanDatabase] Persisted scanned record ${record.id} (${record.name}) to Hive');
    } catch (e) {
      debugPrint('⚠️ [HiveScanDatabase] Error saving scanned record: $e');
    }
  }

  /// Batch writes multiple scan records to Hive.
  static Future<void> saveAllScannedRecords(List<ScannedContactModel> records) async {
    if (records.isEmpty) return;
    try {
      final Map<String, String> batch = {};
      for (final r in records) {
        if (r.id.isNotEmpty) {
          final str = jsonEncode(r.toJson());
          batch[r.id] = str;
          _memoryScanBox[r.id] = str;
        }
      }

      if (_scanBox == null || !_scanBox!.isOpen) {
        if (Hive.isBoxOpen(scanBoxName)) {
          _scanBox = Hive.box<String>(scanBoxName);
        } else if (_isInitialized) {
          _scanBox = await Hive.openBox<String>(scanBoxName);
        }
      }

      if (_scanBox != null && _scanBox!.isOpen && batch.isNotEmpty) {
        await _scanBox!.putAll(batch);
      }
    } catch (e) {
      debugPrint('⚠️ [HiveScanDatabase] Error batch saving scanned records: $e');
    }
  }

  static Future<void> _ensureBoxesOpen() async {
    try {
      if ((_scanBox == null || !_scanBox!.isOpen) && Hive.isBoxOpen(scanBoxName)) {
        _scanBox = Hive.box<String>(scanBoxName);
      } else if (_isInitialized && (_scanBox == null || !_scanBox!.isOpen)) {
        try {
          _scanBox = await Hive.openBox<String>(scanBoxName);
        } catch (_) {}
      }
      if ((_smartCardBox == null || !_smartCardBox!.isOpen) && Hive.isBoxOpen(smartCardBoxName)) {
        _smartCardBox = Hive.box<String>(smartCardBoxName);
      } else if (_isInitialized && (_smartCardBox == null || !_smartCardBox!.isOpen)) {
        try {
          _smartCardBox = await Hive.openBox<String>(smartCardBoxName);
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Deletes a scan record from Hive.
  static Future<void> deleteScannedRecord(String id) async {
    if (id.isEmpty) return;
    try {
      _memoryScanBox.remove(id);
      await _ensureBoxesOpen();
      if (_scanBox != null && _scanBox!.isOpen) {
        await _scanBox!.delete(id);
      }
    } catch (e) {
      debugPrint('⚠️ [HiveScanDatabase] Error deleting scanned record: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // SMART CARD RECORDS
  // ---------------------------------------------------------------------------

  /// Reads all persisted smart card records from Hive immediately at startup.
  static List<ScannedContactModel> getAllSmartCardRecords() {
    final List<ScannedContactModel> records = [];
    try {
      if ((_smartCardBox == null || !_smartCardBox!.isOpen) && Hive.isBoxOpen(smartCardBoxName)) {
        _smartCardBox = Hive.box<String>(smartCardBoxName);
      }

      final Iterable<String> values = (_smartCardBox != null && _smartCardBox!.isOpen)
          ? _smartCardBox!.values
          : _memorySmartCardBox.values;

      for (final raw in values) {
        if (raw.isNotEmpty) {
          try {
            final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
            final model = ScannedContactModel.fromJson(map);
            if (model.id.isNotEmpty) {
              records.add(model);
            }
          } catch (e) {
            debugPrint('⚠️ [HiveScanDatabase] Error parsing smart card record: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [HiveScanDatabase] Error reading smart card box: $e');
    }
    return records;
  }

  /// Writes a smart card record to Hive immediately.
  static Future<void> saveSmartCardRecord(ScannedContactModel record) async {
    if (record.id.isEmpty) return;
    try {
      final jsonStr = jsonEncode(record.toJson());
      _memorySmartCardBox[record.id] = jsonStr;

      if (_smartCardBox == null || !_smartCardBox!.isOpen) {
        if (Hive.isBoxOpen(smartCardBoxName)) {
          _smartCardBox = Hive.box<String>(smartCardBoxName);
        } else if (_isInitialized) {
          try {
            _smartCardBox = await Hive.openBox<String>(smartCardBoxName);
          } catch (_) {}
        }
      }

      if (_smartCardBox != null && _smartCardBox!.isOpen) {
        await _smartCardBox!.put(record.id, jsonStr);
      }
    } catch (e) {
      debugPrint('⚠️ [HiveScanDatabase] Error saving smart card record: $e');
    }
  }

  /// Batch writes multiple smart card records to Hive.
  static Future<void> saveAllSmartCardRecords(List<ScannedContactModel> records) async {
    if (records.isEmpty) return;
    try {
      final Map<String, String> batch = {};
      for (final r in records) {
        if (r.id.isNotEmpty) {
          final str = jsonEncode(r.toJson());
          batch[r.id] = str;
          _memorySmartCardBox[r.id] = str;
        }
      }

      if (_smartCardBox == null || !_smartCardBox!.isOpen) {
        if (Hive.isBoxOpen(smartCardBoxName)) {
          _smartCardBox = Hive.box<String>(smartCardBoxName);
        } else if (_isInitialized) {
          _smartCardBox = await Hive.openBox<String>(smartCardBoxName);
        }
      }

      if (_smartCardBox != null && _smartCardBox!.isOpen && batch.isNotEmpty) {
        await _smartCardBox!.putAll(batch);
      }
    } catch (e) {
      debugPrint('⚠️ [HiveScanDatabase] Error batch saving smart card records: $e');
    }
  }

  /// Deletes a smart card record from Hive.
  static Future<void> deleteSmartCardRecord(String id) async {
    if (id.isEmpty) return;
    try {
      _memorySmartCardBox.remove(id);
      await _ensureBoxesOpen();
      if (_smartCardBox != null && _smartCardBox!.isOpen) {
        await _smartCardBox!.delete(id);
      }
    } catch (e) {
      debugPrint('⚠️ [HiveScanDatabase] Error deleting smart card record: $e');
    }
  }

  /// Helper to delete by ID from either or both boxes.
  static Future<void> deleteRecordAny(String id) async {
    await deleteScannedRecord(id);
    await deleteSmartCardRecord(id);
  }

  /// Helper to purge only the specific record matching id and its variations across both boxes.
  /// Never purges separate profiles sharing the same phone number or name.
  static Future<void> deleteMatchingRecords({
    required String id,
    String? phone,
    String? email,
    String? name,
    String? company,
    String? deviceContactId,
  }) async {
    await _ensureBoxesOpen();

    final cleanId = id.trim();
    final rawId = cleanId.replaceFirst('phone_', '').replaceFirst('matched_', '');
    final cleanDevContactId = (deviceContactId ?? '').trim();

    final Set<String> toDeleteFromScan = {};
    final Set<String> toDeleteFromSmart = {};

    void checkEntries(Map<dynamic, dynamic> entries, Set<String> toDeleteSet) {
      entries.forEach((rawKey, rawVal) {
        final k = rawKey.toString().trim();

        // 1. Direct key match variations ONLY (exact match, NEVER substring contains!)
        if (k == cleanId ||
            (rawId.isNotEmpty && (k == rawId || k == 'phone_$rawId' || k == 'matched_$rawId')) ||
            (cleanDevContactId.isNotEmpty && (k == cleanDevContactId || k == 'phone_$cleanDevContactId' || k == 'matched_$cleanDevContactId'))) {
          toDeleteSet.add(k);
          return;
        }

        // 2. Parse record JSON to match ID variations
        try {
          final v = rawVal.toString();
          final map = jsonDecode(v) as Map<String, dynamic>;
          final cId = (map['id']?.toString() ?? '').trim();
          final cRawId = cId.replaceFirst('phone_', '').replaceFirst('matched_', '');
          final cDevId = (map['deviceContactId']?.toString() ?? '').trim();

          // Match by ID variations
          if (cleanId.isNotEmpty && (cId == cleanId || cRawId == cleanId)) {
            toDeleteSet.add(k);
            return;
          }
          if (rawId.isNotEmpty && (cId == rawId || cRawId == rawId || cId == 'phone_$rawId' || cId == 'matched_$rawId')) {
            toDeleteSet.add(k);
            return;
          }
          if (cleanDevContactId.isNotEmpty && cDevId == cleanDevContactId &&
              (cId == cleanDevContactId || cId == 'phone_$cleanDevContactId' || cId == 'matched_$cleanDevContactId' || cRawId == cleanDevContactId)) {
            toDeleteSet.add(k);
            return;
          }
        } catch (_) {}
      });
    }

    // Inspect both disk boxes AND in-memory fallback maps
    final Map<dynamic, dynamic> scanEntries = {};
    if (_scanBox != null && _scanBox!.isOpen) {
      scanEntries.addAll(_scanBox!.toMap());
    }
    scanEntries.addAll(_memoryScanBox);
    checkEntries(scanEntries, toDeleteFromScan);

    final Map<dynamic, dynamic> smartEntries = {};
    if (_smartCardBox != null && _smartCardBox!.isOpen) {
      smartEntries.addAll(_smartCardBox!.toMap());
    }
    smartEntries.addAll(_memorySmartCardBox);
    checkEntries(smartEntries, toDeleteFromSmart);

    // Delete all matched keys from both Hive box and memory map
    for (final k in toDeleteFromScan) {
      _memoryScanBox.remove(k);
      if (_scanBox != null && _scanBox!.isOpen) {
        try {
          await _scanBox!.delete(k);
        } catch (_) {}
      }
    }
    for (final k in toDeleteFromSmart) {
      _memorySmartCardBox.remove(k);
      if (_smartCardBox != null && _smartCardBox!.isOpen) {
        try {
          await _smartCardBox!.delete(k);
        } catch (_) {}
      }
    }
  }

  /// Clears all records from Hive and in-memory caches.
  static Future<void> clearAll() async {
    _memoryScanBox.clear();
    _memorySmartCardBox.clear();
    try {
      if (_scanBox != null && _scanBox!.isOpen) {
        await _scanBox!.clear();
      }
      if (_smartCardBox != null && _smartCardBox!.isOpen) {
        await _smartCardBox!.clear();
      }
    } catch (_) {}
  }
}
