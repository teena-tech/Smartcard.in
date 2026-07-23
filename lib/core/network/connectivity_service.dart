import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// A lightweight helper that exposes online/offline state for the app.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  ConnectivityService() {
    _connectivity.onConnectivityChanged.listen((result) {
      _controller.add(result != ConnectivityResult.none);
    });
  }

  Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Stream<bool> get onlineChanges => _controller.stream;

  void dispose() {
    _controller.close();
  }
}
