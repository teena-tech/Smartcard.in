import 'package:flutter/foundation.dart';

enum ViewState { idle, loading, success, error, offline }

class BaseViewModel extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  String? _message;

  ViewState get state => _state;
  String? get message => _message;
  String? get error => _message;
  bool get isLoading => _state == ViewState.loading;
  bool get hasError => _state == ViewState.error;
  bool get isOffline => _state == ViewState.offline;

  void setLoading([String? message]) {
    _state = ViewState.loading;
    _message = message;
    notifyListeners();
  }

  void setSuccess([String? message]) {
    _state = ViewState.success;
    _message = message;
    notifyListeners();
  }

  void setError(String message) {
    _state = ViewState.error;
    _message = message;
    notifyListeners();
  }

  void setOffline(String message) {
    _state = ViewState.offline;
    _message = message;
    notifyListeners();
  }

  void reset() {
    _state = ViewState.idle;
    _message = null;
    notifyListeners();
  }
}
