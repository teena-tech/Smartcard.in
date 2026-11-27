import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/view/widgets/login_form.dart';
import 'package:smartcard_flutter/core/utils/responsive.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeViewModelProvider).colors;

    return Scaffold(
      backgroundColor: Colors.transparent, // Background handled by ThemeWrapper
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/login.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: ResponsiveCenter(
          child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480), // For larger screens/web
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo Area
                Center(
                  child: Image.asset(
                    'assets/images/smartlogo.png',
                    height: 90,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 48),

                // Headers
                Text(
                  'USER ACCESS',
                  style: AppFonts.poppins(
                    color: AppColors.primaryRedHover,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Login',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w300,
                        color: colors.text,
                      ),
                ),
                const SizedBox(height: 15),

                // Login Form Card handles both the form and the bottom links
                const LoginForm(),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
