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
}
