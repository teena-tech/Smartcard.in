class VideoItem {
  final String url;
  final String title;
  final String platform;
  final String? videoId;
  final String? embedUrl;
  final String? thumbnailUrl;

  const VideoItem({
    required this.url,
    this.title = '',
    this.platform = 'generic',
    this.videoId,
    this.embedUrl,
    this.thumbnailUrl,
  });

  /// Indicates if this video has a vertical aspect ratio (9:16) like Reels or Shorts.
  bool get isVertical {
    final lower = url.toLowerCase();
    return platform == 'tiktok' ||
        (platform == 'youtube' && lower.contains('/shorts/')) ||
        (platform == 'instagram' && (lower.contains('/reel/') || lower.contains('/reels/'))) ||
        (platform == 'facebook' && (lower.contains('/reel/') || lower.contains('/reels/')));
  }

  /// Derives platform, video ID, embed URL, and default thumbnail from a raw URL.
  factory VideoItem.fromUrl(String rawUrl, {String? title}) {
    final cleanUrl = rawUrl.trim();
    if (cleanUrl.isEmpty) {
      return const VideoItem(url: '');
    }

    final lower = cleanUrl.toLowerCase();
    String detectedPlatform = 'generic';
    String? extractedId;
    String? generatedEmbedUrl;
    String? generatedThumb;
    String defaultTitle = title?.trim() ?? '';

    // 1. YouTube & Shorts
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      detectedPlatform = 'youtube';
      extractedId = _extractYoutubeId(cleanUrl);
      if (extractedId != null) {
        generatedEmbedUrl = 'https://www.youtube.com/embed/$extractedId';
        generatedThumb = 'https://img.youtube.com/vi/$extractedId/hqdefault.jpg';
      }
      if (defaultTitle.isEmpty) {
        defaultTitle = lower.contains('/shorts/') ? 'YouTube Short' : 'YouTube Video';
      }
    }
    // 2. Vimeo
    else if (lower.contains('vimeo.com')) {
      detectedPlatform = 'vimeo';
      final match = RegExp(
        r'vimeo\.com\/(?:video\/)?(\d+)',
        caseSensitive: false,
      ).firstMatch(cleanUrl);
      extractedId = match?.group(1);
      if (extractedId != null) {
        generatedEmbedUrl = 'https://player.vimeo.com/video/$extractedId';
      }
      if (defaultTitle.isEmpty) defaultTitle = 'Vimeo Video';
    }
    // 3. Dailymotion
    else if (lower.contains('dailymotion.com') || lower.contains('dai.ly')) {
      detectedPlatform = 'dailymotion';
      final match = RegExp(
        r'(?:dailymotion\.com\/(?:video\/|embed\/video\/)|dai\.ly\/)([A-Za-z0-9]+)',
        caseSensitive: false,
      ).firstMatch(cleanUrl);
      extractedId = match?.group(1);
      if (extractedId != null) {
        generatedEmbedUrl = 'https://www.dailymotion.com/embed/video/$extractedId';
        generatedThumb = 'https://www.dailymotion.com/thumbnail/video/$extractedId';
      }
      if (defaultTitle.isEmpty) defaultTitle = 'Dailymotion Video';
    }
    // 4. Instagram Reels & Posts
    else if (lower.contains('instagram.com') || lower.contains('instagr.am')) {
      detectedPlatform = 'instagram';
      final isReel = lower.contains('/reel/') || lower.contains('/reels/');
      final match = RegExp(
        r'instagram\.com\/(?:reel|reels|p|tv)\/([A-Za-z0-9_-]+)',
        caseSensitive: false,
      ).firstMatch(cleanUrl);
      extractedId = match?.group(1);
      if (extractedId != null) {
        generatedEmbedUrl = 'https://www.instagram.com/p/$extractedId/embed';
      }
      if (defaultTitle.isEmpty) {
        defaultTitle = isReel ? 'Instagram Reel' : 'Instagram Video';
      }
    }
    // 5. TikTok
    else if (lower.contains('tiktok.com')) {
      detectedPlatform = 'tiktok';
      final match = RegExp(
        r'tiktok\.com\/(?:@[^/]+\/video\/|v\/)(\d+)',
        caseSensitive: false,
      ).firstMatch(cleanUrl);
      extractedId = match?.group(1);
      if (extractedId != null) {
        generatedEmbedUrl = 'https://www.tiktok.com/embed/v2/$extractedId';
      }
      if (defaultTitle.isEmpty) defaultTitle = 'TikTok Video';
    }
    // 6. Facebook
    else if (lower.contains('facebook.com') || lower.contains('fb.watch') || lower.contains('fb.com')) {
      detectedPlatform = 'facebook';
      final encoded = Uri.encodeComponent(cleanUrl);
      generatedEmbedUrl = 'https://www.facebook.com/plugins/video.php?href=$encoded&show_text=0';
      if (defaultTitle.isEmpty) {
        defaultTitle = (lower.contains('/reel/') || lower.contains('/reels/')) ? 'Facebook Reel' : 'Facebook Video';
      }
    }
    // 7. Direct video files (.mp4, .mov, etc.)
    else if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.contains('.mp4?') ||
        lower.contains('.mov?') ||
        lower.contains('.webm?')) {
      detectedPlatform = 'directVideo';
      generatedEmbedUrl = cleanUrl;
      if (defaultTitle.isEmpty) defaultTitle = 'Direct Video';
    }
    // 8. Other web links
    else {
      detectedPlatform = 'generic';
      if (defaultTitle.isEmpty) defaultTitle = 'Web Video';
    }

    return VideoItem(
      url: cleanUrl,
      title: (title != null && title.trim().isNotEmpty) ? title.trim() : defaultTitle,
      platform: detectedPlatform,
      videoId: extractedId,
      embedUrl: generatedEmbedUrl,
      thumbnailUrl: generatedThumb,
    );
  }

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    final rawUrl = (json['url'] ?? json['link'] ?? '').toString();
    final item = VideoItem.fromUrl(
      rawUrl,
      title: json['title']?.toString(),
    );

    return VideoItem(
      url: item.url,
      title: json['title']?.toString().isNotEmpty == true
          ? json['title'].toString()
          : item.title,
      platform: json['platform']?.toString().isNotEmpty == true
          ? json['platform'].toString()
          : item.platform,
      videoId: json['video_id']?.toString() ?? item.videoId,
      embedUrl: json['embed_url']?.toString() ?? item.embedUrl,
      thumbnailUrl: json['thumbnail_url']?.toString() ?? item.thumbnailUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'platform': platform,
      if (videoId != null) 'video_id': videoId,
      if (embedUrl != null) 'embed_url': embedUrl,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
    };
  }

  VideoItem copyWith({
    String? url,
    String? title,
    String? platform,
    String? videoId,
    String? embedUrl,
    String? thumbnailUrl,
  }) {
    return VideoItem(
      url: url ?? this.url,
      title: title ?? this.title,
      platform: platform ?? this.platform,
      videoId: videoId ?? this.videoId,
      embedUrl: embedUrl ?? this.embedUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  VideoItem clone() {
    return VideoItem(
      url: url,
      title: title,
      platform: platform,
      videoId: videoId,
      embedUrl: embedUrl,
      thumbnailUrl: thumbnailUrl,
    );
  }

  static String? _extractYoutubeId(String url) {
    final regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.|m\.)?(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/))([\w-]{11})',
      caseSensitive: false,
      multiLine: false,
    );
    final match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }
}
