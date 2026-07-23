import 'dart:async';
import 'package:flutter/material.dart';
import '../repositories/user_repository.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MessageViewModel
///
/// SORTING LOGIC (Tamil explanation in comments):
///
/// வரிசைப்படுத்தல் விதி:
///  1. படிக்காத (unread) messages முதலில் காட்டப்படும்.
///  2. படிக்காத messages-ல் – புதிய message முதலில் (latest first).
///  3. படித்த (read) messages கடைசியில் – புதிய message முதலில் (latest first).
///
///  உதாரணம்:
///   [UNREAD] msg C – 11:30  ← top
///   [UNREAD] msg A – 09:00
///   [READ]   msg D – 12:00
///   [READ]   msg B – 08:00  ← bottom
/// ─────────────────────────────────────────────────────────────────────────────
class MessageViewModel extends ChangeNotifier {
  final UserRepository _repository = UserRepository();

  List<Map<String, dynamic>> _messages = [];
  Timer? _pollingTimer;
  bool _loading = false;
  String? _error;

  // Listeners notified when new messages arrive via polling
  final List<void Function(List<Map<String, dynamic>>)> _newMsgListeners = [];

  // ── Getters ────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get messages => _messages;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get isPolling => _pollingTimer != null;
  int get totalMessages => _messages.length;
  int get unreadCount => _messages.where(_isUnread).length;

  // ── New-message listener hooks ─────────────────────────────────────────────

  void addNewMessageListener(void Function(List<Map<String, dynamic>>) cb) =>
      _newMsgListeners.add(cb);

  void removeNewMessageListener(void Function(List<Map<String, dynamic>>) cb) =>
      _newMsgListeners.remove(cb);

  void _fireNewMessageCallbacks(List<Map<String, dynamic>> arrived) {
    for (final cb in List.of(_newMsgListeners)) {
      cb(arrived);
    }
  }

  // ── Sorting helpers ────────────────────────────────────────────────────────

  /// Returns true when the message has NOT been read (read_at is null).
  static bool _isUnread(Map<String, dynamic> msg) {
    final action = msg['user_action'];
    if (action == null) return true;
    if (action is Map) return action['read_at'] == null;
    return true;
  }

  /// Best sort timestamp in milliseconds.
  /// Priority: created_at → sort_at → show_from → show_until → id (fallback)
  /// Using created_at first = pure time order (newest message first).
  /// sort_at (activity_at) is only a tiebreaker for updated reports.
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

  /// Main sort rule:
  ///   • UNREAD first  (read_at == null → rank 0)
  ///   • Within each group: latest timestamp first
  static List<Map<String, dynamic>> _sort(List<Map<String, dynamic>> msgs) {
    final list = List<Map<String, dynamic>>.from(msgs);
    list.sort((a, b) {
      // Primary: unread (0) before read (1)
      final rankA = _isUnread(a) ? 0 : 1;
      final rankB = _isUnread(b) ? 0 : 1;
      if (rankA != rankB) return rankA - rankB;
      // Secondary: newest first within the same group
      return _sortMs(b) - _sortMs(a);
    });
    return list;
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadMessages({bool silent = false}) async {
    try {
      if (!silent) {
        _loading = true;
        _error = null;
        notifyListeners();
      }
      _messages = _sort(await _repository.getDashboardMessages());
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Polling ────────────────────────────────────────────────────────────────

  /// Start background polling every [intervalSeconds] seconds.
  /// Safe to call multiple times – cancels previous timer first.
  void startPolling({int intervalSeconds = 8}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) async {
      try {
        final fresh = _sort(await _repository.getDashboardMessages());

        // ID-based change detection (new / deleted messages)
        final oldIds = _messages.map((m) => m['id']?.toString() ?? '').toSet();
        final newIds = fresh.map((m) => m['id']?.toString() ?? '').toSet();
        final arrived = fresh.where((m) => !oldIds.contains(m['id']?.toString() ?? '')).toList();

        final changed = fresh.length != _messages.length ||
            !newIds.containsAll(oldIds) ||
            !oldIds.containsAll(newIds);

        if (changed) {
          _messages = fresh;
          notifyListeners();
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
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<bool> markAsRead(String id) async {
    try {
      _updateLocalAction(id, {'read_at': DateTime.now().toIso8601String()}, resort: true);
      await _repository.updateDashboardMessageAction(id, 'mark_read');
      return true;
    } catch (e) {
      await loadMessages(silent: true);
      rethrow;
    }
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

  // ── Private helpers ────────────────────────────────────────────────────────

  Map<String, dynamic>? _findMsg(String id) {
    final msgId = int.tryParse(id);
    final idx = _messages.indexWhere((m) => m['id'] == msgId || m['id'].toString() == id);
    return idx >= 0 ? _messages[idx] : null;
  }

  void _updateLocalAction(String id, Map<String, dynamic> patch, {bool resort = false}) {
    final msgId = int.tryParse(id);
    final idx = _messages.indexWhere((m) => m['id'] == msgId || m['id'].toString() == id);
    if (idx < 0) return;
    final existing = _messages[idx]['user_action'];
    _messages[idx]['user_action'] = {
      ...(existing is Map ? existing : {}),
      ...patch,
    };
    if (resort) _messages = _sort(_messages);
    notifyListeners();
  }

  void _updateLocalStats(
    String id, {
    required String reaction,
    required int likeDelta,
    required int dislikeDelta,
  }) {
    final msgId = int.tryParse(id);
    final idx = _messages.indexWhere((m) => m['id'] == msgId || m['id'].toString() == id);
    if (idx < 0) return;
    final existingAction = _messages[idx]['user_action'];
    final existingStats = _messages[idx]['stats'];
    _messages[idx]['user_action'] = {
      ...(existingAction is Map ? existingAction : {}),
      'reaction': reaction,
    };
    _messages[idx]['stats'] = {
      ...(existingStats is Map ? existingStats : {}),
      'like_count': ((existingStats?['like_count'] ?? 0) as num).toInt() + likeDelta,
      'dislike_count': ((existingStats?['dislike_count'] ?? 0) as num).toInt() + dislikeDelta,
    };
    notifyListeners();
  }
}
