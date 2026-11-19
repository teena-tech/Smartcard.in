import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/database/sqlite_database.dart';
import '../../core/database/hive_scan_database.dart';
import '../../models/scanned_contact_model.dart';
import '../../models/app_contact.dart';
import '../../models/card_duplicate_check.dart';
import '../../core/services/contact_import_service.dart';
import '../../core/services/contact_saver_service.dart';
import '../../core/services/backend_sync_service.dart';
import '../../core/services/export_service.dart';
import '../../core/services/firebase_contact_sync_service.dart';
import '../../core/utils/upload_url_resolver.dart';
import '../../core/utils/phone_normalizer.dart';
import '../../core/utils/company_normalizer.dart';
import '../repositories/contact_repository.dart';

class ContactViewModel extends ChangeNotifier {
  final ContactRepository _repository = ContactRepository();

  List<ScannedContactModel> _allContacts = [];
  List<ScannedContactModel> _filteredContacts = [];

  // Dedicated precomputed lists for O(1) tab access without UI thread lag
  List<ScannedContactModel> _smartCardContacts = [];
  List<ScannedContactModel> _scannedContacts = [];
  int _dataVersion = 0;
  int _sqliteLoadSequence = 0;

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isMatchingPhones = false;
  DateTime? _lastMatchTimestamp;
  String _searchQuery = '';
  String _activeFilter = 'All'; // Default to 'All' so all synced & phone contacts show initially

  // Tracks contact IDs currently being deleted — blocks reconcile from re-adding them
  final Set<String> _deletingIds = {};

  // Pagination
  int _currentPage = 1;
  static const int _pageSize = 50;

  // Global static memory cache for instant 0ms restoration across app restarts & viewmodel instantiation
  static List<ScannedContactModel>? _globalMemoryContacts;
  static int _globalCachedSmartCardCount = 0;
  static int _globalCachedScannedCount = 0;
  static int _globalCachedPhoneCount = 0;

  ContactViewModel({bool autoLoad = true}) {
    // 1. Instantly restore persisted scan records and smart cards from Hive storage
    try {
      final hiveScans = HiveScanDatabase.getAllScannedRecords();
      final hiveSmart = HiveScanDatabase.getAllSmartCardRecords();
      if (hiveScans.isNotEmpty || hiveSmart.isNotEmpty) {
        _allContacts = _deduplicateScannedContacts([...hiveScans, ...hiveSmart]);
        _recomputeCounts();
      }
    } catch (e) {
      debugPrint('⚠️ ContactViewModel Hive initial load warning: $e');
    }

    if (_globalMemoryContacts != null && _globalMemoryContacts!.isNotEmpty) {
      _allContacts = _deduplicateScannedContacts([..._allContacts, ..._globalMemoryContacts!]);
      _recomputeCounts();
      _applyFilters();
    } else {
      _cachedMatchedCount = _globalCachedSmartCardCount;
      _cachedScannedCount = _globalCachedScannedCount;
      _cachedPhoneCount = _globalCachedPhoneCount;
    }
    _loadCachedCountsFromStorage();
    if (autoLoad) {
      _initAndLoad();
    }
  }

  /// Resets in-memory static caches (useful for testing or full app state resets).
  static void resetGlobalMemoryCacheForTesting() {
    _globalMemoryContacts = null;
    _globalCachedSmartCardCount = 0;
    _globalCachedScannedCount = 0;
    _globalCachedPhoneCount = 0;
  }

  Future<void> _loadCachedCountsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final smartCount = prefs.getInt('cached_smart_card_count_v1') ?? 0;
      final scanCount = prefs.getInt('cached_scanned_count_v1') ?? 0;
      final phoneCount = prefs.getInt('cached_phone_count_v1') ?? 0;
      bool changed = false;
      if (smartCount > 0 && _cachedMatchedCount == 0) {
        _cachedMatchedCount = smartCount;
        _globalCachedSmartCardCount = smartCount;
        changed = true;
      }
      if (scanCount > 0 && _cachedScannedCount == 0) {
        _cachedScannedCount = scanCount;
        _globalCachedScannedCount = scanCount;
        changed = true;
      }
      if (phoneCount > 0 && _cachedPhoneCount == 0) {
        _cachedPhoneCount = phoneCount;
        _globalCachedPhoneCount = phoneCount;
        changed = true;
      }
      if (changed) {
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _initAndLoad() async {
    await _loadLifetimeScanCount();
    await _loadSqliteContacts();
    await loadContactsFromBackend();
    await matchPhoneContactsWithServer(force: false);
  }

  List<ScannedContactModel> get contacts => _filteredContacts;
  List<ScannedContactModel> get allContacts => _allContacts;
  List<ScannedContactModel> get smartCardContacts => _smartCardContacts;
  List<ScannedContactModel> get scannedContacts => _scannedContacts;
  int get dataVersion => _dataVersion;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isMatchingPhones => _isMatchingPhones;
  String get searchQuery => _searchQuery;
  String get activeFilter => _activeFilter;

  int _lifetimeScanCount = 0;
  int _cachedMatchedCount = 0;
  int _cachedPhoneCount = 0;
  int _cachedScannedCount = 0;

  void _recomputeCounts() {
    int matched = 0;
    int phone = 0;
    int scanned = 0;
    final List<ScannedContactModel> smartList = [];
    final List<ScannedContactModel> scanList = [];

    for (final c in _allContacts) {
      final bool isPurePhone = c.source == 'phone' || c.id.startsWith('phone_');
      if (isPurePhone) {
        phone++;
      }
      if (c.isSmartCardUser) {
        matched++;
        smartList.add(c);
      }

      // Identify scanned business cards / OCR scans:
      if (!isPurePhone) {
        final src = (c.source ?? '').toLowerCase();
        final bool isScannedCard = src.contains('ocr') ||
            src.contains('business_card') ||
            src.contains('scan') ||
            src == 'scanned' ||
            src == 'card_scan' ||
            c.id.startsWith('scan_') ||
            (c.imagePath != null &&
                c.imagePath!.trim().isNotEmpty &&
                c.imagePath!.trim().toLowerCase() != 'null');
        if (isScannedCard) {
          scanned++;
          scanList.add(c);
        }
      }
    }

    _smartCardContacts = smartList;
    _scannedContacts = scanList;
    _dataVersion++;

    // Preserve valid count while loading/refreshing to avoid 0 flickering
    if (matched > 0) {
      _cachedMatchedCount = matched;
    } else if (!_isLoading && !_isRefreshing && _allContacts.isNotEmpty) {
      _cachedMatchedCount = 0;
    }

    if (scanned > 0 || (!_isLoading && !_isRefreshing)) {
      _cachedScannedCount = scanned;
    }

    _cachedPhoneCount = phone;

    _globalMemoryContacts = List.from(_allContacts);
    _globalCachedSmartCardCount = _cachedMatchedCount;
    _globalCachedScannedCount = _cachedScannedCount;
    _globalCachedPhoneCount = _cachedPhoneCount;

    if (_cachedScannedCount > _lifetimeScanCount) {
      _lifetimeScanCount = _cachedScannedCount;
    }
    _saveCachedCountsToStorage();
  }

  Future<void> _saveCachedCountsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_cachedMatchedCount > 0) {
        await prefs.setInt('cached_smart_card_count_v1', _cachedMatchedCount);
      }
      if (_cachedScannedCount > 0) {
        await prefs.setInt('cached_scanned_count_v1', _cachedScannedCount);
      }
      if (_cachedPhoneCount > 0) {
        await prefs.setInt('cached_phone_count_v1', _cachedPhoneCount);
      }
    } catch (_) {}
  }

  int get totalContactsCount => _allContacts.length;
  int get phoneContactsCount => _cachedPhoneCount;
  int get matchedContactsCount => _cachedMatchedCount;
  int get smartCardContactsCount {
    if (_smartCardContacts.isNotEmpty) return _smartCardContacts.length;
    final liveMatches = _allContacts.where((c) => c.isSmartCardUser).length;
    if (liveMatches > 0) return liveMatches;
    if (_cachedMatchedCount > 0) return _cachedMatchedCount;
    if (_globalCachedSmartCardCount > 0) return _globalCachedSmartCardCount;
    return 0;
  }
  int get scannedContactsCount => _scannedContacts.length;
  int get lifetimeScanCount => scannedContactsCount > _lifetimeScanCount ? scannedContactsCount : _lifetimeScanCount;

  /// Records a scan event instantly and persists across app restarts
  Future<void> recordScan() async {
    _lifetimeScanCount++;
    if (_cachedScannedCount > _lifetimeScanCount) {
      _lifetimeScanCount = _cachedScannedCount;
    }
    await _saveLifetimeScanCount(_lifetimeScanCount);
    notifyListeners();
  }

  Future<void> _loadLifetimeScanCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const storage = FlutterSecureStorage();

      final count1 = prefs.getInt('stats_lifetime_scan_count') ?? 0;
      final count2 = prefs.getInt('stats_scanned_cards') ?? 0;
      int maxLoaded = count1 > count2 ? count1 : count2;

      if (maxLoaded <= 0) {
        final secVal = await storage.read(key: 'stats_lifetime_scan_count') ??
            await storage.read(key: 'stats_scanned_cards');
        if (secVal != null) {
          maxLoaded = int.tryParse(secVal) ?? 0;
        }
      }

      _lifetimeScanCount = maxLoaded;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveLifetimeScanCount(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const storage = FlutterSecureStorage();

      if (count >= _lifetimeScanCount) {
        _lifetimeScanCount = count;
      }

      await prefs.setInt('stats_lifetime_scan_count', _lifetimeScanCount);
      await prefs.setInt('stats_scanned_cards', _lifetimeScanCount);

      await storage.write(key: 'stats_lifetime_scan_count', value: _lifetimeScanCount.toString());
      await storage.write(key: 'stats_scanned_cards', value: _lifetimeScanCount.toString());
    } catch (_) {}
  }

  void setActiveFilter(String filter) {
    if (_activeFilter != filter) {
      _activeFilter = filter;
      _currentPage = 1;
      _applyFilters();
    }
  }

  // ---------------------------------------------
  // HELPERS
  // ---------------------------------------------

  String _phone(String v) => v.replaceAll(RegExp(r'\D'), '');

  bool _phoneMatch(String a, String b) {
    if (PhoneNormalizer.isSame(a, b)) return true;
    final pa = _phone(a);
    final pb = _phone(b);
    return pa.length >= 7 && pb.length >= 7 && (pa.endsWith(pb.substring(pb.length >= 10 ? pb.length - 10 : 0)) || pb.endsWith(pa.substring(pa.length >= 10 ? pa.length - 10 : 0)));
  }

  bool _emailMatch(String a, String b) {
    final ea = a.trim().toLowerCase();
    final eb = b.trim().toLowerCase();
    return ea.isNotEmpty && ea == eb;
  }

  bool _contactMatches(ScannedContactModel c, String id, String phone, String email, String name, [String? company]) {
    if (c.id == id && id.isNotEmpty) return true;
    final rawTargetId = id.replaceFirst('phone_', '').replaceFirst('matched_', '');
    final rawCId = c.id.replaceFirst('phone_', '').replaceFirst('matched_', '');
    if (rawTargetId.isNotEmpty && rawCId == rawTargetId) return true;

    // Distinct scanned cards/profiles with different IDs should NEVER match/merge!
    final bool cIsScanned = c.source != 'phone' && !c.id.startsWith('phone_') && !c.id.startsWith('matched_');
    final bool targetIsScanned = !id.startsWith('phone_') && !id.startsWith('matched_') && id.isNotEmpty;
    if (cIsScanned && targetIsScanned && c.id != id) {
      return false; // Distinct cards — keep separate!
    }

    final cleanComp1 = (company ?? '').trim();
    final cleanComp2 = c.company.trim();

    // If either company is specified, they must match to be considered the same profile
    if (cleanComp1.isNotEmpty || cleanComp2.isNotEmpty) {
      if (!CompanyNormalizer.isSimilar(cleanComp1, cleanComp2)) {
        return false; // Distinct company profiles!
      }
    }

    // If names differ, they are distinct profiles
    final cleanName1 = name.trim().toLowerCase();
    final cleanName2 = c.name.trim().toLowerCase();
    if (cleanName1.isNotEmpty && cleanName2.isNotEmpty && cleanName1 != cleanName2) {
      return false;
    }

    // Only allow merging phone-imported contacts with server match
    if (c.source == 'phone' || c.id.startsWith('phone_')) {
      if (phone.isNotEmpty && _phoneMatch(c.phone, phone)) return true;
      if (email.isNotEmpty && _emailMatch(c.email, email)) return true;
    }
    return false;
  }

  // ---------------------------------------------
  // LOAD
  // ---------------------------------------------

  List<ScannedContactModel> _deduplicateScannedContacts(List<ScannedContactModel> list) {
    final Set<String> seenIds = {};
    final Map<String, int> seenCanonicalIdMap = {};
    final Map<String, int> seenProfileKeyMap = {};
    final List<ScannedContactModel> deduplicated = [];

    for (final c in list) {
      if (c.id.isEmpty) continue;
      final rawId = c.id.replaceFirst('phone_', '').replaceFirst('matched_', '');
      final canonicalId = rawId.isNotEmpty ? rawId : c.id;

      if (!seenIds.add(c.id)) {
        continue;
      }

      // If an existing item shares the same canonical ID (e.g. phone_123 vs matched_123), merge them!
      if (rawId.isNotEmpty && (c.id.startsWith('phone_') || c.id.startsWith('matched_'))) {
        final existingCanonicalIdx = seenCanonicalIdMap[canonicalId];
        if (existingCanonicalIdx != null) {
          final existing = deduplicated[existingCanonicalIdx];
          final merged = existing.copyWith(
            isMatched: existing.isMatched || c.isMatched,
            deviceContactId: (existing.deviceContactId != null && existing.deviceContactId!.isNotEmpty)
                ? existing.deviceContactId
                : c.deviceContactId,
            matchedUserId: (existing.matchedUserId != null && existing.matchedUserId!.isNotEmpty)
                ? existing.matchedUserId
                : c.matchedUserId,
            matchedProfileImage: (existing.matchedProfileImage != null && existing.matchedProfileImage!.isNotEmpty)
                ? existing.matchedProfileImage
                : c.matchedProfileImage,
            profileImage: (existing.profileImage != null && existing.profileImage!.isNotEmpty)
                ? existing.profileImage
                : c.profileImage,
            company: existing.company.isNotEmpty ? existing.company : c.company,
            designation: existing.designation.isNotEmpty ? existing.designation : c.designation,
            email: existing.email.isNotEmpty ? existing.email : c.email,
            website: existing.website.isNotEmpty ? existing.website : c.website,
            address: existing.address.isNotEmpty ? existing.address : c.address,
            cardUrl: (existing.cardUrl != null && existing.cardUrl!.isNotEmpty) ? existing.cardUrl : c.cardUrl,
            matchedCards: (existing.matchedCards != null && existing.matchedCards!.isNotEmpty)
                ? existing.matchedCards
                : c.matchedCards,
            totalCardsCount: existing.totalCardsCount ?? c.totalCardsCount,
          );
          deduplicated[existingCanonicalIdx] = merged;
          continue;
        }
      }

      // Check for exact profile match: same phone + same company + same name
      // This merges scanned records with server match/device records of the same profile
      final cleanPhone = PhoneNormalizer.last10(c.phone);
      final cleanComp = c.company.trim().toLowerCase();
      final cleanName = c.name.trim().toLowerCase();
      final profileKey = cleanPhone.length >= 7 ? '$cleanPhone|$cleanComp|$cleanName' : '';

      if (profileKey.isNotEmpty && seenProfileKeyMap.containsKey(profileKey)) {
        final existingIdx = seenProfileKeyMap[profileKey]!;
        final existing = deduplicated[existingIdx];

        // Merge fields: prefer whichever has matched data, photo, or deviceContactId
        final merged = existing.copyWith(
          isMatched: existing.isMatched || c.isMatched,
          deviceContactId: (existing.deviceContactId != null && existing.deviceContactId!.isNotEmpty)
              ? existing.deviceContactId
              : c.deviceContactId,
          matchedUserId: (existing.matchedUserId != null && existing.matchedUserId!.isNotEmpty)
              ? existing.matchedUserId
              : c.matchedUserId,
          matchedProfileImage: (existing.matchedProfileImage != null && existing.matchedProfileImage!.isNotEmpty)
              ? existing.matchedProfileImage
              : c.matchedProfileImage,
          profileImage: (existing.profileImage != null && existing.profileImage!.isNotEmpty)
              ? existing.profileImage
              : c.profileImage,
          company: existing.company.isNotEmpty ? existing.company : c.company,
          designation: existing.designation.isNotEmpty ? existing.designation : c.designation,
          email: existing.email.isNotEmpty ? existing.email : c.email,
          website: existing.website.isNotEmpty ? existing.website : c.website,
          address: existing.address.isNotEmpty ? existing.address : c.address,
          cardUrl: (existing.cardUrl != null && existing.cardUrl!.isNotEmpty) ? existing.cardUrl : c.cardUrl,
          matchedCards: (existing.matchedCards != null && existing.matchedCards!.isNotEmpty)
              ? existing.matchedCards
              : c.matchedCards,
          totalCardsCount: existing.totalCardsCount ?? c.totalCardsCount,
        );
        deduplicated[existingIdx] = merged;
        continue;
      }

      if (rawId.isNotEmpty && (c.id.startsWith('phone_') || c.id.startsWith('matched_'))) {
        seenCanonicalIdMap[canonicalId] = deduplicated.length;
      }
      if (profileKey.isNotEmpty) {
        seenProfileKeyMap[profileKey] = deduplicated.length;
      }
      deduplicated.add(c);
    }

    return deduplicated;
  }

  /// Finds an existing contact by phone number (checks primary, alt, and extra phones).
  ScannedContactModel? findContactByPhone(String phone) {
    final p10 = PhoneNormalizer.last10(phone);
    if (p10.length < 7) return null;
    for (final c in _allContacts) {
      if (PhoneNormalizer.isSame(c.phone, phone)) return c;
      if (c.alternativePhone != null && PhoneNormalizer.isSame(c.alternativePhone!, phone)) return c;
      for (final ap in c.additionalPhones) {
        if (PhoneNormalizer.isSame(ap, phone)) return c;
      }
    }
    return null;
  }

  /// Returns all contacts sharing the same normalized phone number (last 10 digits).
  List<ScannedContactModel> getContactsForPhone(String phone) {
    final p10 = PhoneNormalizer.last10(phone);
    if (p10.length < 7) return [];
    return _allContacts.where((c) {
      if (PhoneNormalizer.last10(c.phone) == p10) return true;
      if (c.alternativePhone != null && PhoneNormalizer.last10(c.alternativePhone!) == p10) return true;
      for (final ap in c.additionalPhones) {
        if (PhoneNormalizer.last10(ap) == p10) return true;
      }
      return false;
    }).toList();
  }

  /// Saves [incoming] as a brand-new independent record (different company, same phone).
  Future<ScannedContactModel> saveAsNewCompanyRecord(ScannedContactModel incoming) async {
    final newId = 'scan_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';
    final newContact = incoming.copyWith(id: newId);
    await SqliteDatabase.saveContact(newContact);
    await HiveScanDatabase.saveScannedRecord(newContact);
    await _loadSqliteContacts();
    notifyListeners();

    // Background cloud backup to Firebase Firestore
    FirebaseContactSyncService().syncContactToFirebase(newContact);
    return newContact;
  }

  /// Saves a newly scanned card when it has the same phone number as an existing contact,
  /// preserving all companies into a single profile.
  Future<ScannedContactModel> saveMultiCompanyScan({
    required ScannedContactModel incoming,
    required ScannedContactModel existing,
    required Map<String, dynamic> chosenFields,
  }) async {
    _sqliteLoadSequence++;

    // 1. Compile incoming company profile
    final incomingCompProfile = <String, dynamic>{
      'company': chosenFields['company']?.toString() ?? incoming.company,
      'designation': chosenFields['designation']?.toString() ?? incoming.designation,
      'email': chosenFields['email']?.toString() ?? incoming.email,
      'website': chosenFields['website']?.toString() ?? incoming.website,
      'address': chosenFields['address']?.toString() ?? incoming.address,
      if (incoming.imagePath != null) 'imagePath': incoming.imagePath,
    };

    // 2. Merge company profiles into the single existing record's additionalCompanies list
    final List<Map<String, dynamic>> existingAdditional = List.from(existing.additionalCompanies);
    final inCompName = incomingCompProfile['company']?.toString().trim().toLowerCase() ?? '';
    final chosenCompany = chosenFields['company']?.toString().trim() ?? incoming.company.trim();

    // If existing company is different from chosen company, preserve existing in additionalCompanies
    if (existing.company.trim().isNotEmpty &&
        chosenCompany.isNotEmpty &&
        existing.company.trim().toLowerCase() != chosenCompany.toLowerCase() &&
        !existingAdditional.any((c) => (c['company']?.toString().trim().toLowerCase() ?? '') == existing.company.trim().toLowerCase())) {
      existingAdditional.add({
        'company': existing.company,
        'designation': existing.designation,
        'email': existing.email,
        'website': existing.website,
        'address': existing.address,
        if (existing.imagePath != null) 'imagePath': existing.imagePath,
      });
    }

    if (inCompName.isNotEmpty &&
        inCompName != chosenCompany.toLowerCase() &&
        !existingAdditional.any((c) => (c['company']?.toString().trim().toLowerCase() ?? '') == inCompName)) {
      existingAdditional.add(incomingCompProfile);
    }

    // 3. Create new profile with chosen fields and preserve links to other companies
    final newId = incoming.id.isNotEmpty && incoming.id != existing.id
        ? incoming.id
        : 'scan_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';

    final savedNewProfile = incoming.copyWith(
      id: newId,
      name: chosenFields['name']?.toString().isNotEmpty == true ? chosenFields['name']!.toString() : (incoming.name.isNotEmpty ? incoming.name : existing.name),
      company: chosenCompany.isNotEmpty ? chosenCompany : incoming.company,
      designation: chosenFields['designation']?.toString().isNotEmpty == true ? chosenFields['designation']!.toString() : (incoming.designation.isNotEmpty ? incoming.designation : existing.designation),
      email: chosenFields['email']?.toString().isNotEmpty == true ? chosenFields['email']!.toString() : (incoming.email.isNotEmpty ? incoming.email : existing.email),
      website: chosenFields['website']?.toString().isNotEmpty == true ? chosenFields['website']!.toString() : (incoming.website.isNotEmpty ? incoming.website : existing.website),
      address: chosenFields['address']?.toString().isNotEmpty == true ? chosenFields['address']!.toString() : (incoming.address.isNotEmpty ? incoming.address : existing.address),
      additionalCompanies: existingAdditional,
      updatedAt: DateTime.now(),
    );

    // Save existing record ensuring it is kept in database
    await SqliteDatabase.saveContact(existing);
    await HiveScanDatabase.saveScannedRecord(existing);

    // Save newly scanned company profile as a separate record
    await SqliteDatabase.saveContact(savedNewProfile);
    await HiveScanDatabase.saveScannedRecord(savedNewProfile);

    _mergeContacts([existing, savedNewProfile]);

    await _loadSqliteContacts();
    _recomputeCounts();
    notifyListeners();

    FirebaseContactSyncService().syncContactToFirebase(savedNewProfile);
    return savedNewProfile;
  }

  Future<void> _loadSqliteContacts() async {
    final seq = ++_sqliteLoadSequence;
    try {
      final cached = await SqliteDatabase.getAllContactsAsync();
      final hiveScans = HiveScanDatabase.getAllScannedRecords();
      final hiveSmart = HiveScanDatabase.getAllSmartCardRecords();
      if (seq != _sqliteLoadSequence) return;
      final combined = _deduplicateScannedContacts([...cached, ...hiveScans, ...hiveSmart]);
      if (combined.isNotEmpty) {
        if (seq != _sqliteLoadSequence) return;
        combined.removeWhere((c) => _deletingIds.contains(c.id));
        _allContacts = combined;
        _allContacts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _recomputeCounts();
        _isLoading = false;
        _applyFilters();
        _precacheMatchedImages();
        notifyListeners();

        // Dual persistence: ensure all scans and smart cards exist in Hive
        if (_scannedContacts.isNotEmpty) {
          HiveScanDatabase.saveAllScannedRecords(_scannedContacts);
        }
        if (_smartCardContacts.isNotEmpty) {
          HiveScanDatabase.saveAllSmartCardRecords(_smartCardContacts);
        }
      }
    } catch (e) {
      debugPrint('Error loading SQLite contacts: $e');
    }
  }

  void _precacheMatchedImages() {
    // Run asynchronously without blocking frame rendering
    Future.microtask(() {
      for (final c in _allContacts) {
        final img = c.matchedProfileImage ?? c.profileImage;
        if (img != null && img.isNotEmpty && (img.startsWith('http://') || img.startsWith('https://') || !img.contains('data:'))) {
          final cleanUrl = UploadUrlResolver.resolve(img, type: 'profile');
          if (cleanUrl.isNotEmpty && (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://'))) {
            try {
              final provider = CachedNetworkImageProvider(
                cleanUrl,
                cacheKey: cleanUrl.split('?').first,
              );
              provider.resolve(const ImageConfiguration());
            } catch (_) {}
          }
        }
      }
    });
  }

  Future<void> loadContactsFromBackend({int page = 1}) async {
    if (_allContacts.isEmpty) {
      _isLoading = true;
    } else {
      _isRefreshing = true;
    }
    notifyListeners();

    try {
      await _flushPendingDeletions();

      final rawContacts = await _repository.getContacts(page: page, limit: 100);
      final serverContacts = <ScannedContactModel>[];

      for (final item in rawContacts) {
        if (item is Map<String, dynamic>) {
          try {
            final parsed = ScannedContactModel.fromJson(item);
            serverContacts.add(
              parsed.copyWith(
                source: (item['source'] != null && item['source'].toString().isNotEmpty)
                    ? item['source'].toString()
                    : parsed.source,
                syncStatus: 'synced',
              ),
            );
          } catch (e) {
            debugPrint('Error parsing contact item: $e');
          }
        }
      }

      // Filter out any contacts that are currently being deleted to prevent re-adding them
      // STRICTLY filter by contact ID so independent records sharing a phone number are preserved
      final safeServerContacts = serverContacts.where((c) {
        return !_deletingIds.contains(c.id);
      }).toList();

      await SqliteDatabase.reconcileSmartCardContacts(safeServerContacts);

      final cached = await SqliteDatabase.getAllContactsAsync();
      final hiveScans = HiveScanDatabase.getAllScannedRecords();
      final hiveSmart = HiveScanDatabase.getAllSmartCardRecords();
      _allContacts = _deduplicateScannedContacts([...cached, ...hiveScans, ...hiveSmart]);
      _allContacts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _recomputeCounts();
      if (_smartCardContacts.isNotEmpty) {
        HiveScanDatabase.saveAllSmartCardRecords(_smartCardContacts);
      }
      // Bulk sync local Hive scans to Firebase Firestore & restore any missing ones
      try {
        FirebaseContactSyncService().syncAllLocalScansToFirebase();
        final restored = await FirebaseContactSyncService().restoreContactsFromFirebase();
        if (restored.isNotEmpty) {
          final refreshedHive = HiveScanDatabase.getAllScannedRecords();
          _allContacts = _deduplicateScannedContacts([..._allContacts, ...refreshedHive]);
          _allContacts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _recomputeCounts();
        }
      } catch (e) {
        debugPrint('⚠️ Firebase sync/restore during load error: $e');
      }

      await _saveLifetimeScanCount(scannedContactsCount);
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading contacts from backend: $e');
      await _loadSqliteContacts();
    } finally {
      _isRefreshing = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------
  // SEARCH & PAGINATION
  // ---------------------------------------------

  void setSearchQuery(String query) {
    _searchQuery = query;
    _currentPage = 1;
    _applyFilters();
  }

  void loadMore() {
    if ((_currentPage * _pageSize) < _allContacts.length) {
      _currentPage++;
      _applyFilters();
    }
  }

  void _applyFilters() {
    List<ScannedContactModel> filtered = _allContacts;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.phone.contains(q) ||
            (c.alternativePhone?.contains(q) ?? false) ||
            c.email.toLowerCase().contains(q) ||
            c.company.toLowerCase().contains(q);
      }).toList();
    }

    if (_activeFilter == 'Phone') {
      filtered = filtered.where((c) => c.source == 'phone' || c.id.startsWith('phone_')).toList();
    } else if (_activeFilter == 'Matched') {
      filtered = filtered.where((c) => c.isMatched || (c.matchedUserId != null && c.matchedUserId!.isNotEmpty) || (c.matchedCards != null && c.matchedCards!.isNotEmpty)).toList();
    } else if (_activeFilter == 'Scanned') {
      filtered = filtered.where((c) {
        if (c.source == 'phone' || c.id.startsWith('phone_')) return false;
        return true;
      }).toList();
    } else if (_activeFilter == 'Favorites') {
      filtered = filtered.where((c) => c.isFavorite).toList();
    }

    final end = (_currentPage * _pageSize).clamp(0, filtered.length);
    _filteredContacts = filtered.sublist(0, end);
    notifyListeners();
  }

  // ---------------------------------------------
  // PHONE MATCHING WITH BACKEND (Batched & Persisted)
  // ---------------------------------------------

  Future<void> matchPhoneContactsWithServer({
    bool force = false,
    List<String>? devicePhones,
    Map<String, String>? phoneToNameMap,
    Map<String, String>? phoneToDevIdMap,
  }) async {
    if (_isMatchingPhones) return;

    final now = DateTime.now();
    if (!force && _lastMatchTimestamp != null && now.difference(_lastMatchTimestamp!).inMinutes < 15) {
      debugPrint('Skipping phone matching API: throttled within 15 mins.');
      return;
    }

    _isMatchingPhones = true;
    notifyListeners();

    try {
      final phoneNumbers = _allContacts
          .map((c) => c.phone.trim())
          .where((p) => p.isNotEmpty)
          .toSet();

      if (devicePhones != null) {
        for (final p in devicePhones) {
          final cleaned = p.trim();
          if (cleaned.isNotEmpty) phoneNumbers.add(cleaned);
        }
      }

      final phoneList = phoneNumbers.toList();
      if (phoneList.isEmpty) return;

      // Batch phone numbers in chunks of 200 for fast & safe payload delivery
      const chunkSize = 200;
      final rawMatches = <dynamic>[];

      for (var i = 0; i < phoneList.length; i += chunkSize) {
        final chunk = phoneList.sublist(
          i,
          (i + chunkSize > phoneList.length) ? phoneList.length : i + chunkSize,
        );
        try {
          final batchMatches = await _repository.matchPhoneContacts(chunk);
          if (batchMatches.isNotEmpty) {
            rawMatches.addAll(batchMatches);
          }
        } catch (err) {
          debugPrint('Error matching batch $i to ${i + chunk.length}: $err');
        }
      }

      if (rawMatches.isEmpty) {
        _lastMatchTimestamp = DateTime.now();
        return;
      }

      bool updatedAny = false;

      for (final item in rawMatches) {
        if (item is Map<String, dynamic>) {
          final matchedPhone = item['matchedPhone']?.toString() ?? '';
          final matchedTenDigit = item['matchedTenDigit']?.toString() ?? '';

          if (matchedPhone.isEmpty && matchedTenDigit.isEmpty) continue;

          final contactsToUpdate = _allContacts.where((c) {
            final p = _phone(c.phone);
            return (matchedTenDigit.isNotEmpty && p.endsWith(matchedTenDigit)) ||
                   (matchedPhone.isNotEmpty && _phoneMatch(c.phone, matchedPhone));
          }).toList();

          String? resolveMatchedImage(Map<String, dynamic> itm) {
            final candidates = [
              itm['profileImage'],
              itm['profile_image'],
              itm['profileImageName'],
              itm['profile_image_name'],
              itm['matched_profile_image'],
              itm['matchedProfileImage'],
              itm['user_image'],
              itm['userImage'],
              itm['user_photo'],
              itm['userPhoto'],
              itm['avatar'],
              itm['image'],
              itm['photo'],
              itm['logo'],
              itm['company_logo'],
              itm['companyLogo'],
            ];
            for (final c in candidates) {
              if (c != null && c.toString().trim().isNotEmpty && c.toString().trim().toLowerCase() != 'null') {
                return c.toString().trim();
              }
            }

            final cardsList = (itm['cards'] as Iterable?) ?? (itm['matchedCards'] as Iterable?);
            if (cardsList != null) {
              for (final card in cardsList) {
                if (card is Map) {
                  final cardCandidates = [
                    card['profileImageName'],
                    card['profile_image_name'],
                    card['profileImage'],
                    card['profile_image'],
                    card['user_image'],
                    card['userImage'],
                    card['user_photo'],
                    card['userPhoto'],
                    card['avatar'],
                    card['image'],
                    card['photo'],
                    card['logo'],
                    card['company_logo'],
                    card['companyLogo'],
                    card['front_image'],
                    card['card_image'],
                    card['image_url'],
                    card['url'],
                  ];
                  for (final c in cardCandidates) {
                    if (c != null && c.toString().trim().isNotEmpty && c.toString().trim().toLowerCase() != 'null') {
                      return c.toString().trim();
                    }
                  }
                }
              }
            }
            return null;
          }

          final resolvedProfileImg = resolveMatchedImage(item);
          final resolvedCompanyName = item['company']?.toString().trim().isNotEmpty == true
              ? item['company'].toString().trim()
              : (item['companyName']?.toString().trim().isNotEmpty == true ? item['companyName'].toString().trim() : '');

          final resolvedDevContactId = phoneToDevIdMap != null
              ? (phoneToDevIdMap[matchedTenDigit] ??
                  phoneToDevIdMap[matchedPhone] ??
                  phoneToDevIdMap[_phone(matchedPhone)])
              : null;

          if (contactsToUpdate.isNotEmpty) {
            for (final contact in contactsToUpdate) {
              final updated = contact.copyWith(
                isMatched: true,
                deviceContactId: contact.deviceContactId ?? resolvedDevContactId,
                company: resolvedCompanyName.isNotEmpty ? resolvedCompanyName : contact.company,
                matchedUserId: item['userId']?.toString(),
                totalCardsCount: item['cardCount'] is int
                    ? item['cardCount'] as int
                    : int.tryParse(item['cardCount']?.toString() ?? ''),
                primaryDesignation: item['designation']?.toString(),
                cardUrl: item['cardUrl']?.toString(),
                matchedProfileImage: resolvedProfileImg ?? contact.matchedProfileImage,
                matchedCards: (item['cards'] as Iterable?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ??
                    (item['matchedCards'] as Iterable?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
              );
              await SqliteDatabase.saveContact(updated);
              await HiveScanDatabase.saveSmartCardRecord(updated);
              updatedAny = true;
            }
          } else {
            // Create a new matched contact record from device phone
            String contactName = item['name']?.toString() ?? item['displayName']?.toString() ?? '';
            if (contactName.trim().isEmpty || contactName.trim().toLowerCase() == 'smartcard user') {
              if (phoneToNameMap != null) {
                final cleanP = matchedTenDigit.isNotEmpty ? matchedTenDigit : _phone(matchedPhone);
                contactName = phoneToNameMap[cleanP] ?? phoneToNameMap[matchedPhone] ?? 'SmartCard User';
              } else {
                contactName = 'SmartCard User';
              }
            }

            final newMatched = ScannedContactModel(
              id: 'matched_${item['userId'] ?? (matchedTenDigit.isNotEmpty ? matchedTenDigit : matchedPhone)}',
              deviceContactId: resolvedDevContactId,
              name: contactName,
              company: resolvedCompanyName,
              designation: item['designation']?.toString() ?? '',
              phone: matchedPhone.isNotEmpty ? matchedPhone : matchedTenDigit,
              email: item['email']?.toString() ?? '',
              website: '',
              address: '',
              socialLinks: const [],
              source: 'phone',
              isMatched: true,
              matchedUserId: item['userId']?.toString(),
              totalCardsCount: item['cardCount'] is int
                  ? item['cardCount'] as int
                  : int.tryParse(item['cardCount']?.toString() ?? ''),
              primaryDesignation: item['designation']?.toString(),
              cardUrl: item['cardUrl']?.toString(),
              matchedProfileImage: resolvedProfileImg,
              matchedCards: (item['cards'] as Iterable?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ??
                  (item['matchedCards'] as Iterable?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
              createdAt: DateTime.now(),
            );
            await SqliteDatabase.saveContact(newMatched);
            await HiveScanDatabase.saveSmartCardRecord(newMatched);
            updatedAny = true;
          }
        }
      }

      _lastMatchTimestamp = DateTime.now();

      if (updatedAny) {
        await _loadSqliteContacts();
      }
    } catch (e) {
      debugPrint('Error matching phone contacts with server: $e');
    } finally {
      _isMatchingPhones = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------
  // MERGE (dedup by id / phone / email)
  // ---------------------------------------------

  void _mergeContacts(List<ScannedContactModel> incoming) {
    for (final contact in incoming) {
      if (_deletingIds.contains(contact.id)) continue;
      final idx = _allContacts.indexWhere(
        (c) => _contactMatches(c, contact.id, contact.phone, contact.email, contact.name, contact.company),
      );

      if (idx != -1) {
        final old = _allContacts[idx];
        final bool oldIsScanned = old.source != 'phone' && !old.id.startsWith('phone_');
        final bool incomingIsPhone = contact.source == 'phone' || contact.id.startsWith('phone_');

        if (oldIsScanned && incomingIsPhone) {
          // Keep old scanned ID and source, but merge any extra details from phone contact
          _allContacts[idx] = old.copyWith(
            profileImage: old.profileImage?.isNotEmpty == true ? old.profileImage : contact.profileImage,
            imagePath: old.imagePath?.isNotEmpty == true ? old.imagePath : contact.imagePath,
            company: old.company.isNotEmpty ? old.company : contact.company,
            designation: old.designation.isNotEmpty ? old.designation : contact.designation,
            email: old.email.isNotEmpty ? old.email : contact.email,
            isMatched: old.isMatched || contact.isMatched,
            matchedUserId: old.matchedUserId ?? contact.matchedUserId,
            matchedProfileImage: old.matchedProfileImage ?? contact.matchedProfileImage,
            matchedCards: old.matchedCards ?? contact.matchedCards,
            cardUrl: (old.cardUrl?.isNotEmpty == true) ? old.cardUrl : contact.cardUrl,
          );
        } else {
          _allContacts[idx] = contact.copyWith(
            id: (oldIsScanned) ? old.id : contact.id,
            source: (oldIsScanned) ? old.source : contact.source,
            isMatched: old.isMatched || contact.isMatched,
            matchedUserId: old.matchedUserId ?? contact.matchedUserId,
            matchedProfileImage: old.matchedProfileImage ?? contact.matchedProfileImage,
            matchedCards: old.matchedCards ?? contact.matchedCards,
            cardUrl: (contact.cardUrl?.isNotEmpty == true) ? contact.cardUrl : old.cardUrl,
            profileImage: contact.profileImage?.isNotEmpty == true ? contact.profileImage : old.profileImage,
            imagePath: contact.imagePath?.isNotEmpty == true ? contact.imagePath : old.imagePath,
          );
        }
      } else {
        _allContacts.add(contact);
      }
    }
    _allContacts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _recomputeCounts();
  }

  // ---------------------------------------------
  // DUPLICATE DETECTION & MERGE
  // ---------------------------------------------

  /// Evaluates [incoming] scanned card against existing database & in-memory contacts.
  /// Distinguishes between:
  ///   - [CardDuplicateType.exactDuplicate]: Same card (identical ID, digital card URL, or same phone + same name/company)
  ///   - [CardDuplicateType.sameNumberDifferentCard]: Same card/phone number, but different physical card / person
  ///   - [CardDuplicateType.none]: Unique new card
  CardDuplicateCheck checkCardDuplicate(
    ScannedContactModel incoming, {
    List<AppContact>? phoneContacts,
  }) {
    final inPhone = incoming.phone.trim();
    final inPhone10 = PhoneNormalizer.last10(inPhone);
    final inEmail = incoming.email.trim().toLowerCase();
    final inName = incoming.name.trim().toLowerCase();
    final inCompany = incoming.company.trim().toLowerCase();
    final inCardUrl = (incoming.cardUrl ?? '').trim().toLowerCase();
    final inMatchedUserId = (incoming.matchedUserId ?? '').trim();

    CardDuplicateCheck? pendingSameNumberCheck;

    for (final c in _allContacts) {
      // 1. Exact ID match
      if (incoming.id.isNotEmpty && c.id == incoming.id) {
        return CardDuplicateCheck(
          type: CardDuplicateType.exactDuplicate,
          existingContact: c,
          matchedField: 'ID',
        );
      }

      // 2. Exact Card URL match (Digital SmartCard link)
      if (inCardUrl.isNotEmpty && (c.cardUrl ?? '').trim().isNotEmpty) {
        if (c.cardUrl!.trim().toLowerCase() == inCardUrl) {
          return CardDuplicateCheck(
            type: CardDuplicateType.exactDuplicate,
            existingContact: c,
            matchedField: 'Card URL',
          );
        }
      }

      // 3. Exact Matched User ID match
      if (inMatchedUserId.isNotEmpty && (c.matchedUserId ?? '').trim().isNotEmpty) {
        if (c.matchedUserId!.trim() == inMatchedUserId) {
          return CardDuplicateCheck(
            type: CardDuplicateType.exactDuplicate,
            existingContact: c,
            matchedField: 'User Card ID',
          );
        }
      }

      // 4. Phone Match Evaluation (Primary, Alternative, or Additional Phones)
      bool phoneMatched = false;
      String? matchedPhone;
      if (inPhone10.length >= 7) {
        if (PhoneNormalizer.isSame(c.phone, inPhone)) {
          phoneMatched = true;
          matchedPhone = c.phone;
        } else if (c.alternativePhone != null && PhoneNormalizer.isSame(c.alternativePhone!, inPhone)) {
          phoneMatched = true;
          matchedPhone = c.alternativePhone;
        } else {
          for (final ap in c.additionalPhones) {
            if (PhoneNormalizer.isSame(ap, inPhone)) {
              phoneMatched = true;
              matchedPhone = ap;
              break;
            }
          }
        }
      }

      if (phoneMatched) {
        final cName = c.name.trim().toLowerCase();
        final cCompany = c.company.trim();

        // 1. Both have company info specified
        if (inCompany.isNotEmpty && cCompany.isNotEmpty) {
          if (CompanyNormalizer.isSimilar(inCompany, cCompany)) {
            // Same phone + same or similar company -> CASE A: Duplicate / Scam Alert
            return CardDuplicateCheck(
              type: CardDuplicateType.exactDuplicate,
              existingContact: c,
              matchedField: 'Phone: $matchedPhone & Company: ${c.company}',
            );
          }

          // Check if incoming company matches any company in additionalCompanies
          for (final ac in c.additionalCompanies) {
            final acComp = ac['company']?.toString().trim() ?? '';
            if (acComp.isNotEmpty && CompanyNormalizer.isSimilar(inCompany, acComp)) {
              return CardDuplicateCheck(
                type: CardDuplicateType.exactDuplicate,
                existingContact: c,
                matchedField: 'Phone: $matchedPhone & Company: $acComp',
              );
            }
          }

          // Same phone + different company -> candidate for CASE B.
          // Don't return immediately; keep searching in case another card sharing this phone is an exact match!
          pendingSameNumberCheck ??= CardDuplicateCheck(
            type: CardDuplicateType.sameNumberDifferentCard,
            existingContact: c,
            matchedField: 'Phone: $matchedPhone',
          );
          continue;
        }

        // 2. Company information is missing from one or both cards
        // Requirement 8: "If company information is missing from either card, do not automatically
        // classify it as a different company solely because the company field is empty."
        final bool bothNamesPresent = inName.isNotEmpty && cName.isNotEmpty;
        final bool nameMatches = bothNamesPresent &&
            (inName == cName || inName.contains(cName) || cName.contains(inName));
        final bool emailMatches = inEmail.isNotEmpty && inEmail == c.email.trim().toLowerCase();

        if (bothNamesPresent && !nameMatches && !emailMatches) {
          // Distinctly different person names sharing phone -> CASE B
          pendingSameNumberCheck ??= CardDuplicateCheck(
            type: CardDuplicateType.sameNumberDifferentCard,
            existingContact: c,
            matchedField: 'Phone: $matchedPhone',
          );
          continue;
        }

        // Same person name, matching email, or one name empty -> CASE A: Exact Duplicate
        return CardDuplicateCheck(
          type: CardDuplicateType.exactDuplicate,
          existingContact: c,
          matchedField: 'Phone: $matchedPhone',
        );
      }

      // 5. Email Match
      if (inEmail.isNotEmpty && c.email.trim().isNotEmpty) {
        if (c.email.trim().toLowerCase() == inEmail) {
          final cName = c.name.trim().toLowerCase();
          final bool nameMatches = inName.isEmpty || cName.isEmpty || inName == cName || inName.contains(cName) || cName.contains(inName);
          if (nameMatches) {
            return CardDuplicateCheck(
              type: CardDuplicateType.exactDuplicate,
              existingContact: c,
              matchedField: 'Email: ${c.email}',
            );
          } else {
            pendingSameNumberCheck ??= CardDuplicateCheck(
              type: CardDuplicateType.sameNumberDifferentCard,
              existingContact: c,
              matchedField: 'Email: ${c.email}',
            );
          }
        }
      }
    }

    // 6. Check phone contacts if provided and phone was not matched in scanned cards
    if (phoneContacts != null && inPhone10.length >= 7) {
      for (final pc in phoneContacts) {
        bool pcMatched = false;
        String? pcMatchedPhone;
        for (final p in pc.phones) {
          if (PhoneNormalizer.isSame(p.number, inPhone)) {
            pcMatched = true;
            pcMatchedPhone = p.number;
            break;
          }
        }
        if (pcMatched) {
          final pcScanned = ScannedContactModel(
            id: pc.id,
            name: pc.displayName,
            phone: pcMatchedPhone ?? inPhone,
            company: pc.company ?? '',
            designation: pc.jobTitle ?? '',
            email: pc.primaryEmail,
            website: pc.websites.isNotEmpty ? pc.websites.first.url : '',
            address: pc.addresses.isNotEmpty ? pc.addresses.first.address : '',
            source: 'phone',
            socialLinks: const [],
            createdAt: DateTime.now(),
          );
          final pcComp = (pc.company ?? '').trim();
          final pcName = pc.displayName.trim().toLowerCase();

          if (inCompany.isNotEmpty && pcComp.isNotEmpty && CompanyNormalizer.isSimilar(inCompany, pcComp)) {
            return CardDuplicateCheck(
              type: CardDuplicateType.exactDuplicate,
              existingContact: pcScanned,
              matchedField: 'Phone: $pcMatchedPhone & Company: $pcComp',
            );
          } else if (inName.isNotEmpty && pcName.isNotEmpty && inName == pcName && (inCompany.isEmpty || pcComp.isEmpty)) {
            return CardDuplicateCheck(
              type: CardDuplicateType.exactDuplicate,
              existingContact: pcScanned,
              matchedField: 'Phone: $pcMatchedPhone & Name: ${pc.displayName}',
            );
          } else {
            pendingSameNumberCheck ??= CardDuplicateCheck(
              type: CardDuplicateType.sameNumberDifferentCard,
              existingContact: pcScanned,
              matchedField: 'Phone: $pcMatchedPhone',
            );
          }
        }
      }
    }

    if (pendingSameNumberCheck != null) {
      return pendingSameNumberCheck;
    }

    return const CardDuplicateCheck(type: CardDuplicateType.none);
  }

  /// Backward-compatible helper returning existing duplicate if any.
  ScannedContactModel? findDuplicate(ScannedContactModel incoming) {
    final check = checkCardDuplicate(incoming);
    return check.isDuplicate ? check.existingContact : null;
  }

  /// Returns true if [phone] already exists in any stored contact (normalized).
  bool phoneAlreadyExists(String phone) {
    final p10 = PhoneNormalizer.last10(phone);
    if (p10.length < 7) return false;
    for (final c in _allContacts) {
      if (PhoneNormalizer.isSame(c.phone, phone)) return true;
      for (final ap in c.additionalPhones) {
        if (PhoneNormalizer.isSame(ap, phone)) return true;
      }
      if (c.alternativePhone != null && PhoneNormalizer.isSame(c.alternativePhone!, phone)) return true;
    }
    return false;
  }

  // ---------------------------------------------
  // MERGE
  // ---------------------------------------------

  /// Merges [incoming] into [existing] contact.
  /// Rules:
  ///   - Preserve all existing non-empty fields.
  ///   - Combine all phone numbers safely into additionalPhones, deduplicated.
  ///   - Combine emails, websites, physical addresses, social links.
  ///   - Preserve profile photos and digital SmartCard matching references.
  ///   - Remove duplicate ID if different so only one master card remains.
  ///   - Never silently delete existing data.
  Future<void> mergeScannedContact(
    ScannedContactModel existing,
    ScannedContactModel incoming,
  ) async {
    _sqliteLoadSequence++;
    // Build merged all-phones list
    final allPhones = <String>[
      existing.phone,
      ...existing.additionalPhones,
      if (existing.alternativePhone != null && existing.alternativePhone!.isNotEmpty)
        existing.alternativePhone!,
    ];

    // Add incoming.phone only if not already stored
    if (incoming.phone.isNotEmpty && !PhoneNormalizer.existsIn(incoming.phone, allPhones)) {
      allPhones.add(incoming.phone);
    }
    // Also include incoming additional/alternative phones
    for (final ap in incoming.additionalPhones) {
      if (ap.isNotEmpty && !PhoneNormalizer.existsIn(ap, allPhones)) {
        allPhones.add(ap);
      }
    }
    if (incoming.alternativePhone != null &&
        incoming.alternativePhone!.isNotEmpty &&
        !PhoneNormalizer.existsIn(incoming.alternativePhone!, allPhones)) {
      allPhones.add(incoming.alternativePhone!);
    }

    // Deduplicate additionalPhones (exclude primary phone)
    final extraPhones = PhoneNormalizer.deduplicate(
      allPhones.where((p) => !PhoneNormalizer.isSame(p, existing.phone)).toList(),
    );

    // Merge emails — preserve existing; add incoming only if different + valid
    final String mergedEmail;
    final inEmail = incoming.email.trim();
    final exEmail = existing.email.trim();
    if (exEmail.isNotEmpty) {
      mergedEmail = exEmail;
    } else if (inEmail.isNotEmpty) {
      mergedEmail = inEmail;
    } else {
      mergedEmail = '';
    }

    // Combine social links safely
    final Set<String> mergedSocial = {...existing.socialLinks, ...incoming.socialLinks};

    final merged = existing.copyWith(
      company: existing.company.isNotEmpty ? existing.company : incoming.company,
      designation: existing.designation.isNotEmpty ? existing.designation : incoming.designation,
      website: existing.website.isNotEmpty ? existing.website : incoming.website,
      address: existing.address.isNotEmpty ? existing.address : incoming.address,
      email: mergedEmail,
      additionalPhones: extraPhones,
      socialLinks: mergedSocial.toList(),
      // Preserve images
      profileImage: existing.profileImage?.isNotEmpty == true ? existing.profileImage : incoming.profileImage,
      imagePath: existing.imagePath?.isNotEmpty == true ? existing.imagePath : incoming.imagePath,
      // Preserve digital card matches
      isMatched: existing.isMatched || incoming.isMatched,
      matchedUserId: existing.matchedUserId ?? incoming.matchedUserId,
      matchedCards: existing.matchedCards ?? incoming.matchedCards,
      cardUrl: existing.cardUrl ?? incoming.cardUrl,
      syncStatus: 'pending',
    );

    // Remove separate duplicate record if incoming had a distinct ID in database
    if (incoming.id.isNotEmpty && incoming.id != existing.id) {
      await SqliteDatabase.deleteContact(incoming.id);
      await HiveScanDatabase.deleteRecordAny(incoming.id);
      _allContacts.removeWhere((c) => c.id == incoming.id);
    }

    await SqliteDatabase.saveContact(merged);
    await HiveScanDatabase.saveScannedRecord(merged);
    _mergeContacts([merged]);
    _recomputeCounts();
    await _saveLifetimeScanCount(scannedContactsCount);
    _applyFilters();
    notifyListeners();

    // Sync merged record to backend
    BackendSyncService().uploadContact(merged).then((success) {
      if (success) SqliteDatabase.updateSyncStatus(merged.id, 'synced');
    }).catchError((_) {});

    // Sync merged record to Firebase Firestore
    FirebaseContactSyncService().syncContactToFirebase(merged);

    debugPrint('✅ Merged contact ${incoming.name} → ${existing.name} (master phone: ${merged.phone}, extra phones: ${merged.additionalPhones.length})');
  }

  // ---------------------------------------------
  // ADD / EDIT (3-Tier: SQLite -> Device Phonebook -> Live Server)
  // ---------------------------------------------

  /// Atomically saves or updates an app profile across Hive, SQLite, Firebase, and Native Contacts.
  /// Step 1: Save locally in Hive & SQLite.
  /// Step 2: Sync to Firebase Firestore.
  /// Step 3: Synchronize all numbers into 1 native device contact.
  /// Step 4: Immediately update UI without requiring app restart.
  Future<ScannedContactModel> saveOrUpdateProfile(ScannedContactModel profile) async {
    _sqliteLoadSequence++;
    final effectiveId = (profile.id.trim().isNotEmpty && profile.id != 'null')
        ? profile.id
        : 'scan_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';
    final effectiveSource = (profile.source != null && profile.source!.isNotEmpty && profile.source != 'phone')
        ? profile.source!
        : 'scanned';

    var valid = profile.copyWith(
      id: effectiveId,
      source: effectiveSource,
      updatedAt: DateTime.now(),
    );

    // 1. Save locally in SQLite & Hive (Instant UI response)
    await SqliteDatabase.saveContact(valid);
    await HiveScanDatabase.saveScannedRecord(valid);
    _mergeContacts([valid]);
    _recomputeCounts();
    if (scannedContactsCount > _lifetimeScanCount) {
      _lifetimeScanCount = scannedContactsCount;
    }
    await _saveLifetimeScanCount(_lifetimeScanCount);
    _applyFilters();
    notifyListeners();

    // 2. Synchronize with Native Device Contacts (all phone numbers in 1 device contact)
    try {
      final savedDeviceId = await ContactSaverService.saveToDevice(valid);
      if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
        valid = valid.copyWith(deviceContactId: savedDeviceId);
        await SqliteDatabase.saveContact(valid);
        await HiveScanDatabase.saveScannedRecord(valid);
        _mergeContacts([valid]);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Device contact sync error: $e');
    }

    // 3. Immediately trigger background upload to Live Server Database & Firebase Firestore
    try {
      FirebaseContactSyncService().syncContactToFirebase(valid);
    } catch (e) {
      debugPrint('⚠️ Firebase sync error: $e');
    }

    try {
      BackendSyncService().uploadContact(valid).catchError((_) => false);
    } catch (_) {}

    return valid;
  }

  Future<void> addScannedContact(ScannedContactModel scanned) async {
    await saveOrUpdateProfile(scanned);
  }

  // ---------------------------------------------
  // DELETE (Simultaneous 3-Tier: UI -> SQLite -> Device Phonebook -> Live Server)
  // ---------------------------------------------

  Future<void> deleteContact(String id, {ScannedContactModel? target}) async {
    _sqliteLoadSequence++;
    final contact = target ??
        _allContacts.firstWhere(
          (c) => c.id == id,
          orElse: () => ScannedContactModel(
            id: id,
            name: '',
            company: '',
            designation: '',
            phone: '',
            email: '',
            website: '',
            address: '',
            socialLinks: const [],
            createdAt: DateTime.now(),
          ),
        );

    final phone = contact.phone.trim();
    final name = contact.name.trim();
    final company = contact.company.trim();
    final targetId = id.trim();
    final rawId = targetId.replaceFirst('phone_', '').replaceFirst('matched_', '');
    final devContactId = contact.deviceContactId ?? (rawId.isNotEmpty ? rawId : null);

    // ── STEP 0: Write tombstone ─────────────────────────────────────────────────
    _deletingIds.add(targetId);
    if (rawId.isNotEmpty) {
      _deletingIds.add(rawId);
      _deletingIds.add('phone_$rawId');
      _deletingIds.add('matched_$rawId');
    }
    // Only tombstone exact ID variants — NEVER phone or email so other profiles remain safe!
    await SqliteDatabase.addPendingDeletion(targetId);
    if (rawId.isNotEmpty && rawId != targetId) {
      await SqliteDatabase.addPendingDeletion(rawId);
      await SqliteDatabase.addPendingDeletion('phone_$rawId');
      await SqliteDatabase.addPendingDeletion('matched_$rawId');
    }

    // ── STEP 1: Find ONLY profiles matching THIS specific ID, linked deviceContactId, or exact company match ───
    final Set<String> targetIdVariants = {targetId};
    if (rawId.isNotEmpty) {
      targetIdVariants.add(rawId);
      targetIdVariants.add('phone_$rawId');
      targetIdVariants.add('matched_$rawId');
    }
    if (devContactId != null && devContactId.isNotEmpty) {
      targetIdVariants.add(devContactId);
      targetIdVariants.add('phone_$devContactId');
      targetIdVariants.add('matched_$devContactId');
    }

    final toDelete = <ScannedContactModel>[];
    for (final c in _allContacts) {
      final cRawId = c.id.replaceFirst('phone_', '').replaceFirst('matched_', '');
      final bool isExactIdMatch = targetIdVariants.contains(c.id) ||
          (rawId.isNotEmpty && (c.id == rawId || cRawId == rawId));

      final bool isDevIdMatch = devContactId != null && devContactId.isNotEmpty &&
          (c.deviceContactId == devContactId || cRawId == devContactId);

      // Safe fallback when deviceContactId was not set: match only if phone AND company match!
      final bool isPhoneAndCompMatch = phone.isNotEmpty &&
          _phoneMatch(c.phone, phone) &&
          company.isNotEmpty && CompanyNormalizer.isSimilar(c.company, company) &&
          (name.isEmpty || c.name.isEmpty || c.name.trim().toLowerCase() == name.toLowerCase());

      if (isExactIdMatch || isDevIdMatch || isPhoneAndCompMatch) {
        toDelete.add(c);
      }
    }

    // ── STEP 2: Instant UI removal from _allContacts & notifyListeners ─────────
    final Set<String> removedIds = Set.from(targetIdVariants);
    for (final c in toDelete) {
      removedIds.add(c.id);
      _deletingIds.add(c.id);
    }

    _allContacts = _allContacts.where((c) => !removedIds.contains(c.id)).toList();
    _recomputeCounts();
    _applyFilters();
    notifyListeners();

    // ── STEP 3: Remove from local SQLite database and Hive ──────────────────────
    for (final rid in removedIds) {
      await SqliteDatabase.deleteContact(rid);
      await HiveScanDatabase.deleteRecordAny(rid);
      FirebaseContactSyncService().deleteContactFromFirebase(rid);
    }
    await HiveScanDatabase.deleteMatchingRecords(
      id: targetId,
      deviceContactId: devContactId,
    );

    // ── STEP 4: Delete only this profile's corresponding Native Device Contact ──────────
    // Note: Do NOT delete by phone number alone, so other company/personal profiles sharing this phone are preserved!
    try {
      final bool isPhoneContact = contact.source == 'phone' || targetId.startsWith('phone_') || (devContactId != null && targetId == devContactId);
      if (isPhoneContact && devContactId != null && devContactId.isNotEmpty) {
        final bool otherProfileUsesDevIdOrPhone = _allContacts.any(
          (c) => !removedIds.contains(c.id) && (
            (c.deviceContactId != null && c.deviceContactId == devContactId) ||
            (phone.isNotEmpty && _phoneMatch(c.phone, phone))
          ),
        );
        if (!otherProfileUsesDevIdOrPhone) {
          await ContactSaverService.deleteDeviceContact(devContactId);
          debugPrint('📱 Contact $devContactId permanently deleted from native device address book.');
        } else {
          debugPrint('📱 Preserved native device contact $devContactId as another profile is linked to it.');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error deleting from device address book: $e');
    }

    // ── STEP 5: Delete from Live Server Database ───────────────────────────────
    try {
      await _repository.deleteContact(targetId);
      await SqliteDatabase.removePendingDeletion(targetId);
      if (rawId.isNotEmpty) {
        await SqliteDatabase.removePendingDeletion(rawId);
      }
      debugPrint('☁️ Contact $targetId permanently deleted from live server database.');
    } catch (e) {
      debugPrint('⚠️ Contact delete recorded in tombstone for background flush: $e');
    }

    // ── STEP 6: Delete from Firebase Firestore ───────────────────────────────
    for (final rid in removedIds) {
      FirebaseContactSyncService().deleteContactFromFirebase(rid);
    }

    // Done — remove from in-memory guard
    for (final rid in removedIds) {
      _deletingIds.remove(rid);
    }
  }

  /// Sync contacts deleted or modified in Google / Device address book in real-time across ALL tabs.
  /// Detects phone number removals from native contacts without deleting the whole profile (Requirement 9).
  Future<void> syncDeletedDeviceContacts(
    Set<String> validDeviceIds, {
    Set<String> validDevicePhones = const {},
    List<AppContact> currentDeviceContacts = const [],
  }) async {
    if (validDeviceIds.isEmpty && validDevicePhones.isEmpty) {
      return;
    }

    bool changed = false;
    final List<ScannedContactModel> toRemove = [];

    // 1. Check for phone number changes on synced profiles (Requirement 9)
    if (currentDeviceContacts.isNotEmpty) {
      final dcMap = {for (final dc in currentDeviceContacts) dc.id: dc};
      for (int i = 0; i < _allContacts.length; i++) {
        final c = _allContacts[i];
        if (c.deviceContactId != null && dcMap.containsKey(c.deviceContactId)) {
          final dc = dcMap[c.deviceContactId]!;
          final devPhones = dc.phones.map((p) => p.number.trim()).where((p) => p.isNotEmpty).toList();
          if (devPhones.isNotEmpty) {
            final appPhones = [c.phone, if (c.alternativePhone != null) c.alternativePhone!, ...c.additionalPhones];
            bool diff = false;
            if (appPhones.length != devPhones.length) {
              diff = true;
            } else {
              for (final p in appPhones) {
                if (!devPhones.any((dp) => PhoneNormalizer.isSame(dp, p))) {
                  diff = true;
                  break;
                }
              }
            }
            if (diff) {
              final updated = c.copyWith(
                phone: devPhones.first,
                alternativePhone: devPhones.length > 1 ? devPhones[1] : null,
                clearAlternativePhone: devPhones.length <= 1,
                additionalPhones: devPhones.length > 2 ? devPhones.sublist(2) : const [],
                updatedAt: DateTime.now(),
              );
              _allContacts[i] = updated;
              await SqliteDatabase.saveContact(updated);
              await HiveScanDatabase.saveScannedRecord(updated);
              FirebaseContactSyncService().syncContactToFirebase(updated);
              changed = true;
            }
          }
        }
      }
    }

    for (final c in _allContacts) {
      final rawId = c.id.replaceFirst('phone_', '').replaceFirst('matched_', '');

      // 1. If any profile (Smart Card, Scanned, Phone) has an explicit real native device contact ID and that device contact was deleted in phonebook:
      final devId = (c.deviceContactId ?? '').trim();
      final hasLinkedDevId = devId.isNotEmpty && !devId.startsWith('device_');
      final isLinkedDeviceDeleted = hasLinkedDevId && validDeviceIds.isNotEmpty && !validDeviceIds.contains(devId);

      // 2. Direct device ID deletion for phone-imported contacts
      final isDirectDeviceDeleted = (c.source == 'phone' || c.id.startsWith('phone_')) && rawId.isNotEmpty && validDeviceIds.isNotEmpty && !validDeviceIds.contains(rawId);

      if (isLinkedDeviceDeleted || isDirectDeviceDeleted) {
        toRemove.add(c);
      }
    }

    if (toRemove.isNotEmpty) {
      final Set<String> toRemoveIds = toRemove.map((c) => c.id).toSet();
      _allContacts = _allContacts.where((item) => !toRemoveIds.contains(item.id)).toList();
      for (final c in toRemove) {
        await SqliteDatabase.deleteContact(c.id);
        await HiveScanDatabase.deleteRecordAny(c.id);
        await HiveScanDatabase.deleteMatchingRecords(
          id: c.id,
          deviceContactId: c.deviceContactId,
        );
        FirebaseContactSyncService().deleteContactFromFirebase(c.id);
        changed = true;
      }
    }

    if (changed) {
      _recomputeCounts();
      _applyFilters();
      notifyListeners();
      debugPrint('⚡ [ContactViewModel] Processed device contact changes across SQLite, Hive, and memory.');
    }
  }


  // ---------------------------------------------
  // OFFLINE FLUSH (runs before every backend load)
  // ---------------------------------------------

  Future<void> _flushPendingDeletions() async {
    final tombstones = await SqliteDatabase.getPendingDeletionTombstonesAsync();
    for (final tomb in tombstones) {
      final id = tomb['id'] ?? '';
      final phone = tomb['phone'] ?? '';
      final email = tomb['email'] ?? '';
      try {
        await _repository.deleteContact(id, phone: phone.isNotEmpty ? phone : null, email: email.isNotEmpty ? email : null);
        await SqliteDatabase.removePendingDeletion(id);
        debugPrint('✅ Flushed pending deletion for contact $id (phone=$phone)');
      } catch (e) {
        final err = e.toString().toLowerCase();
        if (err.contains('404') || err.contains('not found')) {
          await SqliteDatabase.removePendingDeletion(id);
          debugPrint('✅ Pending deletion $id already gone from server, tombstone cleared.');
        } else {
          debugPrint('⚠️ Pending deletion flush failed for $id: $e (will retry next time)');
        }
      }
    }
  }

  // ---------------------------------------------
  // FAVOURITE
  // ---------------------------------------------

  Future<void> toggleFavorite(String id) async {
    final idx = _allContacts.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final updated = _allContacts[idx].copyWith(isFavorite: !_allContacts[idx].isFavorite);
    _allContacts[idx] = updated;
    await SqliteDatabase.saveContact(updated);
    if (updated.isSmartCardUser) {
      await HiveScanDatabase.saveSmartCardRecord(updated);
    } else {
      await HiveScanDatabase.saveScannedRecord(updated);
    }
    _recomputeCounts();
    _applyFilters();
    notifyListeners();
  }

  /// Saves a newly scanned or edited contact directly to SQLite + Hive and updates state
  Future<void> saveScannedContact(ScannedContactModel contact) async {
    await SqliteDatabase.saveContact(contact);
    await HiveScanDatabase.saveScannedRecord(contact);
    if (contact.isSmartCardUser) {
      await HiveScanDatabase.saveSmartCardRecord(contact);
    }
    await _loadSqliteContacts();
    _recomputeCounts();
    _applyFilters();
    notifyListeners();
    FirebaseContactSyncService().syncContactToFirebase(contact);
  }

  /// Toggle or set a phone contact's Smart Card membership
  Future<bool> toggleSmartCardMembership(AppContact appContact, {bool? setMembership}) async {
    final cleanPhones = appContact.phones
        .map((p) => p.number.replaceAll(RegExp(r'\D'), ''))
        .where((p) => p.isNotEmpty)
        .toList();

    int existingIdx = -1;
    for (int i = 0; i < _allContacts.length; i++) {
      final c = _allContacts[i];
      if (c.deviceContactId == appContact.id && appContact.id.isNotEmpty) {
        existingIdx = i;
        break;
      }
      final cPhone = c.phone.replaceAll(RegExp(r'\D'), '');
      final c10 = cPhone.length >= 10 ? cPhone.substring(cPhone.length - 10) : cPhone;
      for (final p in cleanPhones) {
        final p10 = p.length >= 10 ? p.substring(p.length - 10) : p;
        if (p10.length >= 7 && c10.length >= 7 && (p10 == c10 || p.endsWith(c10) || cPhone.endsWith(p10))) {
          existingIdx = i;
          break;
        }
      }
      if (existingIdx != -1) break;
    }

    final bool currentlyIsSmart = existingIdx != -1 && _allContacts[existingIdx].isSmartCardUser;
    final bool targetMembership = setMembership ?? !currentlyIsSmart;

    if (targetMembership) {
      // Add as Smart Card user
      ScannedContactModel model;
      if (existingIdx != -1) {
        model = _allContacts[existingIdx].copyWith(
          isMatched: true,
          source: 'smart_card',
          deviceContactId: appContact.id.isNotEmpty ? appContact.id : _allContacts[existingIdx].deviceContactId,
          name: appContact.displayName.isNotEmpty ? appContact.displayName : _allContacts[existingIdx].name,
          phone: appContact.primaryPhone.isNotEmpty ? appContact.primaryPhone : _allContacts[existingIdx].phone,
          company: (appContact.company != null && appContact.company!.isNotEmpty)
              ? appContact.company
              : _allContacts[existingIdx].company,
          designation: (appContact.jobTitle != null && appContact.jobTitle!.isNotEmpty)
              ? appContact.jobTitle
              : _allContacts[existingIdx].designation,
          email: appContact.primaryEmail.isNotEmpty ? appContact.primaryEmail : _allContacts[existingIdx].email,
        );
        _allContacts[existingIdx] = model;
      } else {
        final stableId = 'smart_${appContact.id.isNotEmpty ? appContact.id : appContact.primaryPhone.replaceAll(RegExp(r'\D'), '')}';
        model = ScannedContactModel(
          id: stableId,
          deviceContactId: appContact.id,
          name: appContact.displayName.isNotEmpty ? appContact.displayName : 'Contact',
          company: appContact.company ?? '',
          designation: appContact.jobTitle ?? '',
          phone: appContact.primaryPhone,
          alternativePhone: appContact.phones.length > 1 ? appContact.phones[1].number : null,
          additionalPhones: appContact.phones.length > 2
              ? appContact.phones.skip(2).map((p) => p.number).toList()
              : const [],
          email: appContact.primaryEmail,
          website: appContact.primaryWebsite,
          address: appContact.primaryAddress,
          socialLinks: const [],
          source: 'smart_card',
          isMatched: true,
          createdAt: DateTime.now(),
        );
        _allContacts.insert(0, model);
      }

      await SqliteDatabase.saveContact(model);
      await HiveScanDatabase.saveSmartCardRecord(model);
      await HiveScanDatabase.saveScannedRecord(model);
    } else {
      // Unselect: remove Smart Card membership without deleting phone contact
      if (existingIdx != -1) {
        final current = _allContacts[existingIdx];
        await HiveScanDatabase.deleteSmartCardRecord(current.id);

        if (current.source == 'smart_card' || current.id.startsWith('smart_')) {
          final updated = current.copyWith(
            isMatched: false,
            source: 'phone',
            clearCardUrl: true,
            clearMatchedUserId: true,
          );
          _allContacts[existingIdx] = updated;
          await SqliteDatabase.saveContact(updated);
        } else {
          final updated = current.copyWith(
            isMatched: false,
            clearCardUrl: true,
            clearMatchedUserId: true,
          );
          _allContacts[existingIdx] = updated;
          await SqliteDatabase.saveContact(updated);
        }
      }
    }

    _recomputeCounts();
    _applyFilters();
    notifyListeners();
    return targetMembership;
  }


  // ---------------------------------------------
  // PHONE BOOK IMPORT
  // ---------------------------------------------

  Future<void> importPhoneContacts({bool force = false}) async {
    _isRefreshing = true;
    notifyListeners();
    try {
      await ContactImportService.importPhoneContacts(
        _allContacts,
        batchSize: 50,
        onTotalCountDiscovered: (totalCount) {
          debugPrint('📱 Discovered $totalCount total contacts in device phonebook.');
          notifyListeners();
        },
        onBatchLoaded: (batch) async {
          if (batch.isNotEmpty) {
            await SqliteDatabase.saveContacts(batch);
            _mergeContacts(batch);
            _applyFilters();
            notifyListeners();
          }
        },
      );
      await matchPhoneContactsWithServer(force: force);
    } catch (e) {
      debugPrint('Error importing phone contacts: $e');
    } finally {
      _isRefreshing = false;
      _loadSqliteContacts();
      notifyListeners();
    }
  }

  // ---------------------------------------------
  // EXPORT
  // ---------------------------------------------

  Future<void> exportVcf() => ExportService.exportAsVcf(_filteredContacts);
  Future<void> exportCsv() => ExportService.exportAsCsv(_filteredContacts);

  // ---------------------------------------------
  // BACKGROUND SYNC (pending uploads)
  // ---------------------------------------------

  Future<void> syncContactsToApi() async {
    _isRefreshing = true;
    notifyListeners();
    try {
      await _flushPendingDeletions();

      final pending = _allContacts
          .where((c) => c.syncStatus == 'pending' && c.source != 'phone')
          .toList();

      final synced = <ScannedContactModel>[];
      for (final contact in pending) {
        try {
          await _repository.saveContact({
            'name': contact.name,
            'phone': contact.phone,
            'alternative_phone': contact.alternativePhone ?? '',
            'landline': contact.landline ?? '',
            'whatsapp': contact.whatsApp ?? '',
            'email': contact.email,
            'company': contact.company,
            'company_name': contact.company,
            'designation': contact.designation,
            'address': contact.address,
            'pin_code': contact.pinCode ?? '',
            'district': contact.district ?? '',
            'state_name': contact.stateName ?? '',
            'website': contact.website,
            'social_links': contact.socialLinks,
            'profile_image': contact.profileImage ?? contact.imagePath ?? '',
            'company_logo': contact.companyLogo ?? '',
            'source': contact.source ?? 'scan',
          });
          final idx = _allContacts.indexWhere((c) => c.id == contact.id);
          if (idx != -1) {
            _allContacts[idx] = _allContacts[idx].copyWith(syncStatus: 'synced');
            synced.add(_allContacts[idx]);
          }
        } catch (e) {
          debugPrint('Sync failed for ${contact.name}: $e');
        }
      }
      if (synced.isNotEmpty) await SqliteDatabase.saveContacts(synced);
      _applyFilters();
    } catch (e) {
      debugPrint('Error during background sync: $e');
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }
}
