import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../core/network/api_exceptions.dart';
import '../core/services/dio_client.dart';
import '../data/models/message_model.dart';
import '../data/repositories/support_repository.dart';

enum SupportState { initial, loading, loaded, error }

class SupportViewModel extends ChangeNotifier {
  final SupportRepository _repository;

  SupportState _state = SupportState.initial;
  String? _errorMessage;
  List<MessageModel> _messages = [];
  int _unreadCount = 0;

  Map<String, dynamic>? _supportContext;

  SupportViewModel(this._repository);

  SupportState get state => _state;
  String? get errorMessage => _errorMessage;
  List<MessageModel> get messages => _messages;
  int get unreadCount => _unreadCount;
  Map<String, dynamic>? get supportContext => _supportContext;
  bool get isLoading => _state == SupportState.loading;

  void _setState(SupportState state, {String? error}) {
    _state = state;
    _errorMessage = error;
    notifyListeners();
  }

  Future<void> fetchMessages(String userId, {bool loadMore = false}) async {
    // Only show loading state if this is the initial load and messages are empty
    if (!loadMore && _messages.isEmpty) {
      _setState(SupportState.loading);
    }

    try {
      final fetchedMessages = await _repository.getChatMessages(
        userId,
        limit: 20,
        beforeId: loadMore && _messages.isNotEmpty ? _messages.last.id : null,
      );

      if (loadMore) {
        // For pagination: add new messages while avoiding duplicates
        final existingIds = _messages.map((m) => m.id).toSet();
        final newMessages = fetchedMessages.where((m) => !existingIds.contains(m.id)).toList();
        _messages.addAll(newMessages);
      } else {
        // Source of truth: replace list directly with backend fetched messages
        final Map<int, MessageModel> uniqueMap = {};
        for (final msg in fetchedMessages) {
          uniqueMap[msg.id] = msg;
        }
        _messages = uniqueMap.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      _setState(SupportState.loaded);
    } catch (e) {
      _setState(SupportState.error, error: _formatError(e));
    }
  }

  Future<void> fetchSupportContext(dynamic userId) async {
    _setState(SupportState.loading);
    try {
      final res = await _repository.getUserSupportContext(userId.toString());
      if (res['success'] == true && res['data'] != null) {
        _supportContext = Map<String, dynamic>.from(res['data']);
      } else {
        _supportContext = Map<String, dynamic>.from(res);
      }
      _setState(SupportState.loaded);
    } catch (e) {
      _setState(SupportState.error, error: _formatError(e));
    }
  }

  Future<void> fetchUnreadCount(String userId) async {
    try {
      _unreadCount = await _repository.getUnreadMessageCount(userId);
      notifyListeners();
    } catch (e) {
      // Ignore unread count fetch errors
    }
  }

  Future<bool> sendMessage(String userId, String text, {File? attachment}) async {
    try {
      final newMessage = await _repository.sendChatMessage(userId, text: text, attachment: attachment);
      final existingIndex = _messages.indexWhere((m) => m.id == newMessage.id);
      if (existingIndex >= 0) {
        _messages[existingIndex] = newMessage;
      } else {
        _messages.insert(0, newMessage);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _formatError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitReport(String reportType, String reportText) async {
    _setState(SupportState.loading);
    try {
      await _repository.createUserReport(reportType, reportText);
      _setState(SupportState.loaded);
      return true;
    } catch (e) {
      _setState(SupportState.error, error: _formatError(e));
      return false;
    }
  }

  String _formatError(Object e) {
    if (e is DioException) {
      if (e.error is ApiException) {
        return (e.error as ApiException).message;
      }
      return DioClient.getErrorMessage(e, 'Request failed.');
    }
    if (e is ApiException) {
      return e.message;
    }
    return e.toString();
  }
}
