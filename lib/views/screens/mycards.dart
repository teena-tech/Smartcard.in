import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_riverpod_providers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/contact_model.dart';
import '../../models/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/vcard_photo_service.dart';
import '../../core/utils/file_downloader.dart';
import '../../core/utils/upload_url_resolver.dart';
import '../../models/card_model.dart';
import '../../core/utils/responsive.dart';
import '../widgets/common_drawer.dart';
import '../widgets/master_app_bar.dart';

/// Simple QR card viewer — manual swipe only, zero auto-scroll by design.
class MyCardsScreen extends ConsumerStatefulWidget {
  final bool isStandalone;
  const MyCardsScreen({super.key, this.isStandalone = true});

  /// Formats the Contact QR clipboard text with icons and digital card link.
  static String buildContactCopyText({
    required String name,
    required String designation,
    required String company,
    required String phone,
    required String cardUrl,
  }) {
    final cleanName = name.trim();
    final cleanDesignation = designation.trim();
    final cleanCompany =
        company.trim().toLowerCase() == 'null' ? '' : company.trim();
    final cleanPhone = phone.trim();
    final cleanUrl = cardUrl.trim();

    final lines = <String>[
      if (cleanName.isNotEmpty) '👤 $cleanName',
      if (cleanDesignation.isNotEmpty) '💻 $cleanDesignation',
      if (cleanCompany.isNotEmpty) '🏢 $cleanCompany',
      if (cleanPhone.isNotEmpty) '📞 $cleanPhone',
    ];

    if (cleanUrl.isNotEmpty) {
      if (lines.isNotEmpty) lines.add('');
      lines.add('🔗 View Digital Card: $cleanUrl');
    }
    return lines.join('\n');
  }

  @override
  ConsumerState<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends ConsumerState<MyCardsScreen> {
  final Map<int, GlobalKey> _contactQrKeys = {};
  final Map<int, GlobalKey> _webQrKeys = {};
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
      final msgVm = ref.read(messageViewModelProvider);
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

  GlobalKey _getContactQrKey(int index) =>
      _contactQrKeys.putIfAbsent(index, () => GlobalKey());
  GlobalKey _getWebQrKey(int index) =>
      _webQrKeys.putIfAbsent(index, () => GlobalKey());

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
    HapticFeedback.lightImpact();
    final url = card.qrData;
    Clipboard.setData(ClipboardData(text: url));
    _showCopiedWithDeleteSnackBar(context, 'Link copied!');
  }

  /// Clears the system clipboard and displays a confirmation floating bar.
  static Future<void> _clearClipboardAndNotify(BuildContext context) async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(const ClipboardData(text: ''));
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1F2430),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
            SizedBox(width: 10),
            Text(
              'Clipboard cleared!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  static void _showCopiedWithDeleteSnackBar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1F2430),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
            TextButton.icon(
              onPressed: () => _clearClipboardAndNotify(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Colors.redAccent.withValues(alpha: 0.14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _isValidStr(String? val) =>
      val != null &&
      val.trim().isNotEmpty &&
      val.trim().toLowerCase() != 'null' &&
      val.trim().toLowerCase() != 'undefined';

  static String _extractPrimaryPhone(CardModel card, {UserModel? user}) {
    final candidates = <String>[
      card.phone,
      if (card.isPrimary && user?.phone != null) user!.phone!,
      if (user?.phone != null) user!.phone!,
    ];
    for (final raw in candidates) {
      if (!_isValidStr(raw)) continue;
      final cleaned = raw.replaceAll(RegExp(r'[\[\]"]'), '');
      final tokens = cleaned
          .split(RegExp(r'[\n/,;]'))
          .map((e) => e.trim())
          .where((e) => _isValidStr(e))
          .toList();
      if (tokens.isNotEmpty) {
        return tokens.first;
      }
    }
    return '';
  }

  static String _resolveDesignation(CardModel card, {UserModel? user}) {
    if (_isValidStr(card.designation)) return card.designation!.trim();
    if (card.isPrimary && _isValidStr(user?.profession)) {
      return user!.profession!.trim();
    }
    return '';
  }

  static String? _resolveProfileImage(
    CardModel card,
    List<CardModel> allCards, {
    UserModel? user,
  }) {
    if (_isValidStr(card.profileImageName)) return card.profileImageName!.trim();
    if (card.isPrimary && _isValidStr(user?.profileImage)) {
      return user!.profileImage!.trim();
    }
    for (final c in allCards) {
      if (_isValidStr(c.profileImageName)) return c.profileImageName!.trim();
    }
    if (_isValidStr(user?.profileImage)) return user!.profileImage!.trim();
    return null;
  }

  Rect? _getShareOriginRect() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    return null;
  }

  // TEMP TEST: Hardcoded public HTTPS .jpg URL in Contact QR (PHOTO;VALUE=URI:)
  // for testing Google Lens / Camera behavior with a direct .jpg HTTP path.
  static const String _tempDummyHardcodedJpegUrl =
      'https://randomuser.me/api/portraits/men/32.jpg';

  static ContactModel _buildShareContactModel(
    CardModel card, {
    required String primaryPhone,
    required String designation,
    String? profileImageUrl,
  }) {
    return ContactModel(
      name: card.name,
      jobTitle: designation,
      company: card.companyName,
      phone: primaryPhone,
      email: card.email ?? '',
      website: card.qrData,
      profileImageName: profileImageUrl,
    );
  }

  static String _buildContactQrVCard(
    CardModel card, {
    required String primaryPhone,
    required String designation,
    String? profileImageUrl,
  }) {
    return _buildShareContactModel(
      card,
      primaryPhone: primaryPhone,
      designation: designation,
      profileImageUrl: _tempDummyHardcodedJpegUrl,
    ).toVCard();
  }

  Future<void> _shareContactVCard(
    CardModel card, {
    required String primaryPhone,
    required String designation,
    String? profileImageUrl,
  }) async {
    if (card.isSuspended) {
      _showSuspendedSnackBar('Card is suspended. Unsuspend in Manage Cards to share.');
      return;
    }
    try {
      final originRect = _getShareOriginRect();
      final contact = _buildShareContactModel(
        card,
        primaryPhone: primaryPhone,
        designation: designation,
        profileImageUrl: profileImageUrl,
      );

      final vcfContent = await contact.toVCardWithPhoto(forQrCode: false);
      final tempDir = await getTemporaryDirectory();
      final sanitizedName = card.name
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .toLowerCase();
      final vcfFile = File('${tempDir.path}/$sanitizedName.vcf');
      await vcfFile.writeAsString(vcfContent);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(vcfFile.path, mimeType: 'text/vcard')],
          text: contact.toPlainText(),
          subject: '${card.name} - Digital Business Card',
          sharePositionOrigin: originRect,
        ),
      );

      if (!mounted) return;
      final profileVm = ref.read(profileViewModelProvider);
      final targetUserId = profileVm.user?.id ?? card.accountUserId.toString();
      profileVm.incrementShareCount(targetUserId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share contact: $e')),
      );
    }
  }

  void _shareWebLink(CardModel card) {
    if (card.isSuspended) {
      _showSuspendedSnackBar('Card is suspended. Unsuspend in Manage Cards to share.');
      return;
    }
    final url = card.qrData;
    // ignore: deprecated_member_use
    Share.share(url);
    final profileVm = ref.read(profileViewModelProvider);
    final targetUserId = profileVm.user?.id ?? card.accountUserId.toString();
    profileVm.incrementShareCount(targetUserId);
  }

  Future<void> _downloadPng(GlobalKey key, CardModel card, {required String suffix}) async {
    if (card.isSuspended) {
      _showSuspendedSnackBar('Card is suspended. Unsuspend in Manage Cards to download PNG.');
      return;
    }
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
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
      final fileName = '${cleanName}_${suffix}_QR.png';

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

  Future<void> _downloadSvg(
    String qrContent,
    CardModel card, {
    required String suffix,
  }) async {
    if (card.isSuspended) {
      _showSuspendedSnackBar('Card is suspended. Unsuspend in Manage Cards to download SVG.');
      return;
    }
    try {
      final result = QrValidator.validate(
          data: qrContent,
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
      final fileName = '${cleanName}_${suffix}_QR.svg';

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
    final colors = ref.watch(themeViewModelProvider).colors;
    final user = ref.watch(profileViewModelProvider).user;
    final cards = ref.watch(cardViewModelProvider).cards;

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

        final body = Column(
          children: [
            const SizedBox(height: 12),
            // ── Swipeable card area (horizontal between cards) ─────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const PageScrollPhysics(),
                itemCount: cards.length > 1 ? _kMultiplier : 1,
                onPageChanged: (virtual) =>
                    setState(() => _page = virtual % cards.length),
                itemBuilder: (_, virtual) {
                  final i = cards.length > 1 ? virtual % cards.length : 0;
                  final card = cards[i];
                  final contactKey = _getContactQrKey(i);
                  final webKey = _getWebQrKey(i);
                  final primaryPhone = _extractPrimaryPhone(card, user: user);
                  final designation = _resolveDesignation(card, user: user);
                  final profileImageUrl = _resolveProfileImage(card, cards, user: user);

                  final vCardData = _buildContactQrVCard(
                    card,
                    primaryPhone: primaryPhone,
                    designation: designation,
                    profileImageUrl: profileImageUrl,
                  );

                  final qrPage = _CardQrPage(
                    key: ValueKey('card_$i'),
                    card: card,
                    primaryPhone: primaryPhone,
                    designation: designation,
                    profileImageUrl: profileImageUrl,
                    contactQrKey: contactKey,
                    webQrKey: webKey,
                    colors: colors,
                    onCopy: () => _copyLink(card),
                    onShareContact: () => _shareContactVCard(
                      card,
                      primaryPhone: primaryPhone,
                      designation: designation,
                      profileImageUrl: profileImageUrl,
                    ),
                    onShareWeb: () => _shareWebLink(card),
                    onDownloadContactPng: () => _downloadPng(contactKey, card, suffix: 'Contact'),
                    onDownloadContactSvg: () => _downloadSvg(vCardData, card, suffix: 'Contact'),
                    onDownloadWebPng: () => _downloadPng(webKey, card, suffix: 'Web'),
                    onDownloadWebSvg: () => _downloadSvg(card.qrData, card, suffix: 'Web'),
                  );

                  if (cards.length <= 1) return qrPage;

                  return AnimatedBuilder(
                    animation: _pageController,
                    child: qrPage,
                    builder: (context, child) {
                      double pageOffset = 0.0;
                      if (_pageController.position.haveDimensions) {
                        final currentPage =
                            _pageController.page ?? _pageController.initialPage.toDouble();
                        pageOffset = (virtual - currentPage).clamp(-1.0, 1.0);
                      }
                      final angleY = pageOffset * 0.48;
                      final scale = 1.0 - 0.12 * pageOffset.abs();
                      final matrix = Matrix4.identity()
                        ..setEntry(3, 2, 0.0018)
                        ..rotateY(angleY);
                      return Transform.scale(
                        scale: scale,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: matrix,
                          child: child,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // ── Bottom White Card Strip (Which Card + Red Highlight) ────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFC40000).withValues(alpha: 0.22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC40000),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Card ${_page + 1}/${cards.length}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        (cards[_page].companyName.trim().isNotEmpty
                                ? cards[_page].companyName.trim()
                                : cards[_page].name.trim())
                            .toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFC40000),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    if (cards.length > 1) ...[
                      const SizedBox(width: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(cards.length, (i) {
                          final active = i == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 9 : 7,
                            height: active ? 9 : 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active ? const Color(0xFFC40000) : Colors.white,
                              border: active
                                  ? null
                                  : Border.all(
                                      color: Colors.black.withValues(alpha: 0.24),
                                      width: 1.0,
                                    ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );

    return _wrap(child: body, colors: colors);
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

class _CardQrPage extends StatefulWidget {
  final CardModel card;
  final String primaryPhone;
  final String designation;
  final String? profileImageUrl;
  final GlobalKey contactQrKey;
  final GlobalKey webQrKey;
  final AppColors colors;
  final VoidCallback onCopy;
  final VoidCallback onShareContact;
  final VoidCallback onShareWeb;
  final VoidCallback onDownloadContactPng;
  final VoidCallback onDownloadContactSvg;
  final VoidCallback onDownloadWebPng;
  final VoidCallback onDownloadWebSvg;

  const _CardQrPage({
    super.key,
    required this.card,
    required this.primaryPhone,
    required this.designation,
    this.profileImageUrl,
    required this.contactQrKey,
    required this.webQrKey,
    required this.colors,
    required this.onCopy,
    required this.onShareContact,
    required this.onShareWeb,
    required this.onDownloadContactPng,
    required this.onDownloadContactSvg,
    required this.onDownloadWebPng,
    required this.onDownloadWebSvg,
  });

  @override
  State<_CardQrPage> createState() => _CardQrPageState();
}

class _CardQrPageState extends State<_CardQrPage> with TickerProviderStateMixin {
  AnimationController? _flipAnimController;
  AnimationController get _flipController {
    if (_flipAnimController == null) {
      final ctrl = AnimationController.unbounded(
        vsync: this,
        value: 0.0,
      );
      ctrl.addListener(_onFlipTick);
      _flipAnimController = ctrl;
    }
    return _flipAnimController!;
  }

  AnimationController? _dotSpinController;
  AnimationController get _dotSpin => _dotSpinController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..repeat();

  bool _wasContactFace = true;
  bool _showCopyDelete = false;
  double _dragStartTurns = 0.0;
  Timer? _scrollSnapTimer;
  Timer? _copyDeleteTimer;

  void _prewarmVcfPhoto() {
    // Keep QR lean and fast-scannable (~57x57 modules), while pre-warming
    // the 256px JPEG Base64 photo so tapping Share (.vcf) is instantaneous.
    unawaited(VCardPhotoService.getVcfPhotoBase64(widget.profileImageUrl));
  }

  @override
  void initState() {
    super.initState();
    _flipController;
    _dotSpin;
    _prewarmVcfPhoto();
  }

  @override
  void didUpdateWidget(covariant _CardQrPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileImageUrl != widget.profileImageUrl) {
      _prewarmVcfPhoto();
    }
  }

  @override
  void dispose() {
    _scrollSnapTimer?.cancel();
    _copyDeleteTimer?.cancel();
    _flipAnimController?.removeListener(_onFlipTick);
    _flipAnimController?.dispose();
    _dotSpinController?.dispose();
    super.dispose();
  }

  bool _isContactForValue(double v) {
    final phase = ((v % 2.0) + 2.0) % 2.0;
    return phase < 0.5 || phase >= 1.5;
  }

  void _onFlipTick() {
    final isNowContact = _isContactForValue(_flipController.value);
    if (isNowContact != _wasContactFace) {
      _wasContactFace = isNowContact;
      _triggerHapticVibration();
    }
  }

  /// Continuous C1-smooth [0..1] cosine pulse with zero pause at loop boundaries.
  double _continuousPulse(double t) => 0.5 - 0.5 * math.cos(t * 2 * math.pi);

  void _triggerHapticVibration() {
    if (Platform.isAndroid) {
      HapticFeedback.vibrate();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  void _animateToMode(int targetMode) {
    final nearest = _flipController.value.roundToDouble();
    final isCurrentlyContact = nearest.round().isEven;
    if ((targetMode == 0) == isCurrentlyContact) {
      if ((_flipController.value - nearest).abs() < 0.001) return;
      _flipController.animateTo(
        nearest,
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    final target = targetMode == 1 ? nearest + 1.0 : nearest - 1.0;
    _flipController.animateTo(
      target,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeInOutSine,
    );
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _scrollSnapTimer?.cancel();
    _flipController.stop();
    _dragStartTurns = _flipController.value.roundToDouble();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _flipController.value += -details.delta.dy / 185.0;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final vy = details.primaryVelocity ?? 0.0;
    final current = _flipController.value;
    final double target;
    if (vy < -150) {
      target = current > _dragStartTurns + 0.05
          ? current.ceilToDouble()
          : _dragStartTurns + 1.0;
    } else if (vy > 150) {
      target = current < _dragStartTurns - 0.05
          ? current.floorToDouble()
          : _dragStartTurns - 1.0;
    } else {
      final delta = current - _dragStartTurns;
      if (delta.abs() >= 0.5) {
        target = current.roundToDouble();
      } else if (delta >= 0.18) {
        target = _dragStartTurns + 1.0;
      } else if (delta <= -0.18) {
        target = _dragStartTurns - 1.0;
      } else {
        target = _dragStartTurns;
      }
    }
    _flipController.animateTo(
      target,
      duration: const Duration(milliseconds: 440),
      curve: Curves.easeOutCubic,
    );
  }

  void _onVerticalDragCancel() {
    _flipController.animateTo(
      _flipController.value.roundToDouble(),
      duration: const Duration(milliseconds: 440),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
      _scrollSnapTimer?.cancel();
      _flipController.stop();
      _flipController.value += event.scrollDelta.dy / 160.0;
      _scrollSnapTimer = Timer(const Duration(milliseconds: 160), () {
        if (!mounted) return;
        _flipController.animateTo(
          _flipController.value.roundToDouble(),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  void _activateCopyDelete() {
    _copyDeleteTimer?.cancel();
    if (!_showCopyDelete) {
      setState(() => _showCopyDelete = true);
    }
    _copyDeleteTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() => _showCopyDelete = false);
    });
  }

  Future<void> _clearCopiedFromBox() async {
    _copyDeleteTimer?.cancel();
    if (_showCopyDelete) {
      setState(() => _showCopyDelete = false);
    }
    await _MyCardsScreenState._clearClipboardAndNotify(context);
  }

  void _handleCopy(bool isContact) {
    if (widget.card.isSuspended) return;
    if (isContact) {
      _copyContactDetails();
    } else {
      widget.onCopy();
      _activateCopyDelete();
    }
  }

  void _copyContactDetails() {
    final card = widget.card;
    if (card.isSuspended) return;
    HapticFeedback.lightImpact();

    final displayName = card.name.trim().isNotEmpty
        ? card.name.trim()
        : card.companyName.trim();
    final formatted = MyCardsScreen.buildContactCopyText(
      name: displayName,
      designation: widget.designation,
      company: card.companyName,
      phone: widget.primaryPhone,
      cardUrl: card.qrData,
    );

    Clipboard.setData(ClipboardData(text: formatted));
    _activateCopyDelete();
    _MyCardsScreenState._showCopiedWithDeleteSnackBar(
      context,
      'Contact details copied!',
    );
  }

  Widget _buildQrCard({
    required GlobalKey qrKey,
    required String qrData,
    required bool isSuspended,
  }) {
    return Container(
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
                      data: qrData,
                      version: QrVersions.auto,
                      errorCorrectionLevel: QrErrorCorrectLevel.L,
                      size: 220,
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
    );
  }

  Widget _buildIndicatorDot({
    required bool isActive,
    required double spinProgress,
    required double pulse,
    required VoidCallback onTap,
  }) {
    const bloodyRed = Color(0xFFC40000);
    final activeScale = 0.96 + 0.12 * pulse;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: SizedBox(
          width: 22,
          height: 22,
          child: Center(
            child: isActive
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: spinProgress * 2 * math.pi,
                        child: const CustomPaint(
                          size: Size(19, 19),
                          painter: _OrbitArcPainter(),
                        ),
                      ),
                      Transform.scale(
                        scale: activeScale,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: bloodyRed,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF1A1A)
                                    .withValues(alpha: 0.45 + 0.35 * pulse),
                                blurRadius: 6 + 4 * pulse,
                                spreadRadius: 0.8 * pulse,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.24),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalReelsIndicators() {
    return AnimatedBuilder(
      animation: Listenable.merge([_flipController, _dotSpin]),
      builder: (context, _) {
        final isContact = _isContactForValue(_flipController.value);
        final spinProgress = _dotSpin.value;
        final pulse = _continuousPulse(spinProgress);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIndicatorDot(
              isActive: isContact,
              spinProgress: spinProgress,
              pulse: pulse,
              onTap: () => _animateToMode(0),
            ),
            const SizedBox(height: 2),
            _buildIndicatorDot(
              isActive: !isContact,
              spinProgress: spinProgress,
              pulse: pulse,
              onTap: () => _animateToMode(1),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompanyHeader(CardModel card, AppColors colors, bool isContact) {
    final titleText =
        (card.companyName.trim().isNotEmpty ? card.companyName.trim() : card.name.trim())
            .toUpperCase();
    final rawLogo = card.companyLogo?.trim() ?? '';
    final resolvedLogo = (rawLogo.isNotEmpty &&
            rawLogo.toLowerCase() != 'null' &&
            rawLogo.toLowerCase() != 'undefined')
        ? UploadUrlResolver.resolve(rawLogo, type: 'logo')
        : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFC40000).withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (resolvedLogo.isNotEmpty) ...[
                Container(
                  width: 34,
                  height: 34,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: CachedNetworkImage(
                      imageUrl: resolvedLogo,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => const Icon(
                        Icons.business_rounded,
                        size: 20,
                        color: Color(0xFFC40000),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  titleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFC40000).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isContact ? 'CONTACT QR' : 'WEB CODE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFC40000),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardFace({
    required int mode,
    required String vCardData,
    required String contactLabel,
  }) {
    final card = widget.card;
    final colors = widget.colors;
    final isSuspended = card.isSuspended;
    final isContact = mode == 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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

        // 1. Organization Logo + Name + Active QR Type Frame
        _buildCompanyHeader(card, colors, isContact),
        const SizedBox(height: 16),

        // 3. QR Code Frame
        _buildQrCard(
          qrKey: isContact ? widget.contactQrKey : widget.webQrKey,
          qrData: isContact ? vCardData : card.qrData,
          isSuspended: isSuspended,
        ),
        const SizedBox(height: 20),

        // 4. Pill down below QR code (with copy button)
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
                if (isContact) ...[
                  const Icon(
                    Icons.contact_phone_rounded,
                    size: 16,
                    color: AppColors.primaryRed,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    isContact ? contactLabel : card.qrData,
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
                  onPressed: isSuspended ? null : () => _handleCopy(isContact),
                  icon: Icon(
                    isSuspended ? Icons.block : Icons.copy_rounded,
                    size: 18,
                  ),
                  color: isSuspended ? Colors.grey : AppColors.primaryRed,
                  tooltip: isSuspended ? 'Suspended' : 'Copy',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.border.withValues(alpha: 0.3),
                  ),
                ),
                if (!isSuspended && _showCopyDelete) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: _clearCopiedFromBox,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                    ),
                    color: const Color(0xFFC40000),
                    tooltip: 'Delete',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          const Color(0xFFC40000).withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 5. Action buttons: Share, PNG, SVG
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: [
            _ActionBtn(
              icon: isSuspended ? Icons.block : Icons.share,
              label: 'Share',
              onTap: isContact ? widget.onShareContact : widget.onShareWeb,
              colors: colors,
              disabled: isSuspended,
            ),
            _ActionBtn(
              icon: isSuspended ? Icons.block : Icons.download_rounded,
              label: 'PNG',
              onTap: isContact ? widget.onDownloadContactPng : widget.onDownloadWebPng,
              colors: colors,
              disabled: isSuspended,
            ),
            _ActionBtn(
              icon: isSuspended ? Icons.block : Icons.download_rounded,
              label: 'SVG',
              onTap: isContact ? widget.onDownloadContactSvg : widget.onDownloadWebSvg,
              colors: colors,
              disabled: isSuspended,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    final vCardData = _MyCardsScreenState._buildContactQrVCard(
      card,
      primaryPhone: widget.primaryPhone,
      designation: widget.designation,
      profileImageUrl: widget.profileImageUrl,
    );

    final contactLabel = widget.primaryPhone.isNotEmpty
        ? 'Contact QR • ${widget.primaryPhone}'
        : 'Contact QR • ${card.name}';

    final contactFace = _buildCardFace(
      mode: 0,
      vCardData: vCardData,
      contactLabel: contactLabel,
    );
    final webFace = _buildCardFace(
      mode: 1,
      vCardData: vCardData,
      contactLabel: contactLabel,
    );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        onVerticalDragCancel: _onVerticalDragCancel,
        child: Stack(
          children: [
            Center(
              child: ResponsiveCenter(
                maxWidth: 600,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width > 600
                        ? 600
                        : MediaQuery.of(context).size.width,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Continuous bidirectional 1:1 3D Up & Down X-Axis Rotation
                          AnimatedBuilder(
                            animation: _flipController,
                            builder: (context, _) {
                              final v = _flipController.value;
                              final phase = ((v % 2.0) + 2.0) % 2.0;
                              final isContact = phase < 0.5 || phase >= 1.5;
                              final double angleX;
                              if (phase < 0.5) {
                                angleX = -phase * math.pi;
                              } else if (phase < 1.5) {
                                angleX = (1.0 - phase) * math.pi;
                              } else {
                                angleX = (2.0 - phase) * math.pi;
                              }
                              final depthFactor =
                                  math.sin((phase % 1.0) * math.pi).abs();
                              final scale = 1.0 - 0.10 * depthFactor;
                              final matrix = Matrix4.identity()
                                ..setEntry(3, 2, 0.0017)
                                ..rotateX(angleX);

                              return Transform.scale(
                                scale: scale,
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: matrix,
                                  child: RepaintBoundary(
                                    child: isContact ? contactFace : webFace,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // 6. Continuous smooth bloody-red bidirectional swipe cue
                          AnimatedBuilder(
                            animation: Listenable.merge([_flipController, _dotSpin]),
                            builder: (context, _) {
                              final isContact =
                                  _isContactForValue(_flipController.value);
                              final pulse = _continuousPulse(_dotSpin.value);
                              final beatScale = 1.0 + 0.04 * pulse;
                              const bloodyRed = Color(0xFFC40000);
                              return GestureDetector(
                                onTap: () => _animateToMode(isContact ? 1 : 0),
                                behavior: HitTestBehavior.opaque,
                                child: Transform.scale(
                                  scale: beatScale,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.94),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: bloodyRed.withValues(alpha: 0.35),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF1A1A)
                                              .withValues(alpha: 0.14 + 0.14 * pulse),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isContact
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons.keyboard_arrow_down_rounded,
                                          size: 18,
                                          color: bloodyRed,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isContact
                                              ? 'Contact QR  •  Swipe ↑ Web Code'
                                              : 'Web Code  •  Swipe ↓ Contact QR',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: bloodyRed.withValues(
                                              alpha: 0.88 + 0.12 * pulse,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.swap_vert_rounded,
                                          size: 16,
                                          color: bloodyRed,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
            // Right side vertical reels indicator dots
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: _buildVerticalReelsIndicators(),
              ),
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
            onTap: disabled
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onTap();
                  },
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

/// Paints a smooth bloody-red orbital arc rotated continuously around the
/// active Share Card indicator dot without pauses.
class _OrbitArcPainter extends CustomPainter {
  const _OrbitArcPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 2.2) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const sweep = math.pi * 1.45;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: 0.0,
        endAngle: sweep,
        colors: [
          Color(0x14C40000),
          Color(0xFFC40000),
          Color(0xFFFF2E2E),
        ],
        stops: [0.0, 0.7, 1.0],
      ).createShader(rect);

    canvas.drawArc(rect, 0.0, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbitArcPainter oldDelegate) => false;
}
