import 'dart:async';
import 'package:flutter/foundation.dart';

/// Global loading state with task-counter support.
///
/// Multiple concurrent async operations each call [startTask]/[endTask]
/// (or use the [run] helper). The overlay stays visible until ALL tasks
/// complete, preventing a flicker when e.g. login triggers both a
/// network call and a profile fetch.
class AppLoadingService extends ChangeNotifier {
  /// Singleton so DioClient (non-widget) can call it without BuildContext.
  static final AppLoadingService instance = AppLoadingService._internal();

  int _taskCount = 0;
  String? _message;
  String? _currentUserId;

  AppLoadingService._internal();

  // ── Minimum display duration ──────────────────────────────────────────────
  /// Overlay stays visible for at least this long so users can actually see it
  /// even on a very fast connection.
  static const Duration _minDisplayDuration = Duration(milliseconds: 3000);

  DateTime? _loadingStartedAt;
  Timer? _hideTimer;

  // ── Getters ─────────────────────────────────────────────────────────────
  bool get isLoading => _taskCount > 0;
  String? get message => _message;
  String? get error => _message; // backward-compat alias
  String? get currentUserId => _currentUserId;

  // ── Task helpers ─────────────────────────────────────────────────────────

  /// Increment the active task counter (shows overlay).
  void startTask({String? message}) {
    _hideTimer?.cancel();
    _hideTimer = null;
    _taskCount++;
    _loadingStartedAt ??= DateTime.now();
    if (message != null) _message = message;
    notifyListeners();
  }

  /// Decrement the active task counter (hides overlay when it reaches 0).
  /// Respects the minimum display duration — waits if needed.
  void endTask() {
    if (_taskCount > 0) _taskCount--;
    if (_taskCount == 0) {
      _scheduleHide();
    }
  }

  void _scheduleHide() {
    final startedAt = _loadingStartedAt;
    if (startedAt == null) {
      _doHide();
      return;
    }
    final elapsed = DateTime.now().difference(startedAt);
    final remaining = _minDisplayDuration - elapsed;
    if (remaining <= Duration.zero) {
      _doHide();
    } else {
      _hideTimer = Timer(remaining, _doHide);
    }
  }

  void _doHide() {
    _message = null;
    _loadingStartedAt = null;
    _hideTimer = null;
    notifyListeners();
  }

  /// Convenience wrapper: shows overlay, runs [task], hides overlay.
  ///
  ///   final result = await loadingService.run(() => myApiCall());
  Future<T> run<T>(Future<T> Function() task, {String? message}) async {
    startTask(message: message);
    try {
      return await task();
    } finally {
      endTask();
    }
  }

  // ── Legacy API (kept for backward compatibility) ─────────────────────────

  /// Prefer [startTask]/[endTask] or [run] for new code.
  void setLoading(bool value, {String? message}) {
    if (value) {
      startTask(message: message);
    } else {
      // Force-clear all tasks (for legacy callers that call setLoading(false))
      if (_taskCount > 0) {
        _taskCount = 0;
        _message = null;
        notifyListeners();
      }
    }
  }

  void setCurrentUserId(String? id) {
    if (_currentUserId == id) return;
    _currentUserId = id;
    notifyListeners();
  }

  void clear() {
    _hideTimer?.cancel();
    _taskCount = 0;
    _message = null;
    _loadingStartedAt = null;
    _currentUserId = null;
    notifyListeners();
  }
}
