import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for managing Firebase Anonymous Authentication
///
/// This service handles anonymous authentication for the app, allowing
/// transactions to be securely associated with a device without requiring
/// user credentials. The anonymous UID persists across app restarts.
///
/// Requirements: 8.1, 8.2, 8.3, 8.6
class AuthService {
  final FirebaseAuth _firebaseAuth;

  /// Current authenticated user ID (anonymous UID)
  String? _currentUid;

  /// Whether the service is operating in local-only mode due to auth failure
  bool _isLocalOnlyMode = false;

  /// Stream controller for auth state changes
  final StreamController<String?> _authStateController =
      StreamController<String?>.broadcast();

  /// Creates an AuthService instance
  ///
  /// [firebaseAuth] - Optional FirebaseAuth instance for testing
  AuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  /// Initialize auth - creates anonymous session if needed
  ///
  /// Returns the UID on success, or null if auth fails (local-only mode)
  /// Requirements: 8.1, 8.2, 8.6
  Future<String?> initialize() async {
    try {
      // Check if user is already signed in (persisted session)
      final currentUser = _firebaseAuth.currentUser;

      if (currentUser != null) {
        // Restore existing anonymous session
        _currentUid = currentUser.uid;
        _isLocalOnlyMode = false;
        debugPrint('✅ AuthService: Restored existing anonymous session: $_currentUid');
        _authStateController.add(_currentUid);
        return _currentUid;
      }

      // Create new anonymous session
      debugPrint('🔄 AuthService: Creating new anonymous session...');
      final userCredential = await _firebaseAuth.signInAnonymously();
      _currentUid = userCredential.user?.uid;
      _isLocalOnlyMode = false;

      if (_currentUid != null) {
        debugPrint('✅ AuthService: Created new anonymous session: $_currentUid');
        _authStateController.add(_currentUid);
        return _currentUid;
      } else {
        throw Exception('Anonymous sign-in returned null user');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ AuthService: Firebase Auth error: ${e.code} - ${e.message}');
      _handleAuthFailure(e.message ?? 'Firebase Auth error');
      return null;
    } catch (e) {
      debugPrint('❌ AuthService: Auth initialization failed: $e');
      _handleAuthFailure(e.toString());
      return null;
    }
  }

  /// Handle auth failure by switching to local-only mode
  void _handleAuthFailure(String errorMessage) {
    _currentUid = null;
    _isLocalOnlyMode = true;
    _authStateController.add(null);
    debugPrint('⚠️ AuthService: Operating in local-only mode due to: $errorMessage');
  }

  /// Get current UID
  ///
  /// Returns null if not authenticated or in local-only mode
  /// Requirements: 8.3
  String? get currentUid => _currentUid;

  /// Get current UID (throws if not authenticated)
  ///
  /// Use this when UID is required for an operation
  /// Requirements: 8.3
  String get requireUid {
    if (_currentUid == null) {
      throw StateError(
        'User is not authenticated. Call initialize() first or check isAuthenticated.',
      );
    }
    return _currentUid!;
  }

  /// Check if user is authenticated
  ///
  /// Returns false if in local-only mode
  bool get isAuthenticated => _currentUid != null && !_isLocalOnlyMode;

  /// Check if operating in local-only mode
  ///
  /// Requirements: 8.6
  bool get isLocalOnlyMode => _isLocalOnlyMode;

  /// Stream of auth state changes
  ///
  /// Emits the UID when authenticated, null when not authenticated
  Stream<String?> get authStateChanges => _authStateController.stream;

  /// Sign out (for testing/reset purposes)
  ///
  /// This will clear the anonymous session and require re-initialization
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      _currentUid = null;
      _isLocalOnlyMode = false;
      _authStateController.add(null);
      debugPrint('✅ AuthService: Signed out successfully');
    } catch (e) {
      debugPrint('❌ AuthService: Sign out failed: $e');
      rethrow;
    }
  }

  /// Refresh the current auth token
  ///
  /// Useful when encountering permission errors
  Future<void> refreshToken() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.getIdToken(true);
        debugPrint('✅ AuthService: Token refreshed successfully');
      }
    } catch (e) {
      debugPrint('❌ AuthService: Token refresh failed: $e');
      rethrow;
    }
  }

  /// Dispose resources
  void dispose() {
    _authStateController.close();
  }
}
