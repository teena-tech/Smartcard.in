import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/features/messages_screen/presentation/viewmodel/message_viewmodel.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/core/utils/responsive.dart';
import 'package:smartcard_flutter/core/utils/upload_url_resolver.dart';
import 'package:smartcard_flutter/core/widgets/lottie_loader.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  // Banner animation
  late final AnimationController _bannerController;
  late final Animation<Offset> _bannerSlide;
  bool _showBanner = false;
  String _bannerText = '';
  String _bannerSub = '';

  @override
  void initState() {
    super.initState();

    // Set up slide-in banner animation
    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _bannerSlide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _bannerController, curve: Curves.easeOutBack));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = ref.read(messageViewModelProvider.notifier);
      // Do a fresh load when the screen opens
      vm.loadMessages();
      // Register for new-message notifications
      vm.addNewMessageListener(_onNewMessages);
    });
  }

  @override
  void dispose() {
    ref.read(messageViewModelProvider.notifier).removeNewMessageListener(_onNewMessages);
    _bannerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Called by MessageViewModel whenever new messages arrive during polling.
  void _onNewMessages(List<Map<String, dynamic>> arrived) {
    if (!mounted) return;
    final count = arrived.length;
    final firstTitle = arrived.first['title'] ?? arrived.first['subject'] ?? 'New message';

    setState(() {
      _bannerText = count == 1 ? firstTitle.toString() : '$count new messages received';
      _bannerSub = count == 1
          ? (arrived.first['summary'] ?? arrived.first['content'] ?? '').toString()
          : 'Tap to view all';
      _showBanner = true;
    });

    // Animate banner in
    _bannerController.forward(from: 0);

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      _bannerController.reverse().then((_) {
        if (mounted) setState(() => _showBanner = false);
      });
    });

    // Scroll to top so newest message is visible
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  void _dismissBanner() {
    _bannerController.reverse().then((_) {
      if (mounted) setState(() => _showBanner = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeViewModelProvider).colors;
    ref.watch(messageViewModelProvider);
    final viewModel = ref.read(messageViewModelProvider.notifier);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/login.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
        ResponsiveCenter(
          child: viewModel.isLoading
              ? const Center(child: LottieLoader(size: 80))
              : viewModel.error != null && viewModel.messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_off_rounded, size: 64, color: Colors.orange.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'Could not load messages',
                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: colors.text),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              viewModel.error!,
                              style: GoogleFonts.inter(fontSize: 13, color: colors.muted),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => viewModel.loadMessages(),
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text('Try Again', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : viewModel.messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined, size: 64, color: colors.muted.withValues(alpha: 0.4)),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: GoogleFonts.inter(fontSize: 16, color: colors.muted),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => viewModel.loadMessages(),
                          color: AppColors.primaryRed,
                          child: CustomScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'Total: ${viewModel.totalMessages}',
                                                style: GoogleFonts.inter(fontSize: 14, color: colors.text),
                                              ),
                                              const SizedBox(width: 16),
                                              if (viewModel.unreadCount > 0) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primaryRed,
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                    '${viewModel.unreadCount} unread',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          // Live indicator
                                          Row(
                                            children: [
                                              _LiveDot(),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Live',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Divider(color: colors.border),
                                    ],
                                  ),
                                ),
                              ),
                              Builder(
                                builder: (ctx) {
                                  final msgs = viewModel.messages;
                                  final unreadCount = msgs.where((m) {
                                    final a = m['user_action'];
                                    return a == null || (a is Map && a['read_at'] == null);
                                  }).length;
                                  final readCount = msgs.length - unreadCount;

                                  // Build items list with section headers inserted
                                  final items = <Widget>[];

                                  // ── UNREAD section ──────────────────────────
                                  if (unreadCount > 0) {
                                    items.add(
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 4,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryRed,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'UNREAD  ($unreadCount)',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryRed,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  for (int i = 0; i < unreadCount; i++) {
                                    items.add(_buildMessageCard(context, msgs[i], colors, viewModel));
                                  }

                                  // ── READ section ────────────────────────────
                                  if (readCount > 0) {
                                    items.add(
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8, top: 12),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 4,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: colors.muted.withValues(alpha: 0.3),
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'READ  ($readCount)',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: colors.muted,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  for (int i = unreadCount; i < msgs.length; i++) {
                                    items.add(_buildMessageCard(context, msgs[i], colors, viewModel));
                                  }

                                  return SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 80),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (_, i) => items[i],
                                        childCount: items.length,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
        ),

        // ── New-message banner ──────────────────────────────────────────────
        if (_showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _bannerSlide,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.5)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_active_rounded,
                              color: AppColors.primaryRed, size: 20),
                        ),
                        title: Text(
                          _bannerText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: _bannerSub.isNotEmpty
                            ? Text(
                                _bannerSub,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                              )
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                          onPressed: _dismissBanner,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Message Card
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildMessageCard(
    BuildContext context,
    Map<String, dynamic> msg,
    dynamic colors,
    MessageViewModel viewModel,
  ) {
    final bool isUnread = msg['user_action'] == null || msg['user_action']['read_at'] == null;
    final String messageId = msg['id'].toString();

    // Parse fields
    final String rawTitle = msg['title'] ?? msg['subject'] ?? 'Message';
    final String title = _replaceReportCopy(rawTitle);

    final String rawSummary = msg['summary'] ?? msg['details'] ?? msg['content'] ?? msg['body'] ?? msg['message'] ?? '';
    final String summaryText = _replaceReportCopy(rawSummary).trim();

    final String rawDetails = msg['details'] ?? '';
    final String detailsText = _replaceReportCopy(rawDetails).trim();

    final String messageSource = (msg['source'] ?? '').toString().trim().toLowerCase();

    // sort_at is the internal ordering key; created_at is what we display to users
    final String displayDateRaw = msg['created_at']?.toString() ?? '';
    final String sortAtRaw = msg['sort_at']?.toString() ?? '';

    // For report messages: if sort_at != created_at, admin replied (activity moved it up)
    final bool isUpdated = messageSource == 'report' &&
        sortAtRaw.isNotEmpty &&
        displayDateRaw.isNotEmpty &&
        sortAtRaw != displayDateRaw;

    final bool allowLikeDislike = msg['allow_like_dislike'] == true ||
        msg['allow_like_dislike'] == 1 ||
        msg['allow_like_dislike'] == '1';

    // Attachment fields
    final String attachmentType = (msg['attachment_type'] ?? '').toString().trim().toLowerCase();
    final String attachmentUrl = msg['attachment_url'] != null
        ? UploadUrlResolver.resolve(msg['attachment_url'].toString().trim(), type: 'image')
        : '';
    final bool hasPreview = attachmentType.isNotEmpty &&
        attachmentUrl.isNotEmpty &&
        (attachmentType == 'image' || attachmentType == 'video');

    final String rawButtonText = (msg['button_text'] ?? '').toString().trim();
    final String buttonText = _replaceReportCopy(rawButtonText);
    final String buttonUrl = (msg['button_url'] ?? '').toString().trim();
    final bool hasButtonLink = buttonText.isNotEmpty && buttonUrl.isNotEmpty;

    // Format created_at for display (with seconds for precision)
    String formattedDate = displayDateRaw;
    try {
      if (displayDateRaw.isNotEmpty) {
        final dt = DateTime.parse(displayDateRaw).toLocal();
        formattedDate =
            '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? Colors.blue.withValues(alpha: 0.25) : colors.border,
          width: isUnread ? 1.5 : 1.0,
        ),
        boxShadow: isUnread
            ? [BoxShadow(color: Colors.blue.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MESSAGE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colors.muted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isUpdated ? 'Updated $formattedDate' : formattedDate,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isUpdated ? Colors.orange.shade600 : colors.muted,
                      fontWeight: isUpdated ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (isUnread) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        try {
                          await viewModel.markAsRead(messageId);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString().replaceAll('Exception:', '').trim()),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check, size: 12, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              'Mark as Read',
                              style: GoogleFonts.inter(fontSize: 10, color: colors.text, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Attachment Container
          if (hasPreview) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  if (attachmentType == 'image')
                    Image.network(
                      attachmentUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 160,
                          color: Colors.grey.shade100,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: AppColors.primaryRed,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, e, s) => Container(
                        height: 160,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: 40, color: Colors.grey),
                              SizedBox(height: 4),
                              Text('Image not available',
                                  style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (attachmentType == 'video')
                    Container(
                      height: 160,
                      color: Colors.black87,
                      child: Center(
                        child: IconButton(
                          icon: const Icon(Icons.play_circle_outline, color: Colors.white, size: 50),
                          onPressed: () async {
                            try {
                              final uri = Uri.parse(attachmentUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            } catch (_) {}
                          },
                        ),
                      ),
                    ),
                  if (hasButtonLink)
                    InkWell(
                      onTap: () async {
                        try {
                          final uri = Uri.parse(buttonUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        } catch (_) {}
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        color: AppColors.primaryRed,
                        child: Center(
                          child: Text(
                            buttonText,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: colors.border.withValues(alpha: 0.15),
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.text,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Standalone button (when no image/video preview)
          if (!hasPreview && hasButtonLink) ...[
            InkWell(
              onTap: () async {
                try {
                  final uri = Uri.parse(buttonUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } catch (_) {}
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.open_in_new, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      buttonText,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Content body
          if (messageSource == 'report') ...[
            Text(
              summaryText,
              style: GoogleFonts.inter(
                  fontSize: 14, color: colors.text, fontWeight: FontWeight.w600, height: 1.4),
            ),
            if (detailsText.isNotEmpty && detailsText.toLowerCase() != 'no details') ...[
              const SizedBox(height: 12),
              Text(
                detailsText,
                style: GoogleFonts.inter(fontSize: 14, color: colors.text, height: 1.4),
              ),
            ],
          ] else ...[
            Text(
              summaryText,
              style: GoogleFonts.inter(fontSize: 14, color: colors.text, height: 1.5),
            ),
          ],
          const SizedBox(height: 16),

          // Bottom Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (allowLikeDislike)
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        try {
                          final currentReaction = msg['user_action'] != null
                              ? msg['user_action']['reaction']?.toString().toLowerCase()
                              : 'none';
                          if (currentReaction == 'like') {
                            await viewModel.clearReaction(messageId);
                          } else {
                            await viewModel.likeMessage(messageId);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString().replaceAll('Exception:', '').trim()),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.thumb_up_outlined,
                              size: 16,
                              color: (msg['user_action'] != null &&
                                      msg['user_action']['reaction'] == 'like')
                                  ? AppColors.primaryRed
                                  : colors.text,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${msg['stats'] != null ? msg['stats']['like_count'] ?? 0 : 0}',
                              style: GoogleFonts.inter(fontSize: 12, color: colors.text),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        try {
                          final currentReaction = msg['user_action'] != null
                              ? msg['user_action']['reaction']?.toString().toLowerCase()
                              : 'none';
                          if (currentReaction == 'dislike') {
                            await viewModel.clearReaction(messageId);
                          } else {
                            await viewModel.dislikeMessage(messageId);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString().replaceAll('Exception:', '').trim()),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.thumb_down_outlined,
                              size: 16,
                              color: (msg['user_action'] != null &&
                                      msg['user_action']['reaction'] == 'dislike')
                                  ? Colors.red
                                  : colors.text,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${msg['stats'] != null ? msg['stats']['dislike_count'] ?? 0 : 0}',
                              style: GoogleFonts.inter(fontSize: 12, color: colors.text),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              else
                const SizedBox.shrink(),

              const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
  }

  String _replaceReportCopy(String value) {
    return value
        .replaceAll(RegExp(r'\bagent request reports\b', caseSensitive: false), 'agent requests')
        .replaceAll(RegExp(r'\bagent request report\b', caseSensitive: false), 'agent request')
        .replaceAll(RegExp(r'\ba agent request\b'), 'an agent request')
        .replaceAll(RegExp(r'\bA agent request\b'), 'An agent request')
        .replaceAll(RegExp(r'\bREPORTS\b'), 'REQUESTS')
        .replaceAll(RegExp(r'\bReports\b'), 'Requests')
        .replaceAll(RegExp(r'\breports\b'), 'requests')
        .replaceAll(RegExp(r'\bREPORT\b'), 'REQUEST')
        .replaceAll(RegExp(r'\bReport\b'), 'Request')
        .replaceAll(RegExp(r'\breport\b'), 'request');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing green "Live" dot indicator
// ─────────────────────────────────────────────────────────────────────────────

class _LiveDot extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends ConsumerState<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
