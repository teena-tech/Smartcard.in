import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/database/sqlite_database.dart';
import '../../models/scanned_contact_model.dart';
import '../../core/services/contact_import_service.dart';
import '../../core/services/contact_saver_service.dart';
import '../../core/services/export_service.dart';
import '../repositories/contact_repository.dart';

class ContactViewModel extends ChangeNotifier {
  final ContactRepository _repository = ContactRepository();

  List<ScannedContactModel> _allContacts = [];
  List<ScannedContactModel> _filteredContacts = [];

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isMatchingPhones = false;
  DateTime? _lastMatchTimestamp;
  String _searchQuery = '';
  String _activeFilter = 'Scanned'; // Default to 'Scanned' so only user's scanned cards show initially

  // Tracks contact IDs currently being deleted — blocks reconcile from re-adding them
  final Set<String> _deletingIds = {};

  // Pagination
  int _currentPage = 1;
  static const int _pageSize = 50;

  ContactViewModel() {
    _loadSqliteContacts();
    loadContactsFromBackend();
  }

  List<ScannedContactModel> get contacts => _filteredContacts;
  List<ScannedContactModel> get allContacts => _allContacts;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isMatchingPhones => _isMatchingPhones;
  String get searchQuery => _searchQuery;
  String get activeFilter => _activeFilter;

  int get totalContactsCount => _allContacts.length;
  int get phoneContactsCount => _allContacts.where((c) => c.source == 'phone' || c.id.startsWith('phone_')).length;
  int get matchedContactsCount => _allContacts.where((c) => c.isMatched || (c.matchedUserId != null && c.matchedUserId!.isNotEmpty) || (c.matchedCards != null && c.matchedCards!.isNotEmpty)).length;
  int get smartCardContactsCount => matchedContactsCount;
  int get scannedContactsCount => _allContacts.where((c) => c.source != 'phone' && !c.id.startsWith('phone_')).length;

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
    final pa = _phone(a);
    final pb = _phone(b);
    return pa.length >= 10 && pb.length >= 10 && pa.endsWith(pb.substring(pb.length - 10));
  }

  bool _emailMatch(String a, String b) {
    final ea = a.trim().toLowerCase();
    final eb = b.trim().toLowerCase();
    return ea.isNotEmpty && ea == eb;
  }

  bool _contactMatches(ScannedContactModel c, String id, String phone, String email, String name) {
    if (c.id == id) return true;
    if (phone.isNotEmpty && _phoneMatch(c.phone, phone)) return true;
    if (email.isNotEmpty && _emailMatch(c.email, email)) return true;
    return false;
  }

  // ---------------------------------------------
  // LOAD
  // ---------------------------------------------

  void _loadSqliteContacts() async {
    try {
      _allContacts = await SqliteDatabase.getAllContactsAsync();
      _allContacts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading SQLite contacts: $e');
    }
  }

  Future<void> loadContactsFromBackend({int page = 1}) async {
    _isRefreshing = true;
    notifyListeners();

    try {
      await _flushPendingDeletions();

      final rawContacts = await _repository.getContacts(page: page, limit: 50);
      final serverContacts = <ScannedContactModel>[];

      for (final item in rawContacts) {
        if (item is Map<String, dynamic>) {
          try {
            serverContacts.add(
              ScannedContactModel.fromJson(item).copyWith(
                source: item['source']?.toString() ?? 'smartcard',
                syncStatus: 'synced',
              ),
            );
          } catch (e) {
            debugPrint('Error parsing contact item: $e');
          }
        }
      }

      // Filter out any contacts that are currently being deleted to prevent re-adding them
      final safeServerContacts = serverContacts.where((c) {
        if (_deletingIds.contains(c.id)) return false;
        final cp = _phone(c.phone);
        final ce = c.email.trim().toLowerCase();
        return !_deletingIds.any((delId) {
          final delContact = _allContacts.firstWhere((x) => x.id == delId, orElse: () => ScannedContactModel(id: delId, name: '', company: '', designation: '', phone: '', email: '', website: '', address: '', socialLinks: const [], createdAt: DateTime.now()));
          final dp = _phone(delContact.phone);
          final de = delContact.email.trim().toLowerCase();
          if (cp.length >= 10 && dp.length >= 10 && cp.endsWith(dp.substring(dp.length - 10))) return true;
          if (ce.isNotEmpty && de.isNotEmpty && ce == de) return true;
          return false;
        });
      }).toList();

      await SqliteDatabase.reconcileSmartCardContacts(safeServerContacts);

      _allContacts = await SqliteDatabase.getAllContactsAsync();
      _allContacts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading contacts from backend: $e');
    } finally {
      _isRefreshing = false;
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
      filtered = filtered.where((c) => c.source != 'phone' && !c.id.startsWith('phone_')).toList();
    }

    final end = (_currentPage * _pageSize).clamp(0, filtered.length);
    _filteredContacts = filtered.sublist(0, end);
    notifyListeners();
  }

  // ---------------------------------------------
  // PHONE MATCHING WITH BACKEND (Batched & Persisted)
  // ---------------------------------------------

  Future<void> matchPhoneContactsWithServer({bool force = false}) async {
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
          .toSet()
          .toList();

      if (phoneNumbers.isEmpty) return;

      // Batch phone numbers in chunks of 200 for fast & safe payload delivery
      const chunkSize = 200;
      final rawMatches = <dynamic>[];

      for (var i = 0; i < phoneNumbers.length; i += chunkSize) {
        final chunk = phoneNumbers.sublist(
          i,
          (i + chunkSize > phoneNumbers.length) ? phoneNumbers.length : i + chunkSize,
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

          for (final contact in contactsToUpdate) {
            final updated = contact.copyWith(
              isMatched: true,
              matchedUserId: item['userId']?.toString(),
              totalCardsCount: item['cardCount'] is int
                  ? item['cardCount'] as int
                  : int.tryParse(item['cardCount']?.toString() ?? ''),
              primaryDesignation: item['designation']?.toString(),
              cardUrl: item['cardUrl']?.toString(),
              matchedProfileImage: item['profileImage']?.toString(),
            );
            await SqliteDatabase.saveContact(updated);
            updatedAny = true;
          }
        }
      }

      _lastMatchTimestamp = DateTime.now();

      if (updatedAny) {
        _loadSqliteContacts();
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
      final idx = _allContacts.indexWhere(
        (c) => _contactMatches(c, contact.id, contact.phone, contact.email, contact.name),
      );

      if (idx != -1) {
        final old = _allContacts[idx];
        _allContacts[idx] = contact.copyWith(
          profileImage: contact.profileImage?.isNotEmpty == true ? contact.profileImage : old.profileImage,
          imagePath: contact.imagePath?.isNotEmpty == true ? contact.imagePath : old.imagePath,
        );
      } else {
        _allContacts.add(contact);
      }
    }
    _allContacts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ---------------------------------------------
  // ADD / EDIT
  // ---------------------------------------------

  Future<void> addScannedContact(ScannedContactModel scanned) async {
    // 1. Save strictly to local SQLite database
    await SqliteDatabase.saveContact(scanned);
    _mergeContacts([scanned]);
    _applyFilters();

    // 2. Automatically save/update directly in device native address book (Phone Contacts)
    try {
      await ContactSaverService.saveToDevice(scanned);
      debugPrint('📱 Scanned contact saved to device phonebook: ${scanned.name}');
    } catch (e) {
      debugPrint('⚠️ Error saving contact to device phonebook: $e');
    }
  }

  // ---------------------------------------------
  // DELETE (simultaneous: UI -> SQLite & Device Phonebook)
  // ---------------------------------------------

  Future<void> deleteContact(String id, {ScannedContactModel? target}) async {
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

    final phone = contact.phone;
    final email = contact.email;
    final name = contact.name;

    // ── STEP 0: Write tombstone ─────────────────────────────────────────────────
    _deletingIds.add(id);
    await SqliteDatabase.addPendingDeletion(id, phone: phone, email: email);

    // ── STEP 1: Instant UI removal ─────────────────────────────────────────────
    _allContacts.removeWhere((c) => _contactMatches(c, id, phone, email, name));
    _applyFilters();

    // ── STEP 2: Remove from local SQLite database ──────────────────────────────
    await SqliteDatabase.deleteContact(id, phone: phone, email: email, name: name);

    // ── STEP 3: Delete simultaneously from Native Device Address Book ──────────
    try {
      await ContactImportService.deleteDeviceContact(id, phone: phone);
      await SqliteDatabase.removePendingDeletion(id);
      debugPrint('✅ Contact $id permanently deleted from device address book and SQLite.');
    } catch (e) {
      debugPrint('⚠️ Error deleting from device address book: $e');
    }

    // Done — remove from in-memory guard
    _deletingIds.remove(id);
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
    _applyFilters();
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
            'email': contact.email,
            'company': contact.company,
            'designation': contact.designation,
            'address': contact.address,
            'website': contact.website,
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
