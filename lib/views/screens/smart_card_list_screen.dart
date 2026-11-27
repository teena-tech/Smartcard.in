import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/app_riverpod_providers.dart';
import '../../models/card_model.dart';
import '../../core/network/api_config.dart';
import '../../core/utils/app_haptics.dart';
import '../widgets/premium_card_widget.dart';
import '../widgets/digital_corporate_card_widget.dart';
import '../widgets/premium_upgrade_dialog.dart';
import '../../core/utils/card_expansion_route.dart';
import 'customize/customize_menu_screen.dart';
import 'home_screen.dart';
import '../widgets/master_app_bar.dart';
import '../widgets/master_bottom_nav.dart';
import 'manage_cards/manage_card_screens.dart' as new_manage_cards;

class SmartCardListScreen extends ConsumerStatefulWidget {
  final bool isTab;
  const SmartCardListScreen({super.key, this.isTab = false});

  @override
  ConsumerState<SmartCardListScreen> createState() => _SmartCardListScreenState();
}

class _SmartCardListScreenState extends ConsumerState<SmartCardListScreen> {
  void _openCardProfileDetail(CardModel card, int index) {
    try {
      final cardViewModel = ref.read(cardViewModelProvider);
      if (index >= 0) {
        cardViewModel.setCurrentIndex(index);
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => new_manage_cards.ManageCardsScreen(initialCard: card),
        ),
      );
    } catch (e, stack) {
      debugPrint('🚨 Error in _openCardProfileDetail: $e\n$stack');
    }
  }

  Future<void> _handleCreateNewCard() async {
    final authUser = ref.read(authViewModelProvider).currentUser;
    final cardViewModel = ref.read(cardViewModelProvider);
    final subscriptionViewModel = ref.read(subscriptionViewModelProvider);
    final cards = cardViewModel.cards;
    final userId = authUser?.id ?? '';

    if (userId.isNotEmpty && subscriptionViewModel.subscription == null) {
      await subscriptionViewModel.fetchSubscription(userId);
      if (!mounted) return;
    }

    final sub = subscriptionViewModel.subscription;
    if (sub == null && subscriptionViewModel.errorMessage != null && subscriptionViewModel.errorMessage!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(subscriptionViewModel.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final mem = (sub?.membership ?? '').trim().toUpperCase();
    final bool isPremium = sub != null && (sub.isActive || mem == 'PREMIUM' || mem == 'PAID');

    if (!isPremium && cards.isNotEmpty) {
      PremiumUpgradeDialog.show(context);
    } else {
      await cardViewModel.handleAddMoreCard(context, masterProfile: authUser);
    }
  }



  /// Non-Editable Preview Sheet: Shows full interactive card preview without customize controls
  void _showOrganizationNonEditablePreview(BuildContext context, CardModel card) {
    AppHaptics.selection();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF0A1220),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF38BDF8), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Organization Card Preview',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Non-Editable Visual Identity & Theme',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF7DD3FC),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                children: [
                  // Notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1E36),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_rounded, color: Color(0xFF38BDF8), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Card styling, theme colors, and layout are centrally locked by ${card.companyName.isNotEmpty ? card.companyName : "Organization"} to maintain brand guidelines. Visual modifications are read-only.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFFBAE6FD),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Digital Card presentation with flip
                  DigitalCorporateCardWidget(
                    card: card,
                    showLockDetails: true,
                  ),
                ],
              ),
            ),
            // Bottom Action
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF0284C7)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text('Open Live URL', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final uri = Uri.parse(card.qrData);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Done', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardViewModel = ref.watch(cardViewModelProvider);
    final allCards = cardViewModel.cards;

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
          // ── Card List View ───────────────────────────────────────
          Expanded(
            child: allCards.isEmpty
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
                          'No Smart Cards Yet',
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
                    itemCount: allCards.length + 1,
                    itemBuilder: (_, index) {
                      // End of list item: Create new card CTA
                      if (index == allCards.length) {
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

                      final card = allCards[index];
                      final originalIndex = index;
                      final sub = ref.read(subscriptionViewModelProvider).subscription;
                      final isUserPremium = sub != null && (sub.isActive || sub.membership.toUpperCase() == 'PREMIUM');
                      final canEditCard = card.isPrimary || isUserPremium;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: GestureDetector(
                          onTap: () {
                            _openCardProfileDetail(card, originalIndex >= 0 ? originalIndex : index);
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PremiumCardWidget(
                                card: card,
                                margin: EdgeInsets.zero,
                                onTap: () {
                                  _openCardProfileDetail(card, originalIndex >= 0 ? originalIndex : index);
                                },
                                bottomActions: (!canEditCard && !card.isOrganization || card.isSuspended)
                                    ? null
                                    : Row(
                                        children: [
                                          // ── Details Button ─────────────────────
                                          Expanded(
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20)),
                                                onTap: () {
                                                  _openCardProfileDetail(card, originalIndex >= 0 ? originalIndex : index);
                                                },
                                                child: Center(
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        card.isOrganization
                                                            ? Icons.lock_outline_rounded
                                                            : Icons.assignment_outlined,
                                                        color: Colors.white,
                                                        size: 15,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        card.isOrganization ? 'Details' : 'Details',
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
                                          // ── Customize Button ───────────────────
                                          Expanded(
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () async {
                                                  if (card.isOrganization) {
                                                    // Organization card: Show non-editable preview!
                                                    _showOrganizationNonEditablePreview(context, card);
                                                  } else {
                                                    // Personal card: Standard editable customize
                                                    cardViewModel.setCurrentIndex(originalIndex >= 0 ? originalIndex : index);
                                                    if (context.mounted) {
                                                      await Navigator.push(
                                                        context,
                                                        CardExpansionPageRoute(
                                                          page: const CustomizeMenuScreen(),
                                                        ),
                                                      );
                                                      if (!context.mounted) return;
                                                      final authVm = ref.read(authViewModelProvider);
                                                      if (authVm.currentUser?.id != null) {
                                                        final userModel = authVm.currentUser!;
                                                        cardViewModel.fetchCards(
                                                          userModel.id!,
                                                          fallbackName: userModel.displayName,
                                                          fallbackPhone: userModel.phone ?? '',
                                                          fallbackEmail: userModel.email,
                                                        );
                                                      }
                                                    }
                                                  }
                                                },
                                                child: Center(
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        card.isOrganization
                                                            ? Icons.visibility_outlined
                                                            : Icons.palette,
                                                        color: Colors.white,
                                                        size: 15,
                                                      ),
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
                                          // ── Preview Button ─────────────────────
                                          Expanded(
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius: const BorderRadius.only(bottomRight: Radius.circular(20)),
                                                onTap: () async {
                                                  cardViewModel.setCurrentIndex(originalIndex >= 0 ? originalIndex : index);
                                                  ref.read(profileViewModelProvider).incrementCardViews(card.accountUserId.toString());
                                                  final liveLink = ApiConfig.resolveLiveCardUrl(
                                                    qrCode: card.qrCode,
                                                    profileUrl: card.profileUrl,
                                                    workProfileId: '${card.workProfileId}',
                                                  );
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
                                              await cardViewModel.toggleSuspensionForCardIndex(
                                                originalIndex >= 0 ? originalIndex : index,
                                              );
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
                              else if (!canEditCard && !card.isOrganization)
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
                        ),
                      );
                    },
                  ),
          ),
          if (allCards.isEmpty)
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
        titleText: 'MY CARDS',
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
