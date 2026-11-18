import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:provider/provider.dart';
import 'dart:async';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/support_viewmodel.dart';
import '../../data/models/message_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/global_bottom_nav.dart';
import 'home_screen.dart';
import 'support_agent_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  Timer? _messagePollingTimer;
  MessageModel? _replyingToMessage;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();

    // Auto-scroll when keyboard opens if user is near bottom
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _scrollController.hasClients && _scrollController.offset <= 120) {
        _scrollToBottom();
      }
    });

    // Listen to scroll events to paginate older messages when user scrolls up
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;
        if (maxScroll > 0 && currentScroll >= maxScroll - 200) {
          final authViewModel = context.read<AuthViewModel>();
          final supportViewModel = context.read<SupportViewModel>();
          final userId = authViewModel.currentUser?.id;
          if (userId != null && !supportViewModel.isLoading) {
            supportViewModel.fetchMessages(userId, loadMore: true);
          }
        }
      }
    });

    // Start message polling timer (check for new messages every 5 seconds)
    _messagePollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (context.mounted) {
        final authViewModel = context.read<AuthViewModel>();
        final supportViewModel = context.read<SupportViewModel>();
        final userId = authViewModel.currentUser?.id;
        if (userId != null) {
          supportViewModel.fetchMessages(userId);
          supportViewModel.fetchUnreadCount(userId);

          // ONLY auto-scroll to bottom if user is currently reading bottom/latest messages
          if (_scrollController.hasClients && _scrollController.offset <= 100) {
            _scrollToBottom(animated: true);
          }
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = context.read<AuthViewModel>();
      final supportViewModel = context.read<SupportViewModel>();
      final userId = authViewModel.currentUser?.id;
      if (userId != null) {
        supportViewModel.fetchMessages(userId);
        supportViewModel.fetchUnreadCount(userId);
      }
    });
  }

  @override
  void dispose() {
    _messagePollingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Scrolls to the latest message (offset 0.0 because list is reversed)
  void _scrollToBottom({bool animated = true}) {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients && context.mounted) {
        if (animated) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(0.0);
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final authViewModel = context.read<AuthViewModel>();
    final supportViewModel = context.read<SupportViewModel>();
    final userId = authViewModel.currentUser?.id;
    if (userId == null) return;

    String textToSend = text;
    if (_replyingToMessage != null) {
      final replyText = _replyingToMessage!.details.isNotEmpty
          ? _replyingToMessage!.details
          : _replyingToMessage!.summary;
      textToSend = '[reply:${_replyingToMessage!.id}:${replyText.replaceAll('\n', ' ')}] $text';
    }

    setState(() {
      _replyingToMessage = null;
    });

    _controller.clear();
    _scrollToBottom();

    final success = await supportViewModel.sendMessage(userId, textToSend);
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              supportViewModel.errorMessage ?? 'Failed to send message',
            ),
          ),
        );
      }
    } else {
      // Immediately refresh messages after sending
      Future.delayed(const Duration(milliseconds: 300), () {
        if (context.mounted) {
          supportViewModel.fetchMessages(userId);
          _scrollToBottom();
        }
      });
    }
  }

  DateTime _parseDateStr(String raw) {
    final str = raw.trim();
    if (str.isEmpty || str == 'Just now') return DateTime.now();
    final numVal = num.tryParse(str);
    if (numVal != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        numVal > 100000000000 ? numVal.toInt() : (numVal * 1000).toInt(),
      ).toLocal();
    }
    final sanitized = str.replaceAll(' ', 'T');
    return DateTime.tryParse(sanitized)?.toLocal() ?? DateTime.now();
  }

  /// Format timestamp: "12:35 PM" or "10:15 AM"
  String _formatTime(String createdAt) {
    try {
      final dt = _parseDateStr(createdAt);
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } catch (_) {
      final now = DateTime.now();
      final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      final minute = now.minute.toString().padLeft(2, '0');
      final period = now.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }
  }

  void _showMessageContextMenu(BuildContext context, MessageModel msg, TapDownDetails details) {
    final String textToCopy = msg.details.isNotEmpty ? msg.details : msg.summary;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        details.globalPosition,
        details.globalPosition,
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: [
        PopupMenuItem<String>(
          value: 'reply',
          child: Row(
            children: [
              const Icon(Icons.reply, size: 18, color: Colors.black87),
              const SizedBox(width: 10),
              Text('Reply', style: GoogleFonts.inter(fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy, size: 18, color: Colors.black87),
              const SizedBox(width: 10),
              Text('Copy', style: GoogleFonts.inter(fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'info',
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: Colors.black87),
              const SizedBox(width: 10),
              Text('Info', style: GoogleFonts.inter(fontSize: 14)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (!mounted) return;
      if (value == 'reply') {
        setState(() {
          _replyingToMessage = msg;
        });
        _focusNode.requestFocus();
      } else if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: textToCopy));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message copied to clipboard')),
        );
      } else if (value == 'info') {
        _showMessageInfoDialog(context, msg);
      }
    });
  }

  void _showMessageInfoDialog(BuildContext context, MessageModel msg) {
    final String content = msg.details.isNotEmpty ? msg.details : msg.summary;
    final String timeStr = _formatTime(msg.createdAt);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Message Info', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(content, style: GoogleFonts.inter(fontSize: 13, color: Colors.black87)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.check, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text('Sent: ', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(timeStr.isNotEmpty ? timeStr : 'Delivered', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.done_all, size: 18, color: msg.isRead ? const Color(0xFF4FC3F7) : Colors.grey),
                const SizedBox(width: 8),
                Text('Read: ', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(msg.isRead ? 'Read by agent' : 'Not read yet', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: colors.backgroundStart,
      bottomNavigationBar: const GlobalBottomNav(),
      appBar: CommonAppBar(
        titleText: 'SUPPORT CHAT',
        showProfile: true,
        onProfileTap: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 3)),
            (route) => false,
          );
        },
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/login.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: ResponsiveCenter(
          child: Column(
          children: [
            /// CHAT LIST
            Expanded(
              child: Consumer<SupportViewModel>(
                builder: (context, supportViewModel, child) {
                  final messages = supportViewModel.messages;

                  // Scroll to bottom only once on initial load
                  if (_isInitialLoad && messages.isNotEmpty) {
                    _isInitialLoad = false;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom(animated: false);
                    });
                  }

                  if (supportViewModel.isLoading && messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (supportViewModel.state == SupportState.error && messages.isEmpty) {
                    final errText = supportViewModel.errorMessage ?? 'Unable to load support messages.';
                    final isNoAgent = errText.toLowerCase().contains('no agent');

                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isNoAgent ? Icons.support_agent : Icons.error_outline,
                              size: 56,
                              color: colors.muted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isNoAgent ? 'No Support Agent Assigned' : 'Unable to load messages',
                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: colors.text),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isNoAgent
                                  ? 'Please select or request an agent from your district to start chatting.'
                                  : errText,
                              style: GoogleFonts.inter(fontSize: 14, color: colors.muted),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                if (isNoAgent) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SupportAgentScreen()),
                                  );
                                } else {
                                  final authViewModel = context.read<AuthViewModel>();
                                  final userId = authViewModel.currentUser?.id;
                                  if (userId != null) {
                                    supportViewModel.fetchMessages(userId);
                                  }
                                }
                              },
                              icon: Icon(isNoAgent ? Icons.person_add_outlined : Icons.refresh, size: 18),
                              label: Text(
                                isNoAgent ? 'Select Support Agent' : 'Retry',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      final authViewModel = context.read<AuthViewModel>();
                      final userId = authViewModel.currentUser?.id;
                      if (userId != null) {
                        await supportViewModel.fetchMessages(userId);
                      }
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true, // Newer messages at the bottom (offset 0)
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];

                        // Show date separator when date changes between messages
                        final showDateSep = _shouldShowDateSeparator(messages, index);

                        return Column(
                          children: [
                            if (showDateSep) _buildDateSeparator(messages, index, colors),
                            _buildMessageBubble(msg, colors, isDark),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            /// INPUT AREA
            _buildComposer(colors),
          ],
        ),
      ),
      ),
    );
  }

  bool _shouldShowDateSeparator(List<MessageModel> messages, int index) {
    // In reverse list, index+1 is the older message
    if (index + 1 >= messages.length) return true; // First ever message
    try {
      final current = _parseDateStr(messages[index].createdAt);
      final prev = _parseDateStr(messages[index + 1].createdAt);
      return current.day != prev.day ||
          current.month != prev.month ||
          current.year != prev.year;
    } catch (_) {
      return false;
    }
  }

  Widget _buildDateSeparator(List<MessageModel> messages, int index, dynamic colors) {
    String label = '';
    try {
      final dt = _parseDateStr(messages[index].createdAt);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(msgDay).inDays;

      if (diff == 0) {
        label = 'Today';
      } else if (diff == 1) {
        label = 'Yesterday';
      } else {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        label = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
      }
    } catch (_) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: colors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(color: colors.muted, fontSize: 11),
              ),
            ),
          ),
          Expanded(child: Divider(color: colors.border)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, dynamic colors, bool isDark) {
    final bool isMe = msg.source == 'user';
    final timeStr = _formatTime(msg.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bot avatar
          if (!isMe) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryRed,
              child: Icon(Icons.support_agent, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 6),
          ],

          // Bubble
          Flexible(
            child: GestureDetector(
              onLongPressStart: (details) => _showMessageContextMenu(
                context, 
                msg, 
                TapDownDetails(globalPosition: details.globalPosition),
              ),
              child: Container(
                constraints: BoxConstraints(
                  minWidth: 110, // Minimum 10 letters width box size
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                margin: EdgeInsets.only(
                  left: isMe ? 50 : 0,
                  right: isMe ? 0 : 50,
                  bottom: 4,
                ),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                decoration: BoxDecoration(
                  color: isMe
                      ? const Color(0xFFFDE8E8) // Pale-red background for sent messages
                      : (isDark ? colors.card : const Color(0xFFF0F2F5)),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  border: isMe ? Border.all(color: const Color(0xFFFECACA), width: 1) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top row with options dropdown icon (left side for sent message, right side for received)
                    Row(
                      mainAxisAlignment: isMe ? MainAxisAlignment.start : MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        GestureDetector(
                          onTapDown: (details) => _showMessageContextMenu(context, msg, details),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: isMe ? const Color(0xFF991B1B) : colors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Message content
                    Builder(
                      builder: (context) {
                        String rawText = msg.details.isNotEmpty ? msg.details : msg.summary;
                        String? replyContent;
                        String displayMsgText = rawText;

                        if (rawText.startsWith('[reply:')) {
                          final match = RegExp(r'^\[reply:\d+:(.*?)\]\s*(.*)$').firstMatch(rawText);
                          if (match != null) {
                            replyContent = match.group(1);
                            displayMsgText = match.group(2) ?? '';
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (replyContent != null && replyContent.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isMe ? const Color(0xFFFCA5A5).withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border(
                                    left: BorderSide(color: isMe ? const Color(0xFF991B1B) : AppColors.primaryRed, width: 3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'You',
                                      style: GoogleFonts.inter(
                                        color: isMe ? const Color(0xFF991B1B) : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      replyContent,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: isMe ? const Color(0xFF7F1D1D) : Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Message text
                            Text(
                              displayMsgText,
                              style: GoogleFonts.inter(
                                color: isMe ? Colors.black87 : (isDark ? Colors.white : Colors.black87),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),

                    // Timestamp + tick status row near the tick part at bottom right
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: GoogleFonts.inter(
                              color: isMe ? Colors.black54 : colors.muted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          _buildReadTick(msg),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Spacer for bot messages
          if (!isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }

  /// Read tick indicator for sent message status
  Widget _buildReadTick(MessageModel msg) {
    final isRead = msg.isRead;
    final color = isRead ? const Color(0xFF16A34A) : Colors.black45;

    return Icon(isRead ? Icons.done_all : Icons.done, size: 14, color: color);
  }

  Widget _buildComposer(dynamic colors) {
    final replyMsg = _replyingToMessage;
    final replyText = replyMsg != null
        ? (replyMsg.details.isNotEmpty ? replyMsg.details : replyMsg.summary)
        : '';
    final replySender = replyMsg != null
        ? (replyMsg.source == 'user' ? 'You' : 'Agent')
        : '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
        left: 12,
        right: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // WhatsApp style Reply Preview Banner above input box
          if (replyMsg != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.backgroundStart,
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: AppColors.primaryRed, width: 4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          replySender,
                          style: GoogleFonts.inter(
                            color: AppColors.primaryRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          replyText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: colors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: colors.muted),
                    onPressed: () {
                      setState(() {
                        _replyingToMessage = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
          // Text input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: colors.backgroundStart,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.border, width: 0.8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                style: GoogleFonts.inter(
                  color: (context.read<ThemeViewModel>().themeMode != AppThemeMode.light)
                      ? Colors.white
                      : Colors.black,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: GoogleFonts.inter(color: colors.muted, fontSize: 15),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primaryRed, AppColors.secondaryRed],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x44E53935),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }
}
