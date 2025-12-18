import 'package:paylog/core/services/permissions_service.dart';

/// Example demonstrating how to use the PermissionsService
void main() async {
  // Initialize the permissions service
  final permissionsService = PermissionsService();
  await permissionsService.initialize();

  try {
    // Check if SMS permissions are already granted
    final hasPermissions = await permissionsService.hasSmsPermissions();
    print('Has SMS permissions: $hasPermissions');

    if (!hasPermissions) {
      // Check if permissions were permanently denied
      final permanentlyDenied = await permissionsService.areSmsPermissionsPermanentlyDenied();
      
      if (permanentlyDenied) {
        print('Permissions permanently denied. Opening app settings...');
        await permissionsService.openPermissionSettings();
      } else {
        // Request permissions
        print('Requesting SMS permissions...');
        final result = await permissionsService.requestSmsPermissions();
        
        // Get user-friendly message
        final message = permissionsService.getPermissionStatusMessage(result);
        print('Permission result: $message');
        
        switch (result) {
          case PermissionRequestResult.granted:
            print('✅ Permissions granted! SMS monitoring can start.');
            break;
          case PermissionRequestResult.denied:
            print('❌ Permissions denied. User can try again.');
            break;
          case PermissionRequestResult.permanentlyDenied:
            print('🚫 Permissions permanently denied. Need manual intervention.');
            break;
          case PermissionRequestResult.tooManyDenials:
            print('⚠️ Too many denials. Should not ask again automatically.');
            break;
          case PermissionRequestResult.error:
            print('💥 Error occurred during permission request.');
            break;
        }
      }
    }

    // Get detailed permission status
    final detailedStatus = await permissionsService.getSmsPermissionStatus();
    print('Detailed permission status: $detailedStatus');

    // Check permission history
    final hasAsked = await permissionsService.hasAskedForSmsPermissions();
    final denialCount = await permissionsService.getPermissionDenialCount();
    final lastRequest = await permissionsService.getLastPermissionRequestTime();
    
    print('Permission history:');
    print('  - Has asked before: $hasAsked');
    print('  - Denial count: $denialCount');
    print('  - Last request: $lastRequest');

  } finally {
    // Clean up
    await permissionsService.close();
  }
}
