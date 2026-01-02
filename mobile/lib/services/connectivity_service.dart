import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();

  bool _isConnected = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  bool get isConnected => _isConnected;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  ConnectivityService() {
    _initialize();
  }

  void _initialize() {
    // Check initial connectivity
    _checkConnectivity();

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) {
        _updateConnectionStatus(result);
      },
    );
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      _isConnected = false;
      _connectionStatusController.add(_isConnected);
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final wasConnected = _isConnected;

    // Consider connected if result is not 'none'
    _isConnected = result != ConnectivityResult.none;

    debugPrint('Connectivity changed: $_isConnected (result: $result)');

    // Notify listeners if status changed
    if (wasConnected != _isConnected) {
      _connectionStatusController.add(_isConnected);
    }
  }

  Future<bool> checkConnection() async {
    await _checkConnectivity();
    return _isConnected;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionStatusController.close();
  }
}
