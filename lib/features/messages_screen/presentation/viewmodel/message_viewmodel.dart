import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/features/profile_screen/data/repositories/user_repository.dart';

@immutable
class MessageState {
  final List<Map<String, dynamic>> messages;
  final bool isLoading;
  final String? error;
  final bool isPolling;

  const MessageState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.isPolling = false,
  });

  int get totalMessages => messages.length;
  int get unreadCount => messages.where(MessageViewModel.isUnread).length;

  MessageState copyWith({
    List<Map<String, dynamic>>? messages,
    bool? isLoading,
    String? error,
    bool? isPolling,
    bool clearError = false,
  }) {
    return MessageState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isPolling: isPolling ?? this.isPolling,
    );
  }
}

class MessageViewModel extends Notifier<MessageState> {
  final UserRepository _repository = UserRepository();
  Timer? _pollingTimer;
  final List<void Function(List<Map<String, dynamic>>)> _newMsgListeners = [];
  Set<String>? _locallyReadMessageIds;

  Set<String> get _locallyReadSet => _locallyReadMessageIds ??= <String>{};

  @override
  MessageState build() {
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });
    return const MessageState();
  }

  // Getters for convenience
  List<Map<String, dynamic>> get messages => state.messages;
  bool get isLoading => state.isLoading;
  String? get error => state.error;
  bool get isPolling => state.isPolling;
  int get totalMessages => state.totalMessages;
  int get unreadCount => state.unreadCount;

  void addNewMessageListener(void Function(List<Map<String, dynamic>>) cb) =>
      _newMsgListeners.add(cb);

  void removeNewMessageListener(void Function(List<Map<String, dynamic>>) cb) =>
      _newMsgListeners.remove(cb);

  void _fireNewMessageCallbacks(List<Map<String, dynamic>> arrived) {
    for (final cb in List.of(_newMsgListeners)) {
      cb(arrived);
    }
  }

  static bool isUnread(Map<String, dynamic> msg) {
    final action = msg['user_action'];
    if (action == null) return true;
    if (action is Map) return action['read_at'] == null;
    return true;
  }

  static int _sortMs(Map<String, dynamic> msg) {
    for (final key in ['created_at', 'sort_at', 'show_from', 'show_until']) {
      final raw = msg[key]?.toString();
      if (raw != null && raw.isNotEmpty) {
        try {
          final ms = DateTime.parse(raw).millisecondsSinceEpoch;
          if (ms > 0) return ms;
        } catch (_) {}
      }
    }
    return int.tryParse(msg['id']?.toString() ?? '') ?? 0;
  }

  static List<Map<String, dynamic>> _sort(List<Map<String, dynamic>> msgs) {
    final list = List<Map<String, dynamic>>.from(msgs);
    list.sort((a, b) {
      final rankA = isUnread(a) ? 0 : 1;
      final rankB = isUnread(b) ? 0 : 1;
      if (rankA != rankB) return rankA - rankB;
      return _sortMs(b) - _sortMs(a);
    });
    return list;
  }

  Future<void> loadMessages({bool silent = false}) async {
    try {
      if (!silent) {
        state = state.copyWith(isLoading: true, clearError: true);
      }
      final fetched = await _repository.getDashboardMessages();
      for (final m in fetched) {
        final idStr = m['id']?.toString() ?? '';
        if (_locallyReadSet.contains(idStr)) {
          final action = m['user_action'] is Map ? Map<String, dynamic>.from(m['user_action']) : <String, dynamic>{};
          action['read_at'] ??= DateTime.now().toIso8601String();
          m['user_action'] = action;
        }
      }
      state = state.copyWith(
        messages: _sort(fetched),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void startPolling({int intervalSeconds = 60}) {
    _pollingTimer?.cancel();
    state = state.copyWith(isPolling: true);
    _pollingTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) async {
      try {
        final fresh = _sort(await _repository.getDashboardMessages());
        final oldIds = state.messages.map((m) => m['id']?.toString() ?? '').toSet();
        final newIds = fresh.map((m) => m['id']?.toString() ?? '').toSet();
        final arrived = fresh.where((m) => !oldIds.contains(m['id']?.toString() ?? '')).toList();

        final changed = fresh.length != state.messages.length ||
            !newIds.containsAll(oldIds) ||
            !oldIds.containsAll(newIds);

        if (changed) {
          state = state.copyWith(messages: fresh);
        }
        if (arrived.isNotEmpty) {
          _fireNewMessageCallbacks(arrived);
        }
      } catch (_) {}
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    state = state.copyWith(isPolling: false);
  }

  Future<bool> markAsRead(String id) async {
    _locallyReadSet.add(id);
    _updateLocalAction(id, {'read_at': DateTime.now().toIso8601String()}, resort: true);
    try {
      await _repository.updateDashboardMessageAction(id, 'mark_read');
    } catch (e) {
      debugPrint('⚠️ Gracefully handled backend message action error: $e');
    }
    return true;
  }

  Future<void> likeMessage(String id) async {
    try {
      final msg = _findMsg(id);
      if (msg != null) {
        final wasDislike = msg['user_action']?['reaction'] == 'dislike';
        _updateLocalStats(id, reaction: 'like', likeDelta: 1, dislikeDelta: wasDislike ? -1 : 0);
      }
      await _repository.updateDashboardMessageAction(id, 'like');
    } catch (e) {
      await loadMessages(silent: true);
      rethrow;
    }
  }

  Future<void> dislikeMessage(String id) async {
    try {
      final msg = _findMsg(id);
      if (msg != null) {
        final wasLike = msg['user_action']?['reaction'] == 'like';
        _updateLocalStats(id, reaction: 'dislike', likeDelta: wasLike ? -1 : 0, dislikeDelta: 1);
      }
      await _repository.updateDashboardMessageAction(id, 'dislike');
    } catch (e) {
      await loadMessages(silent: true);
      rethrow;
    }
  }

  Future<void> clearReaction(String id) async {
    try {
      final msg = _findMsg(id);
      if (msg != null) {
        final reaction = msg['user_action']?['reaction'];
        _updateLocalStats(
          id,
          reaction: 'none',
          likeDelta: reaction == 'like' ? -1 : 0,
          dislikeDelta: reaction == 'dislike' ? -1 : 0,
        );
      }
      await _repository.updateDashboardMessageAction(id, 'clear_reaction');
    } catch (e) {
      await loadMessages(silent: true);
      rethrow;
    }
  }

  Future<bool> deleteMessage(String id) async {
    try {
      await _repository.updateDashboardMessageAction(id, 'delete');
      await loadMessages(silent: true);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic>? _findMsg(String id) {
    final msgId = int.tryParse(id);
    final idx = state.messages.indexWhere((m) => m['id'] == msgId || m['id'].toString() == id);
    return idx >= 0 ? state.messages[idx] : null;
  }

  void _updateLocalAction(String id, Map<String, dynamic> patch, {bool resort = false}) {
    final msgId = int.tryParse(id);
    final idx = state.messages.indexWhere((m) => m['id'] == msgId || m['id'].toString() == id);
    if (idx < 0) return;
    final list = List<Map<String, dynamic>>.from(state.messages);
    final existing = list[idx]['user_action'];
    list[idx] = Map<String, dynamic>.from(list[idx]);
    list[idx]['user_action'] = {
      ...(existing is Map ? existing : {}),
      ...patch,
    };
    final finalMsgs = resort ? _sort(list) : list;
    state = state.copyWith(messages: finalMsgs);
  }

  void _updateLocalStats(
    String id, {
    required String reaction,
    required int likeDelta,
    required int dislikeDelta,
  }) {
    final msgId = int.tryParse(id);
    final idx = state.messages.indexWhere((m) => m['id'] == msgId || m['id'].toString() == id);
    if (idx < 0) return;
    final list = List<Map<String, dynamic>>.from(state.messages);
    final existingAction = list[idx]['user_action'];
    final existingStats = list[idx]['stats'];
    list[idx] = Map<String, dynamic>.from(list[idx]);
    list[idx]['user_action'] = {
      ...(existingAction is Map ? existingAction : {}),
      'reaction': reaction,
    };
    list[idx]['stats'] = {
      ...(existingStats is Map ? existingStats : {}),
      'like_count': ((existingStats?['like_count'] ?? 0) as num).toInt() + likeDelta,
      'dislike_count': ((existingStats?['dislike_count'] ?? 0) as num).toInt() + dislikeDelta,
    };
    state = state.copyWith(messages: list);
  }
}

final messageViewModelProvider =
    NotifierProvider<MessageViewModel, MessageState>(MessageViewModel.new);
