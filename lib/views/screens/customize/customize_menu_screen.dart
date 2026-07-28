import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/card_viewmodel.dart';
import '../../../viewmodels/theme_viewmodel.dart';
import '../../widgets/common_drawer.dart';
import '../../widgets/customize_flow_widgets.dart';
import '../../widgets/global_bottom_nav.dart';
import 'customize_ai_screen.dart';
import 'customize_theme_screen.dart';
class CustomizeMenuScreen extends StatefulWidget {
  const CustomizeMenuScreen({super.key});

  @override
  State<CustomizeMenuScreen> createState() => _CustomizeMenuScreenState();
}

class _CustomizeMenuScreenState extends State<CustomizeMenuScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureCardContextLoaded();
    });
  }

  Future<void> _ensureCardContextLoaded() async {
    final authVm = context.read<AuthViewModel>();
    final cardVm = context.read<CardViewModel>();
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeVm = context.watch<ThemeViewModel>();
    final colors = themeVm.colors;
    final cardVm = context.watch<CardViewModel>();
    final currentCard = cardVm.currentCard;
    final initials = context.read<AuthViewModel>().currentUser == null
        ? 'U'
        : [
            context.read<AuthViewModel>().currentUser?.firstName,
            context.read<AuthViewModel>().currentUser?.lastName,
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
      border: Border.all(color: colors.border),
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
      drawer: const CommonDrawer(),
      backgroundColor: colors.backgroundStart,
      appBar: SmartCardsFlowAppBar(
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        initials: initials.isNotEmpty ? initials : 'U',
        onProfileTap: () {},
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
                if (currentCard != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: currentCard.companyLogo != null && currentCard.companyLogo!.isNotEmpty
                              ? Image.network(
                                  currentCard.companyLogo!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.credit_card, color: AppColors.primaryRed),
                                )
                              : const Icon(Icons.credit_card, color: AppColors.primaryRed),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentCard.name.isNotEmpty ? currentCard.name : 'Unknown Name',
                                style: GoogleFonts.inter(
                                  color: colors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (currentCard.designation != null && currentCard.designation!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    currentCard.designation!,
                                    style: GoogleFonts.inter(
                                      color: optionMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Card Settings',
                  style: GoogleFonts.inter(
                    color: colors.text,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 26),
                _OptionCard(
                  style: optionCardStyle,
                  iconBackground: optionIconBackground,
                  iconColor: usesDarkSurface ? Colors.white : AppColors.primaryRed,
                  title: 'AI Customization',
                  subtitle: 'Upload logo and pick overlay colors automatically',
                  subtitleColor: optionMuted,
                  trailingColor: colors.text,
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
                  trailingColor: colors.text,
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

class _OptionCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
            Icon(Icons.chevron_right_rounded, color: trailingColor, size: 28),
          ],
        ),
      ),
    );
  }
}
