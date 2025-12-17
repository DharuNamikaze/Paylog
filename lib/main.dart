import 'package:flutter/material.dart';
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
    // Skip Firebase for now - we'll add it later when properly configured
    debugPrint('⚠️ Firebase initialization skipped - not configured yet');
    
    // Initialize Hive
    await Hive.initFlutter();
    debugPrint('✅ Hive initialized successfully');
    
    // Initialize service locator and all dependencies (without Firebase)
    await serviceLocator.initializeWithoutFirebase();
    debugPrint('✅ Service locator initialized successfully (without Firebase)');
    
    servicesInitialized = true;
  } catch (e) {
    debugPrint('❌ Service initialization failed: $e');
    servicesInitialized = false;
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
    return MultiBlocProvider(
      providers: [
        // SMS BLoC for managing SMS listening state
        BlocProvider<SmsBloc>(
          create: (context) => serviceLocator.createSmsBloc(),
        ),
        // Transaction BLoC for managing transaction data
        BlocProvider<TransactionBloc>(
          create: (context) => serviceLocator.createTransactionBloc(),
        ),
      ],
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

