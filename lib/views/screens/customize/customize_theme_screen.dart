import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/upload_url_resolver.dart';
import '../../../models/app_theme_item.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/card_viewmodel.dart';
import '../../../viewmodels/customize_viewmodel.dart';
import '../../../viewmodels/profile_viewmodel.dart';
import '../../../viewmodels/theme_viewmodel.dart';
import '../../../viewmodels/subscription_viewmodel.dart';
import '../../widgets/circular_profile_avatar.dart';
import '../../widgets/global_bottom_nav.dart';
import '../../widgets/master_app_bar.dart';
import '../subscription_screen.dart';
import 'customize_menu_screen.dart';





class CustomizeThemeScreen extends StatefulWidget {
  const CustomizeThemeScreen({super.key});

  @override
  State<CustomizeThemeScreen> createState() => _CustomizeThemeScreenState();
}

class _CustomizeThemeScreenState extends State<CustomizeThemeScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _saving = false;
  List<AppThemeItem> _themes = [];
  int _currentIndex = 0;
  int _initialIndex = 0;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _heartbeatController;
  late Animation<double> _heartbeatAnimation;

  @override
  void initState() {
    super.initState();
    _heartbeatController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _heartbeatAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _heartbeatController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVm = context.read<AuthViewModel>();
      final userId = authVm.currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        context.read<SubscriptionViewModel>().fetchSubscription(userId);
      }
      _loadThemes();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _heartbeatController.dispose();
    super.dispose();
  }

  Future<void> _loadThemes() async {
    setState(() => _loading = true);

    final customizeVm = context.read<CustomizeViewModel>();
    final authVm = context.read<AuthViewModel>();
    final cardVm = context.read<CardViewModel>();

    final userId = authVm.currentUser?.id ?? '';
    final workProfileId = cardVm.currentCard?.workProfileId ?? cardVm.currentCard?.userId;

    try {
      await customizeVm.fetchTemplates();
    } catch (_) {}
    try {
      if (userId.isNotEmpty) {
        await customizeVm.fetchTheme(userId, workProfileId: workProfileId);
      }
    } catch (_) {}

    try {
      final List<AppThemeItem> items = [];
      final seenIds = <String>{};

      // Always prepend the default smartcard classic theme as the first item
      items.add(AppThemeItem.defaultTheme);
      seenIds.add(AppThemeItem.defaultTheme.id);

      // Load ONLY Templates from backend API (/api/v1/themes/templates)
      // Background images are a SEPARATE feature for background pattern selection
      for (int i = 0; i < customizeVm.templates.length; i++) {
        final t = customizeVm.templates[i];
        if (t is Map<String, dynamic>) {
          final item = AppThemeItem.fromMap(t, index: items.length);
          if (!seenIds.contains(item.id)) {
            seenIds.add(item.id);
            items.add(item);
          }
        }
      }

      final dbTemplateId = customizeVm.themeData?['template_id']?.toString() ?? '';
      final dbTemplateKey = customizeVm.themeData?['template_key']?.toString() ?? '';
      final dbBgImage = customizeVm.themeData?['bg_image']?.toString() ?? '';
      
      int activeIdx = -1;
      if (dbTemplateId.isNotEmpty || dbTemplateKey.isNotEmpty) {
        activeIdx = items.indexWhere((t) => 
          t.id == dbTemplateId || 
          t.id == dbTemplateKey || 
          t.templateKey == dbTemplateKey ||
          (dbTemplateId.isNotEmpty && t.id.replaceAll(RegExp(r'\D'), '') == dbTemplateId)
        );
      }
      if (activeIdx < 0 && dbBgImage.isNotEmpty) {
        activeIdx = items.indexWhere((t) => t.frontImage == dbBgImage || t.frontImage.endsWith(dbBgImage));
      }
      if (activeIdx < 0 && cardVm.currentCard?.isPrimary == true) {
        final themeVm = context.read<ThemeViewModel>();
        final selectedId = themeVm.selectedThemeId;
        activeIdx = items.indexWhere((t) => t.id == selectedId);
      }
      if (activeIdx < 0) {
        activeIdx = 0; // Default to first card/theme if not saved
      }

      if (mounted) {
        setState(() {
          _themes = items;
          _currentIndex = activeIdx;
          _initialIndex = activeIdx;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _themes = AppThemeItem.builtinTemplates;
          _currentIndex = 0;
          _initialIndex = 0;
          _loading = false;
        });
      }
    }
  }


  void _onPreviewPressed() async {
    final cardVm = context.read<CardViewModel>();
    final card = cardVm.currentCard;
    if (card == null) return;

    String liveLink = card.profileUrl ?? 'https://thesmartcards.com/profile/${card.workProfileId}';
    final dbQr = card.qrCode ?? '';
    if (dbQr.isNotEmpty) {
      try {
        final dbUri = Uri.parse(dbQr);
        final scVal = dbUri.queryParameters['sc'];
        if (scVal != null && scVal.isNotEmpty) {
          liveLink = 'https://thesmartcards.com/?sc=$scVal';
        } else if (dbQr.startsWith('http://') || dbQr.startsWith('https://')) {
          liveLink = dbQr;
        }
      } catch (_) {}
    }

    try {
      final uri = Uri.parse(liveLink);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _onPreviewTheme(int index) {
    if (index < 0 || index >= _themes.length) return;
    setState(() => _currentIndex = index);

    if (_scrollController.hasClients) {
      final double targetOffset = index * 56.0; // 44 width + 12 margins (6 * 2)
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveSelectedTheme() async {
    if (_themes.isEmpty || _currentIndex >= _themes.length) return;

    final theme = _themes[_currentIndex];
    final subVm = context.read<SubscriptionViewModel>();
    final isPremiumUser = subVm.subscription?.isActive == true || subVm.subscription?.membership == 'PREMIUM';

    if (!theme.isFree && !isPremiumUser) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.lock_outline, color: AppColors.primaryRed),
              const SizedBox(width: 8),
              const Text('Premium Theme'),
            ],
          ),
          content: const Text('This theme is locked. Please upgrade to a premium plan to customize with this theme.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              },
              child: const Text('Upgrade', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    final themeVm = context.read<ThemeViewModel>();
    final authVm = context.read<AuthViewModel>();
    final cardVm = context.read<CardViewModel>();
    final customizeVm = context.read<CustomizeViewModel>();

    setState(() => _saving = true);

    try {
      // 1. Persist to API and await completion
      final userId = authVm.currentUser?.id ?? '';
      if (userId.isNotEmpty) {
        final workProfileId = cardVm.currentCard?.workProfileId ?? cardVm.currentCard?.userId;
        if (theme.isDefault || theme.id == 'default_theme_01') {
          // Clear background and template details to restore classic look
          await customizeVm.saveTemplate(
            userId,
            {
              'template_id': null,
              'template_key': null,
            },
            workProfileId: workProfileId,
          );
          await customizeVm.clearBackground(
            userId,
            workProfileId: workProfileId,
          );
        } else {
          final numMatch = RegExp(r'\d+').firstMatch(theme.id);
          final parsedId = numMatch != null ? int.tryParse(numMatch.group(0)!) : null;
          final templateKey = theme.templateKey ?? 
              (parsedId != null ? 'template_$parsedId' : theme.id);

          await customizeVm.saveTemplate(
            userId,
            {
              'template_id': parsedId,
              'template_key': templateKey,
            },
            workProfileId: workProfileId,
          );

          if (theme.frontImage.isNotEmpty) {
            String savedBg = theme.frontImage;
            if (savedBg.contains('shared-uploads/')) {
              final index = savedBg.indexOf('shared-uploads/');
              savedBg = savedBg.substring(index);
            } else if (savedBg.contains('assets/')) {
              // keep asset path as-is
            } else {
              savedBg = savedBg.split('/').last;
            }

            await customizeVm.saveBackgroundSelection(
              userId,
              {
                'bg_image': savedBg,
              },
              workProfileId: workProfileId,
            );
          }
        }

        // Refresh cards list to persist theme update for secondary card
        await cardVm.fetchCards(
          userId,
          fallbackName: authVm.currentUser?.displayName,
          fallbackPhone: authVm.currentUser?.phone ?? '',
          fallbackEmail: authVm.currentUser?.email,
        );
      }

      setState(() {
        _saving = false;
        _initialIndex = _currentIndex;
      });

      // 2. Update ThemeViewModel & Local Persistence only if primary card
      if (cardVm.currentCard?.isPrimary == true) {
        themeVm.selectTheme(theme);
      }

      final numMatch = RegExp(r'\d+').firstMatch(theme.id);
      final parsedId = numMatch != null ? int.tryParse(numMatch.group(0)!) : null;
      final templateKey = theme.templateKey ?? 
          (parsedId != null ? 'template_$parsedId' : theme.id);

      // 3. Update CardViewModel active card
      cardVm.updateActiveCardTheme(
        backgroundImage: (theme.isDefault || theme.id == 'default_theme_01') ? null : theme.frontImage,
        backgroundColor: null,
        textColor: null,
        bgImageColor: null,
        templateId: (theme.isDefault || theme.id == 'default_theme_01') ? null : (parsedId?.toString() ?? theme.id),
        templateKey: (theme.isDefault || theme.id == 'default_theme_01') ? null : templateKey,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Theme Applied Successfully!',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save theme: ${e.toString().replaceAll("Exception: ", "")}',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _resetThemeSelection() {
    setState(() => _currentIndex = _initialIndex);
  }

  void _onBackPress() {
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null && modalRoute.isFirst) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CustomizeMenuScreen()),
      );
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CustomizeMenuScreen()),
      );
    }
  }



  void _prevTheme() {
    if (_themes.isEmpty) return;
    final prevIndex = (_currentIndex - 1 + _themes.length) % _themes.length;
    _onPreviewTheme(prevIndex);
  }

  void _nextTheme() {
    if (_themes.isEmpty) return;
    final nextIndex = (_currentIndex + 1) % _themes.length;
    _onPreviewTheme(nextIndex);
  }

  Widget _buildThemeImage(String imagePath, {required BoxFit fit}) {
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: fit,
        errorBuilder: (_, __, ___) => Image.asset('assets/images/smartlogo.png', fit: fit),
      );
    }
    return CachedNetworkImage(
      imageUrl: imagePath,
      fit: fit,
      placeholder: (context, url) => Container(
        color: Colors.grey.shade900,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed)),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey.shade800,
        child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 32),
      ),
    );
  }

  Widget _buildSectionBox(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeVm = context.watch<ThemeViewModel>();
    final cardVm = context.watch<CardViewModel>();
    final authVm = context.watch<AuthViewModel>();

    final subVm = context.watch<SubscriptionViewModel>();
    final isPremiumUser = subVm.subscription?.isActive == true || subVm.subscription?.membership == 'PREMIUM';

    final profileVm = context.watch<ProfileViewModel>();
    final user = profileVm.user ?? authVm.currentUser;
    final cardImage = cardVm.currentCard?.profileImageName;
    final imagePath = (cardImage != null && cardImage.isNotEmpty) ? cardImage : user?.profileImage;
    final imageUrl = (imagePath != null && imagePath.isNotEmpty)
        ? UploadUrlResolver.resolve(imagePath, type: 'profile')
        : null;

    final cardDetails = cardVm.selectedCardDetails;
    final companyName = cardDetails?.companyName.trim().isNotEmpty == true
        ? cardDetails!.companyName.trim()
        : (cardVm.currentCard?.companyName.isNotEmpty == true
            ? cardVm.currentCard!.companyName
            : 'Antzmedia');

    final designation = cardDetails?.designation.trim().isNotEmpty == true
        ? cardDetails!.designation.trim()
        : 'Flutter';

    final email = (user?.email != null && user!.email!.isNotEmpty)
        ? user.email!
        : 'teenatech8086@gmail.com';

    final phone = (user?.phone != null && user!.phone!.isNotEmpty)
        ? user.phone!
        : '8086750402';


    final initials = user == null
        ? 'TN'
        : [user.firstName, user.lastName]
            .whereType<String>()
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .map((part) => part[0].toUpperCase())
            .take(2)
            .join();

    final activeTheme = _themes.isNotEmpty && _currentIndex < _themes.length
        ? _themes[_currentIndex]
        : themeVm.currentTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBackPress();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF0F0),
        bottomNavigationBar: const GlobalBottomNav(),
        appBar: MasterAppBar(
          titleText: 'Customize',
          style: MasterHeaderStyle.gradient,
          onBackTap: _onBackPress,
        ),

      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
            const SizedBox(height: 12),

            // 1. VERTICAL CARD PREVIEW CONTAINER WITH DETAILS & FLOATING [✕] [✓]
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  // Swipe Left → Next Theme
                  if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
                    _nextTheme();
                  }
                  // Swipe Right → Previous Theme
                  else if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
                    _prevTheme();
                  }
                },
                child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [

                    // Business Card Mockup Body
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: KeyedSubtree(
                            key: ValueKey(activeTheme.id),
                            child: Stack(
                              children: [
                                // Theme Background Image
                                Positioned.fill(
                                  child: _buildThemeImage(activeTheme.frontImage, fit: BoxFit.cover),
                                ),

                                // Dark Overlay for text readability
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black.withValues(alpha: 0.25),
                                  ),
                                ),

                                // Top Center Lock & Premium Badge (with heartbeat animation) if template is paid/premium & user is non-premium
                                if (!activeTheme.isFree && !isPremiumUser)
                                  Positioned(
                                    top: 14,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: ScaleTransition(
                                        scale: _heartbeatAnimation,
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.75),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: Colors.amber, width: 1.5),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.amber.withValues(alpha: 0.3),
                                                  blurRadius: 8,
                                                  spreadRadius: 1,
                                                )
                                              ],
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.lock,
                                                  color: Colors.amber,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'PREMIUM',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                    letterSpacing: 1.0,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                // Top Left Theme Counter Badge
                                // Top Left Header: Counter & Preview Badge
                                Positioned(
                                  top: 14,
                                  left: 14,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.35),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${_currentIndex + 1} / ${_themes.length}',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: _onPreviewPressed,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.35),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 13),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Preview',
                                                style: GoogleFonts.inter(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Top Right Header: Floating [✕] (Red) and [✓] (Green) Action Buttons
                                Positioned(
                                  top: 14,
                                  right: 14,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // [✕] Close / Reset Button (RED)
                                      GestureDetector(
                                        onTap: _resetThemeSelection,
                                        child: Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFFEF4444),
                                            border: Border.all(color: Colors.white, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.3),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                                        ),
                                      ),

                                      const SizedBox(width: 10),

                                      // [✓] Save / Apply Button (GREEN)
                                      GestureDetector(
                                        onTap: _saveSelectedTheme,
                                        child: Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF22C55E),
                                            border: Border.all(color: Colors.white, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.3),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(Icons.check, color: Colors.white, size: 22),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Left Nav Arrow <
                    Positioned(
                      left: 8,
                      child: GestureDetector(
                        onTap: _prevTheme,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.85),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.chevron_left, color: Colors.black87, size: 24),
                        ),
                      ),
                    ),

                    // Right Nav Arrow >
                    Positioned(
                      right: 8,
                      child: GestureDetector(
                        onTap: _nextTheme,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.85),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.chevron_right, color: Colors.black87, size: 24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ), // GestureDetector end
            ), // Expanded end

            // Horizontal Theme Selector List
            if (!_loading && _themes.isNotEmpty)
              Container(
                height: 70,
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _themes.length,
                  itemBuilder: (context, index) {
                    final theme = _themes[index];
                    final isSelected = index == _currentIndex;
                    return GestureDetector(
                      onTap: () => _onPreviewTheme(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        width: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryRed : Colors.grey.withValues(alpha: 0.4),
                            width: isSelected ? 2.5 : 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primaryRed.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : [],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: _buildThemeImage(theme.frontImage, fit: BoxFit.cover),
                            ),
                            if (!theme.isFree && !isPremiumUser)
                              Container(
                                color: Colors.black.withValues(alpha: 0.35),
                                child: Center(
                                  child: ScaleTransition(
                                    scale: _heartbeatAnimation,
                                    child: const Icon(
                                      Icons.lock,
                                      color: AppColors.primaryRed,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),
          ],
        ),
        if (_saving)
          Container(
            color: Colors.black.withValues(alpha: 0.35),
            child: const Center(
              child: Card(
                elevation: 4,
                shape: CircleBorder(),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
   ),
  );
  }
}





class _CrossLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8B0000)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

