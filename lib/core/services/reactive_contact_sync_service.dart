import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import '../../providers/contact_provider.dart';
import '../../viewmodels/contact_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';

/// Real-time Google / Device Contacts Sync & Event Service.
/// Reactively detects contact additions, edits, and deletions in Google Contacts
/// and updates Contacts, Smart Cards, Scan Tabs, and Home Screen counters instantly.
class ReactiveContactSyncService {
  static final ReactiveContactSyncService _instance = ReactiveContactSyncService._internal();
  factory ReactiveContactSyncService() => _instance;
  ReactiveContactSyncService._internal();

  StreamSubscription<void>? _deviceSubscription;
  final StreamController<SyncEvent> _eventController = StreamController<SyncEvent>.broadcast();

  Stream<SyncEvent> get events => _eventController.stream;

  bool _isInitialized = false;

  void initialize({
    required ContactProvider contactProvider,
    required ContactViewModel contactViewModel,
    required DashboardViewModel dashboardViewModel,
  }) {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      _deviceSubscription?.cancel();
      _deviceSubscription = fc.FlutterContacts.onDatabaseChange.listen((_) async {
        debugPrint('⚡ [ReactiveSyncService] Device/Google contacts change detected in real-time!');
        await handleDatabaseChange(
          contactProvider: contactProvider,
          contactViewModel: contactViewModel,
          dashboardViewModel: dashboardViewModel,
        );
      });
    } catch (e) {
      debugPrint('⚠️ Native contacts database listener init warning: $e');
    }
  }

  bool _isHandlingChange = false;
  bool _hasPendingChange = false;

  /// Called when device contacts database fires an update or deletion event
  Future<void> handleDatabaseChange({
    required ContactProvider contactProvider,
    required ContactViewModel contactViewModel,
    required DashboardViewModel dashboardViewModel,
    bool silent = true,
  }) async {
    if (_isHandlingChange) {
      _hasPendingChange = true;
      return;
    }
    _isHandlingChange = true;
    try {
      do {
        _hasPendingChange = false;
        // 1. Refresh device contacts stream
        await contactProvider.syncWithDevice(silent: silent);

        // 2. Extract updated device phone numbers and IDs
        final currentDeviceContacts = contactProvider.contacts;
        final Set<String> validDeviceIds = currentDeviceContacts.map((c) => c.id).toSet();
        final Set<String> validDevicePhones = contactProvider.validDevicePhones;

        // 3. Purge deleted contacts from ContactViewModel and SQLite/Hive database across all tabs
        await contactViewModel.syncDeletedDeviceContacts(
          validDeviceIds,
          validDevicePhones: validDevicePhones,
          currentDeviceContacts: currentDeviceContacts,
        );

        // 4. Broadcast instant deletion event so all screens and counters update immediately
        _eventController.add(SyncEvent(type: SyncEventType.deletionOrUpdate));

        // 5. Notify DashboardViewModel to repaint counts reactively
        dashboardViewModel.refresh();
      } while (_hasPendingChange);
    } catch (e) {
      debugPrint('⚠️ Error handling database change in ReactiveSyncService: $e');
    } finally {
      _isHandlingChange = false;
    }
  }

  void dispose() {
    _deviceSubscription?.cancel();
    _eventController.close();
    _isInitialized = false;
  }
}

enum SyncEventType { deletionOrUpdate, manualSync }

class SyncEvent {
  final SyncEventType type;
  final String? contactId;

  SyncEvent({required this.type, this.contactId});
}
