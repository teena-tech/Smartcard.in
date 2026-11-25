import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class AppLoadingState {
  final int taskCount;
  final String? message;
  final String? currentUserId;

  const AppLoadingState({
    this.taskCount = 0,
    this.message,
    this.currentUserId,
  });

  bool get isLoading => taskCount > 0;
  String? get error => message;

  AppLoadingState copyWith({
    int? taskCount,
    String? message,
    String? currentUserId,
  }) {
    return AppLoadingState(
      taskCount: taskCount ?? this.taskCount,
      message: message ?? this.message,
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }
}

class AppLoadingNotifier extends Notifier<AppLoadingState> {
  static AppLoadingNotifier? _instance;
  static int _globalTaskCount = 0;
  static String? _globalMessage;
  static String? _globalUserId;

  static AppLoadingNotifier get instance => _instance ?? AppLoadingNotifier();

  Timer? _hideTimer;

  @override
  AppLoadingState build() {
    _instance = this;
    ref.onDispose(() {
      _hideTimer?.cancel();
      _instance = null;
    });
    return AppLoadingState(
      taskCount: _globalTaskCount,
      message: _globalMessage,
      currentUserId: _globalUserId,
    );
  }

  void startTask({String? message}) {
    _hideTimer?.cancel();
    _hideTimer = null;
    _globalTaskCount++;
    if (message != null) _globalMessage = message;
    if (_instance != null) {
      _instance!.state = AppLoadingState(
        taskCount: _globalTaskCount,
        message: _globalMessage,
        currentUserId: _globalUserId,
      );
    }
  }

  void endTask() {
    if (_globalTaskCount > 0) {
      _globalTaskCount--;
      if (_globalTaskCount == 0) {
        _globalMessage = null;
      }
      if (_instance != null) {
        _instance!.state = AppLoadingState(
          taskCount: _globalTaskCount,
          message: _globalMessage,
          currentUserId: _globalUserId,
        );
      }
    }
  }

  void setCurrentUser(String? userId) {
    _globalUserId = userId;
    if (_instance != null) {
      _instance!.state = AppLoadingState(
        taskCount: _globalTaskCount,
        message: _globalMessage,
        currentUserId: _globalUserId,
      );
    }
  }

  void setCurrentUserId(String? userId) => setCurrentUser(userId);

  void setLoading(bool value, {String? message}) {
    if (value) {
      startTask(message: message);
    } else {
      hideNow();
    }
  }

  void hideNow() {
    _hideTimer?.cancel();
    _globalTaskCount = 0;
    _globalMessage = null;
    if (_instance != null) {
      _instance!.state = AppLoadingState(
        taskCount: 0,
        message: null,
        currentUserId: _globalUserId,
      );
    }
  }

  Future<T> run<T>(Future<T> Function() task, {String? message}) async {
    startTask(message: message);
    try {
      return await task();
    } finally {
      endTask();
    }
  }
}

final appLoadingProvider =
    NotifierProvider<AppLoadingNotifier, AppLoadingState>(AppLoadingNotifier.new);

/// Compatibility bridge alias for AppLoadingService
class AppLoadingService {
  static AppLoadingNotifier get instance => AppLoadingNotifier.instance;
}
