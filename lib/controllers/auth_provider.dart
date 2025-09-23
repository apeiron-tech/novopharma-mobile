import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:novopharma/models/user_model.dart';
import 'package:novopharma/services/auth_service.dart';
import 'package:novopharma/services/user_service.dart';

enum AppAuthState {
  unknown,
  unauthenticated,
  authenticatedPending,
  authenticatedActive,
  authenticatedDisabled,
}

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  User? _firebaseUser;
  UserModel? _userProfile;
  AppAuthState _appAuthState = AppAuthState.unknown;
  StreamSubscription<UserModel?>? _userProfileSubscription;

  AuthProvider() {
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  // Getters
  User? get firebaseUser => _firebaseUser;
  UserModel? get userProfile => _userProfile;
  AppAuthState get appAuthState => _appAuthState;

  @override
  void dispose() {
    _userProfileSubscription?.cancel();
    super.dispose();
  }

  Future<void> _onAuthStateChanged(User? user) async {
    await _userProfileSubscription?.cancel();

    if (user == null) {
      _firebaseUser = null;
      _userProfile = null;
      _appAuthState = AppAuthState.unauthenticated;
      print('[AuthProvider] State changed to: AppAuthState.unauthenticated');
      notifyListeners();
      return;
    } else {
      _firebaseUser = user;
      _appAuthState = AppAuthState.unknown;
      print('[AuthProvider] State changed to: AppAuthState.unknown (user found, loading profile)');
      notifyListeners(); // Notify for the initial loading state

      _userProfileSubscription =
          _userService.getUserProfile(user.uid).listen((userProfile) async {
        _userProfile = userProfile;
        if (_userProfile == null) {
          _appAuthState = AppAuthState.authenticatedDisabled;
          print('[AuthProvider] State changed to: AppAuthState.authenticatedDisabled (profile is null)');
        } else {
          switch (_userProfile!.status) {
            case UserStatus.active:
              try {
                await _firebaseUser!.getIdToken();
                _appAuthState = AppAuthState.authenticatedActive;
                print('[AuthProvider] State changed to: AppAuthState.authenticatedActive');
              } catch (e) {
                print('Error getting ID token: $e');
                _appAuthState = AppAuthState.unauthenticated;
                print('[AuthProvider] State changed to: AppAuthState.unauthenticated (token error)');
              }
              break;
            case UserStatus.pending:
              _appAuthState = AppAuthState.authenticatedPending;
              print('[AuthProvider] State changed to: AppAuthState.authenticatedPending');
              break;
            case UserStatus.disabled:
              _appAuthState = AppAuthState.authenticatedDisabled;
              print('[AuthProvider] State changed to: AppAuthState.authenticatedDisabled');
              break;
            default:
              _appAuthState = AppAuthState.unauthenticated;
              print('[AuthProvider] State changed to: AppAuthState.unauthenticated (default case)');
          }
        }
        notifyListeners();
      }, onError: (error) {
        print('Error fetching user profile: $error');
        _appAuthState = AppAuthState.unauthenticated;
        print('[AuthProvider] State changed to: AppAuthState.unauthenticated (profile fetch error)');
        notifyListeners();
      });
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _authService.signInWithEmailAndPassword(email, password);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message; // Return error message
    }
  }

  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
    required DateTime dateOfBirth,
    required String pharmacyId,
    required String pharmacyName,
    required String phone,
  }) async {
    try {
      // Step 1: Create user in Firebase Auth
      UserCredential userCredential = await _authService
          .createUserWithEmailAndPassword(email, password);
      User newUser = userCredential.user!;

      // Step 2: Create user profile in Firestore
      await _userService.createUserProfile(
        user: newUser,
        name: name,
        dateOfBirth: dateOfBirth,
        pharmacyId: pharmacyId,
        pharmacyName: pharmacyName,
        phone: phone,
      );

      // The _onAuthStateChanged listener will automatically handle the state update
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message; // Return error message
    } catch (e) {
      return 'An unexpected error occurred.';
    }
  }

  Future<String?> updateUserProfile(Map<String, dynamic> data) async {
    if (_firebaseUser == null) return 'No user logged in.';
    try {
      await _userService.updateUserProfile(_firebaseUser!.uid, data);
      // No need to manually refresh, the stream will handle it.
      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<String?> changePassword(String currentPassword, String newPassword) async {
    if (_firebaseUser == null) return 'No user logged in.';
    try {
      await _authService.changePassword(
        email: _firebaseUser!.email!,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred.';
    }
  }
}
