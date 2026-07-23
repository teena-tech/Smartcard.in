import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../../core/utils/responsive.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _identifierController = TextEditingController();
  bool _loading = false;
  String _message = '';
  String _error = '';

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    setState(() {
      _error = '';
      _message = '';
    });

    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() => _error = 'Email or phone is required');
      return;
    }

    setState(() => _loading = true);

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _loading = false;
      _message = 'Reset email sent. Redirecting...';
      _identifierController.clear();
    });

    // Simulate redirect
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (context.mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    return Scaffold(
      backgroundColor: Colors.transparent, // Background handled by ThemeWrapper
      body: ResponsiveCenter(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Headers
                  Text(
                    'RECOVER ACCESS',
                    style: GoogleFonts.inter(
                      color: AppColors.primaryRedHover,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Forgot password',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colors.text,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Request a reset link with the same email or mobile number you use for login.',
                    style: GoogleFonts.inter(
                      color: colors.muted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form Card
                  Container(
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.border),
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
                          label: 'Email or Mobile',
                          hintText: 'Enter email or 10-digit mobile number',
                          controller: _identifierController,
                        ),
                        const SizedBox(height: 16),
                        if (_message.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              _message,
                              style: GoogleFonts.inter(
                                color: Colors.redAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (_error.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              _error,
                              style: GoogleFonts.inter(
                                color: Colors.red[600],
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Text(
                          'If a reset link is available, you will be redirected automatically after the request succeeds.',
                          style: GoogleFonts.inter(
                            color: colors.muted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          text: _loading ? 'Sending...' : 'Send Reset Link',
                          isLoading: _loading,
                          onPressed: _handleSubmit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Footer Actions
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryRedHover,
                        textStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      child: const Text('Back to login'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ),
    );
  }
}
