import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/sms_listener_service.dart';
import '../../domain/entities/sms_message.dart';

// Events
abstract class SmsEvent {}

class StartSmsListening extends SmsEvent {}

class StopSmsListening extends SmsEvent {}

class SmsReceived extends SmsEvent {
  final SmsMessage message;

  SmsReceived(this.message);
}

class RequestSmsPermissions extends SmsEvent {}

// States
abstract class SmsState {}

class SmsInitial extends SmsState {}

class SmsListening extends SmsState {
  final DateTime startedAt;

  SmsListening({DateTime? startedAt})
      : startedAt = startedAt ?? DateTime.now();
}

class SmsPermissionDenied extends SmsState {
  final String message;

  SmsPermissionDenied({
    this.message = 'SMS permissions are required to monitor incoming messages',
  });
}

class SmsError extends SmsState {
  final String error;
  final SmsState? previousState;

  SmsError({
    required this.error,
    this.previousState,
  });
}

// BLoC
class SmsBloc extends Bloc<SmsEvent, SmsState> {
  final SmsListenerService _smsListenerService;
  StreamSubscription<SmsListenerEvent>? _serviceSubscription;

  SmsBloc({
    required SmsListenerService smsListenerService,
  })  : _smsListenerService = smsListenerService,
        super(SmsInitial()) {
    on<StartSmsListening>(_onStartSmsListening);
    on<StopSmsListening>(_onStopSmsListening);
    on<SmsReceived>(_onSmsReceived);
    on<RequestSmsPermissions>(_onRequestSmsPermissions);
  }

  Future<void> _onStartSmsListening(
    StartSmsListening event,
    Emitter<SmsState> emit,
  ) async {
    try {
      // Check if already listening
      if (_smsListenerService.isListening) {
        emit(SmsListening());
        return;
      }

      // Check permissions first
      final hasPermissions = await _smsListenerService.checkPermissions();
      if (!hasPermissions) {
        emit(SmsPermissionDenied());
        return;
      }

      // Cancel any existing subscription
      await _serviceSubscription?.cancel();

      // Subscribe to service events
      _serviceSubscription = _smsListenerService.eventStream.listen(
        (event) {
          if (!isClosed) {
            _handleServiceEvent(event);
          }
        },
        onError: (error) {
          if (!isClosed) {
            add(StopSmsListening());
            final currentState = state;
            emit(SmsError(
              error: 'SMS service error: ${error.toString()}',
              previousState: currentState,
            ));
          }
        },
      );

      // Start the SMS listener service with default user ID
      // In a real app, this would come from authentication
      await _smsListenerService.startListening('default_user');

      emit(SmsListening());
    } on SmsListenerException catch (e) {
      final currentState = state;
      
      // Check if it's a permission error
      if (e.message.toLowerCase().contains('permission')) {
        emit(SmsPermissionDenied(message: e.message));
      } else {
        emit(SmsError(
          error: 'Failed to start SMS listening: ${e.message}',
          previousState: currentState,
        ));
      }
    } catch (e) {
      final currentState = state;
      emit(SmsError(
        error: 'Failed to start SMS listening: ${e.toString()}',
        previousState: currentState,
      ));
    }
  }

  Future<void> _onStopSmsListening(
    StopSmsListening event,
    Emitter<SmsState> emit,
  ) async {
    try {
      // Cancel the service subscription
      await _serviceSubscription?.cancel();
      _serviceSubscription = null;

      // Stop the SMS listener service
      if (_smsListenerService.isListening) {
        await _smsListenerService.stopListening();
      }

      emit(SmsInitial());
    } on SmsListenerException catch (e) {
      final currentState = state;
      emit(SmsError(
        error: 'Failed to stop SMS listening: ${e.message}',
        previousState: currentState,
      ));
    } catch (e) {
      final currentState = state;
      emit(SmsError(
        error: 'Failed to stop SMS listening: ${e.toString()}',
        previousState: currentState,
      ));
    }
  }

  Future<void> _onSmsReceived(
    SmsReceived event,
    Emitter<SmsState> emit,
  ) async {
    // This event is triggered when an SMS is received
    // The actual processing of the SMS (parsing, validation, storage)
    // should be handled by other components/BLoCs
    // This BLoC only manages the SMS listening state
    
    // Keep the current listening state
    if (state is SmsListening) {
      emit(SmsListening(startedAt: (state as SmsListening).startedAt));
    }
  }

  Future<void> _onRequestSmsPermissions(
    RequestSmsPermissions event,
    Emitter<SmsState> emit,
  ) async {
    try {
      final granted = await _smsListenerService.requestPermissions();
      
      if (granted) {
        // Permissions granted, try to start listening
        add(StartSmsListening());
      } else {
        emit(SmsPermissionDenied(
          message: 'SMS permissions were denied by the user',
        ));
      }
    } on SmsListenerException catch (e) {
      final currentState = state;
      emit(SmsError(
        error: 'Failed to request SMS permissions: ${e.message}',
        previousState: currentState,
      ));
    } catch (e) {
      final currentState = state;
      emit(SmsError(
        error: 'Failed to request SMS permissions: ${e.toString()}',
        previousState: currentState,
      ));
    }
  }

  /// Handle events from the SMS Listener Service
  void _handleServiceEvent(SmsListenerEvent event) {
    // Use toString() to check event types since the concrete classes are private
    final eventType = event.toString();
    
    if (eventType.startsWith('ServiceStarted')) {
      // Service started successfully
      if (state is! SmsListening) {
        add(SmsReceived(SmsMessage(
          sender: 'system',
          content: 'SMS monitoring started',
          timestamp: DateTime.now(),
        )));
      }
    } else if (eventType.startsWith('ServiceStopped')) {
      // Service stopped - handled by stop event
    } else if (eventType.startsWith('ServiceError')) {
      // Service error
      final currentState = state;
      final errorMessage = eventType.contains('message:') 
          ? eventType.split('message: ')[1].replaceAll(')', '')
          : 'Unknown service error';
      
      // Don't emit directly from event handler, let the error be handled by the main event handlers
    } else if (eventType.startsWith('FinancialMessageDetected')) {
      // Financial message detected - this means SMS processing is working
      // We don't need to add SmsReceived here as it's handled by the service
    }
    // Other events like TransactionParsed, TransactionSaved are handled by TransactionBloc
  }

  @override
  Future<void> close() {
    _serviceSubscription?.cancel();
    return super.close();
  }
}
