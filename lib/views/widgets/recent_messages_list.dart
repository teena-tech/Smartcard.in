import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/upload_url_resolver.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/message_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../screens/messages_screen.dart';

class RecentMessagesList extends StatelessWidget {
  final List<Map<String, dynamic>> messages;

  const RecentMessagesList({super.key, required this.messages});

  static bool _isUnread(Map<String, dynamic> msg) {
    if (msg['is_read'] == true || msg['is_read'] == 1) return false;
    final action = msg['user_action'];
    if (action == null) return true;
    if (action is Map) return action['read_at'] == null;
    return true;
  }

  /// Best timestamp in ms: created_at → sort_at → id fallback
  static int _timeMs(Map<String, dynamic> msg) {
    for (final key in ['created_at', 'sort_at', 'show_from', 'show_until']) {
      final raw = msg[key]?.toString();
      if (raw != null && raw.isNotEmpty) {
        try {
          final ms = DateTime.parse(raw).millisecondsSinceEpoch;
          if (ms > 0) return ms;
        } catch (_) {}
      }
    }
    return int.tryParse(msg['id']?.toString() ?? '') ?? 0;
  }

  static List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> msgs) {
    final list = List<Map<String, dynamic>>.from(msgs);
    list.sort((a, b) {
      final unreadA = _isUnread(a) ? 0 : 1;
      final unreadB = _isUnread(b) ? 0 : 1;
      if (unreadA != unreadB) return unreadA - unreadB;
      return _timeMs(b) - _timeMs(a);
    });
    return list;
  }

  String _pick(Map<String, dynamic> msg, List<String> keys, [String fallback = '']) {
    for (final key in keys) {
      final val = msg[key];
      if (val != null && val.toString().trim().isNotEmpty) return val.toString().trim();
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;

    final sorted = _sorted(messages);
    final display = sorted.take(5).toList();
    final unreadCount = sorted.where(_isUnread).length;

    if (display.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.symmetric(horizontal: 24.0),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: colors.muted.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text('No recent messages', style: GoogleFonts.inter(color: colors.muted, fontSize: 14)),
          ],
        ),
      );
    }

    void goToMessages() {
      try {
        context.read<MessageViewModel>().loadMessages();
        context.read<DashboardViewModel>().setIndex(5);
      } catch (_) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen()));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Unread count badge ───────────────────────────────────────────────
        if (unreadCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$unreadCount unread',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryRed,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

        // ── List card ───────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24.0),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: List.generate(display.length, (index) {
                final msg = display[index];
                final bool unread = _isUnread(msg);

                final String title = _pick(msg, ['title', 'subject', 'notification_title', 'name'], 'Message');
                final String body = _pick(msg, ['details', 'summary', 'content', 'body', 'message', 'description', 'text']);

                // Image attachment URL resolution
                final String attachType = (msg['attachment_type'] ?? '').toString().toLowerCase().trim();
                final String rawUrl = msg['attachment_url']?.toString().trim() ??
                    msg['image_url']?.toString().trim() ??
                    msg['image']?.toString().trim() ?? '';
                final String imageUrl = (attachType == 'image' || rawUrl.isNotEmpty) && rawUrl.isNotEmpty
                    ? UploadUrlResolver.resolve(rawUrl, type: 'image')
                    : '';
                final bool hasImage = imageUrl.isNotEmpty;

                return Column(
                  children: [
                    if (index > 0)
                      Divider(color: colors.border, height: 1, indent: 16, endIndent: 16),
                    Material(
                      color: unread
                          ? AppColors.primaryRed.withValues(alpha: 0.03)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: goToMessages,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Full Image Container at the TOP (if message has image)
                              if (hasImage) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    imageUrl,
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context2, err, stack) => Container(
                                      height: 120,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: colors.border.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image_outlined, size: 32, color: colors.muted),
                                          const SizedBox(height: 4),
                                          Text('Image not available', style: GoogleFonts.inter(fontSize: 12, color: colors.muted)),
                                        ],
                                      ),
                                    ),
                                    loadingBuilder: (_, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        height: 150,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: colors.border.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // 2. Icon + Title & Body + Unread indicator below image
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Leading icon
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: unread
                                        ? AppColors.primaryRed.withValues(alpha: 0.15)
                                        : colors.border.withValues(alpha: 0.15),
                                    child: Icon(
                                      unread ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined,
                                      color: unread ? AppColors.primaryRed : colors.muted,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Title and Body
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                                            color: colors.text,
                                          ),
                                        ),
                                        if (body.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            body,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(fontSize: 12, color: colors.muted),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  if (unread) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(top: 6),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryRed,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
