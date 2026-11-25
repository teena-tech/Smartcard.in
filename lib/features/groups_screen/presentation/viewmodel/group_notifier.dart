import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:smartcard_flutter/features/contacts_screen/data/models/app_contact.dart';
import 'package:smartcard_flutter/core/services/group_service.dart';
import 'package:smartcard_flutter/core/services/group_storage.dart';

@immutable
class GroupState {
  final List<fc.Group> groups;
  final bool isLoading;
  final String? errorMessage;

  const GroupState({
    this.groups = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  int get totalGroupsCount => groups.length;

  GroupState copyWith({
    List<fc.Group>? groups,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GroupState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class GroupNotifier extends Notifier<GroupState> {
  final GroupService _groupService = GroupService();
  final GroupStorage _groupStorage = GroupStorage();

  @override
  GroupState build() {
    Future.microtask(() => loadGroups());
    return const GroupState();
  }

  List<fc.Group> get groups => state.groups;
  bool get isLoading => state.isLoading;
  String? get errorMessage => state.errorMessage;
  int get totalGroupsCount => state.totalGroupsCount;

  Future<void> loadGroups() async {
    if (state.groups.isEmpty) {
      state = state.copyWith(isLoading: true);
    }

    try {
      await _groupStorage.init();
      final loaded = await _groupService.getAllGroups(withContactCount: true);
      state = state.copyWith(groups: loaded, clearError: true, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to load groups: $e',
        isLoading: false,
      );
      debugPrint(state.errorMessage);
    }
  }

  Future<fc.Group?> createGroup(String name) async {
    try {
      final created = await _groupService.createGroup(name);
      if (created != null) {
        await loadGroups();
        return created;
      }
      return null;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to create group: $e');
      return null;
    }
  }

  Future<bool> renameGroup(String groupId, String newName) async {
    try {
      final success = await _groupService.updateGroup(groupId, newName);
      if (success) {
        await loadGroups();
      }
      return success;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to rename group: $e');
      return false;
    }
  }

  Future<bool> deleteGroup(String groupId) async {
    try {
      final success = await _groupService.deleteGroup(groupId);
      if (success) {
        final updated = state.groups.where((g) => g.id != groupId).toList();
        state = state.copyWith(groups: updated);
        await loadGroups();
      }
      return success;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to delete group: $e');
      return false;
    }
  }

  Future<bool> addContactsToGroup({
    required String groupId,
    required List<String> contactIds,
  }) async {
    try {
      final success = await _groupService.addContactsToGroup(
        groupId: groupId,
        contactIds: contactIds,
      );
      if (success) {
        await loadGroups();
      }
      return success;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to add contacts: $e');
      return false;
    }
  }

  Future<bool> removeContactsFromGroup({
    required String groupId,
    required List<String> contactIds,
  }) async {
    try {
      final success = await _groupService.removeContactsFromGroup(
        groupId: groupId,
        contactIds: contactIds,
      );
      if (success) {
        await loadGroups();
      }
      return success;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to remove contacts: $e');
      return false;
    }
  }

  Future<List<fc.Group>> getGroupsForContact(String contactId) async {
    return _groupService.getGroupsForContact(contactId);
  }

  List<AppContact> getMembersForGroup(String groupId, List<AppContact> allContacts) {
    final contactIds = _groupStorage.getContactIdsForGroup(groupId);
    return allContacts.where((c) => contactIds.contains(c.id)).toList();
  }

  int getMemberCount(String groupId, List<AppContact> allContacts) {
    return _groupStorage.getContactIdsForGroup(groupId).length;
  }

  fc.Group? findGroupById(String groupId) {
    try {
      return state.groups.firstWhere((g) => g.id == groupId);
    } catch (_) {
      return null;
    }
  }
}

final groupNotifierProvider =
    NotifierProvider<GroupNotifier, GroupState>(GroupNotifier.new);

