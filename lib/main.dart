import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Conditional imports - only import if services are available
import 'core/services/service_locator.dart';
import 'core/routes/app_routes.dart';
import 'presentation/bloc/sms_bloc.dart';
import 'presentation/bloc/transaction_bloc.dart';

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
    } catch (fallbackError) {
      debugPrint('❌ Fallback initialization also failed: $fallbackError');
      servicesInitialized = false;
    }
  }
  
  runApp(MyApp(servicesInitialized: servicesInitialized));
}

class MyApp extends StatelessWidget {
  final bool servicesInitialized;
  
  const MyApp({super.key, required this.servicesInitialized});

  @override
  Widget build(BuildContext context) {
    if (!servicesInitialized) {
      // Fallback to simple app if services failed to initialize
      return MaterialApp(
        title: 'SMS Transaction Parser',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
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

    return MultiBlocProvider(
      providers: providers,
      child: MaterialApp(
        title: 'SMS Transaction Parser',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
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
        title: const Text('SMS Transaction Parser'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 64,
                color: Colors.orange,
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
                          color: Colors.orange.shade700,
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

