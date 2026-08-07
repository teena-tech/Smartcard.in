import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../viewmodels/card_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../widgets/premium_card_widget.dart';
import '../widgets/premium_upgrade_dialog.dart';
import 'customize/customize_menu_screen.dart';
import 'home_screen.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../widgets/master_app_bar.dart';
import '../widgets/global_bottom_nav.dart';

class SmartCardListScreen extends StatefulWidget {
  final bool isTab;
  const SmartCardListScreen({super.key, this.isTab = false});

  @override
  State<SmartCardListScreen> createState() => _SmartCardListScreenState();
}

class _SmartCardListScreenState extends State<SmartCardListScreen> {
  Future<void> _handleCreateNewCard() async {
    final authUser = context.read<AuthViewModel>().currentUser;
    final cardViewModel = context.read<CardViewModel>();
    final subscriptionViewModel = context.read<SubscriptionViewModel>();
    final cards = cardViewModel.cards;
    final userId = authUser?.id ?? '';

    if (userId.isNotEmpty && subscriptionViewModel.subscription == null) {
      await subscriptionViewModel.fetchSubscription(userId);
      if (!mounted) return;
    }

    final sub = subscriptionViewModel.subscription;
    bool isPremium = false;
    if (sub != null) {
      final mem = sub.membership.toUpperCase();
      if (sub.isActive || mem == 'PREMIUM' || mem == 'PAID' || mem != 'FREE') {
        isPremium = true;
      }
    } else if (authUser != null && userId.isNotEmpty) {
      // Logged in user fallback
      isPremium = true;
    }

    if (!isPremium && cards.isNotEmpty) {
      PremiumUpgradeDialog.show(context);
    } else {
      cardViewModel.handleAddMoreCard(context, masterProfile: authUser);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardViewModel = context.watch<CardViewModel>();
    final cards = cardViewModel.cards;

    Widget body = Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/login.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
        Expanded(
          child: cards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.credit_card_off_outlined,
                        size: 72,
                        color: Colors.grey.withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Cards Yet',
                        style: GoogleFonts.inter(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "CREATE NEW CARD" below to get started.',
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: cards.length + 1,
                  itemBuilder: (_, index) {
                    if (index == cards.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const AnimatedHeartbeatIcon(),
                            label: Text(
                              'CREATE NEW CARD',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            onPressed: _handleCreateNewCard,
                          ),
                        ),
                      );
                    }
                    final card = cards[index];
                    final sub = context.read<SubscriptionViewModel>().subscription;
                    final isUserPremium = sub != null && (sub.isActive || sub.membership.toUpperCase() == 'PREMIUM');
                    final canEditCard = card.isPrimary || isUserPremium;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PremiumCardWidget(
                              card: card,
                              margin: EdgeInsets.zero,
                              bottomActions: (!canEditCard || card.isSuspended) ? null : Row(
                              children: [
                                // Details Button
                                Expanded(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20)),
                                      onTap: () {
                                        cardViewModel.setCurrentIndex(index);
                                        context.read<DashboardViewModel>().setIndex(2);
                                        if (!widget.isTab) {
                                          Navigator.pop(context);
                                        }
                                      },
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.assignment_outlined, color: Colors.white, size: 15),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Details',
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Divider
                                Container(
                                  width: 1,
                                  height: 18,
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                                // Customize Button
                                Expanded(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () async {
                                        cardViewModel.setCurrentIndex(index);
                                        if (context.mounted) {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const CustomizeMenuScreen(),
                                            ),
                                          );
                                          if (!context.mounted) return;
                                          final authVm = context.read<AuthViewModel>();
                                          if (authVm.currentUser?.id != null) {
                                            final user = authVm.currentUser!;
                                            cardViewModel.fetchCards(
                                              user.id!,
                                              fallbackName: user.displayName,
                                              fallbackPhone: user.phone ?? '',
                                              fallbackEmail: user.email,
                                            );
                                          }
                                        }
                                      },
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.palette, color: Colors.white, size: 15),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Customize',
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Divider
                                Container(
                                  width: 1,
                                  height: 18,
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                                // Preview Button
                                Expanded(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: const BorderRadius.only(bottomRight: Radius.circular(20)),
                                      onTap: () async {
                                        cardViewModel.setCurrentIndex(index);
                                        context.read<ProfileViewModel>().incrementCardViews(card.accountUserId.toString());
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
                                      },
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.remove_red_eye, color: Colors.white, size: 15),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Preview',
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Central Unsuspend Button or Premium Upgrade Badge
                          if (card.isSuspended)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                elevation: 8,
                              ),
                              icon: const Icon(Icons.play_circle_fill, color: Colors.green),
                              label: Text(
                                'UNSUSPEND CARD',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('Unsuspend Card', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                    content: Text(
                                      'Are you sure you want to unsuspend this card? It will become active again.',
                                      style: GoogleFonts.inter(),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          await cardViewModel.toggleSuspensionForCardIndex(index);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Unsuspend'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          else if (!canEditCard)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 1.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lock, color: Colors.amber, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Upgrade to Premium to Edit',
                                    style: GoogleFonts.inter(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (cards.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 45),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const AnimatedHeartbeatIcon(),
                label: Text(
                  'CREATE NEW CARD',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                onPressed: _handleCreateNewCard,
              ),
            ),
          ),
      ],
    ),
  );

    if (widget.isTab) return body;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: MasterAppBar(
        titleText: 'MY DIGITAL CARDS',
        style: MasterHeaderStyle.gradient,
        onBackTap: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          }
        },
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: body,
    );
  }
}

class AnimatedHeartbeatIcon extends StatefulWidget {
  const AnimatedHeartbeatIcon({super.key});

  @override
  State<AnimatedHeartbeatIcon> createState() => _AnimatedHeartbeatIconState();
}

class _AnimatedHeartbeatIconState extends State<AnimatedHeartbeatIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: const Icon(
        Icons.workspace_premium,
        size: 24,
        color: Colors.amber,
      ),
    );
  }
}
