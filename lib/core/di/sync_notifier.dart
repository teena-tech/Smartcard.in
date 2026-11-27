import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/services/backend_sync_service.dart';
import 'package:smartcard_flutter/core/database/sqlite_database.dart';

@immutable
class SyncState {
  final bool isInProgress;
  final int syncedCount;
  final String? error;

  const SyncState({
    this.isInProgress = false,
    this.syncedCount = 0,
    this.error,
  });

  SyncState copyWith({
    bool? isInProgress,
    int? syncedCount,
    String? error,
  }) {
    return SyncState(
      isInProgress: isInProgress ?? this.isInProgress,
      syncedCount: syncedCount ?? this.syncedCount,
      error: error ?? this.error,
    );
  }
}

class SyncNotifier extends Notifier<SyncState> {
  final BackendSyncService _syncService = BackendSyncService();

  @override
  SyncState build() {
    return const SyncState();
  }

  Future<void> triggerSync() async {
    state = state.copyWith(isInProgress: true, error: null);
    try {
      final pending = await SqliteDatabase.getPendingContactsAsync();
      if (pending.isEmpty) {
        state = state.copyWith(isInProgress: false, syncedCount: 0);
        return;
      }

      int successCount = 0;
      for (var contact in pending) {
        final success = await _syncService.uploadContact(contact);
        if (success) {
          await SqliteDatabase.updateSyncStatus(contact.id, 'synced');
          successCount++;
        }
      }

      state = state.copyWith(isInProgress: false, syncedCount: successCount);
    } catch (e) {
      state = state.copyWith(isInProgress: false, error: e.toString());
    }
  }

  Future<void> onNetworkRestored() async {
    final pending = await SqliteDatabase.getPendingContactsAsync();
    if (pending.isNotEmpty) {
      await triggerSync();
    }
  }
}

final syncProvider =
    NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);
