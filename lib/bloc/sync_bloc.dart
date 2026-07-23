import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../core/services/backend_sync_service.dart';
import '../core/database/hive_database.dart';

// ==========================================
// EVENTS
// ==========================================
abstract class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object?> get props => [];
}

class TriggerSync extends SyncEvent {}

class NetworkRestored extends SyncEvent {}

// ==========================================
// STATES
// ==========================================
abstract class SyncState extends Equatable {
  const SyncState();

  @override
  List<Object?> get props => [];
}

class SyncInitial extends SyncState {}

class SyncInProgress extends SyncState {}

class SyncSuccess extends SyncState {
  final int syncedCount;
  const SyncSuccess({required this.syncedCount});

  @override
  List<Object?> get props => [syncedCount];
}

class SyncFailure extends SyncState {
  final String error;
  const SyncFailure({required this.error});

  @override
  List<Object?> get props => [error];
}

// ==========================================
// BLOC IMPLEMENTATION
// ==========================================
class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final BackendSyncService _syncService = BackendSyncService();

  SyncBloc() : super(SyncInitial()) {
    on<TriggerSync>((event, emit) async {
      emit(SyncInProgress());
      try {
        final pending = HiveDatabase.getPendingContacts();
        if (pending.isEmpty) {
          emit(const SyncSuccess(syncedCount: 0));
          return;
        }

        int successCount = 0;
        for (var contact in pending) {
          final success = await _syncService.uploadContact(contact);
          if (success) {
            await HiveDatabase.updateSyncStatus(contact.id, 'synced');
            successCount++;
          }
        }

        emit(SyncSuccess(syncedCount: successCount));
      } catch (e) {
        emit(SyncFailure(error: e.toString()));
      }
    });

    on<NetworkRestored>((event, emit) async {
      final pending = HiveDatabase.getPendingContacts();
      if (pending.isNotEmpty) {
        add(TriggerSync());
      }
    });
  }
}
