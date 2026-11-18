import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class GroupStorage {
  static final GroupStorage _instance = GroupStorage._internal();
  factory GroupStorage() => _instance;
  GroupStorage._internal();

  bool _initialized = false;
  // groupId -> Set<contactId>
  final Map<String, Set<String>> _groupToContacts = {};
  // contactId -> Set<groupId>
  final Map<String, Set<String>> _contactToGroups = {};

  Future<File?> _getFile() async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/contact_groups_map.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }
    try {
      final file = await _getFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final dynamic data = jsonDecode(content);
          if (data is Map<String, dynamic>) {
            _groupToContacts.clear();
            _contactToGroups.clear();

            data.forEach((groupId, contactList) {
              if (contactList is List) {
                final set = contactList.map((e) => e.toString()).toSet();
                _groupToContacts[groupId] = set;
                for (final contactId in set) {
                  _contactToGroups.putIfAbsent(contactId, () => {}).add(groupId);
                }
              }
            });
          }
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint('Error loading GroupStorage: $e');
      _initialized = true;
    }
  }

  Future<void> _save() async {
    if (kIsWeb) return;
    try {
      final file = await _getFile();
      if (file == null) return;
      final Map<String, List<String>> data = {};
      _groupToContacts.forEach((groupId, contacts) {
        data[groupId] = contacts.toList();
      });
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving GroupStorage: $e');
    }
  }

  Set<String> getContactIdsForGroup(String groupId) {
    return _groupToContacts[groupId] ?? {};
  }

  Set<String> getGroupIdsForContact(String contactId) {
    return _contactToGroups[contactId] ?? {};
  }

  int getContactCountForGroup(String groupId) {
    return _groupToContacts[groupId]?.length ?? 0;
  }

  Map<String, List<String>> getAllContactGroupIds() {
    final Map<String, List<String>> result = {};
    _contactToGroups.forEach((contactId, groupIds) {
      result[contactId] = groupIds.toList();
    });
    return result;
  }

  Future<void> addContactsToGroup(String groupId, List<String> contactIds) async {
    await init();
    _groupToContacts.putIfAbsent(groupId, () => {}).addAll(contactIds);
    for (final cid in contactIds) {
      _contactToGroups.putIfAbsent(cid, () => {}).add(groupId);
    }
    await _save();
  }

  Future<void> removeContactsFromGroup(String groupId, List<String> contactIds) async {
    await init();
    if (_groupToContacts.containsKey(groupId)) {
      _groupToContacts[groupId]!.removeAll(contactIds);
    }
    for (final cid in contactIds) {
      if (_contactToGroups.containsKey(cid)) {
        _contactToGroups[cid]!.remove(groupId);
      }
    }
    await _save();
  }

  Future<void> setGroupsForContact(String contactId, List<String> groupIds) async {
    await init();
    // Remove contact from all existing groups
    _groupToContacts.forEach((gId, contacts) {
      contacts.remove(contactId);
    });
    _contactToGroups.remove(contactId);

    // Add contact to selected groups
    for (final gId in groupIds) {
      _groupToContacts.putIfAbsent(gId, () => {}).add(contactId);
      _contactToGroups.putIfAbsent(contactId, () => {}).add(gId);
    }
    await _save();
  }

  Future<void> deleteGroup(String groupId) async {
    await init();
    final contactsInGroup = _groupToContacts.remove(groupId) ?? {};
    for (final cid in contactsInGroup) {
      if (_contactToGroups.containsKey(cid)) {
        _contactToGroups[cid]!.remove(groupId);
      }
    }
    await _save();
  }
}
