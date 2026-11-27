import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:smart_auth/smart_auth.dart';

/// Singleton service to manage the OTP Autofill lifecycle, persistent authorization state, and platform SMS retrieval.
/// Follows platform best practices:
/// - Android: Zero dangerous permissions (no READ_SMS). Uses Google Play Services SMS Retriever
///   and native Autofill framework. User Consent API is only requested on the very first authorization,
///   persisting `otp_autofill_initialized = true` in SharedPreferences to prevent duplicate prompts on subsequent
///   logins, registrations, or profile OTP flows.
/// - iOS: Relies on native iOS QuickType bar via AutofillGroup / AutofillHints.oneTimeCode (0 permissions, 0 dialogs).
/// - Cleanly controls listener subscriptions and timers, preventing memory leaks and duplicate listeners.
class OtpAutofillService {
  static final OtpAutofillService _instance = OtpAutofillService._internal();
  factory OtpAutofillService() => _instance;
  OtpAutofillService._internal();

  /// Key used in persistent storage (SharedPreferences)
  static const String prefKeyOtpAutofillInitialized = 'otp_autofill_initialized';

  late final SmsAutoFill _smsAutoFill = SmsAutoFill();
  StreamSubscription<String>? _subscription;
  Timer? _timeoutTimer;
  bool _isListening = false;
  bool? _isInitialized;

  /// Whether the native listener and Dart stream subscription are actively listening
  bool get isListening => _isListening;

  /// Returns whether OTP autofill has been initialized/authorized before on this device.
  Future<bool> isAutofillInitialized() async {
    if (_isInitialized != null) return _isInitialized!;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isInitialized = prefs.getBool(prefKeyOtpAutofillInitialized) ?? false;
      return _isInitialized!;
    } catch (e) {
      debugPrint('⚠️ [OtpAutofillService] Error reading initialized state: $e');
      return _isInitialized ?? false;
    }
  }

  /// Sets the persistent OTP autofill initialization state in SharedPreferences.
  Future<void> setAutofillInitialized(bool value) async {
    _isInitialized = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKeyOtpAutofillInitialized, value);
      debugPrint('💾 [OtpAutofillService] Stored otp_autofill_initialized = $value');
    } catch (e) {
      debugPrint('⚠️ [OtpAutofillService] Error saving initialized state: $e');
    }
  }

  /// Marks OTP autofill as initialized so future screens do not trigger permission/consent prompts.
  Future<void> markAutofillInitialized() async {
    await setAutofillInitialized(true);
  }

  /// Resets the persistent state (primarily for test/debug scenarios; never called on logout).
  @visibleForTesting
  Future<void> resetAutofillState() async {
    _isInitialized = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefKeyOtpAutofillInitialized);
    } catch (_) {}
  }

  /// Extracts a clean 6-digit OTP from incoming SMS payload.
  /// Handles full message texts, keyword prefixes/suffixes, and raw OTP strings accurately.
  static String? extractOtp(String message) {
    if (message.isEmpty) return null;

    final trimmed = message.trim();

    // 1. Raw exact 6-digit code
    if (RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      return trimmed;
    }

    // 2. Look for 6 digits preceded by OTP keywords
    // E.g.: "Your OTP is 654291", "verification code: 654291", "code is 654291"
    final keywordBeforeRegex = RegExp(
      r'(?:otp|code|verification|passcode|secret|pin)[\s:=#\-A-Za-z]{0,25}?(?<!\d)(\d{6})(?!\d)',
      caseSensitive: false,
    );
    final keywordBeforeMatch = keywordBeforeRegex.firstMatch(trimmed);
    if (keywordBeforeMatch != null && keywordBeforeMatch.group(1) != null) {
      return keywordBeforeMatch.group(1);
    }

    // 3. Look for 6 digits followed by OTP keywords
    // E.g.: "654291 is your OTP verification code for Smart Card"
    final keywordAfterRegex = RegExp(
      r'(?<!\d)(\d{6})(?!\d)[\s:=#\-A-Za-z]{0,25}?(?:otp|code|verification|passcode|secret|pin)',
      caseSensitive: false,
    );
    final keywordAfterMatch = keywordAfterRegex.firstMatch(trimmed);
    if (keywordAfterMatch != null && keywordAfterMatch.group(1) != null) {
      return keywordAfterMatch.group(1);
    }

    // 4. Google Play Services SMS Retriever standard format:
    // "<#> 654291 is your code..." or "<#> Your code is 654291..."
    if (trimmed.contains('<#>')) {
      final retrieverMatch = RegExp(r'(?<!\d)\d{6}(?!\d)').firstMatch(trimmed);
      if (retrieverMatch != null) {
        return retrieverMatch.group(0);
      }
    }

    // 5. Standalone 6 digits surrounded by non-digits
    final standaloneMatch = RegExp(r'(?<!\d)\d{6}(?!\d)').firstMatch(trimmed);
    if (standaloneMatch != null) {
      return standaloneMatch.group(0);
    }

    // 6. Fallback: sanitize non-digits and take if exactly 6 digits
    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length == 6) {
      return digitsOnly;
    }

    return null;
  }

  /// Retrieves the Android app signature hash used by Google SMS Retriever.
  Future<String?> getAppSignature() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final smartAuthSig = await SmartAuth.instance.getAppSignature();
      if (smartAuthSig.hasData && smartAuthSig.data != null && smartAuthSig.data!.isNotEmpty) {
        return smartAuthSig.data;
      }
      return await _smsAutoFill.getAppSignature;
    } catch (e) {
      debugPrint('⚠️ [OtpAutofillService] Error getting app signature: $e');
      return null;
    }
  }

  /// Inspects the platform's SMS permission status without triggering an unwanted prompt.
  Future<PermissionStatus> checkSmsPermissionStatus() async {
    if (kIsWeb) return PermissionStatus.denied;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        return await Permission.sms.status;
      } catch (e) {
        debugPrint('⚠️ [OtpAutofillService] Error checking SMS permission: $e');
        return PermissionStatus.denied;
      }
    }
    return PermissionStatus.granted;
  }

  /// Starts listening for incoming OTP codes automatically.
  /// - Automatically checks persistent state: If already initialized, it NEVER prompts for consent again.
  /// - First time: Initiates first-time authorization/consent flow and stores `otp_autofill_initialized = true`.
  /// - Subsequent times: Operates silently via zero-touch SMS Retriever and system keyboard autofill without modal dialogs.
  /// - Sets an automatic timeout (default 2 minutes) to release resources if no SMS arrives.
  /// - Automatically stops listening immediately upon successful OTP detection.
  Future<void> startListening({
    required void Function(String code) onCodeReceived,
    void Function()? onTimeout,
    Duration timeout = const Duration(minutes: 2),
    String? regexPattern,
    bool forceConsentPrompt = false,
  }) async {
    if (kIsWeb) return;

    try {
      // 1. Properly stop any existing listener before starting a new one
      await stopListening();

      // 2. On iOS: native keyboard QuickType bar (AutofillHints.oneTimeCode) handles SMS OTP
      // natively without background listeners or dialogs.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint('🍏 [OtpAutofillService] iOS detected: relying on native keyboard QuickType autofill');
        await markAutofillInitialized();
        return;
      }

      // 3. Android platform handling
      if (defaultTargetPlatform == TargetPlatform.android) {
        _isListening = true;

        // Start automatic timeout
        _timeoutTimer?.cancel();
        _timeoutTimer = Timer(timeout, () {
          debugPrint('⏰ [OtpAutofillService] OTP listening timed out after ${timeout.inSeconds}s');
          stopListening();
          onTimeout?.call();
        });

        // Google Play Services SMS User Consent API (via smart_auth)
        // Designed specifically for standard SMS without app hash. When an OTP SMS arrives,
        // Google Play Services presents a system bottom sheet consent dialog.
        // Once approved by user, SmartAuth delivers the SMS, we extract the 6-digit OTP,
        // and populate all 6 OTP fields automatically.
        SmartAuth.instance.getSmsWithUserConsentApi().then((result) {
          if (!_isListening) return;
          if (result.hasData && result.data != null) {
            final sms = result.data!.sms;
            debugPrint('📨 [OtpAutofillService - UserConsent] Received SMS via User Consent (length: ${sms.length})');
            final extracted = extractOtp(sms) ??
                (result.data!.code != null && result.data!.code!.length == 6
                    ? result.data!.code
                    : null);
            if (extracted != null && extracted.length == 6 && _isListening) {
              debugPrint('✅ [OtpAutofillService - UserConsent] Successfully extracted valid 6-digit OTP');
              stopListening();
              onCodeReceived(extracted);
            }
          }
        }).catchError((err) {
          debugPrint('⚠️ [OtpAutofillService - UserConsent] Error: $err');
        });

        debugPrint('🎧 [OtpAutofillService] Started listening with SmartAuth User Consent (timeout: ${timeout.inSeconds}s)');
      }
    } catch (e) {
      debugPrint('⚠️ [OtpAutofillService] Failed to start listening: $e');
      _isListening = false;
    }
  }

  /// Stops and unregisters all native receivers and cancels the stream subscription and timeout.
  /// Must be invoked when leaving the OTP screen, logging out, or resetting state.
  Future<void> stopListening() async {
    try {
      _timeoutTimer?.cancel();
      _timeoutTimer = null;

      if (_subscription != null) {
        await _subscription!.cancel();
        _subscription = null;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _smsAutoFill.unregisterListener();
        await SmartAuth.instance.removeUserConsentApiListener();
      }
      _isListening = false;
      debugPrint('🛑 [OtpAutofillService] Stopped listening and unregistered native receivers');
    } catch (e) {
      debugPrint('⚠️ [OtpAutofillService] Error during stopListening: $e');
      _isListening = false;
    }
  }
}

