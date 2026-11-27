import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/features/support_agent_screen/presentation/view/support_agent_screen.dart';
import 'package:smartcard_flutter/features/contact_company_screen/presentation/view/contact_company_screen.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeViewModelProvider).colors;
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/login.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
            children: [
              Container(
                height: 185,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                alignment: Alignment.center,
                child: Lottie.asset(
                  'assets/lottie/people.json',
                  height: 340,
                  width: 340,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 185,
                      alignment: Alignment.center,
                      child: Text(
                        'Animation Error:\n$error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
        
              _buildSupportItem(
                context, 
                'Contact Agent', 
                'Open agent details, call, or chat', 
                Icons.support_agent, 
                colors,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SupportAgentScreen()),
                  );
                }
              ),
              const SizedBox(height: 12),
              _buildSupportItem(
                context, 
                'Contact Company', 
                'Create and track your company contact request', 
                Icons.business, 
                colors,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ContactCompanyScreen()),
                  );
                }
              ),
            ],
          ),
        ),
      ),
     ),
    );
  }

  Widget _buildSupportItem(BuildContext context, String title, String subtitle, IconData icon, dynamic colors, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.6), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.panel,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colors.text, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: colors.text)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppFonts.poppins(fontSize: 12, color: colors.muted)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFE53935)),
          ],
        ),
      ),
    );
  }
}
