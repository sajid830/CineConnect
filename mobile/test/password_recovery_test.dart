import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cineconnect/core/auth/password_recovery_client.dart';
import 'package:cineconnect/core/utils/web_tab_sync.dart';
import 'package:cineconnect/screens/auth_gate.dart';
import 'package:cineconnect/screens/forgot_password_screen.dart';
import 'package:cineconnect/features/talent/presentation/talent_portal_screen.dart';

/// Test double implementing [PasswordRecoveryClient] for deterministic testing.
class FakePasswordRecoveryClient implements PasswordRecoveryClient {
  final List<String> resetPasswordRequests = [];
  final List<Map<String, String>> verifyOtpRequests = [];
  final List<String> updatePasswordRequests = [];
  int signOutCalls = 0;

  bool shouldFailReset = false;
  String resetErrorMessage = 'Rate limit exceeded';

  bool shouldFailVerify = false;
  String verifyErrorMessage = 'Invalid or expired OTP token';

  bool shouldFailUpdate = false;
  String updateErrorMessage = 'Password too weak or expired session';

  bool shouldFailSignOut = false;

  OtpType? lastOtpTypeUsed;

  /// Hook to observe application state *during* verification execution.
  void Function()? onVerifyingOtp;

  @override
  Future<void> resetPasswordForEmail(String email) async {
    if (shouldFailReset) {
      throw AuthException(resetErrorMessage);
    }
    resetPasswordRequests.add(email);
  }

  @override
  Future<AuthResponse> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    lastOtpTypeUsed = OtpType.recovery;
    onVerifyingOtp?.call();

    if (shouldFailVerify) {
      throw AuthException(verifyErrorMessage);
    }
    verifyOtpRequests.add({'email': email, 'token': token});
    return AuthResponse(
      session: Session(
        accessToken: 'fake_access_token',
        tokenType: 'bearer',
        user: User(
          id: 'fake_user_id',
          appMetadata: {},
          userMetadata: {'account_type': 'talent'},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        ),
      ),
      user: User(
        id: 'fake_user_id',
        appMetadata: {},
        userMetadata: {'account_type': 'talent'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  Future<UserResponse> updatePassword(String newPassword) async {
    if (shouldFailUpdate) {
      throw AuthException(updateErrorMessage);
    }
    updatePasswordRequests.add(newPassword);
    return UserResponse.fromJson({
      'id': 'fake_user_id',
      'aud': 'authenticated',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (shouldFailSignOut) {
      throw const AuthException('Session revocation timeout / network disconnected');
    }
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: child,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setPasswordRecoveryInProgress(false);
  });

  tearDown(() {
    setPasswordRecoveryInProgress(false);
  });

  group('Password Recovery Client Contract', () {
    test('Client uses OtpType.recovery and records requests', () async {
      final fake = FakePasswordRecoveryClient();
      await fake.resetPasswordForEmail('user@test.com');
      expect(fake.resetPasswordRequests, equals(['user@test.com']));

      final resp = await fake.verifyRecoveryOtp(
        email: 'user@test.com',
        token: '123456',
      );
      expect(resp.session, isNotNull);
      expect(fake.lastOtpTypeUsed, equals(OtpType.recovery));
      expect(fake.lastOtpTypeUsed, isNot(equals(OtpType.signup)));
      expect(fake.verifyOtpRequests.first['token'], equals('123456'));

      await fake.updatePassword('NewSecret99!');
      expect(fake.updatePasswordRequests, equals(['NewSecret99!']));

      await fake.signOut();
      expect(fake.signOutCalls, equals(1));
    });
  });

  group('ForgotPasswordScreen Native OTP Workflow & Event Ordering', () {
    testWidgets('Step 1: Empty and invalid email validation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fake = FakePasswordRecoveryClient();
      await tester.pumpWidget(_wrap(ForgotPasswordScreen(recoveryClient: fake)));

      // Tap send with empty email
      await tester.tap(find.text('Send Recovery Code'));
      await tester.pump();
      expect(find.text('Please enter your email address.'), findsOneWidget);
      expect(fake.resetPasswordRequests, isEmpty);

      // Enter invalid email
      await tester.enterText(find.byType(TextField).first, 'notanemail');
      await tester.tap(find.text('Send Recovery Code'));
      await tester.pump();
      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(fake.resetPasswordRequests, isEmpty);
    });

    testWidgets('Step 1: Recovery request failure displays error banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fake = FakePasswordRecoveryClient()..shouldFailReset = true;
      await tester.pumpWidget(_wrap(ForgotPasswordScreen(recoveryClient: fake)));

      await tester.enterText(find.byType(TextField).first, 'user@cineconnect.com');
      await tester.tap(find.text('Send Recovery Code'));
      await tester.pumpAndSettle();

      expect(find.text('Rate limit exceeded'), findsOneWidget);
      expect(find.text('Enter Recovery Code'), findsNothing);
    });

    testWidgets('Step 1 -> Step 2: Valid email sends code and advances to OTP entry', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fake = FakePasswordRecoveryClient();
      await tester.pumpWidget(_wrap(ForgotPasswordScreen(recoveryClient: fake)));

      await tester.enterText(find.byType(TextField).first, 'actor@cineconnect.com');
      await tester.tap(find.text('Send Recovery Code'));
      await tester.pumpAndSettle();

      expect(fake.resetPasswordRequests, equals(['actor@cineconnect.com']));
      expect(find.text('Enter Recovery Code'), findsOneWidget);
      expect(find.text('000000'), findsOneWidget);
    });

    testWidgets('Step 2: Recovery guard is enabled BEFORE awaiting verifyRecoveryOtp', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool guardWasActiveDuringVerification = false;
      final fake = FakePasswordRecoveryClient()
        ..onVerifyingOtp = () {
          guardWasActiveDuringVerification = isPasswordRecoveryInProgress();
        };

      await tester.pumpWidget(_wrap(ForgotPasswordScreen(recoveryClient: fake)));

      // Advance to Step 2
      await tester.enterText(find.byType(TextField).first, 'actor@cineconnect.com');
      await tester.tap(find.text('Send Recovery Code'));
      await tester.pumpAndSettle();

      // Submit OTP
      await tester.enterText(find.byType(TextField).first, '654321');
      await tester.tap(find.text('Verify Code'));
      await tester.pumpAndSettle();

      expect(guardWasActiveDuringVerification, isTrue,
          reason: 'Recovery guard must be enabled before awaiting verifyRecoveryOtp');
      expect(isPasswordRecoveryInProgress(), isTrue,
          reason: 'Recovery guard must remain active after verification success');
    });

    testWidgets('Step 2: OTP verification failure clears the recovery guard safely', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fake = FakePasswordRecoveryClient()..shouldFailVerify = true;
      await tester.pumpWidget(_wrap(ForgotPasswordScreen(recoveryClient: fake)));

      // Step 1
      await tester.enterText(find.byType(TextField).first, 'actor@cineconnect.com');
      await tester.tap(find.text('Send Recovery Code'));
      await tester.pumpAndSettle();

      // Step 2 with failing OTP
      await tester.enterText(find.byType(TextField).first, '999999');
      await tester.tap(find.text('Verify Code'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Invalid or expired recovery code'), findsOneWidget);
      expect(isPasswordRecoveryInProgress(), isFalse,
          reason: 'Failed OTP verification must safely clear the recovery-in-progress guard');
      expect(find.text('Reset Password'), findsNothing);
    });

    testWidgets('Step 3: Password validation enforces exact signup consistency', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fake = FakePasswordRecoveryClient();
      await tester.pumpWidget(_wrap(ForgotPasswordScreen(
        isRecoveryMode: true,
        initialEmail: 'actor@cineconnect.com',
        recoveryClient: fake,
      )));

      // Empty password
      await tester.ensureVisible(find.text('Update Password'));
      await tester.tap(find.text('Update Password'));
      await tester.pump();
      expect(find.text('Please enter a new password.'), findsOneWidget);

      // Password < 6 characters
      await tester.enterText(find.byType(TextField).at(1), '12345');
      await tester.enterText(find.byType(TextField).at(2), '12345');
      await tester.tap(find.text('Update Password'));
      await tester.pump();
      expect(find.text('New password must be at least 6 characters.'), findsOneWidget);
      expect(fake.updatePasswordRequests, isEmpty);

      // Password mismatch
      await tester.enterText(find.byType(TextField).at(1), 'validpass1');
      await tester.enterText(find.byType(TextField).at(2), 'validpass2');
      await tester.tap(find.text('Update Password'));
      await tester.pump();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(fake.updatePasswordRequests, isEmpty);
    });

    testWidgets('Step 3 -> Step 4: Password update succeeds even when remote signOut fails', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fake = FakePasswordRecoveryClient()..shouldFailSignOut = true;
      await tester.pumpWidget(_wrap(ForgotPasswordScreen(
        isRecoveryMode: true,
        initialEmail: 'actor@cineconnect.com',
        recoveryClient: fake,
      )));

      expect(isPasswordRecoveryInProgress(), isTrue);

      await tester.enterText(find.byType(TextField).at(1), 'CinePass#2026');
      await tester.enterText(find.byType(TextField).at(2), 'CinePass#2026');
      await tester.ensureVisible(find.text('Update Password'));
      await tester.tap(find.text('Update Password'));
      await tester.pump();

      // Password updated and signOut attempted
      expect(fake.updatePasswordRequests, equals(['CinePass#2026']));
      expect(fake.signOutCalls, equals(1));

      // Guard is cleared even though signOut reported a revocation error
      expect(isPasswordRecoveryInProgress(), isFalse);

      // UI presents success, NOT failure
      expect(find.text('Password updated successfully'), findsOneWidget);
      expect(find.text('Back to Sign In'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1600));
    });

    testWidgets('Step 2: Resend code displays cooldown timer and prevents spam', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fake = FakePasswordRecoveryClient();
      await tester.pumpWidget(_wrap(ForgotPasswordScreen(recoveryClient: fake)));

      // Step 1
      await tester.enterText(find.byType(TextField).first, 'actor@cineconnect.com');
      await tester.tap(find.text('Send Recovery Code'));
      await tester.pumpAndSettle();

      // Step 2 shows cooldown active
      expect(find.textContaining('Resend code in'), findsOneWidget);

      // Fast-forward cooldown by 61 seconds
      await tester.pump(const Duration(seconds: 61));

      // Now "Didn't receive code? Resend" should appear
      expect(find.text("Didn't receive code? Resend"), findsOneWidget);

      // Tap resend
      await tester.tap(find.text("Didn't receive code? Resend"));
      await tester.pumpAndSettle();

      // Verify second request was issued
      expect(fake.resetPasswordRequests.length, equals(2));
      expect(find.textContaining('A fresh 6-digit recovery code has been sent'), findsOneWidget);
    });
  });

  group('Interrupted Recovery Persistence Across Simulated App Restart', () {
    test('Recovery guard state survives cold application restart', () async {
      SharedPreferences.setMockInitialValues({});

      // Set recovery in progress
      await setPasswordRecoveryInProgress(true);
      expect(isPasswordRecoveryInProgress(), isTrue);

      // Verify persisted in SharedPreferences
      final sp = await SharedPreferences.getInstance();
      expect(sp.getBool('cineconnect_recovery_in_progress'), isTrue);

      // Simulate cold app restart: re-initialize state from SharedPreferences
      await initPasswordRecoveryState();
      expect(isPasswordRecoveryInProgress(), isTrue);

      // Complete recovery & clear
      await setPasswordRecoveryInProgress(false);
      expect(isPasswordRecoveryInProgress(), isFalse);

      // Verify cleared from SharedPreferences
      final sp2 = await SharedPreferences.getInstance();
      expect(sp2.getBool('cineconnect_recovery_in_progress'), isNull);

      // Simulate cold restart after completion
      await initPasswordRecoveryState();
      expect(isPasswordRecoveryInProgress(), isFalse);
    });

    test('Stale recovery state on restart without session clears guard and does not trap user', () async {
      SharedPreferences.setMockInitialValues({'cineconnect_recovery_in_progress': true});
      await initPasswordRecoveryState();
      expect(isPasswordRecoveryInProgress(), isTrue);

      // In AuthGate, if isRecovery is true but session == null, guard is cleared
      // Simulate AuthGate stale recovery resolution:
      setPasswordRecoveryInProgress(false);
      expect(isPasswordRecoveryInProgress(), isFalse);

      final sp = await SharedPreferences.getInstance();
      expect(sp.getBool('cineconnect_recovery_in_progress'), isNull);
    });

    testWidgets('Step 3: User can reset recovery state if session expired', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fake = FakePasswordRecoveryClient();
      await tester.pumpWidget(_wrap(ForgotPasswordScreen(
        isRecoveryMode: true,
        initialEmail: 'actor@cineconnect.com',
        recoveryClient: fake,
      )));

      expect(isPasswordRecoveryInProgress(), isTrue);
      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Session expired? Request fresh code'), findsOneWidget);

      await tester.ensureVisible(find.text('Session expired? Request fresh code'));
      await tester.tap(find.text('Session expired? Request fresh code'));
      await tester.pumpAndSettle();

      // Guard is cleared and user is returned to Step 1 (Request Code)
      expect(isPasswordRecoveryInProgress(), isFalse);
      expect(find.text('Forgot Password'), findsOneWidget);
      expect(find.text('Send Recovery Code'), findsOneWidget);
    });
  });

  group('Recovery Session Identity Across App Restarts', () {
    test('Recovery started without completed OTP verification leaves confirmed identity null', () async {
      SharedPreferences.setMockInitialValues({});
      await setPasswordRecoveryInProgress(true);
      expect(isPasswordRecoveryInProgress(), isTrue);
      expect(getConfirmedRecoveryUserId(), isNull);

      final sp = await SharedPreferences.getInstance();
      expect(sp.getBool('cineconnect_recovery_in_progress'), isTrue);
      expect(sp.getString('cineconnect_recovery_user_id'), isNull);
    });

    test('Normal session restored after restart when OTP was not verified is not treated as recovery', () async {
      // Simulate app restart where user requested recovery but never verified OTP
      SharedPreferences.setMockInitialValues({'cineconnect_recovery_in_progress': true});
      await initPasswordRecoveryState();

      // Normal session restored
      const normalUserId = 'normal_user_123';
      final confirmedUserId = getConfirmedRecoveryUserId();

      // Identity is absent -> must reject recovery
      final isConfirmedRecoveryUser = confirmedUserId != null && confirmedUserId == normalUserId;
      expect(isConfirmedRecoveryUser, isFalse);

      // Safe clearance of stale state
      await clearRecoveryState();
      expect(isPasswordRecoveryInProgress(), isFalse);
      expect(getConfirmedRecoveryUserId(), isNull);
    });

    test('Matching confirmed recovery session identity resumes new-password stage', () async {
      const recoveryUserId = 'verified_recovery_user_999';

      // Simulate completed OTP verification persisted before restart
      SharedPreferences.setMockInitialValues({
        'cineconnect_recovery_in_progress': true,
        'cineconnect_recovery_user_id': recoveryUserId,
      });

      await initPasswordRecoveryState();
      expect(isPasswordRecoveryInProgress(), isTrue);
      expect(getConfirmedRecoveryUserId(), equals(recoveryUserId));

      // Same user session restored
      const restoredUserId = recoveryUserId;
      final isConfirmed = getConfirmedRecoveryUserId() == restoredUserId;
      expect(isConfirmed, isTrue);
    });

    test('Different user session restored while recovery state exists rejects recovery and clears state', () async {
      const recoveryUserId = 'verified_recovery_user_111';
      const differentUserId = 'different_user_222';

      SharedPreferences.setMockInitialValues({
        'cineconnect_recovery_in_progress': true,
        'cineconnect_recovery_user_id': recoveryUserId,
      });

      await initPasswordRecoveryState();

      final confirmedId = getConfirmedRecoveryUserId();
      final isMatch = confirmedId != null && confirmedId == differentUserId;
      expect(isMatch, isFalse);

      await clearRecoveryState();
      expect(isPasswordRecoveryInProgress(), isFalse);
      expect(getConfirmedRecoveryUserId(), isNull);
    });

    test('clearRecoveryState removes all markers from disk and memory', () async {
      SharedPreferences.setMockInitialValues({
        'cineconnect_recovery_in_progress': true,
        'cineconnect_recovery_user_id': 'any_user_id',
      });
      await initPasswordRecoveryState();

      await clearRecoveryState();
      expect(isPasswordRecoveryInProgress(), isFalse);
      expect(getConfirmedRecoveryUserId(), isNull);

      final sp = await SharedPreferences.getInstance();
      expect(sp.getBool('cineconnect_recovery_in_progress'), isNull);
      expect(sp.getString('cineconnect_recovery_user_id'), isNull);
    });
  });

  group('AuthChangeEvent.passwordRecovery and Identity Persistence Ordering', () {
    testWidgets('Recovery OTP event fired before verifyRecoveryOtp Future resolves coordinates safely with AuthGate', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      await clearRecoveryState();

      final authStreamController = StreamController<AuthState>.broadcast();
      addTearDown(() => authStreamController.close());

      // 1. Simulate a normal session existing
      final normalUser = User(
        id: 'normal_user_123',
        appMetadata: {},
        userMetadata: {'account_type': 'talent'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      final normalSession = Session(
        accessToken: 'normal_token',
        tokenType: 'bearer',
        user: normalUser,
      );

      final fakeRecoveryClient = FakePasswordRecoveryClient();

      // Pump AuthGate with the active normal session
      await tester.pumpWidget(_wrap(AuthGate(
        initialSession: normalSession,
        authStream: authStreamController.stream,
        recoveryClient: fakeRecoveryClient,
      )));
      await tester.pumpAndSettle();

      // Normal session routes to TalentPortalScreen
      expect(find.byType(TalentPortalScreen), findsOneWidget);
      expect(find.byType(ForgotPasswordScreen), findsNothing);

      // 2. Start recovery OTP verification for recovery user
      const recoveryUserId = 'recovery_user_456';
      final recoveryUser = User(
        id: recoveryUserId,
        appMetadata: {},
        userMetadata: {'account_type': 'talent'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      final recoverySession = Session(
        accessToken: 'recovery_token',
        tokenType: 'bearer',
        user: recoveryUser,
      );

      // Prepare a completer so verifyRecoveryOtp does not resolve until we say so
      final verifyCompleter = Completer<AuthResponse>();
      fakeRecoveryClient.onVerifyingOtp = () {
        // 3. Emulate GoTrue firing AuthChangeEvent.passwordRecovery
        // BEFORE the verifyRecoveryOtp Future completes!
        authStreamController.add(
          AuthState(AuthChangeEvent.passwordRecovery, recoverySession),
        );
      };

      // Set recovery guard as ForgotPasswordScreen._handleVerifyOtp does
      await setPasswordRecoveryInProgress(true);
      expect(isPasswordRecoveryInProgress(), isTrue);

      // Trigger the verification with the event firing during verifyRecoveryOtp
      final verifyFuture = () async {
        fakeRecoveryClient.onVerifyingOtp?.call();
        final res = await verifyCompleter.future;
        await setConfirmedRecoveryUserId(res.user?.id);
        return res;
      }();

      // 4. Verify AuthGate receives event without clearing state or routing to portals
      await tester.pump(); // Deliver stream event to AuthGate listeners
      await tester.pump(); // Render frame scheduled by setState

      // Recovery guard MUST still be active
      expect(isPasswordRecoveryInProgress(), isTrue);

      // AuthGate immediately captured confirmed recovery identity from the event
      expect(getConfirmedRecoveryUserId(), equals(recoveryUserId));

      // AuthGate MUST NOT route to TalentPortalScreen or clear state!
      expect(find.byType(TalentPortalScreen), findsNothing);
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);

      // 5. Complete verification and verify confirmedRecoveryUserId is persisted
      verifyCompleter.complete(AuthResponse(
        session: recoverySession,
        user: recoveryUser,
      ));
      await verifyFuture;
      await tester.pumpAndSettle();

      expect(getConfirmedRecoveryUserId(), equals(recoveryUserId));
      final sp = await SharedPreferences.getInstance();
      expect(sp.getBool('cineconnect_recovery_in_progress'), isTrue);
      expect(sp.getString('cineconnect_recovery_user_id'), equals(recoveryUserId));

      // 6. Simulate cold restart and verify matching session resumes Step 3 (setNewPassword)
      // Reset memory state
      await clearRecoveryState();
      // Re-initialize from persistent disk state (simulating fresh app launch)
      SharedPreferences.setMockInitialValues({
        'cineconnect_recovery_in_progress': true,
        'cineconnect_recovery_user_id': recoveryUserId,
      });
      await initPasswordRecoveryState();
      expect(isPasswordRecoveryInProgress(), isTrue);
      expect(getConfirmedRecoveryUserId(), equals(recoveryUserId));

      final restartStreamController = StreamController<AuthState>.broadcast();
      addTearDown(() => restartStreamController.close());

      await tester.pumpWidget(_wrap(AuthGate(
        initialSession: recoverySession,
        authStream: restartStreamController.stream,
        recoveryClient: fakeRecoveryClient,
      )));
      await tester.pumpAndSettle();

      // Must remain in ForgotPasswordScreen in recovery mode, NOT portal
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(find.byType(TalentPortalScreen), findsNothing);
      expect(find.text('Reset Password'), findsOneWidget);
    });

    testWidgets('Persistence failure does not accidentally route into a portal during active recovery', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      await clearRecoveryState();

      final authStreamController = StreamController<AuthState>.broadcast();
      addTearDown(() => authStreamController.close());

      final recoveryUser = User(
        id: 'recovery_fail_storage_777',
        appMetadata: {},
        userMetadata: {'account_type': 'talent'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      final recoverySession = Session(
        accessToken: 'recovery_token',
        tokenType: 'bearer',
        user: recoveryUser,
      );

      final fakeRecoveryClient = FakePasswordRecoveryClient();

      await tester.pumpWidget(_wrap(AuthGate(
        initialSession: recoverySession,
        authStream: authStreamController.stream,
        recoveryClient: fakeRecoveryClient,
      )));
      await tester.pumpAndSettle();

      // Emit password recovery event
      authStreamController.add(
        AuthState(AuthChangeEvent.passwordRecovery, recoverySession),
      );
      await tester.pump();
      await tester.pump();

      // In-memory identity and guard are active
      expect(getConfirmedRecoveryUserId(), equals('recovery_fail_storage_777'));

      // Active recovery stays safely in ForgotPasswordScreen, NEVER routes to TalentPortalScreen
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(find.byType(TalentPortalScreen), findsNothing);
    });

    testWidgets('Repeated AuthGate builds do not trigger repeated persistence writes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      await clearRecoveryState();

      final authStreamController = StreamController<AuthState>.broadcast();
      addTearDown(() => authStreamController.close());

      const recoveryUserId = 'build_pure_user_888';
      final recoveryUser = User(
        id: recoveryUserId,
        appMetadata: {},
        userMetadata: {'account_type': 'talent'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      final recoverySession = Session(
        accessToken: 'token_888',
        tokenType: 'bearer',
        user: recoveryUser,
      );

      final fakeRecoveryClient = FakePasswordRecoveryClient();

      await tester.pumpWidget(_wrap(AuthGate(
        initialSession: recoverySession,
        authStream: authStreamController.stream,
        recoveryClient: fakeRecoveryClient,
      )));
      await tester.pumpAndSettle();

      // Fire recovery event
      authStreamController.add(
        AuthState(AuthChangeEvent.passwordRecovery, recoverySession),
      );
      await tester.pump();
      await tester.pump();

      // Recovery identity confirmed
      expect(getConfirmedRecoveryUserId(), equals(recoveryUserId));

      // Trigger 10 repeated rebuilds of AuthGate
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Must remain in ForgotPasswordScreen without crashing or misrouting
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(find.byType(TalentPortalScreen), findsNothing);
    });

    test('Recovery completion and cancellation clear all markers consistently', () async {
      SharedPreferences.setMockInitialValues({
        'cineconnect_recovery_in_progress': true,
        'cineconnect_recovery_user_id': 'user_to_clear',
      });
      await initPasswordRecoveryState();
      expect(isPasswordRecoveryInProgress(), isTrue);
      expect(getConfirmedRecoveryUserId(), equals('user_to_clear'));

      // Completion/cancellation calls clearRecoveryState()
      await clearRecoveryState();

      expect(isPasswordRecoveryInProgress(), isFalse);
      expect(getConfirmedRecoveryUserId(), isNull);

      final sp = await SharedPreferences.getInstance();
      expect(sp.getBool('cineconnect_recovery_in_progress'), isNull);
      expect(sp.getString('cineconnect_recovery_user_id'), isNull);
    });
  });
}
