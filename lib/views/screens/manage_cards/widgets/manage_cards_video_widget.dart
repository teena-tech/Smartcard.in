import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../models/card_model.dart';
import '../../../../models/video_item.dart';
import '../../../../viewmodels/card_viewmodel.dart';

enum VideoPlatformType {
  youtube,
  instagram,
  facebook,
  tiktok,
  vimeo,
  dailymotion,
  twitter,
  linkedin,
  directVideo,
  generic,
}

class VideoPlatformInfo {
  final VideoPlatformType platform;
  final String displayName;
  final dynamic icon;
  final Color brandColor;
  final Color badgeBackground;
  final String originalUrl;
  final String? videoId;
  final String? embedUrl;
  final String? thumbnailUrl;
  final bool isVertical;

  const VideoPlatformInfo({
    required this.platform,
    required this.displayName,
    required this.icon,
    required this.brandColor,
    required this.badgeBackground,
    required this.originalUrl,
    this.videoId,
    this.embedUrl,
    this.thumbnailUrl,
    this.isVertical = false,
  });
}

Widget _buildPlatformIcon(dynamic icon, {required Color color, double? size}) {
  if (icon is IconData) {
    return Icon(icon, color: color, size: size);
  }
  return FaIcon(icon, color: color, size: size);
}

class VideoPlatformHelper {
  static bool isValidUrl(String rawUrl) {
    final url = rawUrl.trim();
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  static VideoPlatformInfo detect(String rawUrl, {String? title}) {
    final url = rawUrl.trim();
    if (url.isEmpty) {
      return const VideoPlatformInfo(
        platform: VideoPlatformType.generic,
        displayName: 'Video',
        icon: Icons.play_circle_outline,
        brandColor: Color(0xFF6B7280),
        badgeBackground: Color(0xFFF3F4F6),
        originalUrl: '',
      );
    }

    final lower = url.toLowerCase();

    // 1. YouTube & Shorts
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      final isShort = lower.contains('/shorts/');
      final id = extractYoutubeId(url);
      return VideoPlatformInfo(
        platform: VideoPlatformType.youtube,
        displayName: isShort ? 'YouTube Short' : 'YouTube Video',
        icon: FontAwesomeIcons.youtube,
        brandColor: const Color(0xFFFF0000),
        badgeBackground: const Color(0xFFFFEBEE),
        originalUrl: url,
        videoId: id,
        embedUrl: id != null ? 'https://www.youtube.com/embed/$id' : null,
        thumbnailUrl: id != null ? 'https://img.youtube.com/vi/$id/hqdefault.jpg' : null,
        isVertical: isShort,
      );
    }

    // 2. Vimeo
    if (lower.contains('vimeo.com')) {
      final match = RegExp(
        r'vimeo\.com\/(?:video\/)?(\d+)',
        caseSensitive: false,
      ).firstMatch(url);
      final id = match?.group(1);
      return VideoPlatformInfo(
        platform: VideoPlatformType.vimeo,
        displayName: 'Vimeo Video',
        icon: FontAwesomeIcons.vimeo,
        brandColor: const Color(0xFF1AB7EA),
        badgeBackground: const Color(0xFFE1F5FE),
        originalUrl: url,
        videoId: id,
        embedUrl: id != null ? 'https://player.vimeo.com/video/$id' : null,
        thumbnailUrl: id != null ? 'https://vumbnail.com/$id.jpg' : null,
        isVertical: false,
      );
    }

    // 3. Dailymotion
    if (lower.contains('dailymotion.com') || lower.contains('dai.ly')) {
      final match = RegExp(
        r'(?:dailymotion\.com\/(?:video\/|embed\/video\/)|dai\.ly\/)([A-Za-z0-9]+)',
        caseSensitive: false,
      ).firstMatch(url);
      final id = match?.group(1);
      return VideoPlatformInfo(
        platform: VideoPlatformType.dailymotion,
        displayName: 'Dailymotion Video',
        icon: Icons.play_circle_filled,
        brandColor: const Color(0xFF0066DC),
        badgeBackground: const Color(0xFFEBF3FF),
        originalUrl: url,
        videoId: id,
        embedUrl: id != null ? 'https://www.dailymotion.com/embed/video/$id' : null,
        thumbnailUrl: id != null ? 'https://www.dailymotion.com/thumbnail/video/$id' : null,
        isVertical: false,
      );
    }

    // 4. Instagram Reels & Posts
    if (lower.contains('instagram.com') || lower.contains('instagr.am')) {
      final isReel = lower.contains('/reel/') || lower.contains('/reels/');
      final match = RegExp(
        r'instagram\.com\/(?:reel|reels|p|tv)\/([A-Za-z0-9_-]+)',
        caseSensitive: false,
      ).firstMatch(url);
      final code = match?.group(1);
      final embedPath = isReel ? 'reel' : 'p';
      return VideoPlatformInfo(
        platform: VideoPlatformType.instagram,
        displayName: isReel ? 'Instagram Reel' : 'Instagram Video',
        icon: FontAwesomeIcons.instagram,
        brandColor: const Color(0xFFE1306C),
        badgeBackground: const Color(0xFFFCE4EC),
        originalUrl: url,
        videoId: code,
        embedUrl: code != null ? 'https://www.instagram.com/$embedPath/$code/embed' : null,
        isVertical: true,
      );
    }

    // 5. TikTok
    if (lower.contains('tiktok.com')) {
      final match = RegExp(
        r'tiktok\.com\/(?:@[^/]+\/video\/|v\/)(\d+)',
        caseSensitive: false,
      ).firstMatch(url);
      final id = match?.group(1);
      return VideoPlatformInfo(
        platform: VideoPlatformType.tiktok,
        displayName: 'TikTok Video',
        icon: FontAwesomeIcons.tiktok,
        brandColor: const Color(0xFF111827),
        badgeBackground: const Color(0xFFF3F4F6),
        originalUrl: url,
        videoId: id,
        embedUrl: id != null ? 'https://www.tiktok.com/embed/v2/$id' : null,
        isVertical: true,
      );
    }

    // 6. Facebook
    if (lower.contains('facebook.com') || lower.contains('fb.watch') || lower.contains('fb.com')) {
      final isFbReel = lower.contains('/reel/') || lower.contains('/reels/');
      final encoded = Uri.encodeComponent(url);
      return VideoPlatformInfo(
        platform: VideoPlatformType.facebook,
        displayName: isFbReel ? 'Facebook Reel' : 'Facebook Video',
        icon: FontAwesomeIcons.facebook,
        brandColor: const Color(0xFF1877F2),
        badgeBackground: const Color(0xFFE7F3FF),
        originalUrl: url,
        embedUrl: 'https://www.facebook.com/plugins/video.php?href=$encoded&show_text=0',
        isVertical: isFbReel,
      );
    }

    // 7. X / Twitter
    if (lower.contains('twitter.com') || lower.contains('x.com')) {
      return VideoPlatformInfo(
        platform: VideoPlatformType.twitter,
        displayName: 'X (Twitter) Video',
        icon: FontAwesomeIcons.xTwitter,
        brandColor: const Color(0xFF0F1419),
        badgeBackground: const Color(0xFFF3F4F6),
        originalUrl: url,
        embedUrl: url,
        isVertical: false,
      );
    }

    // 8. LinkedIn
    if (lower.contains('linkedin.com')) {
      return VideoPlatformInfo(
        platform: VideoPlatformType.linkedin,
        displayName: 'LinkedIn Video',
        icon: FontAwesomeIcons.linkedin,
        brandColor: const Color(0xFF0A66C2),
        badgeBackground: const Color(0xFFE8F4FD),
        originalUrl: url,
      );
    }

    // 9. Direct Video file (.mp4, .mov, etc.)
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m3u8') ||
        lower.endsWith('.m4v') ||
        lower.contains('.mp4?') ||
        lower.contains('.mov?') ||
        lower.contains('.webm?')) {
      String ext = '';
      final dotIdx = url.lastIndexOf('.');
      if (dotIdx != -1) {
        final sub = url.substring(dotIdx).split('?').first.toLowerCase();
        if (sub.isNotEmpty) ext = ' ($sub)';
      }
      return VideoPlatformInfo(
        platform: VideoPlatformType.directVideo,
        displayName: 'Direct Video$ext',
        icon: Icons.movie_outlined,
        brandColor: const Color(0xFF059669),
        badgeBackground: const Color(0xFFECFDF5),
        originalUrl: url,
        embedUrl: url,
      );
    }

    // 10. Generic Web Video
    return VideoPlatformInfo(
      platform: VideoPlatformType.generic,
      displayName: 'Web Video',
      icon: Icons.play_circle_fill,
      brandColor: const Color(0xFF4F46E5),
      badgeBackground: const Color(0xFFEEF2FF),
      originalUrl: url,
    );
  }

  static String? extractYoutubeId(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return null;
    final regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.|m\.)?(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/))([\w-]{11})',
      caseSensitive: false,
      multiLine: false,
    );
    final match = regExp.firstMatch(clean);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return YoutubePlayerController.convertUrlToId(clean);
  }
}

class VideoPlatformBadge extends StatelessWidget {
  final VideoPlatformInfo info;
  final bool compact;

  const VideoPlatformBadge({
    super.key,
    required this.info,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: info.badgeBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: info.brandColor.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPlatformIcon(info.icon, size: compact ? 11 : 13, color: info.brandColor),
          const SizedBox(width: 4),
          Text(
            info.displayName,
            style: GoogleFonts.inter(
              color: info.brandColor,
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The main My Videos / Video Collection section displayed inside Manage Card Details screen.
class MyVideosSectionWidget extends StatefulWidget {
  final CardViewModel viewModel;
  final CardProfileDetails details;
  final AppColors colors;
  final bool isOrganization;

  const MyVideosSectionWidget({
    super.key,
    required this.viewModel,
    required this.details,
    required this.colors,
    this.isOrganization = false,
  });

  @override
  State<MyVideosSectionWidget> createState() => _MyVideosSectionWidgetState();
}

class _MyVideosSectionWidgetState extends State<MyVideosSectionWidget> {
  Future<void> _launchExternalUrl(BuildContext context, String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;
    try {
      final uri = Uri.parse(cleanUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open video URL: $e')),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, int index, VideoItem video) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text(
              'Remove Video?',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${video.title.isNotEmpty ? video.title : 'this video'}" from your card?',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await widget.viewModel.removeVideo(index);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Video removed successfully' : 'Failed to remove video'),
                    backgroundColor: success ? const Color(0xFF1F2937) : Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('Remove', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddVideoCarouselCard(BuildContext context) {
    return InkWell(
      onTap: () => AddEditVideoDialog.show(context, viewModel: widget.viewModel),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 135,
        height: 290,
        decoration: BoxDecoration(
          color: const Color(0xFFFCF0F0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryRed.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryRed.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.add_rounded, size: 26, color: AppColors.primaryRed),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Add Video',
                style: GoogleFonts.inter(
                  color: AppColors.primaryRed,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Reel / Short',
                style: GoogleFonts.inter(
                  color: Colors.grey.shade600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videos = widget.details.videos;
    final totalCount = videos.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isOrganization ? const Color(0xFFBAE6FD) : const Color(0xFFE5E7EB),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section Header Row with Dynamic Count Chip
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              Row(
                children: [
                  const Icon(
                    Icons.video_collection_outlined,
                    size: 16,
                    color: AppColors.primaryRed,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'MY VIDEOS',
                    style: GoogleFonts.inter(
                      color: widget.isOrganization ? const Color(0xFF0369A1) : widget.colors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Dynamic Video Count Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCF0F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primaryRed.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '$totalCount',
                      style: GoogleFonts.inter(
                        color: AppColors.primaryRed,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.isOrganization)
                    InkWell(
                      onTap: () => AddEditVideoDialog.show(context, viewModel: widget.viewModel),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCF0F0),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primaryRed.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add, size: 14, color: AppColors.primaryRed),
                            const SizedBox(width: 4),
                            Text(
                              'Add Video',
                              style: GoogleFonts.inter(
                                color: AppColors.primaryRed,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBAE6FD), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_rounded, size: 11, color: Color(0xFF0284C7)),
                          const SizedBox(width: 4),
                          Text(
                            'Locked',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0369A1),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

          const SizedBox(height: 14),

          // Content Area: Empty State vs Video Items
          if (videos.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFCF0F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.video_library_outlined,
                        color: AppColors.primaryRed,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No Videos Added Yet',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Showcase your YouTube Shorts, Instagram Reels, TikTok, or tutorials in a vertical video list.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  if (!widget.isOrganization) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => AddEditVideoDialog.show(context, viewModel: widget.viewModel),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(
                        'Add First Video',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
          else ...[
            // Horizontal Scrolling Carousel (Swipeable 9:16 portrait cards row)
            SizedBox(
              height: 295,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.antiAlias,
                itemCount: videos.length + (widget.isOrganization ? 0 : 1),
                separatorBuilder: (ctx, idx) => const SizedBox(width: 12),
                itemBuilder: (ctx, idx) {
                  if (idx == videos.length) {
                    return _buildAddVideoCarouselCard(context);
                  }
                  final video = videos[idx];
                  return VerticalReelCarouselCard(
                    key: ValueKey('vid_carousel_${idx}_${video.url}'),
                    video: video,
                    index: idx,
                    isEditable: !widget.isOrganization,
                    onPlay: () => VideoPlayerModal.show(context, video: video),
                    onEdit: () => AddEditVideoDialog.show(
                      context,
                      viewModel: widget.viewModel,
                      initialVideo: video,
                      editIndex: idx,
                    ),
                    onOpenExternal: () => _launchExternalUrl(context, video.url),
                    onDelete: () => _confirmDelete(context, idx, video),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swipe_rounded, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Swipe horizontally to explore reels',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
  }
}

/// A vertical Reel card specifically designed for horizontal swipeable carousel with embedded preview.
class VerticalReelCarouselCard extends StatefulWidget {
  final VideoItem video;
  final int index;
  final bool isEditable;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onOpenExternal;
  final VoidCallback onDelete;

  const VerticalReelCarouselCard({
    super.key,
    required this.video,
    required this.index,
    required this.isEditable,
    required this.onPlay,
    required this.onEdit,
    required this.onOpenExternal,
    required this.onDelete,
  });

  @override
  State<VerticalReelCarouselCard> createState() => _VerticalReelCarouselCardState();
}

class _VerticalReelCarouselCardState extends State<VerticalReelCarouselCard> {
  WebViewController? _webViewController;
  bool _isWebLoaded = false;
  late VideoPlatformInfo _info;

  @override
  void initState() {
    super.initState();
    _info = VideoPlatformHelper.detect(widget.video.url, title: widget.video.title);
    _initEmbedIfNeeded();
  }

  @override
  void didUpdateWidget(covariant VerticalReelCarouselCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.url != widget.video.url) {
      _info = VideoPlatformHelper.detect(widget.video.url, title: widget.video.title);
      _initEmbedIfNeeded();
    }
  }

  void _initEmbedIfNeeded() {
    final thumb = widget.video.thumbnailUrl ?? _info.thumbnailUrl;
    // If a direct static thumbnail image exists (YouTube, Vimeo, Dailymotion), no need for WebView!
    if (thumb != null && thumb.isNotEmpty) {
      _webViewController = null;
      return;
    }

    // For Instagram, Facebook, TikTok - load embedded iframe inside the card to display the actual video cover!
    if (_info.embedUrl != null && _info.embedUrl!.isNotEmpty) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) {
              if (mounted) setState(() => _isWebLoaded = true);
            },
            onWebResourceError: (error) {},
          ),
        );

      final htmlContent = _generateCardEmbedHtml(_info);
      if (htmlContent.isNotEmpty) {
        _webViewController!.loadHtmlString(
          htmlContent,
          baseUrl: 'https://${Uri.tryParse(_info.originalUrl)?.host ?? "instagram.com"}',
        );
      } else {
        _webViewController!.loadRequest(Uri.parse(_info.embedUrl!));
      }
    }
  }

  String _generateCardEmbedHtml(VideoPlatformInfo info) {
    if (info.platform == VideoPlatformType.instagram && info.videoId != null) {
      final code = info.videoId!;
      final embedUrl = 'https://www.instagram.com/reel/$code/embed';
      return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; display: flex; align-items: center; justify-content: center; }
    iframe { width: 100%; height: 100%; min-height: 100%; border: none; pointer-events: none; }
  </style>
</head>
<body>
  <iframe src="$embedUrl" frameborder="0" scrolling="no" allowtransparency="true" allow="autoplay; encrypted-media"></iframe>
</body>
</html>
''';
    }

    if (info.platform == VideoPlatformType.facebook && info.embedUrl != null) {
      return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; display: flex; align-items: center; justify-content: center; }
    iframe { width: 100%; height: 100%; border: none; pointer-events: none; }
  </style>
</head>
<body>
  <iframe src="${info.embedUrl}" frameborder="0" scrolling="no" allowfullscreen></iframe>
</body>
</html>
''';
    }

    if (info.platform == VideoPlatformType.tiktok && info.embedUrl != null) {
      return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; display: flex; align-items: center; justify-content: center; }
    iframe { width: 100%; height: 100%; border: none; pointer-events: none; }
  </style>
</head>
<body>
  <iframe src="${info.embedUrl}" frameborder="0" scrolling="no" allowfullscreen></iframe>
</body>
</html>
''';
    }

    return '';
  }

  @override
  void dispose() {
    _webViewController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.video.title.isNotEmpty ? widget.video.title : _info.displayName;
    final thumb = widget.video.thumbnailUrl ?? _info.thumbnailUrl;

    return Container(
      width: 170,
      height: 290,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _info.brandColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _info.brandColor.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
          // Base Platform Gradient Banner (always present in background)
          _buildCarouselPlatformBanner(_info),

          // If static image thumbnail exists (YouTube, Vimeo, Dailymotion)
          if (thumb != null && thumb.isNotEmpty)
            CachedNetworkImage(
              imageUrl: thumb,
              fit: BoxFit.cover,
              placeholder: (ctx, url) => Container(
                color: const Color(0xFF1F2937),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                ),
              ),
              errorWidget: (ctx, url, err) => _buildCarouselPlatformBanner(_info),
            )
          // Else if embedded iframe is available (Instagram, Facebook, TikTok)
          else if (_webViewController != null) ...[
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _isWebLoaded ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: WebViewWidget(controller: _webViewController!),
              ),
            ),
            if (!_isWebLoaded)
              Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: _info.brandColor,
                  ),
                ),
              ),
          ],

          // Dark gradient scrim top and bottom for readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // Platform Badge Chip on Top-Left
          Positioned(
            top: 10,
            left: 10,
            child: VideoPlatformBadge(info: _info, compact: true),
          ),

          // Center Frosted Play Button
          Center(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _info.brandColor.withValues(alpha: 0.4),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _info.brandColor.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                  const BoxShadow(
                    color: Colors.black45,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: _info.brandColor,
                  size: 32,
                ),
              ),
            ),
          ),

          // Bottom Title & Info Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayTitle,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.touch_app_rounded, color: _info.brandColor, size: 11),
                      const SizedBox(width: 3),
                      Text(
                        'Tap to watch',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Transparent tap layer for entire card
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPlay,
              ),
            ),
          ),

          // Ensure 3-dots popup is on top and clickable
          Positioned(
            top: 8,
            right: 6,
            child: Theme(
              data: Theme.of(context).copyWith(
                cardColor: const Color(0xFF1F2937),
              ),
              child: PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_vert, size: 16, color: Colors.white),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: const Color(0xFF1F2937),
                onSelected: (val) {
                  if (val == 'play') widget.onPlay();
                  if (val == 'edit') widget.onEdit();
                  if (val == 'delete') widget.onDelete();
                  if (val == 'external') widget.onOpenExternal();
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'play',
                    child: Row(
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text('Watch in App', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (widget.isEditable) ...[
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text('Edit Title & Link', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Text('Remove Video', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                  PopupMenuItem(
                    value: 'external',
                    child: Row(
                      children: [
                        const Icon(Icons.open_in_new, color: Colors.white70, size: 15),
                        const SizedBox(width: 8),
                        Text('Open Externally', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildCarouselPlatformBanner(VideoPlatformInfo info) {
    List<Color> gradientColors;
    if (info.platform == VideoPlatformType.instagram) {
      gradientColors = [
        const Color(0xFF833AB4),
        const Color(0xFFFD1D1D),
        const Color(0xFFFCB045),
        const Color(0xFF111827),
      ];
    } else if (info.platform == VideoPlatformType.facebook) {
      gradientColors = [
        const Color(0xFF1877F2),
        const Color(0xFF0D47A1),
        const Color(0xFF111827),
      ];
    } else if (info.platform == VideoPlatformType.tiktok) {
      gradientColors = [
        const Color(0xFF00F2FE).withValues(alpha: 0.6),
        const Color(0xFFFE0979).withValues(alpha: 0.6),
        const Color(0xFF111827),
      ];
    } else {
      gradientColors = [
        info.brandColor.withValues(alpha: 0.9),
        const Color(0xFF111827),
      ];
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPlatformIcon(info.icon, size: 42, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              info.displayName,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A clean, professional card tile representing an individual saved video with vertical Reel preview support.
class VideoCardTile extends StatelessWidget {
  final VideoItem video;
  final int index;
  final bool isEditable;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onOpenExternal;
  final VoidCallback onDelete;

  const VideoCardTile({
    super.key,
    required this.video,
    required this.index,
    required this.isEditable,
    required this.onPlay,
    required this.onEdit,
    required this.onOpenExternal,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final info = VideoPlatformHelper.detect(video.url, title: video.title);
    final displayTitle = video.title.isNotEmpty ? video.title : info.displayName;
    final thumb = video.thumbnailUrl ?? info.thumbnailUrl;
    final host = Uri.tryParse(video.url)?.host ?? '';
    final isVertical = info.isVertical || video.isVertical;
    final previewHeight = isVertical ? 310.0 : 185.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isVertical ? info.brandColor.withValues(alpha: 0.25) : Colors.grey.shade200,
          width: isVertical ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isVertical
                ? info.brandColor.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail / Preview Box (Vertical 9:16 for Reels/Shorts, 16:9 for landscape)
          InkWell(
            onTap: onPlay,
            child: SizedBox(
              height: previewHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Base Background
                  if (isVertical)
                    _buildVerticalReelBackground(info, thumb)
                  else
                    _buildStandardPreview(info, thumb),

                  // Soft dark scrim for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),

                  // Platform Badge Chip on Top-Left
                  Positioned(
                    top: 10,
                    left: 10,
                    child: VideoPlatformBadge(info: info, compact: true),
                  ),

                  // Reel / Aspect Ratio indicator on Top-Right
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isVertical ? info.brandColor.withValues(alpha: 0.7) : Colors.white24,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVertical ? Icons.crop_portrait_rounded : Icons.crop_landscape_rounded,
                            size: 11,
                            color: isVertical ? info.brandColor : Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVertical ? '9:16 REEL' : '16:9 HD',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Center Frosted Play Button with brand halo
                  Center(
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: info.brandColor.withValues(alpha: 0.35),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: info.brandColor.withValues(alpha: 0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                          const BoxShadow(
                            color: Colors.black38,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: info.brandColor,
                          size: 36,
                        ),
                      ),
                    ),
                  ),

                  // Bottom preview prompt with in-app tag
                  Positioned(
                    bottom: 9,
                    left: 10,
                    right: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.touch_app_rounded, color: Colors.white70, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              isVertical ? 'Tap to watch in-app Reel' : 'Tap to watch in app',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (host.isNotEmpty)
                          Text(
                            host,
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 10.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Metadata & Controls Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            info.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: info.brandColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '•',
                            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade400),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              video.url,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),

                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_circle_outline, size: 20, color: AppColors.primaryRed),
                      tooltip: 'Play inside app',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      onPressed: onPlay,
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 17, color: Color(0xFF4B5563)),
                      tooltip: 'Open link externally',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      onPressed: onOpenExternal,
                    ),
                    if (isEditable) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF4B5563)),
                        tooltip: 'Edit Title & Link',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        onPressed: onEdit,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        tooltip: 'Remove Video',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        onPressed: onDelete,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardPreview(VideoPlatformInfo info, String? thumb) {
    if (thumb != null && thumb.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumb,
        fit: BoxFit.cover,
        placeholder: (ctx, url) => Container(
          color: const Color(0xFF1F2937),
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
          ),
        ),
        errorWidget: (ctx, url, err) => _buildPlatformBanner(info, isVertical: false),
      );
    }
    return _buildPlatformBanner(info, isVertical: false);
  }

  Widget _buildVerticalReelBackground(VideoPlatformInfo info, String? thumb) {
    if (thumb != null && thumb.isNotEmpty) {
      return Container(
        color: const Color(0xFF0F172A),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ambient blurred backdrop
            Opacity(
              opacity: 0.35,
              child: CachedNetworkImage(
                imageUrl: thumb,
                fit: BoxFit.cover,
                errorWidget: (ctx, url, err) => _buildPlatformBanner(info, isVertical: true),
              ),
            ),
            // Centered 9:16 Vertical Phone/Reel Preview Window
            Center(
              child: Container(
                width: 174,
                height: 310,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: thumb,
                  fit: BoxFit.cover,
                  errorWidget: (ctx, url, err) => _buildPlatformBanner(info, isVertical: true),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return _buildPlatformBanner(info, isVertical: true);
  }

  Widget _buildPlatformBanner(VideoPlatformInfo info, {bool isVertical = false}) {
    List<Color> gradientColors;
    if (info.platform == VideoPlatformType.instagram) {
      gradientColors = [
        const Color(0xFF833AB4),
        const Color(0xFFFD1D1D),
        const Color(0xFFFCB045),
        const Color(0xFF111827),
      ];
    } else if (info.platform == VideoPlatformType.facebook) {
      gradientColors = [
        const Color(0xFF1877F2),
        const Color(0xFF0D47A1),
        const Color(0xFF111827),
      ];
    } else if (info.platform == VideoPlatformType.tiktok) {
      gradientColors = [
        const Color(0xFF00F2FE).withValues(alpha: 0.6),
        const Color(0xFFFE0979).withValues(alpha: 0.6),
        const Color(0xFF111827),
      ];
    } else {
      gradientColors = [
        info.brandColor.withValues(alpha: 0.9),
        const Color(0xFF111827),
      ];
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -25,
            bottom: -25,
            child: Opacity(
              opacity: 0.18,
              child: _buildPlatformIcon(info.icon, size: isVertical ? 160 : 130, color: Colors.white),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPlatformIcon(info.icon, size: isVertical ? 44 : 36, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  info.displayName,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: isVertical ? 14 : 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isVertical) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'VERTICAL REEL',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A modal dialog / sheet to add or edit a video link with custom title and live validation.
class AddEditVideoDialog extends StatefulWidget {
  final CardViewModel viewModel;
  final VideoItem? initialVideo;
  final int? editIndex;

  const AddEditVideoDialog({
    super.key,
    required this.viewModel,
    this.initialVideo,
    this.editIndex,
  });

  static Future<void> show(
    BuildContext context, {
    required CardViewModel viewModel,
    VideoItem? initialVideo,
    int? editIndex,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AddEditVideoDialog(
        viewModel: viewModel,
        initialVideo: initialVideo,
        editIndex: editIndex,
      ),
    );
  }

  @override
  State<AddEditVideoDialog> createState() => _AddEditVideoDialogState();
}

class _AddEditVideoDialogState extends State<AddEditVideoDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _titleController;
  VideoPlatformInfo? _detectedInfo;
  bool _isSaving = false;
  String? _validationError;

  bool get isEditing => widget.editIndex != null && widget.initialVideo != null;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialVideo?.url ?? '');
    _titleController = TextEditingController(text: widget.initialVideo?.title ?? '');
    _urlController.addListener(_onUrlChanged);
    if (_urlController.text.trim().isNotEmpty) {
      _detectedInfo = VideoPlatformHelper.detect(_urlController.text.trim());
    }
  }

  void _onUrlChanged() {
    final text = _urlController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _detectedInfo = VideoPlatformHelper.detect(text);
        _validationError = null;
      });
    } else {
      setState(() {
        _detectedInfo = null;
        _validationError = null;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _urlController.text = text;
      _onUrlChanged();
    }
  }

  Future<void> _handleSubmit() async {
    final rawUrl = _urlController.text.trim();
    final customTitle = _titleController.text.trim();

    if (rawUrl.isEmpty) {
      setState(() => _validationError = 'Please enter a video URL');
      return;
    }

    if (!VideoPlatformHelper.isValidUrl(rawUrl)) {
      setState(() => _validationError = 'Please enter a valid URL starting with http:// or https://');
      return;
    }

    final newVideo = VideoItem.fromUrl(
      rawUrl,
      title: customTitle.isNotEmpty ? customTitle : null,
    );

    setState(() => _isSaving = true);

    bool success;
    if (isEditing) {
      success = await widget.viewModel.updateVideo(widget.editIndex!, newVideo);
    } else {
      success = await widget.viewModel.addVideo(newVideo);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Video updated successfully' : 'Video added to collection',
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _validationError = widget.viewModel.errorMessage ?? 'Failed to save video';
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFCF0F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.video_call_rounded, color: AppColors.primaryRed, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit Video Details' : 'Add Video to Card',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          'YouTube, Vimeo, Reels, TikTok & more',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Video URL Input
              Text(
                'Video URL *',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                autofocus: !isEditing,
                style: GoogleFonts.inter(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'https://youtube.com/watch?v=... or reel link',
                  hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12.5),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  prefixIcon: const Icon(Icons.link, size: 18, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste, size: 18, color: AppColors.primaryRed),
                    tooltip: 'Paste from clipboard',
                    onPressed: _pasteFromClipboard,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
                  ),
                ),
              ),

              // Live Platform Detection Badge
              if (_detectedInfo != null && _detectedInfo!.originalUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    VideoPlatformBadge(info: _detectedInfo!, compact: true),
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle, size: 13, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      'Detected ${_detectedInfo!.displayName}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF059669),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 14),

              // Video Title Input
              Text(
                'Video Title / Name',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.inter(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'e.g. Flutter Tutorial, My Portfolio, Company Intro',
                  hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12.5),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  prefixIcon: const Icon(Icons.title_rounded, size: 18, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
                  ),
                ),
              ),

              if (_validationError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 15, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _validationError!,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isSaving ? null : _handleSubmit,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            isEditing ? 'Save Changes' : 'Add Video',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// In-app vertical video player modal that plays YouTube, YouTube Shorts, Instagram Reels,
/// Facebook Videos/Reels, TikTok, Vimeo, and direct video files completely inside the app.
class VideoPlayerModal extends StatefulWidget {
  final VideoItem video;

  const VideoPlayerModal({super.key, required this.video});

  static Future<void> show(BuildContext context, {required VideoItem video}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => VideoPlayerModal(video: video),
    );
  }

  @override
  State<VideoPlayerModal> createState() => _VideoPlayerModalState();
}

class _VideoPlayerModalState extends State<VideoPlayerModal> {
  YoutubePlayerController? _youtubeController;
  WebViewController? _webViewController;
  late final VideoPlatformInfo _info;
  bool _isLoading = true;
  double _loadingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _info = VideoPlatformHelper.detect(widget.video.url, title: widget.video.title);

    if (_info.platform == VideoPlatformType.youtube && _info.videoId != null) {
      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: _info.videoId!,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          mute: false,
        ),
      );
      _isLoading = false;
    } else {
      _initWebViewController();
    }
  }

  void _initWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress / 100.0;
                if (progress >= 90) _isLoading = false;
              });
            }
          },
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              if (mounted) setState(() => _isLoading = false);
            }
          },
        ),
      );

    final htmlContent = _generateEmbedHtml(_info);
    if (htmlContent.isNotEmpty) {
      _webViewController!.loadHtmlString(
        htmlContent,
        baseUrl: 'https://${Uri.tryParse(_info.originalUrl)?.host ?? "instagram.com"}',
      );
    } else if (_info.embedUrl != null && _info.embedUrl!.isNotEmpty) {
      _webViewController!.loadRequest(Uri.parse(_info.embedUrl!));
    } else {
      _webViewController!.loadRequest(Uri.parse(_info.originalUrl));
    }
  }

  String _generateEmbedHtml(VideoPlatformInfo info) {
    if (info.platform == VideoPlatformType.instagram && info.videoId != null) {
      final code = info.videoId!;
      final embedUrl = 'https://www.instagram.com/reel/$code/embed';
      return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; display: flex; align-items: center; justify-content: center; }
    iframe { width: 100%; height: 100%; min-height: 100%; border: none; }
  </style>
</head>
<body>
  <iframe src="$embedUrl" frameborder="0" scrolling="no" allowtransparency="true" allowfullscreen allow="autoplay; clipboard-write; encrypted-media; picture-in-picture"></iframe>
</body>
</html>
''';
    }

    if (info.platform == VideoPlatformType.facebook && info.embedUrl != null) {
      return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; display: flex; align-items: center; justify-content: center; }
    iframe { width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <iframe src="${info.embedUrl}" frameborder="0" scrolling="no" allowfullscreen allow="autoplay; clipboard-write; encrypted-media; picture-in-picture"></iframe>
</body>
</html>
''';
    }

    if (info.platform == VideoPlatformType.tiktok && info.embedUrl != null) {
      return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; display: flex; align-items: center; justify-content: center; }
    iframe { width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <iframe src="${info.embedUrl}" frameborder="0" scrolling="no" allowfullscreen allow="autoplay; clipboard-write; encrypted-media; picture-in-picture"></iframe>
</body>
</html>
''';
    }

    if (info.platform == VideoPlatformType.directVideo) {
      return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: #000; display: flex; align-items: center; justify-content: center; }
    video { width: 100%; height: 100%; object-fit: contain; }
  </style>
</head>
<body>
  <video src="${info.originalUrl}" controls autoplay playsinline></video>
</body>
</html>
''';
    }

    if (info.platform == VideoPlatformType.vimeo && info.videoId != null) {
      return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: #000; }
    iframe { width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <iframe src="https://player.vimeo.com/video/${info.videoId}?autoplay=1" frameborder="0" allow="autoplay; fullscreen" allowfullscreen></iframe>
</body>
</html>
''';
    }

    if (info.platform == VideoPlatformType.dailymotion && info.videoId != null) {
      return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: #000; }
    iframe { width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <iframe src="https://www.dailymotion.com/embed/video/${info.videoId}?autoplay=1" frameborder="0" allow="autoplay; fullscreen" allowfullscreen></iframe>
</body>
</html>
''';
    }

    return '';
  }

  @override
  void dispose() {
    _youtubeController?.close();
    super.dispose();
  }

  Future<void> _launchExternal() async {
    try {
      final uri = Uri.parse(widget.video.url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: widget.video.url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video link copied: ${widget.video.url}'),
        backgroundColor: const Color(0xFF1F2937),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video.title.isNotEmpty ? widget.video.title : _info.displayName;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isVertical = _info.isVertical || widget.video.isVertical;

    // Vertical reels get portrait 9:16 modal height (~82% of screen height)
    final modalHeight = isVertical
        ? (screenHeight * 0.82).clamp(520.0, 750.0)
        : (screenHeight * 0.58).clamp(340.0, 480.0);
    final modalWidth = (screenWidth * 0.94).clamp(320.0, 450.0);

    return Dialog(
      backgroundColor: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: SizedBox(
        width: modalWidth,
        height: modalHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Top Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              color: const Color(0xFF1F2937),
              child: Row(
                children: [
                  VideoPlatformBadge(info: _info, compact: true),
                  if (isVertical) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Text(
                        '9:16 REEL',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Close player',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Video Player Body Viewport
            Expanded(
              child: Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_info.platform == VideoPlatformType.youtube && _youtubeController != null)
                      Center(
                        child: YoutubePlayer(controller: _youtubeController!),
                      )
                    else if (_webViewController != null)
                      WebViewWidget(controller: _webViewController!)
                    else
                      Center(
                        child: Text(
                          'Video player could not be loaded.',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                        ),
                      ),

                    // Loading Shimmer / Spinner Overlay
                    if (_isLoading)
                      Container(
                        color: const Color(0xFF0F141C),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 38,
                                height: 38,
                                child: CircularProgressIndicator(
                                  value: _loadingProgress > 0 ? _loadingProgress : null,
                                  strokeWidth: 3,
                                  color: _info.brandColor,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Loading ${_info.displayName}...',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Playing inside SmartCards app',
                                style: GoogleFonts.inter(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Modal Footer Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              color: const Color(0xFF1F2937),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.play_circle_filled, size: 14, color: _info.brandColor),
                      const SizedBox(width: 5),
                      Text(
                        'In-App Player',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 16),
                        tooltip: 'Copy link',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        onPressed: _copyLink,
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        onPressed: _launchExternal,
                        icon: const Icon(Icons.open_in_new, size: 13),
                        label: Text(
                          'Open in App',
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
