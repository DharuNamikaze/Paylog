import 'dart:developer' as developer;

import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Service for managing SMS permissions and user preferences
class PermissionsService {
  static const String _preferencesBoxName = 'permissions_preferences';
  static const String _smsPermissionAskedKey = 'sms_permission_asked';
  static const String _smsPermissionDeniedCountKey = 'sms_permission_denied_count';
  static const String _lastPermissionRequestKey = 'last_permission_request';
  
  Box<dynamic>? _preferencesBox;
  
  /// Initialize the permissions service
  Future<void> initialize() async {
    try {
      _preferencesBox = await Hive.openBox(_preferencesBoxName);
      developer.log('PermissionsService initialized successfully', name: 'PermissionsService');
    } catch (e) {
      developer.log(
        'Error initializing PermissionsService: $e',
        name: 'PermissionsService',
        error: e,
      );
      rethrow;
    }
  }
  
  /// Check if SMS permissions are granted
  Future<bool> hasSmsPermissions() async {
    try {
      final smsPermission = await Permission.sms.status;
      final receivePermission = await Permission.phone.status;
      
      final hasReadSms = smsPermission.isGranted;
      final hasReceiveSms = receivePermission.isGranted || receivePermission.isLimited;
      
      developer.log(
        'SMS permissions status - Read: $hasReadSms, Receive: $hasReceiveSms',
        name: 'PermissionsService',
      );
      
      return hasReadSms && hasReceiveSms;
    } catch (e) {
      developer.log(
        'Error checking SMS permissions: $e',
        name: 'PermissionsService',
        error: e,
      );
      return false;
    }
  }
  
  /// Get detailed permission status for SMS-related permissions
  Future<Map<String, PermissionStatus>> getSmsPermissionStatus() async {
    try {
      final permissions = {
        'sms': await Permission.sms.status,
        'phone': await Permission.phone.status,
      };
      
      developer.log(
        'Detailed SMS permission status: $permissions',
        name: 'PermissionsService',
      );
      
      return permissions;
    } catch (e) {
      developer.log(
        'Error getting detailed SMS permission status: $e',
        name: 'PermissionsService',
        error: e,
      );
      return {};
    }
  }
  
  /// Request SMS permissions from the user
  Future<PermissionRequestResult> requestSmsPermissions() async {
    _ensureInitialized();
    
    try {
      // Check if we should ask for permissions based on user preferences
      if (!_shouldRequestPermissions()) {
        return PermissionRequestResult.tooManyDenials;
      }
      
      // Update request tracking
      await _updatePermissionRequestTracking();
      
      // Request permissions
      final permissions = await [
        Permission.sms,
        Permission.phone,
      ].request();
      
      final smsGranted = permissions[Permission.sms]?.isGranted ?? false;
      final phoneGranted = permissions[Permission.phone]?.isGranted ?? false;
      
      developer.log(
        'Permission request result - SMS: $smsGranted, Phone: $phoneGranted',
        name: 'PermissionsService',
      );
      
      if (smsGranted && phoneGranted) {
        await _resetDenialCount();
        return PermissionRequestResult.granted;
      } else if (permissions[Permission.sms]?.isPermanentlyDenied == true ||
                 permissions[Permission.phone]?.isPermanentlyDenied == true) {
        await _incrementDenialCount();
        return PermissionRequestResult.permanentlyDenied;
      } else {
        await _incrementDenialCount();
        return PermissionRequestResult.denied;
      }
    } catch (e) {
      developer.log(
        'Error requesting SMS permissions: $e',
        name: 'PermissionsService',
        error: e,
      );
      return PermissionRequestResult.error;
    }
  }
  
  /// Check if any SMS permissions are permanently denied
  Future<bool> areSmsPermissionsPermanentlyDenied() async {
    try {
      final smsStatus = await Permission.sms.status;
      final phoneStatus = await Permission.phone.status;
      
      final isPermanentlyDenied = smsStatus.isPermanentlyDenied || phoneStatus.isPermanentlyDenied;
      
      developer.log(
        'SMS permissions permanently denied: $isPermanentlyDenied',
        name: 'PermissionsService',
      );
      
      return isPermanentlyDenied;
    } catch (e) {
      developer.log(
        'Error checking if SMS permissions are permanently denied: $e',
        name: 'PermissionsService',
        error: e,
      );
      return false;
    }
  }
  
  /// Open app settings for the user to manually grant permissions
  Future<bool> openPermissionSettings() async {
    try {
      final opened = await openAppSettings();
      developer.log(
        'App settings opened: $opened',
        name: 'PermissionsService',
      );
      return opened;
    } catch (e) {
      developer.log(
        'Error opening app settings: $e',
        name: 'PermissionsService',
        error: e,
      );
      return false;
    }
  }
  
  /// Check if we have asked for SMS permissions before
  Future<bool> hasAskedForSmsPermissions() async {
    _ensureInitialized();
    
    return _preferencesBox!.get(_smsPermissionAskedKey, defaultValue: false) as bool;
  }
  
  /// Get the number of times permissions have been denied
  Future<int> getPermissionDenialCount() async {
    _ensureInitialized();
    
    return _preferencesBox!.get(_smsPermissionDeniedCountKey, defaultValue: 0) as int;
  }
  
  /// Get the last time permissions were requested
  Future<DateTime?> getLastPermissionRequestTime() async {
    _ensureInitialized();
    
    final timestamp = _preferencesBox!.get(_lastPermissionRequestKey);
    if (timestamp != null && timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }
  
  /// Reset permission preferences (useful for testing or user reset)
  Future<void> resetPermissionPreferences() async {
    _ensureInitialized();
    
    await _preferencesBox!.delete(_smsPermissionAskedKey);
    await _preferencesBox!.delete(_smsPermissionDeniedCountKey);
    await _preferencesBox!.delete(_lastPermissionRequestKey);
    
    developer.log(
      'Permission preferences reset',
      name: 'PermissionsService',
    );
  }
  
  /// Get a user-friendly message based on permission status
  String getPermissionStatusMessage(PermissionRequestResult result) {
    switch (result) {
      case PermissionRequestResult.granted:
        return 'SMS permissions granted successfully. The app can now monitor your transaction messages.';
      case PermissionRequestResult.denied:
        return 'SMS permissions are required to automatically detect transaction messages. Please grant permissions to continue.';
      case PermissionRequestResult.permanentlyDenied:
        return 'SMS permissions have been permanently denied. Please go to Settings > Apps > Flutter SMS Parser > Permissions and enable SMS permissions manually.';
      case PermissionRequestResult.tooManyDenials:
        return 'You have denied SMS permissions multiple times. Please manually enable them in app settings if you want to use automatic transaction detection.';
      case PermissionRequestResult.error:
        return 'An error occurred while requesting permissions. Please try again or enable permissions manually in app settings.';
    }
  }
  
  /// Check if we should request permissions based on denial history
  bool _shouldRequestPermissions() {
    final denialCount = _preferencesBox!.get(_smsPermissionDeniedCountKey, defaultValue: 0) as int;
    final lastRequest = _preferencesBox!.get(_lastPermissionRequestKey);
    
    // Don't ask if denied more than 3 times
    if (denialCount >= 3) {
      return false;
    }
    
    // If denied recently (within 24 hours), don't ask again
    if (lastRequest != null && lastRequest is int) {
      final lastRequestTime = DateTime.fromMillisecondsSinceEpoch(lastRequest);
      final timeSinceLastRequest = DateTime.now().difference(lastRequestTime);
      
      if (timeSinceLastRequest.inHours < 24 && denialCount > 0) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Update tracking when permissions are requested
  Future<void> _updatePermissionRequestTracking() async {
    await _preferencesBox!.put(_smsPermissionAskedKey, true);
    await _preferencesBox!.put(_lastPermissionRequestKey, DateTime.now().millisecondsSinceEpoch);
  }
  
  /// Increment the denial count
  Future<void> _incrementDenialCount() async {
    final currentCount = _preferencesBox!.get(_smsPermissionDeniedCountKey, defaultValue: 0) as int;
    await _preferencesBox!.put(_smsPermissionDeniedCountKey, currentCount + 1);
  }
  
  /// Reset the denial count (when permissions are granted)
  Future<void> _resetDenialCount() async {
    await _preferencesBox!.put(_smsPermissionDeniedCountKey, 0);
  }
  
  /// Ensure the service is initialized before operations
  void _ensureInitialized() {
    if (_preferencesBox == null) {
      throw StateError(
        'PermissionsService not initialized. Call initialize() first.',
      );
    }
  }
  
  /// Close the preferences box
  Future<void> close() async {
    await _preferencesBox?.close();
  }
}

/// Result of a permission request operation
enum PermissionRequestResult {
  /// Permissions were granted
  granted,
  
  /// Permissions were denied but can be requested again
  denied,
  
  /// Permissions were permanently denied and require manual intervention
  permanentlyDenied,
  
  /// Too many denials, should not request again automatically
  tooManyDenials,
  
  /// An error occurred during the request
  error,
}
