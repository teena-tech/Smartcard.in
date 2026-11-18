import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// A lightweight helper that exposes online/offline state for the app.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  ConnectivityService() {
    _connectivity.onConnectivityChanged.listen((results) {
      _controller.add(_isNetworkActive(results));
    });
  }

  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return _isNetworkActive(results);
  }

  bool _isNetworkActive(dynamic results) {
    if (results is List<ConnectivityResult>) {
      return results.isNotEmpty && !results.contains(ConnectivityResult.none);
    } else if (results is ConnectivityResult) {
      return results != ConnectivityResult.none;
    }
    return true;
  }

  Stream<bool> get onlineChanges => _controller.stream;

  void dispose() {
    _controller.close();
  }
}
