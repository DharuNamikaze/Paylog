import 'package:flutter/services.dart';
import 'dart:developer' as developer;

/// Service to manage background SMS monitoring
/// 
/// This service communicates with the native Android background service
/// to ensure SMS monitoring continues even when the app is closed.
class BackgroundSmsService {
  static const MethodChannel _channel = MethodChannel('flutter_sms_parser/methods');
  
  /// Start background SMS monitoring service
  /// 
  /// This will start a foreground service that keeps SMS monitoring active
  /// even when the app is not in the foreground.
  static Future<bool> startBackgroundMonitoring() async {
    try {
      developer.log('Starting background SMS monitoring service', name: 'BackgroundSmsService');
      
      final result = await _channel.invokeMethod('startBackgroundService');
      
      if (result == true) {
        developer.log('Background SMS monitoring started successfully', name: 'BackgroundSmsService');
        return true;
      } else {
        developer.log('Failed to start background SMS monitoring', name: 'BackgroundSmsService');
        return false;
      }
    } catch (e) {
      developer.log('Error starting background SMS monitoring: $e', name: 'BackgroundSmsService', error: e);
      return false;
    }
  }
  
  /// Stop background SMS monitoring service
  static Future<bool> stopBackgroundMonitoring() async {
    try {
      developer.log('Stopping background SMS monitoring service', name: 'BackgroundSmsService');
      
      final result = await _channel.invokeMethod('stopBackgroundService');
      
      if (result == true) {
        developer.log('Background SMS monitoring stopped successfully', name: 'BackgroundSmsService');
        return true;
      } else {
        developer.log('Failed to stop background SMS monitoring', name: 'BackgroundSmsService');
        return false;
      }
    } catch (e) {
      developer.log('Error stopping background SMS monitoring: $e', name: 'BackgroundSmsService', error: e);
      return false;
    }
  }
  
  /// Check if background monitoring is active
  static Future<bool> isBackgroundMonitoringActive() async {
    try {
      final result = await _channel.invokeMethod('isBackgroundServiceRunning');
      return result == true;
    } catch (e) {
      developer.log('Error checking background monitoring status: $e', name: 'BackgroundSmsService', error: e);
      return false;
    }
  }
  
  /// Request battery optimization exemption
  /// 
  /// This is important for ensuring the background service isn't killed
  /// by Android's battery optimization.
  static Future<bool> requestBatteryOptimizationExemption() async {
    try {
      developer.log('Requesting battery optimization exemption', name: 'BackgroundSmsService');
      
      final result = await _channel.invokeMethod('requestBatteryOptimizationExemption');
      
      if (result == true) {
        developer.log('Battery optimization exemption granted', name: 'BackgroundSmsService');
        return true;
      } else {
        developer.log('Battery optimization exemption denied', name: 'BackgroundSmsService');
        return false;
      }
    } catch (e) {
      developer.log('Error requesting battery optimization exemption: $e', name: 'BackgroundSmsService', error: e);
      return false;
    }
  }
  
  /// Check if battery optimization is ignored for this app
  static Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final result = await _channel.invokeMethod('isBatteryOptimizationIgnored');
      return result == true;
    } catch (e) {
      developer.log('Error checking battery optimization status: $e', name: 'BackgroundSmsService', error: e);
      return false;
    }
  }
  
  /// Get device manufacturer information for battery optimization guidance
  static Future<DeviceInfo> getDeviceInfo() async {
    try {
      final result = await _channel.invokeMethod('getDeviceManufacturer');
      if (result is Map) {
        return DeviceInfo(
          manufacturer: result['manufacturer'] as String? ?? 'Unknown',
          model: result['model'] as String? ?? 'Unknown',
          brand: result['brand'] as String? ?? 'Unknown',
        );
      }
      return DeviceInfo.unknown();
    } catch (e) {
      developer.log('Error getting device info: $e', name: 'BackgroundSmsService', error: e);
      return DeviceInfo.unknown();
    }
  }
}

/// Device information for manufacturer-specific guidance
class DeviceInfo {
  final String manufacturer;
  final String model;
  final String brand;
  
  const DeviceInfo({
    required this.manufacturer,
    required this.model,
    required this.brand,
  });
  
  factory DeviceInfo.unknown() => const DeviceInfo(
    manufacturer: 'Unknown',
    model: 'Unknown',
    brand: 'Unknown',
  );
  
  /// Get manufacturer-specific battery optimization instructions
  String? getBatteryOptimizationInstructions() {
    final mfr = manufacturer.toLowerCase();
    
    if (mfr.contains('samsung')) {
      return '''Samsung devices have aggressive battery optimization.

1. Go to Settings → Apps → PayLog
2. Tap "Battery" → Select "Unrestricted"
3. Go to Settings → Battery → Background usage limits
4. Remove PayLog from "Sleeping apps" and "Deep sleeping apps"
5. Go to Settings → Device care → Battery → App power management
6. Disable "Put unused apps to sleep"''';
    }
    
    if (mfr.contains('xiaomi') || mfr.contains('redmi') || mfr.contains('poco')) {
      return '''Xiaomi/Redmi/POCO devices require additional settings.

1. Go to Settings → Apps → Manage apps → PayLog
2. Enable "Autostart"
3. Tap "Battery saver" → Select "No restrictions"
4. Go to Settings → Battery & performance → App battery saver
5. Select PayLog → Choose "No restrictions"
6. Lock the app in recent apps (swipe down on the app card)''';
    }
    
    if (mfr.contains('huawei') || mfr.contains('honor')) {
      return '''Huawei/Honor devices have strict power management.

1. Go to Settings → Apps → Apps → PayLog
2. Tap "Battery" → Enable "Launch manually" and all toggles
3. Go to Settings → Battery → App launch
4. Find PayLog → Disable "Manage automatically"
5. Enable all three toggles: Auto-launch, Secondary launch, Run in background
6. Lock the app in recent apps''';
    }
    
    if (mfr.contains('oneplus') || mfr.contains('oppo') || mfr.contains('realme')) {
      return '''OnePlus/OPPO/Realme devices need battery optimization disabled.

1. Go to Settings → Apps → App management → PayLog
2. Tap "Battery usage" → Enable "Allow background activity"
3. Go to Settings → Battery → Battery optimization
4. Find PayLog → Select "Don't optimize"
5. For OnePlus: Settings → Battery → Battery optimization → PayLog → Don't optimize''';
    }
    
    if (mfr.contains('vivo')) {
      return '''Vivo devices require autostart and background permissions.

1. Go to Settings → Apps → Autostart → Enable PayLog
2. Go to Settings → Battery → Background power consumption
3. Find PayLog → Enable "Allow background running"
4. Go to Settings → Battery → High background power consumption
5. Allow PayLog to run in background''';
    }
    
    if (mfr.contains('asus')) {
      return '''ASUS devices have Auto-start Manager.

1. Go to Settings → Apps → Auto-start Manager
2. Enable PayLog
3. Go to Settings → Battery → PowerMaster
4. Disable battery optimization for PayLog''';
    }
    
    if (mfr.contains('nokia')) {
      return '''Nokia devices use stock Android with Evenwell.

1. Go to Settings → Apps → PayLog → Battery
2. Select "Unrestricted"
3. Go to Settings → Battery → Adaptive Battery
4. Disable or add PayLog to exceptions''';
    }
    
    // Generic Android instructions
    return '''To ensure reliable SMS monitoring:

1. Go to Settings → Apps → PayLog → Battery
2. Select "Unrestricted" or "Don't optimize"
3. Disable any battery saver or power management for PayLog
4. Lock the app in recent apps if your device supports it''';
  }
}
