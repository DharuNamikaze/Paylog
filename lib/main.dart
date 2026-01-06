import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Conditional imports - only import if services are available
import 'core/services/service_locator.dart';
import 'core/routes/app_routes.dart';
import 'core/services/background_sms_service.dart';
import 'core/services/cloud_sync_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/bloc/sms_bloc.dart';
import 'presentation/bloc/transaction_bloc.dart';
import 'presentation/bloc/sync_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize core services with error handling
  bool servicesInitialized = false;
  
  try {
    // Initialize Firebase
    debugPrint('🔄 Initializing Firebase...');
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized successfully');
    
    // Initialize Hive
    await Hive.initFlutter();
    debugPrint('✅ Hive initialized successfully');
    
    // Ensure clean state
    debugPrint('🔄 Resetting service locator...');
    await serviceLocator.reset();
    debugPrint('✅ Service locator reset complete');
    
    // Initialize service locator and all dependencies (with Firebase)
    debugPrint('🔄 Starting service locator initialization...');
    await serviceLocator.initialize();
    debugPrint('✅ Service locator initialized successfully (with Firebase)');
    
    servicesInitialized = true;
    
    // Start background SMS monitoring
    _startBackgroundMonitoring();
  } catch (e, stackTrace) {
    debugPrint('❌ Firebase initialization failed: $e');
    debugPrint('Stack trace: $stackTrace');
    
    // Fallback to local-only mode
    try {
      debugPrint('🔄 Falling back to local-only mode...');
      
      // Initialize Hive
      await Hive.initFlutter();
      debugPrint('✅ Hive initialized successfully');
      
      // Ensure clean state
      debugPrint('🔄 Resetting service locator...');
      await serviceLocator.reset();
      debugPrint('✅ Service locator reset complete');
      
      // Initialize service locator without Firebase
      debugPrint('🔄 Starting service locator initialization (local-only)...');
      await serviceLocator.initializeWithoutFirebase();
      debugPrint('✅ Service locator initialized successfully (local-only mode)');
      
      servicesInitialized = true;
      
      // Start background SMS monitoring
      _startBackgroundMonitoring();
    } catch (fallbackError) {
      debugPrint('❌ Fallback initialization also failed: $fallbackError');
      servicesInitialized = false;
    }
  }
  
  runApp(MyApp(servicesInitialized: servicesInitialized));
}

/// Start background SMS monitoring service
/// 
/// This ensures SMS monitoring continues even when the app is closed
Future<void> _startBackgroundMonitoring() async {
  try {
    debugPrint('🔄 Starting background SMS monitoring...');
    
    // Start the background service
    final started = await BackgroundSmsService.startBackgroundMonitoring();
    
    if (started) {
      debugPrint('✅ Background SMS monitoring started successfully');
      
      // Request battery optimization exemption for better reliability
      final batteryOptimized = await BackgroundSmsService.isBatteryOptimizationIgnored();
      if (!batteryOptimized) {
        debugPrint('⚠️ Battery optimization not ignored - requesting exemption');
        await BackgroundSmsService.requestBatteryOptimizationExemption();
      } else {
        debugPrint('✅ Battery optimization already ignored');
      }
    } else {
      debugPrint('❌ Failed to start background SMS monitoring');
    }
  } catch (e) {
    debugPrint('❌ Error starting background SMS monitoring: $e');
  }
}

class MyApp extends StatefulWidget {
  final bool servicesInitialized;
  
  const MyApp({super.key, required this.servicesInitialized});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Register as lifecycle observer to trigger sync on app resume
    // Requirements: 1.3
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Trigger sync when app resumes from background
    // Requirements: 1.3
    if (state == AppLifecycleState.resumed && widget.servicesInitialized) {
      debugPrint('🔄 App resumed from background - triggering sync');
      _triggerSyncOnResume();
    }
  }

  /// Trigger sync when app resumes from background
  /// 
  /// Requirements: 1.3
  Future<void> _triggerSyncOnResume() async {
    try {
      if (serviceLocator.isRegistered<CloudSyncService>()) {
        final cloudSyncService = serviceLocator.get<CloudSyncService>();
        await cloudSyncService.onAppResume();
      }
    } catch (e) {
      debugPrint('⚠️ Failed to trigger sync on resume: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.servicesInitialized) {
      // Fallback to simple app if services failed to initialize
      return MaterialApp(
        title: 'PayLog',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const ServiceErrorPage(),
        debugShowCheckedModeBanner: false,
      );
    }

    // Full app with all services
    final providers = <BlocProvider>[];
    
    // Try to create Transaction BLoC (should always work)
    try {
      providers.add(
        BlocProvider<TransactionBloc>(
          create: (context) => serviceLocator.createTransactionBloc(),
        ),
      );
      debugPrint('✅ TransactionBloc created successfully');
    } catch (e) {
      debugPrint('❌ Failed to create TransactionBloc: $e');
    }
    
    // Try to create SMS BLoC (might fail if SMS service is not available)
    try {
      providers.add(
        BlocProvider<SmsBloc>(
          create: (context) => serviceLocator.createSmsBloc(),
        ),
      );
      debugPrint('✅ SmsBloc created successfully');
    } catch (e) {
      debugPrint('⚠️ Failed to create SmsBloc: $e');
      debugPrint('⚠️ SMS functionality will be limited');
    }

    // Try to create Sync BLoC (for cloud sync status)
    try {
      providers.add(
        BlocProvider<SyncBloc>(
          create: (context) {
            final bloc = serviceLocator.createSyncBloc();
            // Start sync monitoring immediately
            bloc.add(SyncStarted());
            return bloc;
          },
        ),
      );
      debugPrint('✅ SyncBloc created successfully');
    } catch (e) {
      debugPrint('⚠️ Failed to create SyncBloc: $e');
      debugPrint('⚠️ Cloud sync functionality will be limited');
    }

    return MultiBlocProvider(
      providers: providers,
      child: MaterialApp(
        title: 'PayLog',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        // Set up routing
        initialRoute: AppRoutes.dashboard,
        onGenerateRoute: AppRouteGenerator.generateRoute,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class ServiceErrorPage extends StatelessWidget {
  const ServiceErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PayLog'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 64,
                color: AppTheme.warningOrange,
              ),
              const SizedBox(height: 16),
              Text(
                'Service Initialization Error',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Some services failed to initialize:',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('• Check console logs for detailed error messages'),
                      const Text('• Ensure all dependencies are properly installed'),
                      const Text('• Verify Firebase configuration (if using)'),
                      const Text('• Check device permissions'),
                      const SizedBox(height: 16),
                      Text(
                        'The app is running in safe mode with limited functionality.',
                        style: TextStyle(
                          color: AppTheme.warningOrange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // Restart the app
                      main();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Show debug info
                      _showDebugInfo(context);
                    },
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Debug Info'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDebugInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Information'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Check the console output for detailed error messages.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('Common issues:'),
              SizedBox(height: 8),
              Text('1. Missing Firebase configuration'),
              Text('2. Dependency version conflicts'),
              Text('3. Android SDK/NDK version issues'),
              Text('4. Permission configuration problems'),
              SizedBox(height: 12),
              Text(
                'The app will work in basic mode until these issues are resolved.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

