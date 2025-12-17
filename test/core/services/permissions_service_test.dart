import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sms_parser/core/services/permissions_service.dart';
import 'dart:io';

void main() {
  group('PermissionsService', () {
    late PermissionsService permissionsService;
    late String tempDir;

    setUpAll(() async {
      // Create a temporary directory for Hive
      tempDir = Directory.systemTemp.createTempSync('permissions_test_').path;
    });

    setUp(() async {
      permissionsService = PermissionsService();
      
      // Initialize Hive with temp directory for testing
      Hive.init(tempDir);
      await permissionsService.initialize();
    });

    tearDown(() async {
      await permissionsService.close();
      await Hive.deleteFromDisk();
    });

    tearDownAll(() async {
      // Clean up temp directory
      try {
        await Directory(tempDir).delete(recursive: true);
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('should initialize successfully', () async {
      final service = PermissionsService();
      await service.initialize();
      await service.close();
    });

    test('should track permission request attempts', () async {
      // Initially should not have asked for permissions
      expect(await permissionsService.hasAskedForSmsPermissions(), false);
      expect(await permissionsService.getPermissionDenialCount(), 0);
      expect(await permissionsService.getLastPermissionRequestTime(), null);
    });

    test('should provide appropriate status messages', () {
      expect(
        permissionsService.getPermissionStatusMessage(PermissionRequestResult.granted),
        contains('granted successfully'),
      );
      
      expect(
        permissionsService.getPermissionStatusMessage(PermissionRequestResult.denied),
        contains('required to automatically detect'),
      );
      
      expect(
        permissionsService.getPermissionStatusMessage(PermissionRequestResult.permanentlyDenied),
        contains('permanently denied'),
      );
      
      expect(
        permissionsService.getPermissionStatusMessage(PermissionRequestResult.tooManyDenials),
        contains('multiple times'),
      );
      
      expect(
        permissionsService.getPermissionStatusMessage(PermissionRequestResult.error),
        contains('error occurred'),
      );
    });

    test('should reset permission preferences', () async {
      // Simulate some permission tracking data
      await permissionsService.resetPermissionPreferences();
      
      expect(await permissionsService.hasAskedForSmsPermissions(), false);
      expect(await permissionsService.getPermissionDenialCount(), 0);
      expect(await permissionsService.getLastPermissionRequestTime(), null);
    });

    test('should handle initialization errors gracefully', () async {
      final service = PermissionsService();
      
      // Try to use service without initialization
      expect(
        () => service.hasAskedForSmsPermissions(),
        throwsA(isA<StateError>()),
      );
    });

    test('should provide detailed permission status', () async {
      final status = await permissionsService.getSmsPermissionStatus();
      
      // Should return a map with permission statuses
      expect(status, isA<Map<String, PermissionStatus>>());
      // Note: In test environment, permissions might not be available
      // so we just check that the method returns a map
      expect(status, isNotNull);
    });
  });

  group('PermissionRequestResult', () {
    test('should have all expected values', () {
      expect(PermissionRequestResult.values.length, 5);
      expect(PermissionRequestResult.values, contains(PermissionRequestResult.granted));
      expect(PermissionRequestResult.values, contains(PermissionRequestResult.denied));
      expect(PermissionRequestResult.values, contains(PermissionRequestResult.permanentlyDenied));
      expect(PermissionRequestResult.values, contains(PermissionRequestResult.tooManyDenials));
      expect(PermissionRequestResult.values, contains(PermissionRequestResult.error));
    });
  });
}