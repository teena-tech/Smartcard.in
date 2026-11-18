import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_contact.dart';
import '../models/scanned_contact_model.dart';
import '../core/database/sqlite_database.dart';
import '../core/services/device_contact_service.dart';
import '../core/services/group_storage.dart';
import '../core/utils/permission_helper.dart';
import '../core/utils/phone_normalizer.dart';
import '../core/utils/company_normalizer.dart';

List<AppContact> _parseContactsJson(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .map((m) => AppContact.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    }
  } catch (_) {}
  return [];
}

String _encodeContactsJson(List<Map<String, dynamic>> jsonList) {
  try {
    return jsonEncode(jsonList);
  } catch (_) {
    return '[]';
  }
}

enum ContactFilter {
  all,
  favorites,
  withPhone,
  withEmail,
  group,
}

class ContactProvider extends ChangeNotifier {
  final DeviceContactService _contactService = DeviceContactService();
  final GroupStorage _groupStorage = GroupStorage();
  StreamSubscription<void>? _databaseSubscription;

  List<AppContact> _contacts = [];
  List<AppContact> _filteredContacts = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String _searchQuery = '';
  ContactFilter _currentFilter = ContactFilter.all;
  String? _selectedGroupId;
  String? _selectedGroupName;
  String? _errorMessage;
  ContactPermissionState _permissionState = ContactPermissionState.denied;

  // Local set of starred contact IDs (optimistic favorite tracking)
  final Set<String> _favoriteIds = {};

  // Global static memory cache for 0ms instant loading
  static List<AppContact>? _globalMemoryCachedContacts;

  // O(1) Lookup and Memoization caches
  Map<String, List<AppContact>> _groupedContactsCache = {};
  final Map<String, AppContact> _phoneLookupIndex = {};
  final Map<String, AppContact> _emailLookupIndex = {};
  final Map<String, AppContact> _idLookupIndex = {};
  final Set<String> _favoritePhoneDigits = {};
  final Set<String> _favoriteEmails = {};

  ContactProvider() {
    if (_globalMemoryCachedContacts != null && _globalMemoryCachedContacts!.isNotEmpty) {
      _contacts = List.from(_globalMemoryCachedContacts!);
      _applyFilterAndSearch();
    }
    _initDatabaseListener();
    _loadCachedContacts();
  }

  /// Load cached contacts immediately so the UI renders instantly on launch
  Future<void> _loadCachedContacts() async {
    if (_contacts.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_device_app_contacts_v1');
      if (raw != null && raw.isNotEmpty && _contacts.isEmpty) {
        final list = await compute(_parseContactsJson, raw);
        if (list.isNotEmpty && _contacts.isEmpty) {
          _contacts = list;
          _globalMemoryCachedContacts = List.from(list);
          _applyFilterAndSearch();
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Asynchronously persist cached contacts to local storage using background isolate
  Future<void> _persistCachedContacts() async {
    _globalMemoryCachedContacts = List.from(_contacts);
    try {
      final jsonList = _contacts.map((c) => c.toMap()).toList();
      final raw = await compute(_encodeContactsJson, jsonList);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_device_app_contacts_v1', raw);
    } catch (_) {}
  }

  // Getters
  List<AppContact> get contacts => _contacts;
  List<AppContact> get filteredContacts => _filteredContacts;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String get searchQuery => _searchQuery;
  ContactFilter get currentFilter => _currentFilter;
  String? get selectedGroupId => _selectedGroupId;
  String? get selectedGroupName => _selectedGroupName;
  String? get errorMessage => _errorMessage;
  ContactPermissionState get permissionState => _permissionState;

  /// Check contacts permission without prompting dialog
  Future<ContactPermissionState> checkPermission() async {
    _permissionState = await PermissionHelper.checkContactsPermission();
    notifyListeners();
    return _permissionState;
  }

  Set<String> get favoritePhoneDigits => _favoritePhoneDigits;
  Set<String> get favoriteEmails => _favoriteEmails;
  Set<String> getContactIdsForGroup(String groupId) => _groupStorage.getContactIdsForGroup(groupId);

  Set<String> get validDevicePhones {
    final Set<String> phones = {};
    for (final c in _contacts) {
      for (final p in c.phones) {
        final clean = p.number.replaceAll(RegExp(r'\D'), '');
        final p10 = clean.length >= 10 ? clean.substring(clean.length - 10) : clean;
        if (p10.length >= 7) {
          phones.add(p10);
        }
      }
    }
    return phones;
  }

  int get totalCount => _contacts.length;
  int get favoritesCount => _contacts.where((c) => c.isFavorite || _favoriteIds.contains(c.id)).length;
  List<AppContact> get favoriteContacts =>
      _contacts.where((c) => c.isFavorite || _favoriteIds.contains(c.id)).toList();

  /// Grouped contacts map by first letter (O(1) cached lookup)
  Map<String, List<AppContact>> get groupedContacts {
    if (_groupedContactsCache.isEmpty && _filteredContacts.isNotEmpty) {
      _recomputeGroupedContacts();
    }
    return _groupedContactsCache;
  }

  void _recomputeGroupedContacts() {
    final Map<String, List<AppContact>> groups = {};

    for (final contact in _filteredContacts) {
      final name = contact.displayName.trim();
      String firstChar = name.isNotEmpty ? name[0].toUpperCase() : '#';
      if (!RegExp(r'^[A-Z]$').hasMatch(firstChar)) {
        firstChar = '#';
      }

      if (!groups.containsKey(firstChar)) {
        groups[firstChar] = [];
      }
      groups[firstChar]!.add(contact);
    }

    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });

    final Map<String, List<AppContact>> sortedMap = {};
    for (final k in sortedKeys) {
      sortedMap[k] = groups[k]!;
    }
    _groupedContactsCache = sortedMap;
  }

  void _rebuildLookupIndices() {
    _phoneLookupIndex.clear();
    _emailLookupIndex.clear();
    _idLookupIndex.clear();
    _favoritePhoneDigits.clear();
    _favoriteEmails.clear();

    for (final c in _contacts) {
      if (c.id.isNotEmpty) {
        _idLookupIndex[c.id] = c;
      }
      final isFav = c.isFavorite || _favoriteIds.contains(c.id);
      for (final p in c.phones) {
        final digits = p.number.replaceAll(RegExp(r'\D'), '');
        if (digits.isNotEmpty) {
          final p10 = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
          _phoneLookupIndex[p10] = c;
          _phoneLookupIndex[digits] = c;
          if (digits.length >= 7) {
            final p7 = digits.substring(digits.length - 7);
            _phoneLookupIndex[p7] = c;
          }
          if (isFav) {
            _favoritePhoneDigits.add(p10);
            _favoritePhoneDigits.add(digits);
            if (digits.length >= 7) {
              _favoritePhoneDigits.add(digits.substring(digits.length - 7));
            }
          }
        }
      }
      for (final e in c.emails) {
        final cleanE = e.address.trim().toLowerCase();
        if (cleanE.isNotEmpty) {
          _emailLookupIndex[cleanE] = c;
          if (isFav) {
            _favoriteEmails.add(cleanE);
          }
        }
      }
    }
  }

  /// Listen for real-time changes in Android Contacts database
  void _initDatabaseListener() {
    _databaseSubscription?.cancel();
    _databaseSubscription = _contactService.onDatabaseChange.listen((_) {
      debugPrint('Real-time Android Contacts change detected! Auto-refreshing...');
      syncWithDevice(silent: true);
    });
  }

  @override
  void dispose() {
    _databaseSubscription?.cancel();
    super.dispose();
  }

  /// Helper for unit/widget tests
  void setContactsForTesting(List<AppContact> list) {
    _permissionState = ContactPermissionState.granted;
    _isLoading = false;
    _contacts = List.from(list);
    _filteredContacts = List.from(list);
    _recomputeGroupedContacts();
    _rebuildLookupIndices();
    notifyListeners();
  }

  /// Initial load: Check permission and load Android Contacts directly
  Future<void> initialize() async {
    if (_contacts.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    _permissionState = await PermissionHelper.checkContactsPermission();

    if (_permissionState == ContactPermissionState.granted) {
      await syncWithDevice(silent: true);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Request permission and load contacts directly from Android Contacts Provider
  Future<bool> requestPermissionAndLoad() async {
    // Only flag full-screen loading if no contacts exist yet
    if (_contacts.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    _permissionState = await PermissionHelper.requestContactsPermission();

    if (_permissionState == ContactPermissionState.granted) {
      await syncWithDevice(silent: _contacts.isNotEmpty);
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Refresh / Load contacts directly from Android Contacts Provider
  Future<void> syncWithDevice({
    bool silent = false,
    Map<String, List<String>>? groupNamesMap,
    Map<String, List<String>>? groupIdsMap,
  }) async {
    if (!silent && _contacts.isEmpty) {
      _isSyncing = true;
      notifyListeners();
    }

    try {
      await _groupStorage.init();
      final gIdsMap = groupIdsMap ?? _groupStorage.getAllContactGroupIds();

      final loaded = await _contactService.fetchDeviceContacts(
        contactGroupNamesMap: groupNamesMap ?? {},
        contactGroupIdsMap: gIdsMap,
      );

      // Re-apply favorite flags and persistent group memberships + Deduplicate contacts
      final Set<String> seenIds = {};
      final Set<String> seenPhoneAndCompany = {};
      final List<AppContact> deduplicated = [];

      for (final c in loaded) {
        if (c.id.isNotEmpty && !seenIds.add(c.id)) {
          continue;
        }

        final cleanPhone = c.primaryPhone.replaceAll(RegExp(r'\D'), '');
        final p10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
        final comp = (c.company ?? '').trim().toLowerCase();
        final name = c.displayName.trim().toLowerCase();

        // Only deduplicate if it's the exact same card (same phone + same company + same name)
        final phoneAndCompKey = p10.length >= 7 ? '$p10|$comp|$name' : '';
        if (phoneAndCompKey.isNotEmpty && !seenPhoneAndCompany.add(phoneAndCompKey)) {
          continue;
        }

        final isFav = _favoriteIds.contains(c.id) || c.isFavorite;
        final storedGroupIds = _groupStorage.getGroupIdsForContact(c.id).toList();
        final combinedGroupIds = {...c.groupIds, ...storedGroupIds}.toList();
        deduplicated.add(c.copyWith(
          isFavorite: isFav,
          groupIds: combinedGroupIds,
        ));
      }

      // Seamless SQLite merge & fallback: ensure local Smart Card / scanned contacts are always present
      try {
        final localContacts = await SqliteDatabase.getAllContactsAsync();
        for (final sc in localContacts) {
          if (sc.id.isNotEmpty && seenIds.contains(sc.id)) continue;
          final cleanPhone = sc.phone.replaceAll(RegExp(r'\D'), '');
          final p10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
          final comp = sc.company.trim().toLowerCase();
          final name = sc.name.trim().toLowerCase();
          final phoneAndCompKey = p10.length >= 7 ? '$p10|$comp|$name' : '';
          if (phoneAndCompKey.isNotEmpty && seenPhoneAndCompany.contains(phoneAndCompKey)) continue;

          if (sc.id.isNotEmpty) seenIds.add(sc.id);
          if (phoneAndCompKey.isNotEmpty) seenPhoneAndCompany.add(phoneAndCompKey);

          final alts = [
            if (sc.alternativePhone != null && sc.alternativePhone!.trim().isNotEmpty) sc.alternativePhone!.trim(),
            ...sc.additionalPhones.where((p) => p.trim().isNotEmpty).map((p) => p.trim()),
          ];

          deduplicated.add(AppContact(
            id: sc.id,
            displayName: sc.name.isNotEmpty ? sc.name : 'Unknown Contact',
            givenName: sc.name.contains(' ') ? sc.name.split(' ').first : sc.name,
            familyName: sc.name.contains(' ') ? sc.name.split(' ').sublist(1).join(' ') : null,
            company: sc.company.isNotEmpty ? sc.company : null,
            jobTitle: sc.designation.isNotEmpty ? sc.designation : null,
            phones: [
              if (sc.phone.isNotEmpty) ContactPhone(number: sc.phone, label: 'Mobile'),
              ...alts.map((ap) => ContactPhone(number: ap, label: 'Other')),
            ],
            emails: sc.email.isNotEmpty ? [ContactEmail(address: sc.email, label: 'Work')] : [],
            websites: sc.website.isNotEmpty ? [ContactWebsite(url: sc.website, label: 'Work')] : [],
            addresses: sc.address.isNotEmpty ? [ContactAddress(address: sc.address, label: 'Work')] : [],
            isFavorite: sc.isFavorite || _favoriteIds.contains(sc.id),
          ));
        }
      } catch (err) {
        debugPrint('SQLite contacts merge error: $err');
      }

      _contacts = deduplicated;

      _applyFilterAndSearch();
      _errorMessage = null;
      _persistCachedContacts();
    } catch (e) {
      _errorMessage = 'Failed to load Android contacts: $e';
      debugPrint(_errorMessage);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Set search query with instant filtering
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilterAndSearch();
    notifyListeners();
  }

  /// Set active filter (All, Favorites, With Phone, With Email)
  void setFilter(ContactFilter filter) {
    _currentFilter = filter;
    _selectedGroupId = null;
    _selectedGroupName = null;
    _applyFilterAndSearch();
    notifyListeners();
  }

  /// Filter contacts by a specific Group ID
  void setGroupFilter(String groupId, String groupName) {
    _currentFilter = ContactFilter.group;
    _selectedGroupId = groupId;
    _selectedGroupName = groupName;
    _applyFilterAndSearch();
    notifyListeners();
  }

  /// Toggle contact favorite status
  Future<void> toggleFavorite(AppContact contact) async {
    final willBeFavorite = !contact.isFavorite;
    if (willBeFavorite) {
      _favoriteIds.add(contact.id);
    } else {
      _favoriteIds.remove(contact.id);
    }

    final index = _contacts.indexWhere((c) => c.id == contact.id);
    if (index != -1) {
      _contacts[index] = contact.copyWith(isFavorite: willBeFavorite);
      _applyFilterAndSearch();
      notifyListeners();
    }
  }

  /// Add new contact directly to Android Contacts Provider
  Future<AppContact?> addContact(
    AppContact contact, {
    List<String> assignGroupIds = const [],
  }) async {
    try {
      final created = await _contactService.createContact(
        contact,
        assignGroupIds: assignGroupIds,
      );
      if (created != null) {
        if (assignGroupIds.isNotEmpty) {
          await _groupStorage.setGroupsForContact(created.id, assignGroupIds);
        }
        final withGroups = created.copyWith(groupIds: assignGroupIds);
        _contacts.add(withGroups);
        _contacts.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        _applyFilterAndSearch();
        notifyListeners();
        return withGroups;
      }

      // Safe fallback when native Android Contacts Provider is unavailable (e.g. desktop environment)
      final fallbackId = contact.id.isNotEmpty ? contact.id : 'contact_${DateTime.now().millisecondsSinceEpoch}';
      final fallbackContact = contact.copyWith(id: fallbackId, groupIds: assignGroupIds);
      if (assignGroupIds.isNotEmpty) {
        await _groupStorage.setGroupsForContact(fallbackId, assignGroupIds);
      }
      _contacts.add(fallbackContact);
      _contacts.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      _applyFilterAndSearch();
      _persistCachedContacts();
      notifyListeners();
      return fallbackContact;
    } catch (e) {
      _errorMessage = 'Failed to add contact: $e';
      notifyListeners();
      return null;
    }
  }

  /// Launch native system contact editor dialog as a fallback
  Future<AppContact?> openNativeCreator({AppContact? initialData}) async {
    try {
      final created = await _contactService.openNativeContactCreator(initialData: initialData);
      if (created != null) {
        _contacts.add(created);
        _contacts.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        _applyFilterAndSearch();
        notifyListeners();
        return created;
      }
      return null;
    } catch (e) {
      _errorMessage = 'Failed to launch system contact creator: $e';
      notifyListeners();
      return null;
    }
  }

  /// Update existing contact directly in Android Contacts Provider
  Future<AppContact?> updateContact(
    AppContact contact, {
    List<String>? newGroupIds,
    List<String>? previousGroupIds,
  }) async {
    try {
      final updated = await _contactService.updateContact(
        contact,
        newGroupIds: newGroupIds,
        previousGroupIds: previousGroupIds,
      );
      final finalContact = updated ?? contact;
      if (newGroupIds != null) {
        await _groupStorage.setGroupsForContact(finalContact.id, newGroupIds);
      }
      final withGroups = finalContact.copyWith(groupIds: newGroupIds ?? finalContact.groupIds);
      final index = _contacts.indexWhere((c) => c.id == contact.id);
      if (index != -1) {
        _contacts[index] = withGroups;
        _contacts.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        _applyFilterAndSearch();
        notifyListeners();
      } else {
        _contacts.add(withGroups);
        _contacts.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        _applyFilterAndSearch();
        notifyListeners();
      }
      _persistCachedContacts();
      return withGroups;
    } catch (e) {
      _errorMessage = 'Failed to update contact: $e';
      notifyListeners();
      return null;
    }
  }

  /// Delete contact directly from Android Contacts Provider
  Future<bool> deleteContact(AppContact contact, {dynamic contactViewModel}) async {
    try {
      await _groupStorage.setGroupsForContact(contact.id, []);
      bool success = false;
      try {
        success = await _contactService.deleteContact(contact.id);
      } catch (_) {}
      _contacts.removeWhere((c) {
        if (contact.id.isNotEmpty) return c.id == contact.id;
        return false;
      });
      _favoriteIds.remove(contact.id);
      _applyFilterAndSearch();
      notifyListeners();

      if (contactViewModel != null) {
        try {
          await contactViewModel.deleteContact(
            contact.id,
            target: ScannedContactModel(
              id: contact.id,
              deviceContactId: contact.id,
              name: contact.displayName,
              company: contact.company ?? '',
              designation: contact.jobTitle ?? '',
              phone: contact.primaryPhone,
              email: contact.primaryEmail,
              website: '',
              address: '',
              socialLinks: const [],
              createdAt: DateTime.now(),
            ),
          );
        } catch (_) {}
      }

      return success;
    } catch (e) {
      _contacts.removeWhere((c) => c.id == contact.id);
      _errorMessage = 'Failed to delete contact: $e';
      notifyListeners();
      return false;
    }
  }

  /// Find contact by ID (O(1) indexed lookup)
  AppContact? findContactById(String id) {
    if (id.isNotEmpty && _idLookupIndex.containsKey(id)) {
      return _idLookupIndex[id];
    }
    try {
      return _contacts.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Find existing phone contact by phone number, email address, or display name (O(1) indexed lookup)
  /// If [company] is specified, prioritizes matching contacts that belong to that specific company.
  AppContact? findContactByPhoneOrEmail(String phone, String email, {String? name, String? company}) {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final p10Phone = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    final p7Phone = cleanPhone.length >= 7 ? cleanPhone.substring(cleanPhone.length - 7) : cleanPhone;
    final cleanEmail = email.trim().toLowerCase();
    final cleanComp = (company ?? '').trim();

    // 1. If company is specified, find the specific company profile among matching phone/email contacts
    if (cleanComp.isNotEmpty) {
      for (final c in _contacts) {
        bool phoneMatch = false;
        for (final p in c.phones) {
          if (PhoneNormalizer.isSame(p.number, phone)) {
            phoneMatch = true;
            break;
          }
        }
        final emailMatch = cleanEmail.isNotEmpty && c.emails.any((e) => e.address.trim().toLowerCase() == cleanEmail);
        if (phoneMatch || emailMatch) {
          if (c.company != null && CompanyNormalizer.isSimilar(c.company!, cleanComp)) {
            return c;
          }
          if (c.displayName.toLowerCase().contains(cleanComp.toLowerCase())) {
            return c;
          }
        }
      }
    }

    // 2. Fast O(1) indexed lookup
    if (p10Phone.length >= 7 && _phoneLookupIndex.containsKey(p10Phone)) {
      return _phoneLookupIndex[p10Phone];
    }
    if (p7Phone.length >= 7 && _phoneLookupIndex.containsKey(p7Phone)) {
      return _phoneLookupIndex[p7Phone];
    }
    if (cleanPhone.isNotEmpty && _phoneLookupIndex.containsKey(cleanPhone)) {
      return _phoneLookupIndex[cleanPhone];
    }
    if (cleanEmail.isNotEmpty && _emailLookupIndex.containsKey(cleanEmail)) {
      return _emailLookupIndex[cleanEmail];
    }

    // 3. Name fallback if provided
    final cleanName = (name ?? '').trim().toLowerCase();
    if (cleanName.isNotEmpty && cleanName.length >= 2) {
      for (final c in _contacts) {
        if (c.displayName.trim().toLowerCase() == cleanName) {
          return c;
        }
      }
    }
    return null;
  }

  /// Finds existing device contact by stable deviceContactId, or falls back to phone/company details.
  AppContact? findContactByDeviceContactIdOrDetails(
    String? deviceContactId,
    String phone,
    String email, {
    String? company,
    String? name,
  }) {
    if (deviceContactId != null && deviceContactId.isNotEmpty) {
      final match = findContactById(deviceContactId);
      if (match != null) return match;
    }
    return findContactByPhoneOrEmail(phone, email, name: name, company: company);
  }

  /// Refresh full contact details from Android Contacts Provider
  Future<AppContact?> refreshContact(String id) async {
    final refreshed = await _contactService.getContactById(id);
    if (refreshed != null) {
      final storedGroupIds = _groupStorage.getGroupIdsForContact(id).toList();
      final combined = refreshed.copyWith(
        isFavorite: _favoriteIds.contains(id) || refreshed.isFavorite,
        groupIds: {...refreshed.groupIds, ...storedGroupIds}.toList(),
      );
      final index = _contacts.indexWhere((c) => c.id == id);
      if (index != -1) {
        _contacts[index] = combined;
        _applyFilterAndSearch();
        notifyListeners();
      }
      return combined;
    }
    return null;
  }

  /// Internal filter and search algorithm
  void _applyFilterAndSearch() {
    List<AppContact> temp = List.from(_contacts);

    // 1. Apply category filter
    switch (_currentFilter) {
      case ContactFilter.favorites:
        temp = temp.where((c) => c.isFavorite || _favoriteIds.contains(c.id)).toList();
        break;
      case ContactFilter.group:
        if (_selectedGroupId != null) {
          final groupMemberIds = _groupStorage.getContactIdsForGroup(_selectedGroupId!);
          temp = temp.where((c) => c.groupIds.contains(_selectedGroupId) || groupMemberIds.contains(c.id)).toList();
        }
        break;
      case ContactFilter.all:
      case ContactFilter.withPhone:
      case ContactFilter.withEmail:
        break;
    }

    // 2. Apply search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      temp = temp.where((c) {
        final nameMatch = c.displayName.toLowerCase().contains(q);
        final companyMatch = c.company?.toLowerCase().contains(q) ?? false;
        final phoneMatch = c.phones.any((p) => p.number.replaceAll(RegExp(r'\s+'), '').contains(q));
        final emailMatch = c.emails.any((e) => e.address.toLowerCase().contains(q));
        final groupMatch = c.groupNames.any((g) => g.toLowerCase().contains(q));
        return nameMatch || companyMatch || phoneMatch || emailMatch || groupMatch;
      }).toList();
    }

    // 3. Sort alphabetically
    temp.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    _filteredContacts = temp;
    _recomputeGroupedContacts();
    _rebuildLookupIndices();
  }
}
