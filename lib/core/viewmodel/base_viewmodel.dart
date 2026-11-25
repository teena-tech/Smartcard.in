import 'package:flutter/foundation.dart';

enum ViewState { idle, loading, success, error, offline }

@immutable
class BaseState {
  final ViewState viewState;
  final String? message;
  final String? error;

  const BaseState({
    this.viewState = ViewState.idle,
    this.message,
    this.error,
  });

  bool get isLoading => viewState == ViewState.loading;
  bool get hasError => viewState == ViewState.error;
  bool get isOffline => viewState == ViewState.offline;

  BaseState copyWith({
    ViewState? viewState,
    String? message,
    String? error,
  }) {
    return BaseState(
      viewState: viewState ?? this.viewState,
      message: message ?? this.message,
      error: error ?? this.error,
    );
  }
}
