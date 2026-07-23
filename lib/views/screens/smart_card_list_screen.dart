import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../viewmodels/card_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../models/card_model.dart';
import '../widgets/premium_card_widget.dart';
import '../widgets/premium_upgrade_dialog.dart';
import 'customize/customize_menu_screen.dart';
import 'home_screen.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';

class SmartCardListScreen extends StatefulWidget {
  final bool isTab;
  const SmartCardListScreen({super.key, this.isTab = false});

  @override
  State<SmartCardListScreen> createState() => _SmartCardListScreenState();
}

class _SmartCardListScreenState extends State<SmartCardListScreen> {
  

  void _showLivePreviewModal(BuildContext context, CardModel card) {
    showDialog(
      context: context,
      builder: (context) {
        final linkToDisplay = (card.qrCode != null && card.qrCode!.isNotEmpty) 
            ? card.qrCode! 
            : 'https://www.google.com';

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.red, width: 2),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Live Card Preview',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  PremiumCardWidget(card: card),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: QrImageView(
                      data: linkToDisplay,
                      version: QrVersions.auto,
                      size: 140,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Scan or visit card link:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      try {
                        final uri = Uri.parse(linkToDisplay);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      } catch (_) {}
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        linkToDisplay,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'CLOSE',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardViewModel = context.watch<CardViewModel>();
    final subscriptionViewModel = context.watch<SubscriptionViewModel>();
    final cards = cardViewModel.cards;

    Widget body = Column(
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
                  itemBuilder: (context, index) {
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
                            onPressed: () {
                              final isPremium = subscriptionViewModel.subscription?.isActive == true &&
                                  subscriptionViewModel.subscription?.membership.toUpperCase() != 'FREE';
                              if (!isPremium && cards.isNotEmpty) {
                                PremiumUpgradeDialog.show(context);
                              } else if (isPremium && cards.length >= 5) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Maximum limit of 5 cards reached for Premium members.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } else {
                                cardViewModel.handleAddMoreCard(context, masterProfile: context.read<AuthViewModel>().currentUser);
                              }
                            },
                          ),
                        ),
                      );
                    }
                    final card = cards[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PremiumCardWidget(
                              card: card,
                              margin: EdgeInsets.zero,
                              bottomActions: card.isSuspended ? null : Row(
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
                                        String liveLink = 'https://thesmartcards.com/profile/${card.userId}';
                                        final dbQr = card.qrCode ?? '';
                                        if (dbQr.isNotEmpty) {
                                          try {
                                            final dbUri = Uri.parse(dbQr);
                                            final scVal = dbUri.queryParameters['sc'];
                                            if (scVal != null && scVal.isNotEmpty) {
                                              liveLink = 'https://thesmartcards.com/?sc=$scVal';
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
                          // Central Unsuspend Button
                          if (card.isSuspended)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                elevation: 8,
                              ),
                              onPressed: () {
                                cardViewModel.setCurrentIndex(index);
                                context.read<DashboardViewModel>().setIndex(2);
                                if (!widget.isTab) {
                                  Navigator.pop(context);
                                }
                              },
                              icon: const Icon(Icons.play_circle_fill, color: Colors.green),
                              label: Text(
                                'Tap to Unsuspend',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
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
                onPressed: () {
                  final isPremium = subscriptionViewModel.subscription?.isActive == true &&
                      subscriptionViewModel.subscription?.membership.toUpperCase() != 'FREE';
                  if (!isPremium && cards.isNotEmpty) {
                    PremiumUpgradeDialog.show(context);
                  } else if (isPremium && cards.length >= 5) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Maximum limit of 5 cards reached for Premium members.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else {
                    cardViewModel.handleAddMoreCard(context, masterProfile: context.read<AuthViewModel>().currentUser);
                  }
                },
              ),
            ),
          ),
      ],
    );

    if (widget.isTab) return body;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () {
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
        title: Text(
          'MY DIGITAL CARDS',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
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
