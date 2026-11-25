import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/network/api_exceptions.dart';
import 'package:smartcard_flutter/core/network/dio_service.dart';
import 'package:smartcard_flutter/core/services/dio_client.dart';
import 'package:smartcard_flutter/features/support_chat_screen/data/models/message_model.dart';
import 'package:smartcard_flutter/features/support_chat_screen/data/repositories/support_repository.dart';

enum SupportStatus { initial, loading, loaded, error }

@immutable
class SupportState {
  final SupportStatus status;
  final String? errorMessage;
  final List<MessageModel> messages;
  final int unreadCount;
  final Map<String, dynamic>? supportContext;

  const SupportState({
    this.status = SupportStatus.initial,
    this.errorMessage,
    this.messages = const [],
    this.unreadCount = 0,
    this.supportContext,
  });

  bool get isLoading => status == SupportStatus.loading;

  SupportState copyWith({
    SupportStatus? status,
    String? errorMessage,
    List<MessageModel>? messages,
    int? unreadCount,
    Map<String, dynamic>? supportContext,
    bool clearError = false,
  }) {
    return SupportState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      messages: messages ?? this.messages,
      unreadCount: unreadCount ?? this.unreadCount,
      supportContext: supportContext ?? this.supportContext,
    );
  }
}

class SupportViewModel extends Notifier<SupportState> {
  late final SupportRepository _repository;

  @override
  SupportState build() {
    _repository = SupportRepository(DioService());
    return const SupportState();
  }

  // Getters for convenience
  SupportStatus get supportStatus => state.status;
  SupportStatus get stateStatus => state.status;
  String? get errorMessage => state.errorMessage;
  List<MessageModel> get messages => state.messages;
  int get unreadCount => state.unreadCount;
  Map<String, dynamic>? get supportContext => state.supportContext;
  bool get isLoading => state.isLoading;

  void _setState(SupportStatus status, {String? error}) {
    state = state.copyWith(
      status: status,
      errorMessage: error,
      clearError: error == null,
    );
  }

  Future<void> fetchMessages(String userId, {bool loadMore = false}) async {
    if (!loadMore && state.messages.isEmpty) {
      _setState(SupportStatus.loading);
    }

    try {
      final fetchedMessages = await _repository.getChatMessages(
        userId,
        limit: 20,
        beforeId: loadMore && state.messages.isNotEmpty ? state.messages.last.id : null,
      );

      final Map<int, MessageModel> uniqueMap = loadMore
          ? {for (final m in state.messages) m.id: m}
          : {};
      for (final msg in fetchedMessages) {
        uniqueMap[msg.id] = msg;
      }
      final sortedList = uniqueMap.values.toList()
        ..sort((a, b) {
          final aDate = _parseDateStr(a.createdAt);
          final bDate = _parseDateStr(b.createdAt);
          final dateCmp = bDate.compareTo(aDate);
          if (dateCmp != 0) return dateCmp;
          return b.id.compareTo(a.id);
        });

      state = state.copyWith(
        messages: sortedList,
        status: SupportStatus.loaded,
      );
    } catch (e) {
      _setState(SupportStatus.error, error: _formatError(e));
    }
  }

  Future<void> fetchSupportContext(dynamic userId) async {
    _setState(SupportStatus.loading);
    try {
      final res = await _repository.getUserSupportContext(userId.toString());
      Map<String, dynamic> ctx;
      if (res['success'] == true && res['data'] != null) {
        ctx = Map<String, dynamic>.from(res['data']);
      } else {
        ctx = Map<String, dynamic>.from(res);
      }
      state = state.copyWith(
        supportContext: ctx,
        status: SupportStatus.loaded,
      );
    } catch (e) {
      _setState(SupportStatus.error, error: _formatError(e));
    }
  }

  Future<void> fetchUnreadCount(String userId) async {
    try {
      final count = await _repository.getUnreadMessageCount(userId);
      state = state.copyWith(unreadCount: count);
    } catch (_) {}
  }

  Future<bool> sendMessage(String userId, String text, {File? attachment}) async {
    try {
      final newMessage = await _repository.sendChatMessage(userId, text: text, attachment: attachment);
      final list = List<MessageModel>.from(state.messages);
      final existingIndex = list.indexWhere((m) => m.id == newMessage.id);
      if (existingIndex >= 0) {
        list[existingIndex] = newMessage;
      } else {
        list.insert(0, newMessage);
      }
      state = state.copyWith(messages: list, clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: _formatError(e));
      return false;
    }
  }

  Future<bool> submitReport(String reportType, String reportText) async {
    _setState(SupportStatus.loading);
    try {
      await _repository.createUserReport(reportType, reportText);
      _setState(SupportStatus.loaded);
      return true;
    } catch (e) {
      _setState(SupportStatus.error, error: _formatError(e));
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

  DateTime _parseDateStr(String raw) {
    final str = raw.trim();
    if (str.isEmpty) return DateTime.now();
    final numVal = num.tryParse(str);
    if (numVal != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        numVal > 100000000000 ? numVal.toInt() : (numVal * 1000).toInt(),
      ).toLocal();
    }
    final sanitized = str.replaceAll(' ', 'T');
    return DateTime.tryParse(sanitized)?.toLocal() ?? DateTime.now();
  }
}

final supportViewModelProvider =
    NotifierProvider<SupportViewModel, SupportState>(SupportViewModel.new);
