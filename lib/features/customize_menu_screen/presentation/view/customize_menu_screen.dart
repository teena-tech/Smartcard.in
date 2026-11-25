import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/presentation/viewmodel/card_viewmodel.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/core/widgets/profile_menu_bottom_sheet.dart';
import 'package:smartcard_flutter/features/customize_menu_screen/presentation/view/widgets/customize_flow_widgets.dart';
import 'package:smartcard_flutter/core/widgets/global_bottom_nav.dart';
import 'package:smartcard_flutter/core/utils/card_expansion_route.dart';
import 'package:smartcard_flutter/features/customize_ai_screen/presentation/view/customize_ai_screen.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/view/customize_theme_screen.dart';
class CustomizeMenuScreen extends ConsumerStatefulWidget {
  const CustomizeMenuScreen({super.key});

  @override
  ConsumerState<CustomizeMenuScreen> createState() => _CustomizeMenuScreenState();
}

class _CustomizeMenuScreenState extends ConsumerState<CustomizeMenuScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureCardContextLoaded();
    });
  }

  Future<void> _ensureCardContextLoaded() async {
    final authVm = ref.read(authViewModelProvider.notifier);
    final cardVm = ref.read(cardViewModelProvider.notifier);
    final user = authVm.currentUser;
    if (user == null) return;

    final userId = user.id ?? '';
    if (userId.isEmpty) return;

    if (cardVm.cards.isEmpty) {
      final name = '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim();
      cardVm.init(
        userId: userId,
        fallbackName: name.isNotEmpty ? name : 'User',
        fallbackPhone: user.phone ?? '',
        fallbackEmail: user.email,
      );
    }
  }

  void _navigateTo(Widget page) {
    final cardVm = ref.read(cardViewModelProvider.notifier);
    if (cardVm.currentCard?.isOrganization == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visual customizations for Organization cards are managed by your Organization Administrator.'),
          backgroundColor: Color(0xFF0284C7),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      CardExpansionPageRoute(page: page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeVm = ref.watch(themeViewModelProvider);
    final colors = themeVm.colors;
    final initials = ref.read(authViewModelProvider.notifier).currentUser == null
        ? 'U'
        : [
            ref.read(authViewModelProvider.notifier).currentUser?.firstName,
            ref.read(authViewModelProvider.notifier).currentUser?.lastName,
          ]
            .whereType<String>()
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .map((part) => part[0].toUpperCase())
            .take(2)
            .join();

    final usesDarkSurface = colors.backgroundStart.computeLuminance() < 0.45;
    final optionCardStyle = BoxDecoration(
      color: usesDarkSurface ? const Color(0xFF1F2A3A) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.6), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
    final optionIconBackground = usesDarkSurface
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.white;
    final optionMuted = usesDarkSurface ? const Color(0xFFD8E0EE) : colors.muted;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.backgroundStart,
      appBar: SmartCardsFlowAppBar(
        onMenuTap: () {},
        initials: initials.isNotEmpty ? initials : 'U',
        onProfileTap: () => ProfileMenuBottomSheet.show(context),
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/login.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [


                Center(
                  child: Lottie.asset(
                    'assets/lottie/profile_user_card.json',
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('⚠️ Lottie profile_user_card.json load error: $error');
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                const SizedBox(height: 20),
                _OptionCard(
                  style: optionCardStyle,
                  iconBackground: optionIconBackground,
                  iconColor: usesDarkSurface ? Colors.white : AppColors.primaryRed,
                  title: 'AI Customization',
                  subtitle: 'Upload logo and pick overlay colors automatically',
                  subtitleColor: optionMuted,
                  trailingColor: AppColors.primaryRed,
                  titleColor: colors.text,
                  icon: Icons.auto_awesome_outlined,
                  onTap: () => _navigateTo(const CustomizeAiScreen()),
                ),
                const SizedBox(height: 16),
                _OptionCard(
                  style: optionCardStyle,
                  iconBackground: optionIconBackground,
                  iconColor: usesDarkSurface ? Colors.white : AppColors.primaryRed,
                  title: 'Theme',
                  subtitle: 'Choose template and card design',
                  subtitleColor: optionMuted,
                  trailingColor: AppColors.primaryRed,
                  titleColor: colors.text,
                  icon: Icons.view_quilt_outlined,
                  onTap: () => _navigateTo(const CustomizeThemeScreen()),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _OptionCard extends ConsumerWidget {
  final BoxDecoration style;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final Color trailingColor;
  final Color titleColor;
  final IconData icon;
  final VoidCallback onTap;

  const _OptionCard({
    required this.style,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.trailingColor,
    required this.titleColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: style,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: titleColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: subtitleColor,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFE53935), size: 28),
          ],
        ),
      ),
    );
  }
}
