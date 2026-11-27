import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_config.dart';
import '../../core/providers/app_riverpod_providers.dart';
import '../widgets/master_bottom_nav.dart';
import '../widgets/master_app_bar.dart';
import '../widgets/premium_card_widget.dart';
import '../widgets/statistics_grid.dart';
import '../widgets/recent_activity_list.dart';
import '../widgets/recent_messages_list.dart';
import '../../core/state/app_loading_service.dart';
import '../widgets/profile_menu_bottom_sheet.dart';
import '../widgets/lottie_loader.dart';
import 'smart_scanner_screen.dart';
import 'profile_screen.dart';
import 'smart_card_list_screen.dart';
import 'manage_cards/manage_card_screens.dart' as new_manage_cards;
import 'mycards.dart' as my_cards_list;
import 'contacts_screen.dart';
import 'messages_screen.dart';
import 'support_screen.dart';
import 'support_chat_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import '../../core/utils/responsive.dart';
import '../widgets/auto_loop_carousel.dart';
import '../widgets/premium_upgrade_dialog.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/reactive_contact_sync_service.dart';
import '../../core/services/app_update_service.dart';

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
    final authUser = ref.read(authViewModelProvider).currentUser;
    final cardVm = ref.read(cardViewModelProvider);
    final subVm = ref.read(subscriptionViewModelProvider);
    final userId = authUser?.id ?? '';

    if (userId.isNotEmpty && subVm.subscription == null) {
      await subVm.fetchSubscription(userId);
      if (!mounted) return;
    }

    final sub = subVm.subscription;
    if (sub == null && subVm.errorMessage != null && subVm.errorMessage!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(subVm.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final mem = (sub?.membership ?? '').trim().toUpperCase();
    final bool isPremium = sub != null && (sub.isActive || mem == 'PREMIUM' || mem == 'PAID');

    if (!isPremium && cardVm.cards.isNotEmpty) {
      PremiumUpgradeDialog.show(context);
    } else {
      await cardVm.handleAddMoreCard(context, masterProfile: authUser);
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
        ref.read(tabIndexProvider.notifier).setIndex(widget.initialIndex);
        ref.read(dashboardViewModelProvider).setIndex(widget.initialIndex);
      }
      try {
        ReactiveContactSyncService().initialize(
          contactProvider: ref.read(contactProviderRiverpod),
          contactViewModel: ref.read(contactViewModelProvider),
          dashboardViewModel: ref.read(dashboardViewModelProvider),
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
          contactProvider: ref.read(contactProviderRiverpod),
          contactViewModel: ref.read(contactViewModelProvider),
          dashboardViewModel: ref.read(dashboardViewModelProvider),
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
    final tabIndex = ref.watch(tabIndexProvider);
    final activeIndex = tabIndex;

    void setTab(int idx) {
      ref.read(tabIndexProvider.notifier).setIndex(idx);
      dashboardViewModel.setIndex(idx);
    }

    final List<Widget> pages = [
      _HomeBody(
        onProfileTap: () => ProfileMenuBottomSheet.show(context),
        onScanTap: () => setTab(1),
        onShareTap: () async {
          final cardVm = ref.read(cardViewModelProvider);
          final profileVm = ref.read(profileViewModelProvider);
          final currentCard = cardVm.currentCard;
          final targetUserId = profileVm.user?.id ?? currentCard?.accountUserId.toString() ?? '';
          if (currentCard != null) {
            final url = currentCard.qrData.isNotEmpty
                ? currentCard.qrData
                : ApiConfig.cardProfileUrl('${currentCard.userId}');
            await Share.share(url);
            profileVm.incrementShareCount(targetUserId);
          } else if (cardVm.cards.isNotEmpty) {
            final card = cardVm.cards.first;
            final url = card.qrData.isNotEmpty
                ? card.qrData
                : ApiConfig.cardProfileUrl('${card.userId}');
            await Share.share(url);
            profileVm.incrementShareCount(targetUserId);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No card available to share.')),
            );
          }
        },
        isActive: activeIndex == 0,
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
        if (activeIndex != 0) {
          setTab(0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: colors.backgroundStart,
        // Dynamic AppBar based on selected tab
        appBar: (activeIndex == 3)
            ? null
            : MasterAppBar(
                titleText: _getTitle(activeIndex),
                style: MasterHeaderStyle.gradient,
                showBackButton: false,
                showThemeToggle: false,
                onProfileTap: () => ProfileMenuBottomSheet.show(context),
              ),
        body: IndexedStack(
          index: activeIndex,
          children: pages,
        ),
        floatingActionButton: activeIndex == 0 
            ? _ExpandableFAB(
                onScanTap: () => setTab(1),
                onCreateTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const new_manage_cards.ManageCardsScreen()));
                },
              )
            : null,
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
      final authViewModel = ref.read(authViewModelProvider);
      if (authViewModel.isAuthenticated) {
        final user = authViewModel.currentUser;
        final userId = user?.id;
        if (userId == null || userId.isEmpty) return;

        AppLoadingService.instance.run(() => Future.wait([
          ref.read(cardViewModelProvider).fetchCards(
            userId,
            fallbackName: user?.displayName,
            fallbackPhone: user?.phone ?? '',
            fallbackEmail: user?.email,
          ),
          ref.read(profileViewModelProvider).loadProfile(userId),
          ref.read(subscriptionViewModelProvider).fetchSubscription(userId),
          ref.read(contactViewModelProvider).loadContactsFromBackend(),
          ref.read(messageViewModelProvider).loadMessages(),
        ]));

        // Start global polling so new admin messages are detected
        // even when the Messages tab is not open.
        final msgVm = ref.read(messageViewModelProvider);
        if (!msgVm.isPolling) {
          msgVm.startPolling();
        }
      }
    });
  }

  @override
  void dispose() {
    // Keep polling alive; it is a global ChangeNotifier — do NOT stop it here.
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    final authViewModel = ref.read(authViewModelProvider);
    if (authViewModel.isAuthenticated) {
      final user = authViewModel.currentUser;
      final userId = user?.id;
      if (userId == null || userId.isEmpty) return;
      ref.read(cardViewModelProvider).fetchCards(
        userId,
        fallbackName: user?.displayName,
        fallbackPhone: user?.phone ?? '',
        fallbackEmail: user?.email,
      );
      ref.read(profileViewModelProvider).loadProfile(userId);
      ref.read(contactViewModelProvider).loadContactsFromBackend();
      ref.read(messageViewModelProvider).loadMessages();
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

              // 2. Quick Actions Block
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'QUICK ACTIONS',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: colors.text, // or Colors.white in dark mode
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
                        ref.read(tabIndexProvider.notifier).setIndex(2);
                        ref.read(dashboardViewModelProvider).setIndex(2);
                      },
                      isPrimary: false,
                    ),
                    _QuickActionCard(
                      icon: Icons.qr_code_scanner,
                      label: 'Scan',
                      colors: colors,
                      onTap: widget.onScanTap,
                    ),
                    _QuickActionCard(
                      icon: Icons.share_outlined,
                      label: 'Share',
                      colors: colors,
                      onTap: widget.onShareTap,
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
                            profileViewModel.incrementCardViews(card.accountUserId.toString());
                            cardViewModel.setCurrentIndex(realIndex);
                            ref.read(tabIndexProvider.notifier).setIndex(9); // Navigate to Shared Card Screen
                            ref.read(dashboardViewModelProvider).setIndex(9);
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
                        ref.read(tabIndexProvider.notifier).setIndex(5); // Messages tab
                        ref.read(dashboardViewModelProvider).setIndex(5);
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
                        ref.read(tabIndexProvider.notifier).setIndex(1); // Navigate to scan tab
                        ref.read(dashboardViewModelProvider).setIndex(1);
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

class _ExpandableFAB extends StatefulWidget {
  final VoidCallback onScanTap;
  final VoidCallback onCreateTap;

  const _ExpandableFAB({
    required this.onScanTap,
    required this.onCreateTap,
  });

  @override
  State<_ExpandableFAB> createState() => _ExpandableFABState();
}

class _ExpandableFABState extends State<_ExpandableFAB> with SingleTickerProviderStateMixin {
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

class _ExpandableFABAction extends StatelessWidget {
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
  Widget build(BuildContext context) {
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

class _QuickActionCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isPrimary ? AppColors.primaryRed : AppColors.primaryRed.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryRed, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryRed.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon, 
                color: isPrimary ? Colors.white : AppColors.primaryRed, 
                size: 28
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500, // Medium weight
                  color: isPrimary ? Colors.white : AppColors.primaryRed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
