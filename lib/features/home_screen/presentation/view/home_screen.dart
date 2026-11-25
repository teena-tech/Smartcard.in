import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/core/widgets/global_bottom_nav.dart';
import 'package:smartcard_flutter/core/widgets/master_app_bar.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/viewmodel/dashboard_viewmodel.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/viewmodel/profile_viewmodel.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/presentation/viewmodel/card_viewmodel.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_viewmodel.dart';
import 'package:smartcard_flutter/features/messages_screen/presentation/viewmodel/message_viewmodel.dart';
import 'package:smartcard_flutter/core/widgets/premium_card_widget.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/view/widgets/statistics_grid.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/view/widgets/recent_activity_list.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/view/widgets/recent_messages_list.dart';
import 'package:smartcard_flutter/core/di/app_loading_notifier.dart';
import 'package:smartcard_flutter/core/widgets/profile_menu_bottom_sheet.dart';
import 'package:smartcard_flutter/core/widgets/lottie_loader.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/presentation/view/smart_scanner_screen.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/view/profile_screen.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/presentation/view/smart_card_list_screen.dart';
import 'package:smartcard_flutter/features/manage_cards_screen/presentation/view/manage_card_screens.dart' as new_manage_cards;
import 'package:smartcard_flutter/features/my_cards_screen/presentation/view/mycards.dart' as my_cards_list;
import 'package:smartcard_flutter/features/contacts_screen/presentation/view/contacts_screen.dart';
import 'package:smartcard_flutter/features/messages_screen/presentation/view/messages_screen.dart';
import 'package:smartcard_flutter/features/support_screen/presentation/view/support_screen.dart';
import 'package:smartcard_flutter/features/support_chat_screen/presentation/view/support_chat_screen.dart';
import 'package:smartcard_flutter/features/settings_screen/presentation/view/settings_screen.dart';
import 'package:smartcard_flutter/features/about_screen/presentation/view/about_screen.dart';
import 'package:smartcard_flutter/core/utils/responsive.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/view/widgets/auto_loop_carousel.dart';
import 'package:smartcard_flutter/features/subscription_screen/presentation/viewmodel/subscription_viewmodel.dart';
import 'package:smartcard_flutter/core/widgets/premium_upgrade_dialog.dart';
import 'package:share_plus/share_plus.dart';

import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_notifier.dart';
import 'package:smartcard_flutter/core/services/reactive_contact_sync_service.dart';
import 'package:smartcard_flutter/core/services/app_update_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ignore: unused_element
  Future<void> _handleCreateNewCard() async {
    final authUser = ref.read(authViewModelProvider.notifier).currentUser;
    final cardVm = ref.read(cardViewModelProvider.notifier);
    final subVm = ref.read(subscriptionViewModelProvider.notifier);
    final userId = authUser?.id ?? '';

    if (userId.isNotEmpty && subVm.subscription == null) {
      await subVm.fetchSubscription(userId);
      if (!mounted) return;
    }

    final sub = subVm.subscription;
    bool isPremium = false;
    if (sub != null) {
      final mem = sub.membership.toUpperCase();
      if (sub.isActive || mem == 'PREMIUM' || mem == 'PAID' || mem != 'FREE') {
        isPremium = true;
      }
    } else if (authUser != null && userId.isNotEmpty) {
      isPremium = true;
    }

    if (!isPremium && cardVm.cards.isNotEmpty) {
      PremiumUpgradeDialog.show(context);
    } else {
      cardVm.handleAddMoreCard(context, masterProfile: authUser);
    }
  }

  Future<void> _checkForAppUpdate({bool forceCheck = false}) async {
    if (!mounted) return;
    try {
      await AppUpdateService.checkAndShowUpdateDialog(context, forceCheck: forceCheck);
    } catch (e) {
      debugPrint('HomeScreen _checkForAppUpdate error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialIndex != 0) {
        ref.read(dashboardViewModelProvider.notifier).setIndex(widget.initialIndex);
      }

      final authViewModel = ref.read(authViewModelProvider.notifier);
      if (authViewModel.isAuthenticated) {
        final user = authViewModel.currentUser;
        final userId = user?.id;
        if (userId != null && userId.isNotEmpty) {
          ref.read(appLoadingProvider.notifier).run(() => Future.wait([
            ref.read(cardViewModelProvider.notifier).fetchCards(
              userId,
              fallbackName: user?.displayName,
              fallbackPhone: user?.phone ?? '',
              fallbackEmail: user?.email,
            ),
            ref.read(profileViewModelProvider.notifier).loadProfile(userId),
            ref.read(subscriptionViewModelProvider.notifier).fetchSubscription(userId),
            ref.read(contactViewModelProvider.notifier).loadContactsFromBackend(),
            ref.read(messageViewModelProvider.notifier).loadMessages(),
          ]));
        }
      }

      try {
        ReactiveContactSyncService().initialize(
          contactNotifier: ref.read(contactNotifierProvider.notifier),
          contactViewModel: ref.read(contactViewModelProvider.notifier),
          dashboardViewModel: ref.read(dashboardViewModelProvider.notifier),
        );
      } catch (e) {
        debugPrint('ReactiveContactSyncService init error: $e');
      }
      _checkForAppUpdate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      try {
        ReactiveContactSyncService().handleDatabaseChange(
          contactNotifier: ref.read(contactNotifierProvider.notifier),
          contactViewModel: ref.read(contactViewModelProvider.notifier),
          dashboardViewModel: ref.read(dashboardViewModelProvider.notifier),
        );
      } catch (e) {
        debugPrint('AppLifecycle sync error: $e');
      }
      _checkForAppUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeViewModel = ref.watch(themeViewModelProvider);
    final colors = themeViewModel.colors;
    final dashboardViewModel = ref.watch(dashboardViewModelProvider);

    final List<Widget> pages = [
      _HomeBody(
        onProfileTap: () => ProfileMenuBottomSheet.show(context),
        onScanTap: () => dashboardViewModel.setIndex(1),
        onShareTap: () async {
          final cardVm = ref.read(cardViewModelProvider.notifier);
          final profileVm = ref.read(profileViewModelProvider.notifier);
          final currentCard = cardVm.currentCard;
          final targetUserId = profileVm.user?.id ?? currentCard?.accountUserId.toString() ?? '';
          if (currentCard != null) {
            final url = currentCard.qrData.isNotEmpty ? currentCard.qrData : 'https://thesmartcards.in/profile/${currentCard.userId}';
            await Share.share(url);
            profileVm.incrementShareCount(targetUserId);
          } else if (cardVm.cards.isNotEmpty) {
            final card = cardVm.cards.first;
            final url = card.qrData.isNotEmpty ? card.qrData : 'https://thesmartcards.in/profile/${card.userId}';
            await Share.share(url);
            profileVm.incrementShareCount(targetUserId);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No card available to share.')),
            );
          }
        },
        isActive: dashboardViewModel.currentIndex == 0,
      ),
      const SmartScannerScreen(),
      const SmartCardListScreen(isTab: true),
      const ProfileBody(),
      const ContactsScreen(),
      const MessagesScreen(),
      const SupportScreen(),
      const SettingsScreen(),
      const AboutScreen(),
      const my_cards_list.MyCardsScreen(isStandalone: false),
      const new_manage_cards.ManageCardsScreen(isTab: true),
    ];

    return WillPopScope(
      onWillPop: () async {
        if (dashboardViewModel.currentIndex != 0) {
          ref.read(dashboardViewModelProvider.notifier).setIndex(0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: dashboardViewModel.currentIndex == 1
            ? Colors.black
            : colors.backgroundStart,
        // Dynamic AppBar based on selected tab
        appBar: MasterAppBar(
          titleText: _getTitle(dashboardViewModel.currentIndex),
          style: MasterHeaderStyle.gradient,
          showBackButton: false,
          showThemeToggle: false,
          onProfileTap: () => ProfileMenuBottomSheet.show(context),
        ),
        body: IndexedStack(
          index: dashboardViewModel.currentIndex,
          children: pages,
        ),
        floatingActionButton: null,
        bottomNavigationBar: const GlobalBottomNav(),
      ),
    );
  }
  String _getTitle(int index) {
    switch (index) {
      case 0: return 'Dashboard';
      case 1: return 'Scan';
      case 2: return 'MY CARDS';
      case 3: return 'My Profile';
      case 4: return 'Contacts';
      case 5: return 'Messages';
      case 6: return 'Support';
      case 7: return 'Settings';
      case 8: return 'About';
      case 9: return 'Share Card';
      case 10:
        return 'MY CARDS';
      default:
        return '';
    }
  }
}

class _HomeBody extends ConsumerStatefulWidget {
  final VoidCallback onProfileTap;
  final VoidCallback onScanTap;
  final VoidCallback onShareTap;
  final bool isActive;

  const _HomeBody({
    required this.onProfileTap,
    required this.onScanTap,
    required this.onShareTap,
    required this.isActive,
  });

  @override
  ConsumerState<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<_HomeBody> {
  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = ref.read(authViewModelProvider.notifier);
      if (authViewModel.isAuthenticated) {
        final user = authViewModel.currentUser;
        final userId = user?.id;
        if (userId == null || userId.isEmpty) return;

        AppLoadingService.instance.run(() => Future.wait([
          ref.read(cardViewModelProvider.notifier).fetchCards(
            userId,
            fallbackName: user?.displayName,
            fallbackPhone: user?.phone ?? '',
            fallbackEmail: user?.email,
          ),
          ref.read(profileViewModelProvider.notifier).loadProfile(userId),
          ref.read(subscriptionViewModelProvider.notifier).fetchSubscription(userId),
          ref.read(contactViewModelProvider.notifier).loadContactsFromBackend(),
          ref.read(messageViewModelProvider.notifier).loadMessages(),
        ]));

        // Start global polling so new admin messages are detected
        // even when the Messages tab is not open.
        final msgVm = ref.read(messageViewModelProvider.notifier);
        if (!msgVm.isPolling) {
          msgVm.startPolling();
        }
      }
    });
  }

  @override
  void dispose() {
    // Keep polling alive; it is a global Riverpod Notifier — do NOT stop it here.
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    final authViewModel = ref.read(authViewModelProvider.notifier);
    if (authViewModel.isAuthenticated) {
      final user = authViewModel.currentUser;
      final userId = user?.id;
      if (userId == null || userId.isEmpty) return;
      ref.read(cardViewModelProvider.notifier).fetchCards(
        userId,
        fallbackName: user?.displayName,
        fallbackPhone: user?.phone ?? '',
        fallbackEmail: user?.email,
      );
      ref.read(profileViewModelProvider.notifier).loadProfile(userId);
      ref.read(contactViewModelProvider.notifier).loadContactsFromBackend();
      ref.read(messageViewModelProvider.notifier).loadMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeViewModel = ref.watch(themeViewModelProvider);
    final colors = themeViewModel.colors;
    final profileViewModel = ref.watch(profileViewModelProvider);
    final cardViewModel = ref.watch(cardViewModelProvider);
    final contactViewModel = ref.watch(contactViewModelProvider);
    final messageViewModel = ref.watch(messageViewModelProvider);
    final profile = profileViewModel.user;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.primaryRed,
      child: ResponsiveCenter(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // 2. Greeting Block
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Hello, ${(profile?.displayName.isNotEmpty == true ? profile!.displayName : (ref.watch(authViewModelProvider).currentUser?.displayName.isNotEmpty == true ? ref.watch(authViewModelProvider).currentUser!.displayName : 'Teena Davis'))}',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Row(
                  children: [
                    _QuickActionCard(
                      icon: Icons.edit_document,
                      label: 'Manage Card',
                      colors: colors,
                      onTap: () {
                        ref.read(dashboardViewModelProvider.notifier).setIndex(2);
                      },
                      isPrimary: false,
                    ),
                    _QuickActionCard(
                      icon: Icons.qr_code_scanner,
                      label: 'Scan',
                      colors: colors,
                      onTap: widget.onScanTap,
                      isPrimary: false,
                    ),
                    _QuickActionCard(
                      icon: Icons.share_outlined,
                      label: 'Share',
                      colors: colors,
                      onTap: widget.onShareTap,
                      isPrimary: false,
                    ),

                  ],
                ),
              ),

              const SizedBox(height: 16),
              
              if (cardViewModel.isLoading && cardViewModel.cards.isEmpty)
                const SizedBox(
                  height: 250,
                  child: Center(child: LottieLoader(size: 80)),
                )
              else if (cardViewModel.cards.isEmpty)
                // 8. Empty State
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.credit_card_off_outlined, size: 64, color: colors.muted.withValues(alpha: 0.15)),
                        const SizedBox(height: 16),
                        Text(
                          'No Cards Available',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: colors.text),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first digital smart card to start networking.',
                          style: GoogleFonts.inter(fontSize: 12, color: colors.muted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const new_manage_cards.ManageCardsScreen()));
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Create Card'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    SizedBox(
                      height: 220,
                      child: AutoLoopCarousel(
                        itemCount: cardViewModel.cards.length,
                        initialIndex: cardViewModel.currentIndex,
                        viewportFraction: 0.9,
                        autoScroll: widget.isActive, // stop timer when not on home tab
                        onPageChanged: (realIndex) {
                          cardViewModel.setCurrentIndex(realIndex);
                        },
                        itemBuilder: (context, realIndex, virtualIndex) {
                          final card = cardViewModel.cards[realIndex];
                          void handleCardTap() {
                            ref.read(profileViewModelProvider.notifier).incrementCardViews(card.accountUserId.toString());
                            cardViewModel.setCurrentIndex(realIndex);
                            ref.read(dashboardViewModelProvider.notifier).setIndex(9); // Navigate to Shared Card Screen
                          }
                          return PremiumCardWidget(
                            card: card,
                            onTap: handleCardTap,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        cardViewModel.cards.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: cardViewModel.currentIndex == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: cardViewModel.currentIndex == index ? AppColors.primaryRed : colors.muted.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Removed CardActionsBar
                  ],
                ),

              const SizedBox(height: 24),

              // 6. Statistics Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Statistics',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StatisticsGrid(
                userId: profile?.id,
                totalCards: cardViewModel.cards.length,
                totalViews: profile?.cardViews ?? 0,
                sharedCards: profile?.shareCount ?? 0,
                scannedCards: contactViewModel.scannedContactsCount,
              ),

              const SizedBox(height: 32),

              // 5. Recent Messages Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Messages',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                         ref.read(dashboardViewModelProvider.notifier).setIndex(5); // Messages tab
                      },
                      child: Text(
                        'View All',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              messageViewModel.error != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Could not load messages: ${messageViewModel.error}. Pull to refresh.',
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.orange[700]),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RecentMessagesList(messages: messageViewModel.messages),
              
              const SizedBox(height: 32),

              // 6. Recent Scans Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Scans',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                         ref.read(dashboardViewModelProvider.notifier).setIndex(1); // Navigate to scan tab
                      },
                      child: Text(
                        'View All',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              RecentActivityList(activities: contactViewModel.allContacts.where((c) => c.source != 'phone' && !c.id.startsWith('phone_')).toList()), // Placeholder using contacts for scans
              
              const SizedBox(height: 100), // FAB padding
            ],
          ),
        ),
      ),
    );
  }


}

class _ExpandableFAB extends ConsumerStatefulWidget {
  final VoidCallback onScanTap;
  final VoidCallback onCreateTap;

  const _ExpandableFAB({
    required this.onScanTap,
    required this.onCreateTap,
  });

  @override
  ConsumerState<_ExpandableFAB> createState() => _ExpandableFABState();
}

class _ExpandableFABState extends ConsumerState<_ExpandableFAB> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: _isOpen ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _ExpandableFABAction(
          icon: Icons.chat,
          label: 'Support Chat',
          expandAnimation: _expandAnimation,
          onTap: () {
            _toggle();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SupportChatScreen()),
            );
          },
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: 'main_fab',
          onPressed: _toggle,
          backgroundColor: AppColors.primaryRed,
          child: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _expandAnimation,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _ExpandableFABAction extends ConsumerWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Animation<double> expandAnimation;

  const _ExpandableFABAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.expandAnimation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizeTransition(
      sizeFactor: expandAnimation,
      child: FadeTransition(
        opacity: expandAnimation,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
                ],
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            const SizedBox(width: 16),
            FloatingActionButton.small(
              heroTag: label, // ensure unique tags
              onPressed: onTap,
              backgroundColor: Colors.white,
              child: Icon(icon, color: AppColors.primaryRed),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final AppColors colors;
  final VoidCallback onTap;
  final bool isPrimary;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.92)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.92, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerTap() {
    _controller.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final isAnimating = _controller.isAnimating;

          Widget iconWidget = Icon(
            widget.icon,
            color: AppColors.primaryRed,
            size: 28,
          );

          if (isAnimating) {
            iconWidget = ShaderMask(
              shaderCallback: (bounds) {
                final double shift = -1.5 + (_controller.value * 3.0);
                return LinearGradient(
                  begin: Alignment(shift - 0.4, -0.3),
                  end: Alignment(shift + 0.4, 0.3),
                  colors: const [
                    AppColors.primaryRed,
                    Color(0xFFFFD700), // Rich Gold
                    Color(0xFFFFFFFF), // Pure Silver shimmer
                    Color(0xFFE2E8F0), // Platinum Silver
                    Color(0xFFF59E0B), // Warm Gold
                    AppColors.primaryRed,
                  ],
                  stops: const [0.0, 0.22, 0.45, 0.65, 0.85, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcATop,
              child: iconWidget,
            );
          }

          return ScaleTransition(
            scale: isAnimating ? _scaleAnimation : const AlwaysStoppedAnimation(1.0),
            child: InkWell(
              onTap: _triggerTap,
              borderRadius: BorderRadius.circular(16),
              splashColor: const Color(0xFFFFD700).withValues(alpha: 0.25),
              highlightColor: const Color(0xFFE2E8F0).withValues(alpha: 0.25),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAnimating
                        ? const Color(0xFFFFD700).withValues(alpha: 0.7)
                        : const Color(0xFFFFB4B4),
                    width: isAnimating ? 1.5 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isAnimating
                          ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.02),
                      blurRadius: isAnimating ? 8 : 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    iconWidget,
                    const SizedBox(height: 12),
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
