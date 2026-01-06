import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Connectivity state enum for network status
/// 
/// Distinguishes between different connection types as per Requirements 5.4
enum ConnectivityState {
  /// No network connection available
  offline,
  /// Connected via WiFi
  wifi,
  /// Connected via mobile data (cellular)
  mobile,
  /// Connected via ethernet
  ethernet,
}

/// Monitor for network connectivity changes
/// 
/// This service wraps the `connectivity_plus` package to provide
/// a clean interface for monitoring network state changes and
/// detecting online/offline status.
/// 
/// Requirements: 5.1, 5.4
class ConnectivityMonitor {
  final Connectivity _connectivity;
  
  /// Stream subscription for connectivity changes
  StreamSubscription<ConnectivityResult>? _subscription;
  
  /// Stream controller for connectivity state changes
  final StreamController<ConnectivityState> _stateController =
      StreamController<ConnectivityState>.broadcast();
  
  /// Cached current state
  ConnectivityState _currentState = ConnectivityState.offline;
  
  /// Whether the monitor has been initialized
  bool _isInitialized = false;

  /// Creates a ConnectivityMonitor instance
  /// 
  /// [connectivity] - Optional Connectivity instance for testing
  ConnectivityMonitor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  /// Initialize the connectivity monitor and start listening for changes
  /// 
  /// Requirements: 5.1
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Get initial connectivity state
      final result = await _connectivity.checkConnectivity();
      _currentState = _mapConnectivityResult(result);
      debugPrint('✅ ConnectivityMonitor: Initial state: $_currentState');
      
      // Start listening for connectivity changes
      _subscription = _connectivity.onConnectivityChanged.listen(
        _handleConnectivityChange,
        onError: (error) {
          debugPrint('❌ ConnectivityMonitor: Stream error: $error');
        },
      );
      
      _isInitialized = true;
      debugPrint('✅ ConnectivityMonitor: Initialized successfully');
    } catch (e) {
      debugPrint('❌ ConnectivityMonitor: Initialization failed: $e');
      // Default to offline on error
      _currentState = ConnectivityState.offline;
      _isInitialized = true;
    }
  }

  /// Handle connectivity change events
  void _handleConnectivityChange(ConnectivityResult result) {
    final newState = _mapConnectivityResult(result);
    
    if (newState != _currentState) {
      final previousState = _currentState;
      _currentState = newState;
      _stateController.add(newState);
      debugPrint(
        '🔄 ConnectivityMonitor: State changed from $previousState to $newState',
      );
    }
  }

  /// Map connectivity_plus result to our ConnectivityState enum
  /// 
  /// Requirements: 5.4 - Distinguish between WiFi and mobile data
  ConnectivityState _mapConnectivityResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return ConnectivityState.wifi;
      case ConnectivityResult.mobile:
        return ConnectivityState.mobile;
      case ConnectivityResult.ethernet:
        return ConnectivityState.ethernet;
      case ConnectivityResult.none:
        return ConnectivityState.offline;
      default:
        // For other connection types (VPN, bluetooth, etc.), treat as mobile
        return ConnectivityState.mobile;
    }
  }

  /// Stream of connectivity state changes
  /// 
  /// Emits a new state whenever connectivity changes
  /// Requirements: 5.1
  Stream<ConnectivityState> get connectivityStream => _stateController.stream;

  /// Get current connectivity state
  /// 
  /// Returns the cached state if initialized, otherwise checks connectivity
  Future<ConnectivityState> get currentState async {
    if (!_isInitialized) {
      await initialize();
    }
    return _currentState;
  }

  /// Get current connectivity state synchronously
  /// 
  /// Returns the cached state (may be stale if not initialized)
  ConnectivityState get currentStateSync => _currentState;

  /// Check if currently online (any connection type)
  /// 
  /// Requirements: 5.1
  Future<bool> get isOnline async {
    final state = await currentState;
    return state != ConnectivityState.offline;
  }

  /// Check if currently online synchronously
  /// 
  /// Uses cached state (may be stale if not initialized)
  bool get isOnlineSync => _currentState != ConnectivityState.offline;

  /// Check if connected via WiFi
  /// 
  /// Requirements: 5.4
  bool get isWifi => _currentState == ConnectivityState.wifi;

  /// Check if connected via mobile data
  /// 
  /// Requirements: 5.4
  bool get isMobile => _currentState == ConnectivityState.mobile;

  /// Check if connected via ethernet
  bool get isEthernet => _currentState == ConnectivityState.ethernet;

  /// Force a connectivity check and update state
  /// 
  /// Useful when you need to ensure the state is current
  Future<ConnectivityState> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final newState = _mapConnectivityResult(result);
      
      if (newState != _currentState) {
        _currentState = newState;
        _stateController.add(newState);
      }
      
      return _currentState;
    } catch (e) {
      debugPrint('❌ ConnectivityMonitor: Check connectivity failed: $e');
      return _currentState;
    }
  }

  /// Dispose resources and stop listening for changes
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _stateController.close();
    _isInitialized = false;
    debugPrint('✅ ConnectivityMonitor: Disposed');
  }
}
