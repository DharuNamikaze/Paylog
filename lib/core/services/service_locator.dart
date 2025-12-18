import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../data/datasources/sms_platform_channel.dart';
import '../../data/datasources/local_storage_datasource.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../data/repositories/local_transaction_repository.dart';
import '../../data/services/sms_listener_service.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/usecases/detect_financial_context.dart';
import '../../domain/usecases/parse_sms_transaction.dart';
import '../../domain/usecases/validate_transaction.dart';
import '../../domain/usecases/sync_offline_queue.dart';
import '../../core/utils/duplicate_detector.dart';
import '../../core/services/permissions_service.dart';
import '../../presentation/bloc/sms_bloc.dart';
import '../../presentation/bloc/transaction_bloc.dart';

/// Simple service locator for dependency injection
/// 
/// This class manages the creation and lifecycle of all services,
/// repositories, and use cases in the application.
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  final Map<Type, dynamic> _services = {};
  bool _isInitialized = false;

  /// Initialize all services and dependencies
  /// 
  /// This must be called before accessing any services
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize core services
    await _initializeCoreServices();
    
    // Initialize data sources
    await _initializeDataSources();
    
    // Initialize repositories
    _initializeRepositories();
    
    // Initialize use cases
    _initializeUseCases();
    
    // Initialize application services
    await _initializeApplicationServices();

    _isInitialized = true;
  }

  /// Initialize services without Firebase (for testing or when Firebase is not configured)
  /// 
  /// This initializes all services except those that depend on Firebase
  Future<void> initializeWithoutFirebase() async {
    if (_isInitialized) return;

    // Initialize core services without Firebase
    await _initializeCoreServicesWithoutFirebase();
    
    // Initialize data sources
    await _initializeDataSources();
    
    // Initialize repositories without Firebase
    _initializeRepositoriesWithoutFirebase();
    
    // Initialize use cases without Firebase
    _initializeUseCasesWithoutFirebase();
    
    // Initialize application services without Firebase
    await _initializeApplicationServicesWithoutFirebase();

    _isInitialized = true;
  }

  /// Initialize core services (Firebase, Hive, etc.)
  Future<void> _initializeCoreServices() async {
    // Firebase is already initialized in main.dart
    
    // Initialize Hive (already done in main.dart, but ensure it's ready)
    if (!Hive.isBoxOpen('transactions')) {
      // Hive boxes will be opened by LocalStorageDataSource when needed
    }

    // Register UUID generator
    _services[Uuid] = const Uuid();
  }

  /// Initialize data sources
  Future<void> _initializeDataSources() async {
    // SMS Platform Channel
    _services[SmsPlatformChannel] = SmsPlatformChannel();
    
    // Local Storage Data Source
    final localStorage = LocalStorageDataSource();
    await localStorage.initialize();
    _services[LocalStorageDataSource] = localStorage;
  }

  /// Initialize repositories
  void _initializeRepositories() {
    // Initialize local storage first
    final localStorage = _services[LocalStorageDataSource] as LocalStorageDataSource;
    
    // For now, use local-only mode to avoid Firebase permission issues
    debugPrint('🔄 Initializing in local-only mode to avoid Firebase permission issues');
    _services[TransactionRepository] = LocalTransactionRepository(
      localStorage: localStorage,
      uuid: _services[Uuid] as Uuid,
    );
    debugPrint('✅ TransactionRepository initialized in local-only mode');
  }

  /// Initialize use cases
  void _initializeUseCases() {
    // Financial Context Detector
    _services[FinancialContextDetector] = FinancialContextDetector();
    
    // SMS Parser
    _services[ParseSmsTransaction] = ParseSmsTransaction();
    
    // Transaction Validator
    _services[ValidateTransaction] = ValidateTransaction();
    
    // Offline Queue Sync - only if we have TransactionRepositoryImpl
    final repository = _services[TransactionRepository];
    if (repository is TransactionRepositoryImpl) {
      _services[SyncOfflineQueue] = SyncOfflineQueue(
        localStorage: _services[LocalStorageDataSource] as LocalStorageDataSource,
        repository: repository,
      );
    } else {
      debugPrint('⚠️ Skipping SyncOfflineQueue - using LocalTransactionRepository (no sync needed)');
    }
    
    // Duplicate Detector
    _services[DuplicateDetector] = DuplicateDetector();
    
    // Permissions Service
    _services[PermissionsService] = PermissionsService();
  }

  /// Initialize use cases without Firebase dependencies
  void _initializeUseCasesWithoutFirebase() {
    // Financial Context Detector
    _services[FinancialContextDetector] = FinancialContextDetector();
    
    // SMS Parser
    _services[ParseSmsTransaction] = ParseSmsTransaction();
    
    // Transaction Validator
    _services[ValidateTransaction] = ValidateTransaction();
    
    // Skip Offline Queue Sync for now (it depends on Firebase repository)
    // We'll implement a local-only version later if needed
    
    // Duplicate Detector
    _services[DuplicateDetector] = DuplicateDetector();
    
    // Permissions Service
    _services[PermissionsService] = PermissionsService();
  }

  /// Initialize application services
  Future<void> _initializeApplicationServices() async {
    // SMS Listener Service
    final smsListenerService = SmsListenerService(
      smsChannel: _services[SmsPlatformChannel] as SmsPlatformChannel,
      financialDetector: _services[FinancialContextDetector] as FinancialContextDetector,
      smsParser: _services[ParseSmsTransaction] as ParseSmsTransaction,
      validator: _services[ValidateTransaction] as ValidateTransaction,
      repository: _services[TransactionRepository] as TransactionRepository,
      duplicateDetector: _services[DuplicateDetector] as DuplicateDetector,
      uuid: _services[Uuid] as Uuid,
    );
    
    // Initialize the SMS listener service
    await smsListenerService.initialize();
    
    _services[SmsListenerService] = smsListenerService;
  }

  /// Initialize core services without Firebase
  Future<void> _initializeCoreServicesWithoutFirebase() async {
    // Skip Firebase initialization
    
    // Initialize Hive (already done in main.dart, but ensure it's ready)
    if (!Hive.isBoxOpen('transactions')) {
      // Hive boxes will be opened by LocalStorageDataSource when needed
    }

    // Register UUID generator
    _services[Uuid] = const Uuid();
  }

  /// Initialize repositories without Firebase (use local storage only)
  void _initializeRepositoriesWithoutFirebase() {
    // Create a mock transaction repository that uses local storage only
    _services[TransactionRepository] = LocalTransactionRepository(
      localStorage: _services[LocalStorageDataSource] as LocalStorageDataSource,
      uuid: _services[Uuid] as Uuid,
    );
  }

  /// Initialize application services without Firebase
  Future<void> _initializeApplicationServicesWithoutFirebase() async {
    // Create SMS Listener Service with local repository
    try {
      final smsListenerService = SmsListenerService(
        smsChannel: _services[SmsPlatformChannel] as SmsPlatformChannel,
        financialDetector: _services[FinancialContextDetector] as FinancialContextDetector,
        smsParser: _services[ParseSmsTransaction] as ParseSmsTransaction,
        validator: _services[ValidateTransaction] as ValidateTransaction,
        repository: _services[TransactionRepository] as TransactionRepository,
        duplicateDetector: _services[DuplicateDetector] as DuplicateDetector,
        uuid: _services[Uuid] as Uuid,
      );
      
      // Initialize the SMS listener service
      await smsListenerService.initialize();
      
      _services[SmsListenerService] = smsListenerService;
      debugPrint('✅ SMS Listener Service initialized successfully (local mode)');
    } catch (e) {
      debugPrint('⚠️ Failed to initialize SMS Listener Service: $e');
      // Don't set to null, just don't register it
      debugPrint('⚠️ SMS functionality will be limited');
    }
  }

  /// Get a service instance by type
  T get<T>() {
    if (!_isInitialized) {
      throw StateError('ServiceLocator must be initialized before use');
    }
    
    final service = _services[T];
    if (service == null) {
      throw StateError('Service of type $T is not registered');
    }
    
    return service as T;
  }

  /// Create BLoCs with dependencies
  /// 
  /// BLoCs are created fresh each time to avoid state issues
  SmsBloc createSmsBloc() {
    final smsService = _services[SmsListenerService];
    if (smsService == null) {
      throw StateError('SmsListenerService is not available. Check service initialization.');
    }
    return SmsBloc(
      smsListenerService: smsService as SmsListenerService,
    );
  }

  TransactionBloc createTransactionBloc() {
    final repository = _services[TransactionRepository];
    if (repository == null) {
      throw StateError('TransactionRepository is not available. Check service initialization.');
    }
    return TransactionBloc(
      transactionRepository: repository as TransactionRepository,
    );
  }

  /// Check if a service is registered
  bool isRegistered<T>() {
    return _services.containsKey(T);
  }

  /// Register a service manually (for testing or special cases)
  void register<T>(T service) {
    _services[T] = service;
  }

  /// Unregister a service
  void unregister<T>() {
    _services.remove(T);
  }

  /// Dispose all services and clean up resources
  Future<void> dispose() async {
    // Only dispose if initialized
    if (!_isInitialized) {
      debugPrint('⚠️ ServiceLocator not initialized, skipping dispose');
      return;
    }
    
    try {
      // Dispose SMS Listener Service
      if (_services.containsKey(SmsListenerService)) {
        final service = _services[SmsListenerService] as SmsListenerService?;
        if (service != null) {
          await service.dispose();
        }
      }
      
      // Dispose Duplicate Detector
      if (_services.containsKey(DuplicateDetector)) {
        final detector = _services[DuplicateDetector] as DuplicateDetector?;
        if (detector != null) {
          await detector.close();
        }
      }
      
      // Dispose SMS Platform Channel
      if (_services.containsKey(SmsPlatformChannel)) {
        final channel = _services[SmsPlatformChannel] as SmsPlatformChannel?;
        if (channel != null) {
          channel.dispose();
        }
      }
      
      // Close Hive boxes (only if they're open)
      try {
        if (Hive.isBoxOpen('transactions')) {
          await Hive.box('transactions').close();
        }
        if (Hive.isBoxOpen('queue')) {
          await Hive.box('queue').close();
        }
      } catch (e) {
        debugPrint('⚠️ Error closing Hive boxes: $e');
      }
      
    } catch (e) {
      debugPrint('⚠️ Error during service disposal: $e');
    } finally {
      _services.clear();
      _isInitialized = false;
    }
  }

  /// Reset the service locator (for testing)
  Future<void> reset() async {
    if (_isInitialized) {
      await dispose();
    } else {
      // If not initialized, just clear everything
      _services.clear();
      _isInitialized = false;
    }
  }
}

/// Global service locator instance
final serviceLocator = ServiceLocator();