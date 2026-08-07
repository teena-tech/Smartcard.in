import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:lottie/lottie.dart';
import '../../main.dart';
import '../../core/constants/app_colors.dart';
import '../../core/state/app_loading_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'custom_text_field.dart';
import 'otp_input_field.dart';
import 'primary_button.dart';
import '../screens/register_screen.dart';
import '../screens/home_screen.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> with CodeAutoFill {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  Timer? _resendTimer;
  int _resendSecondsLeft = 0;
  static const int _resendCooldown = 30; // seconds

  // Brute-force protection
  int _failedOtpAttempts = 0;
  static const int _maxOtpAttempts = 3;
  static const int _lockoutDurationSeconds = 5 * 60; // 5 minutes
  Timer? _lockoutTimer;
  int _lockoutSecondsLeft = 0;
  bool get _isLockedOut => _lockoutSecondsLeft > 0;

  @override
  void codeUpdated() {
    if (code != null && code!.length == 6) {
      setState(() {
        _otpController.text = code!;
      });
      // Automatically verify when code is filled
      _handleVerifyOtp();
    }
  }

  @override
  void dispose() {
    unregisterListener();
    _identifierController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _handleLoginSuccess() {
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
      if (!context.mounted) return;
      Navigator.pop(context); // Close the success animation dialog
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    });
  }

  Future<void> _handleLogin() async {
    final phone = _identifierController.text.trim();
    
    // Validate phone number
    if (phone.isEmpty) {
      _showErrorDialog(
        'Invalid Phone',
        'Please enter a phone number.',
      );
      return;
    }
    
    if (phone.length < 10) {
      _showErrorDialog(
        'Invalid Phone',
        'Please enter a valid 10-digit phone number.',
      );
      return;
    }
    
    final authViewModel = context.read<AuthViewModel>();
    final ok = await authViewModel.sendLoginOtp(phone);
    
    if (!context.mounted) return;
    
    if (ok) {
      // OTP sent successfully
      setState(() {
        _failedOtpAttempts = 0;
      });
      _startResendTimer();
      listenForCode(); // Start listening for SMS code autofill
    } else {
      // Failed to send OTP
      final errorMessage = authViewModel.errorMessage ?? 'Failed to send OTP. Please try again.';
      _showErrorDialog('Error', errorMessage);
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (_isLockedOut) return;
    
    final authViewModel = context.read<AuthViewModel>();
    if (authViewModel.isLoading) return;
    if (_otpController.text.trim().length != 6) {
      _showErrorDialog(
        'Invalid OTP',
        'Please enter a 6-digit OTP.',
      );
      return;
    }

    final otp = _otpController.text.trim();
    
    // Call OTP verification
    final success = await authViewModel.verifyLoginOtp(otp);
    
    if (!context.mounted) return;
    
    if (success) {
      // OTP verified successfully - navigate to home screen
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
        _startLockoutTimer();
      }
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

  Future<void> _handleResendOtp() async {
    if (_resendSecondsLeft > 0) return;
    
    final authViewModel = context.read<AuthViewModel>();
    if (authViewModel.isLoading) return;
    
    final phone = _identifierController.text.trim();
    if (phone.isEmpty) {
      _showErrorDialog(
        'Error',
        'Please enter your phone number.',
      );
      return;
    }
    
    _otpController.clear();
    
    final ok = await authViewModel.sendLoginOtp(phone);
    
    if (!context.mounted) return;
    
    if (ok) {
      setState(() {
        _failedOtpAttempts = 0;
      });
      _startResendTimer();
      listenForCode(); // Start listening for SMS code autofill
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'OTP sent successfully',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      final errorMessage = authViewModel.errorMessage ?? 'Failed to resend OTP. Please try again.';
      _showErrorDialog('Error', errorMessage);
    }
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
    final authViewModel = context.watch<AuthViewModel>();
    
    final primaryButtonText = authViewModel.showOtp
        ? (authViewModel.isLoading ? 'Verifying OTP...' : 'Verify OTP')
        : (authViewModel.isLoading ? 'Sending OTP...' : 'Send OTP');

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomTextField(
                label: 'Mobile Number',
                hintText: 'Enter 10-digit mobile number',
                controller: _identifierController,
                keyboardType: TextInputType.phone,
                autofocus: true,
                onChanged: (_) => authViewModel.clearMessages(),
              ),
              const SizedBox(height: 24),
              
              if (authViewModel.showOtp)
                AbsorbPointer(
                  absorbing: _isLockedOut,
                  child: Opacity(
                    opacity: _isLockedOut ? 0.4 : 1.0,
                    child: OTPInputField(
                      controller: _otpController,
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
              
              if (authViewModel.message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    authViewModel.message,
                    style: GoogleFonts.inter(
                      color: Colors.green[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                
              if (!_isLockedOut && authViewModel.error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
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

              if (!_isLockedOut)
                Text(
                  !authViewModel.showOtp
                      ? 'Secure access to your user control center.'
                      : 'Enter the 6-digit OTP sent to your mobile number.',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: _isLockedOut ? 'Login Blocked' : primaryButtonText,
                isLoading: authViewModel.isLoading,
                onPressed: (_isLockedOut || authViewModel.isLoading) ? null : () { authViewModel.showOtp ? _handleVerifyOtp() : _handleLogin(); },
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
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
              _buildFooterLink('Back to login', authViewModel.resetOtpState),

            if (authViewModel.showOtp)
              Center(
                child: TextButton(
                  onPressed: (authViewModel.isLoading || _resendSecondsLeft > 0) ? null : _handleResendOtp,
                  style: TextButton.styleFrom(
                    foregroundColor: _resendSecondsLeft > 0 ? Colors.grey : Colors.green[600],
                    textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  child: Text(_resendSecondsLeft > 0 ? 'Resend in ${_resendSecondsLeft}s' : 'Resend OTP'),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooterLink(String text, VoidCallback onPressed) {
    final bool isRegister = text.toLowerCase() == 'register';
    return Center(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: isRegister ? const Color(0xFFFA0000) : Colors.white,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: Text(text),
      ),
    );
  }
}
