import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:smartcard_flutter/main.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/core/services/otp_autofill_service.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
import 'package:smartcard_flutter/features/register_screen/presentation/view/widgets/otp_channel_banner.dart';
import 'package:smartcard_flutter/core/widgets/otp_input_field.dart';
import 'package:smartcard_flutter/core/widgets/primary_button.dart';
import 'package:smartcard_flutter/features/register_screen/presentation/view/widgets/international_phone_input.dart';
import 'package:smartcard_flutter/core/utils/international_phone_helper.dart';
import 'package:smartcard_flutter/features/register_screen/presentation/view/register_screen.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/view/home_screen.dart';

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  Timer? _resendTimer;
  int _resendSecondsLeft = 0;
  static const int _resendCooldown = 30; // seconds

  int _failedOtpAttempts = 0;
  static const int _maxOtpAttempts = 3;
  static const int _lockoutDurationSeconds = 5 * 60; // 5 minutes
  Timer? _lockoutTimer;
  int _lockoutSecondsLeft = 0;
  bool get _isLockedOut => _lockoutSecondsLeft > 0;
  bool _isVerifyingOtp = false;

  bool _isWhatsAppMode = false;
  String _selectedCountryCode = '+91';
  String _selectedCountryFlag = '🇮🇳';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(authViewModelProvider.notifier).showOtp) {
        _startOtpListener();
      }
    });
  }

  void _startOtpListener() {
    OtpAutofillService().startListening(
      onCodeReceived: (otp6) {
        if (!mounted) return;
        setState(() {
          _otpController.text = otp6;
        });
        // Automatically verify when code is filled
        _handleVerifyOtp();
      },
      onTimeout: () {
        debugPrint('⏰ [LoginForm] OTP autofill listening timed out');
      },
    );
  }

  void _stopOtpListener() {
    OtpAutofillService().stopListening();
  }

  @override
  void dispose() {
    _stopOtpListener();
    _identifierController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _handleLoginSuccess() {
    _stopOtpListener();
    OtpAutofillService().markAutofillInitialized();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(24),
          child: globalSuccessLottieComposition != null
              ? Lottie(
                  composition: globalSuccessLottieComposition,
                  width: 150,
                  height: 150,
                  repeat: false,
                )
              : Lottie.asset(
                  'assets/lottie/Success Animation 2.json',
                  width: 150,
                  height: 150,
                  repeat: false,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.check_circle, color: Colors.green, size: 80),
                ),
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    });
  }

  Future<void> _handleLogin() async {
    final phone = _identifierController.text.trim();
    
    final validationError = InternationalPhoneHelper.validatePhoneNumber(
      phone: phone,
      countryCode: _selectedCountryCode,
      isWhatsApp: _isWhatsAppMode,
    );
    if (validationError != null) {
      _showErrorDialog('Invalid Number', validationError);
      return;
    }
    
    final authViewModel = ref.read(authViewModelProvider.notifier);
    final channel = _isWhatsAppMode ? 'whatsapp' : 'phone';
    final ok = await authViewModel.sendLoginOtp(
      phone,
      channel: channel,
      countryCode: _selectedCountryCode,
    );
    
    if (!context.mounted) return;
    
    if (ok) {
      // OTP sent successfully
      setState(() {
        _failedOtpAttempts = 0;
      });
      _startResendTimer();
      _startOtpListener();
    } else {
      // Failed to send OTP
      final errorMessage = authViewModel.errorMessage ?? 'Failed to send OTP. Please try again.';
      _showErrorDialog('Error', errorMessage);
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (_isLockedOut || _isVerifyingOtp) return;

    final authViewModel = ref.read(authViewModelProvider.notifier);
    if (authViewModel.isLoading) return;
    if (_otpController.text.trim().length != 6) {
      _showErrorDialog(
        'Invalid OTP',
        'Please enter a 6-digit OTP.',
      );
      return;
    }

    _isVerifyingOtp = true;
    try {
      final otp = _otpController.text.trim();

      // Call OTP verification
      final success = await authViewModel.verifyLoginOtp(otp);

      if (!context.mounted) return;

      if (success) {
        // OTP verified successfully - stop listener and navigate to home screen
        _stopOtpListener();
        _handleLoginSuccess();
      } else {
        // OTP verification failed - show error dialog
        final errorMessage = authViewModel.errorMessage ?? 'Invalid OTP. Please try again.';
        _showErrorDialog('Invalid OTP', errorMessage);

        // Clear OTP input field for user to retry
        _otpController.clear();

        // Update brute-force protection
        setState(() {
          _failedOtpAttempts++;
        });

        if (_failedOtpAttempts >= _maxOtpAttempts) {
          _stopOtpListener();
          _startLockoutTimer();
        } else {
          // Restart listener for user retry
          _startOtpListener();
        }
      }
    } finally {
      _isVerifyingOtp = false;
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.red[700],
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryRed,
                textStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    setState(() {
      _lockoutSecondsLeft = _lockoutDurationSeconds;
    });
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!context.mounted) return timer.cancel();
      setState(() {
        _lockoutSecondsLeft = _lockoutSecondsLeft - 1;
        if (_lockoutSecondsLeft <= 0) {
          _lockoutTimer?.cancel();
          _lockoutSecondsLeft = 0;
          _failedOtpAttempts = 0;
        }
      });
    });
  }

  Future<void> _dispatchLoginOtp({
    required bool useWhatsApp,
    required String snackText,
  }) async {
    final authViewModel = ref.read(authViewModelProvider.notifier);
    if (authViewModel.isLoading) return;

    final phone = _identifierController.text.trim();
    final validationError = InternationalPhoneHelper.validatePhoneNumber(
      phone: phone,
      countryCode: _selectedCountryCode,
      isWhatsApp: useWhatsApp,
    );
    if (validationError != null) {
      _showErrorDialog('Error', validationError);
      return;
    }

    final previousWhatsApp = _isWhatsAppMode;
    setState(() {
      _isWhatsAppMode = useWhatsApp;
    });
    _otpController.clear();

    final channel = useWhatsApp ? 'whatsapp' : 'phone';
    final ok = await authViewModel.sendLoginOtp(
      phone,
      channel: channel,
      countryCode: _selectedCountryCode,
    );

    if (!mounted) return;

    if (ok) {
      setState(() {
        _failedOtpAttempts = 0;
      });
      _startResendTimer();
      _startOtpListener();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            snackText,
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFF15803D),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setState(() {
        _isWhatsAppMode = previousWhatsApp;
      });
      final errorMessage = authViewModel.errorMessage ?? 'Failed to send OTP. Please try again.';
      _showErrorDialog('Error', errorMessage);
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendSecondsLeft > 0) return;
    await _dispatchLoginOtp(
      useWhatsApp: _isWhatsAppMode,
      snackText: 'OTP sent successfully',
    );
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendSecondsLeft = _resendCooldown;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!context.mounted) return timer.cancel();
      setState(() {
        _resendSecondsLeft = _resendSecondsLeft - 1;
        if (_resendSecondsLeft <= 0) {
          _resendTimer?.cancel();
          _resendSecondsLeft = 0;
        }
      });
    });
  }

  String _formatLockoutTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // OTP button now triggers sendLoginOtp via _handleLogin


  @override
  Widget build(BuildContext context) {
    final authViewModel = ref.watch(authViewModelProvider);
    
    // Automatically ensure listener is cleaned up if showOtp resets to false
    if (!authViewModel.showOtp && OtpAutofillService().isListening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !authViewModel.showOtp) {
          _stopOtpListener();
        }
      });
    }

    final primaryButtonText = authViewModel.showOtp
        ? (authViewModel.isLoading ? 'Verifying OTP...' : 'Verify OTP')
        : (authViewModel.isLoading
            ? (_isWhatsAppMode ? 'Sending via WhatsApp...' : 'Sending OTP...')
            : (_isWhatsAppMode ? 'SEND OTP VIA WHATSAPP' : 'SEND OTP'));

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.05),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!authViewModel.showOtp)
                InternationalPhoneInput(
                  phoneController: _identifierController,
                  isWhatsAppMode: false,
                  selectedCountryCode: '+91',
                  allowSeparateWhatsApp: false,
                  showModeSelector: false,
                  disableCountryPicker: true,
                  showChannelStatusBanner: false,
                  enabled: !authViewModel.isLoading,
                  onWhatsAppModeChanged: (val) {
                    setState(() {
                      _isWhatsAppMode = val;
                      if (!val) {
                        _selectedCountryCode = '+91';
                        _selectedCountryFlag = '🇮🇳';
                      }
                      authViewModel.clearMessages();
                    });
                  },
                  onCountryCodeChanged: (cData) {
                    setState(() {
                      _selectedCountryCode = cData.code;
                      _selectedCountryFlag = cData.flag;
                      authViewModel.clearMessages();
                    });
                  },
                  onChanged: (_) => authViewModel.clearMessages(),
                )
              else
                OtpChannelBanner(
                  isWhatsAppMode: _isWhatsAppMode,
                  phoneDisplay:
                      '$_selectedCountryFlag $_selectedCountryCode ${_identifierController.text.trim()}',
                  onChangePressed: () {
                    _stopOtpListener();
                    authViewModel.resetOtpState();
                  },
                ),
              const SizedBox(height: 18),

              if (authViewModel.showOtp) ...[
                AbsorbPointer(
                  absorbing: _isLockedOut,
                  child: Opacity(
                    opacity: _isLockedOut ? 0.4 : 1.0,
                    child: OTPInputField(
                      controller: _otpController,
                      accentColor: _isWhatsAppMode
                          ? const Color(0xFF15803D)
                          : const Color(0xFFA81C24),
                      onChanged: (code) {
                        authViewModel.clearMessages();
                      },
                      onCompleted: (code) {
                        if (!_isLockedOut) {
                          Future.microtask(() => _handleVerifyOtp());
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Lockout banner
              if (_isLockedOut)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Too many failed attempts.',
                              style: GoogleFonts.inter(
                                color: Colors.red[700],
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Login blocked. Try again in ${_formatLockoutTime(_lockoutSecondsLeft)}',
                              style: GoogleFonts.inter(
                                color: Colors.red[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (!_isLockedOut && authViewModel.showOtp) ...[
                OtpStatusNotice(
                  statusMessage: authViewModel.message,
                  errorMessage: authViewModel.error,
                  isWhatsAppMode: false,
                ),
                const SizedBox(height: 16),
              ] else if (!_isLockedOut) ...[
                if (authViewModel.error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[600], size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            authViewModel.error,
                            style: GoogleFonts.inter(
                              color: Colors.red[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  _isWhatsAppMode
                      ? '6-digit OTP will be delivered directly to your WhatsApp.'
                      : 'Secure access to your user control center.',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
              ],

              PrimaryButton(
                text: _isLockedOut ? 'Login Blocked' : primaryButtonText,
                isLoading: authViewModel.isLoading,
                onPressed: (_isLockedOut || authViewModel.isLoading)
                    ? null
                    : () {
                        authViewModel.showOtp ? _handleVerifyOtp() : _handleLogin();
                      },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Footer Actions
        Column(
          children: [
            if (!authViewModel.showOtp) ...[
              _buildFooterLink('Register', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                );
              }),
            ],

            if (authViewModel.showOtp)
              _buildFooterLink('Back to login', () {
                _stopOtpListener();
                authViewModel.resetOtpState();
              }),

            if (authViewModel.showOtp)
              Center(
                child: TextButton(
                  onPressed: (authViewModel.isLoading || _resendSecondsLeft > 0)
                      ? null
                      : _handleResendOtp,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF9E1C24),
                    disabledForegroundColor: const Color(0xFF1F2937),
                    textStyle: GoogleFonts.inter(
                      fontWeight: _resendSecondsLeft > 0
                          ? FontWeight.w500
                          : FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  child: Text(
                    _resendSecondsLeft > 0
                        ? 'Resend OTP in ${_resendSecondsLeft}s'
                        : 'Resend OTP',
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooterLink(String text, VoidCallback onPressed) {
    const crimson = Color(0xFF9E1C24);
    return Center(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: crimson,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
            letterSpacing: 0.2,
            decoration: TextDecoration.underline,
            decorationColor: crimson,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        ),
        child: Text(text),
      ),
    );
  }
}
