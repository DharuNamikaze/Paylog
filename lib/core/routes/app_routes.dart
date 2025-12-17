import 'package:flutter/material.dart';
import '../../presentation/pages/dashboard_page.dart';
import '../../presentation/pages/transaction_detail_page.dart';
import '../../presentation/pages/manual_input_page.dart';
import '../../domain/entities/transaction.dart';

/// Application route names
class AppRoutes {
  static const String dashboard = '/';
  static const String transactionDetail = '/transaction-detail';
  static const String manualInput = '/manual-input';
}

/// Route generator for the application
class AppRouteGenerator {
  /// Generate routes based on route settings
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.dashboard:
        // Extract userId from arguments or use default
        final args = settings.arguments as Map<String, dynamic>?;
        final userId = args?['userId'] as String? ?? 'default_user';
        
        return MaterialPageRoute(
          builder: (context) => DashboardPage(userId: userId),
          settings: settings,
        );

      case AppRoutes.transactionDetail:
        // Extract transaction from arguments
        final args = settings.arguments as Map<String, dynamic>?;
        final transaction = args?['transaction'] as Transaction?;
        
        if (transaction == null) {
          return _errorRoute('Transaction not provided');
        }
        
        return MaterialPageRoute(
          builder: (context) => TransactionDetailPage(transaction: transaction),
          settings: settings,
        );

      case AppRoutes.manualInput:
        // Extract userId from arguments
        final args = settings.arguments as Map<String, dynamic>?;
        final userId = args?['userId'] as String?;
        
        if (userId == null) {
          return _errorRoute('User ID not provided');
        }
        
        return MaterialPageRoute(
          builder: (context) => ManualInputPage(userId: userId),
          settings: settings,
        );

      default:
        return _errorRoute('Route not found: ${settings.name}');
    }
  }

  /// Generate error route for unknown routes
  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Navigation Error',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.dashboard,
                    (route) => false,
                  );
                },
                child: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Navigation helper class for type-safe navigation
class AppNavigator {
  /// Navigate to dashboard
  static Future<void> toDashboard(
    BuildContext context, {
    String userId = 'default_user',
    bool clearStack = false,
  }) {
    if (clearStack) {
      return Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.dashboard,
        (route) => false,
        arguments: {'userId': userId},
      );
    } else {
      return Navigator.of(context).pushNamed(
        AppRoutes.dashboard,
        arguments: {'userId': userId},
      );
    }
  }

  /// Navigate to transaction detail
  static Future<void> toTransactionDetail(
    BuildContext context,
    Transaction transaction,
  ) {
    return Navigator.of(context).pushNamed(
      AppRoutes.transactionDetail,
      arguments: {'transaction': transaction},
    );
  }

  /// Navigate to manual input
  static Future<void> toManualInput(
    BuildContext context,
    String userId,
  ) {
    return Navigator.of(context).pushNamed(
      AppRoutes.manualInput,
      arguments: {'userId': userId},
    );
  }

  /// Go back to previous screen
  static void goBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // If can't pop, go to dashboard
      toDashboard(context, clearStack: true);
    }
  }

  /// Check if can go back
  static bool canGoBack(BuildContext context) {
    return Navigator.of(context).canPop();
  }
}