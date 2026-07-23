import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/database/hive_database.dart';
import '../../models/scanned_contact_model.dart';
import '../../core/services/contact_import_service.dart';
import '../../core/services/export_service.dart';
import '../repositories/contact_repository.dart';

class ContactViewModel extends ChangeNotifier {
  List<ScannedContactModel> _allContacts = [];
  List<ScannedContactModel> _filteredContacts = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  String _searchQuery = '';

  ContactViewModel() {
    _loadHiveContacts();
    loadContactsFromBackend();
  }

  List<ScannedContactModel> get contacts => _filteredContacts;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String get searchQuery => _searchQuery;

  // Pagination fields
  int _currentPage = 1;
  static const int _pageSize = 50;

  /// Loads contacts saved in Hive database.
  Future<void> _loadHiveContacts() async {
    _isLoading = true;
    notifyListeners();
    try {
      _allContacts = HiveDatabase.getAllContacts();
      _allContacts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _applySearchAndPagination();
    } catch (e) {
      debugPrint('🚨 Error loading Hive contacts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load contacts from backend API
  Future<void> loadContactsFromBackend() async {
    _isRefreshing = true;
    notifyListeners();

    try {
      // Use ContactRepository to fetch contacts list
      final repository = ContactRepository();
      final contacts = await repository.getContacts();
      final List<ScannedContactModel> contactsToSave = [];
      for (var contactData in contacts) {
        // Assuming contactData is a map with required fields
        final id = contactData['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
        final scanned = ScannedContactModel(
          id: id,
          name: contactData['name'] ?? '',
          designation: contactData['designation'] ?? '',
          company: contactData['company'] ?? '',
          phone: contactData['phone'] ?? '',
          email: contactData['email'] ?? '',
          address: contactData['address'] ?? '',
          website: contactData['website'] ?? '',
          socialLinks: const [],
          source: 'smartcard',
          syncStatus: 'synced',
          isFavorite: false,
          createdAt: DateTime.now(),
        );
        if (!_allContacts.any((c) => c.id == scanned.id)) {
          _allContacts.add(scanned);
          contactsToSave.add(scanned);
        }
      }
      if (contactsToSave.isNotEmpty) {
        await HiveDatabase.saveContacts(contactsToSave);
        _allContacts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      _applySearchAndPagination();
    } catch (e) {
      debugPrint('🚨 Error loading contacts from backend: $e');
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _currentPage = 1; // Reset pagination
    _applySearchAndPagination();
  }

  void _applySearchAndPagination() {
    List<ScannedContactModel> filtered = _allContacts;
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = _allContacts.where((c) {
        return c.name.toLowerCase().contains(query) ||
               c.phone.contains(query) ||
               (c.alternativePhone?.contains(query) ?? false) ||
               c.email.toLowerCase().contains(query) ||
               c.company.toLowerCase().contains(query);
      }).toList();
    }
    
    // List is already kept sorted when modifying _allContacts
    
    // Implement lazy loading/pagination
    final int endIndex = (_currentPage * _pageSize).clamp(0, filtered.length);
    _filteredContacts = filtered.sublist(0, endIndex);
    
    notifyListeners();
  }
  
  void loadMore() {
    if ((_currentPage * _pageSize) < _allContacts.length) {
      _currentPage++;
      _applySearchAndPagination();
    }
  }

  /// Adds a scanned contact and persists it to Hive.
  Future<void> addScannedContact(ScannedContactModel scanned) async {
    await HiveDatabase.saveContact(scanned);
    _allContacts.removeWhere((c) => c.id == scanned.id);
    _allContacts.insert(0, scanned);
    _applySearchAndPagination();
  }

  /// Deletes a contact by its [id].
  Future<void> deleteContact(String id) async {
    _allContacts.removeWhere((c) => c.id == id);
    await HiveDatabase.deleteContact(id);
    _applySearchAndPagination();
  }

  /// Toggles favorite status
  Future<void> toggleFavorite(String id) async {
    final index = _allContacts.indexWhere((c) => c.id == id);
    if (index != -1) {
      final updated = _allContacts[index].copyWith(isFavorite: !_allContacts[index].isFavorite);
      _allContacts[index] = updated;
      await HiveDatabase.saveContact(updated);
      _applySearchAndPagination();
    }
  }

  /// Import contacts from Phone Book
  Future<void> importPhoneContacts() async {
    _isRefreshing = true;
    notifyListeners();
    try {
      final newContacts = await ContactImportService.importPhoneContacts(_allContacts);
      if (newContacts.isNotEmpty) {
        await HiveDatabase.saveContacts(newContacts);
        _allContacts.addAll(newContacts);
        _allContacts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _applySearchAndPagination();
      }
    } catch (e) {
      debugPrint('🚨 Error importing phone contacts: $e');
      rethrow;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Export contacts as VCF
  Future<void> exportVcf() async {
    await ExportService.exportAsVcf(_filteredContacts);
  }

  /// Export contacts as CSV
  Future<void> exportCsv() async {
    await ExportService.exportAsCsv(_filteredContacts);
  }

  /// Background sync for unsynced contacts using ContactRepository
  Future<void> syncContactsToApi() async {
    _isRefreshing = true;
    notifyListeners();
    try {
      final pendingContacts = _allContacts.where((c) => c.syncStatus == 'pending' && c.source != 'phone').toList();
      final repository = ContactRepository();
      final List<ScannedContactModel> updatedContacts = [];
      for (var contact in pendingContacts) {
        final payload = {
          'name': contact.name,
          'phone': contact.phone,
          'email': contact.email,
          'company': contact.company,
          'designation': contact.designation,
          'address': contact.address,
          'website': contact.website,
        };
        try {
          await repository.saveContact(payload);
          // Mark as synced locally
          final index = _allContacts.indexWhere((c) => c.id == contact.id);
          if (index != -1) {
            _allContacts[index] = _allContacts[index].copyWith(syncStatus: 'synced');
            updatedContacts.add(_allContacts[index]);
          }
        } catch (e) {
          debugPrint('Sync failed for ${contact.name}: $e');
        }
      }
      if (updatedContacts.isNotEmpty) {
        await HiveDatabase.saveContacts(updatedContacts);
      }
      _applySearchAndPagination();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }
}
