import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/card_viewmodel.dart';
import '../../viewmodels/message_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/file_downloader.dart';
import '../../models/card_model.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/upload_url_resolver.dart';
import '../widgets/common_drawer.dart';
import '../widgets/master_app_bar.dart';

/// Simple QR card viewer — manual swipe only, zero auto-scroll by design.
///
/// Uses [Selector] so it only rebuilds when [CardViewModel.cards] changes.
/// Changes to [CardViewModel.currentIndex] (driven by the home auto-carousel)
/// are completely ignored, so nothing on this screen ever moves on its own.
class MyCardsScreen extends StatefulWidget {
  final bool isStandalone;
  const MyCardsScreen({super.key, this.isStandalone = true});

  @override
  State<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends State<MyCardsScreen> {
  final Map<int, GlobalKey> _qrKeys = {};
  late final PageController _pageController;

  /// Local page index — driven only by user's own swipe.
  int _page = 0;

  /// Virtual page multiplier for infinite loop effect.
  static const int _kMultiplier = 10000;

  @override
  void initState() {
    super.initState();
    // Start in the middle of the virtual list for infinite loop in both directions.
    _pageController = PageController(
      initialPage: _kMultiplier ~/ 2,
    );
    _page = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final msgVm = context.read<MessageViewModel>();
      if (msgVm.messages.isEmpty && !msgVm.isLoading) {
        msgVm.loadMessages();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  GlobalKey _getQrKey(int index) =>
      _qrKeys.putIfAbsent(index, () => GlobalKey());

  // ─── Actions ────────────────────────────────────────────────────────────────

  void _showSuspendedSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _copyLink(CardModel card) {
    if (card.isSuspended) {
      _showSuspendedSnackBar('Card is suspended. Unsuspend in Manage Cards to copy link.');
      return;
    }
    final url = card.qrData;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Link copied!')));
  }

  void _shareLink(CardModel card) {
    if (card.isSuspended) {
      _showSuspendedSnackBar('Card is suspended. Unsuspend in Manage Cards to share.');
      return;
    }
    final url = card.qrData;
    // ignore: deprecated_member_use
    Share.share(url);
    context.read<ProfileViewModel>().incrementShareCount(card.accountUserId.toString());
  }

  Future<void> _downloadPng(int index, CardModel card) async {
    if (card.isSuspended) {
      _showSuspendedSnackBar('Card is suspended. Unsuspend in Manage Cards to download PNG.');
      return;
    }
    try {
      final boundary = _qrKeys[index]?.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate QR code PNG image.')),
        );
        return;
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final cleanName = (card.companyName.isNotEmpty ? card.companyName : card.name)
          .replaceAll(RegExp(r'[^\w\.-]'), '_');
      final fileName = '${cleanName}_QR.png';

      await saveFileToDevice(fileName, byteData.buffer.asUint8List());

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'PNG image downloaded successfully! ($fileName)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          content: Text('PNG download error: $e'),
        ),
      );
    }
  }

  Future<void> _downloadSvg(CardModel card) async {
    if (card.isSuspended) {
      _showSuspendedSnackBar('Card is suspended. Unsuspend in Manage Cards to download SVG.');
      return;
    }
    try {
      final url = card.qrData;
      final result = QrValidator.validate(
          data: url,
          version: QrVersions.auto,
          errorCorrectionLevel: QrErrorCorrectLevel.M);
      if (result.status != QrValidationStatus.valid) return;
      final qr = QrImage(result.qrCode!);
      final n = qr.moduleCount;
      final buf = StringBuffer()
        ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
        ..writeln('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $n $n">')
        ..writeln('<rect width="100%" height="100%" fill="#ffffff"/>');
      for (var x = 0; x < n; x++) {
        for (var y = 0; y < n; y++) {
          if (qr.isDark(y, x)) {
            buf.writeln('<rect x="$x" y="$y" width="1" height="1" fill="#20263A"/>');
          }
        }
      }
      buf.writeln('</svg>');

      final cleanName = (card.companyName.isNotEmpty ? card.companyName : card.name)
          .replaceAll(RegExp(r'[^\w\.-]'), '_');
      final fileName = '${cleanName}_QR.svg';

      await saveFileToDevice(
          fileName, Uint8List.fromList(utf8.encode(buf.toString())));

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'SVG image downloaded successfully! ($fileName)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          content: Text('SVG download error: $e'),
        ),
      );
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;

    // Selector fires ONLY when cards list changes.
    // Home carousel's setCurrentIndex() is invisible to this widget.
    return Selector<CardViewModel, List<CardModel>>(
      selector: (_, vm) => vm.cards,
      builder: (context, cards, _) {
        if (cards.isEmpty) {
          return _wrap(
            child: Center(
              child: Text('No cards available.',
                  style: GoogleFonts.inter(color: colors.muted)),
            ),
            colors: colors,
          );
        }

        // Clamp page in case cards shrink
        if (_page >= cards.length) {
          _page = cards.length - 1;
        }

        final body = SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // ── Swipeable card area ──────────────────────────────────────
              SizedBox(
                height: 650,
                child: PageView.builder(
                  controller: _pageController,
                  physics: const PageScrollPhysics(),
                  itemCount: cards.length > 1 ? _kMultiplier : 1,
                  onPageChanged: (virtual) =>
                      setState(() => _page = virtual % cards.length),
                  itemBuilder: (_, virtual) {
                    final i = cards.length > 1 ? virtual % cards.length : 0;
                    return _CardQrPage(
                      key: ValueKey('card_$i'),
                      card: cards[i],
                      qrKey: _getQrKey(i),
                      colors: colors,
                      onCopy: () => _copyLink(cards[i]),
                      onShare: () => _shareLink(cards[i]),
                      onDownloadPng: () => _downloadPng(i, cards[i]),
                      onDownloadSvg: () => _downloadSvg(cards[i]),
                    );
                  },
                ),
              ),
              // ── Dot indicators ───────────────────────────────────────────
              if (cards.length > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(cards.length, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.primaryRed : colors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        );

        return _wrap(child: body, colors: colors);
      },
    );
  }

  Widget _wrap({required Widget child, required AppColors colors}) {
    final decoratedChild = Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/login.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
    if (widget.isStandalone) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        drawer: const CommonDrawer(currentRoute: 'My Cards'),
        appBar: const MasterAppBar(
          titleText: 'SHARE CARD',
          style: MasterHeaderStyle.gradient,
        ),
        body: decoratedChild,
      );
    }
    return decoratedChild;
  }
}

// ─── Single card + QR page (extracted widget for clarity) ───────────────────

class _CardQrPage extends StatelessWidget {
  final CardModel card;
  final GlobalKey qrKey;
  final AppColors colors;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onDownloadPng;
  final VoidCallback onDownloadSvg;

  const _CardQrPage({
    super.key,
    required this.card,
    required this.qrKey,
    required this.colors,
    required this.onCopy,
    required this.onShare,
    required this.onDownloadPng,
    required this.onDownloadSvg,
  });

  @override
  Widget build(BuildContext context) {
    final isSuspended = card.isSuspended;

    return ResponsiveCenter(
      maxWidth: 600,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Suspended Badge Header
            if (isSuspended) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, color: Colors.redAccent, size: 10),
                    const SizedBox(width: 6),
                    Text(
                      'Suspended',
                      style: GoogleFonts.inter(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 1. Company Logo (Top-most, outside the card frame)
            if (card.companyLogo != null &&
                card.companyLogo!.isNotEmpty) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 72),
                child: Image.network(
                  UploadUrlResolver.resolve(card.companyLogo!,
                      type: 'logo'),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 2. Organization Name (Middle)
            Text(
              (card.companyName.isNotEmpty ? card.companyName : card.name)
                  .toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colors.text,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),

            // 3. QR Code inside a white card frame (Blurred & Locked if Suspended)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RepaintBoundary(
                    key: qrKey,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: isSuspended ? 14 : 0,
                        sigmaY: isSuspended ? 14 : 0,
                      ),
                      child: Container(
                        color: Colors.white,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            QrImageView(
                              data: card.qrData,
                              version: QrVersions.auto,
                              size: 200,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF20263A),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF20263A),
                              ),
                              backgroundColor: Colors.white,
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isSuspended)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_rounded, color: Colors.redAccent, size: 32),
                          const SizedBox(height: 6),
                          Text(
                            'CARD SUSPENDED',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            'QR Unscannable',
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 4. Dedicated section displaying full url (Disabled styling if suspended)
            Opacity(
              opacity: isSuspended ? 0.5 : 1.0,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: colors.panel.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        card.qrData,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onCopy,
                      icon: Icon(isSuspended ? Icons.block : Icons.copy_rounded, size: 18),
                      color: isSuspended ? Colors.grey : AppColors.primaryRed,
                      tooltip: isSuspended ? 'Suspended' : 'Copy Link',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.border.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons (Disabled styling if suspended)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                _ActionBtn(
                  icon: isSuspended ? Icons.block : Icons.share,
                  label: 'Share',
                  onTap: onShare,
                  colors: colors,
                  disabled: isSuspended,
                ),
                _ActionBtn(
                  icon: isSuspended ? Icons.block : Icons.download_rounded,
                  label: 'PNG',
                  onTap: onDownloadPng,
                  colors: colors,
                  disabled: isSuspended,
                ),
                _ActionBtn(
                  icon: isSuspended ? Icons.block : Icons.download_rounded,
                  label: 'SVG',
                  onTap: onDownloadSvg,
                  colors: colors,
                  disabled: isSuspended,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppColors colors;
  final bool disabled;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: Column(
        children: [
          InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Icon(icon, color: disabled ? Colors.grey : colors.text, size: 24),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: disabled ? Colors.grey : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}