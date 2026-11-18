import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard_flutter/views/widgets/manage_cards/widgets/manage_cards_video_widget.dart';

void main() {
  group('VideoPlatformHelper tests', () {
    test('detects standard YouTube URLs and extracts videoId', () {
      const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      final info = VideoPlatformHelper.detect(url);

      expect(info.platform, VideoPlatformType.youtube);
      expect(info.displayName, 'YouTube Video');
      expect(info.videoId, 'dQw4w9WgXcQ');
      expect(info.embedUrl, 'https://www.youtube.com/embed/dQw4w9WgXcQ');
    });

    test('detects YouTube Shorts URLs', () {
      const url = 'https://youtube.com/shorts/3iG4x4v3Y1s?si=abc123';
      final info = VideoPlatformHelper.detect(url);

      expect(info.platform, VideoPlatformType.youtube);
      expect(info.displayName, 'YouTube Short');
      expect(info.videoId, '3iG4x4v3Y1s');
    });

    test('detects youtu.be shortlinks', () {
      const url = 'https://youtu.be/dQw4w9WgXcQ';
      final info = VideoPlatformHelper.detect(url);

      expect(info.platform, VideoPlatformType.youtube);
      expect(info.videoId, 'dQw4w9WgXcQ');
    });

    test('detects Instagram Reels and extracts shortcode', () {
      const url = 'https://www.instagram.com/reel/C3_kabcdef/?igsh=123';
      final info = VideoPlatformHelper.detect(url);

      expect(info.platform, VideoPlatformType.instagram);
      expect(info.displayName, 'Instagram Reel');
      expect(info.videoId, 'C3_kabcdef');
      expect(info.embedUrl, 'https://www.instagram.com/reel/C3_kabcdef/embed');
    });

    test('detects Instagram posts', () {
      const url = 'https://instagram.com/p/DFj8473_xyZ/';
      final info = VideoPlatformHelper.detect(url);

      expect(info.platform, VideoPlatformType.instagram);
      expect(info.displayName, 'Instagram Video');
      expect(info.videoId, 'DFj8473_xyZ');
    });

    test('detects Facebook video and reel URLs', () {
      const url1 = 'https://www.facebook.com/watch/?v=123456789';
      final info1 = VideoPlatformHelper.detect(url1);
      expect(info1.platform, VideoPlatformType.facebook);
      expect(info1.displayName, 'Facebook Video');

      const url2 = 'https://fb.watch/mXz12345/';
      final info2 = VideoPlatformHelper.detect(url2);
      expect(info2.platform, VideoPlatformType.facebook);
    });

    test('detects TikTok video URLs', () {
      const url = 'https://www.tiktok.com/@creator/video/7234567890123456789';
      final info = VideoPlatformHelper.detect(url);

      expect(info.platform, VideoPlatformType.tiktok);
      expect(info.displayName, 'TikTok Video');
    });

    test('detects Vimeo URLs and extracts numeric ID', () {
      const url = 'https://vimeo.com/76979871';
      final info = VideoPlatformHelper.detect(url);

      expect(info.platform, VideoPlatformType.vimeo);
      expect(info.displayName, 'Vimeo Video');
      expect(info.videoId, '76979871');
      expect(info.embedUrl, 'https://player.vimeo.com/video/76979871');
    });

    test('detects X / Twitter URLs', () {
      const url = 'https://x.com/flutterdev/status/123456789';
      final info = VideoPlatformHelper.detect(url);

      expect(info.platform, VideoPlatformType.twitter);
      expect(info.displayName, 'X (Twitter) Video');
    });

    test('detects LinkedIn URLs', () {
      const url = 'https://www.linkedin.com/posts/flutter-community_update-123';
      final info = VideoPlatformHelper.detect(url);

      expect(info.platform, VideoPlatformType.linkedin);
      expect(info.displayName, 'LinkedIn Video');
    });

    test('detects Direct Video file URLs', () {
      const url = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      final info = VideoPlatformHelper.detect(url);

      expect(info.platform, VideoPlatformType.directVideo);
      expect(info.displayName, 'Direct Video (.mp4)');
    });

    test('detects Generic Web Video URLs', () {
      const url = 'https://mywebsite.com/watch-video';
      final info = VideoPlatformHelper.detect(url);

      expect(info.platform, VideoPlatformType.generic);
      expect(info.displayName, 'Web Video');
    });

    test('handles empty or blank URLs gracefully', () {
      final info = VideoPlatformHelper.detect('   ');
      expect(info.platform, VideoPlatformType.generic);
      expect(info.originalUrl, '');
    });

    test('correctly sets isVertical property for Reels and Shorts', () {
      final ytShort = VideoPlatformHelper.detect('https://youtube.com/shorts/3iG4x4v3Y1s');
      expect(ytShort.isVertical, isTrue);

      final ytStandard = VideoPlatformHelper.detect('https://youtube.com/watch?v=dQw4w9WgXcQ');
      expect(ytStandard.isVertical, isFalse);

      final igReel = VideoPlatformHelper.detect('https://www.instagram.com/reel/C3_kabcdef/');
      expect(igReel.isVertical, isTrue);

      final tiktok = VideoPlatformHelper.detect('https://www.tiktok.com/@creator/video/123456');
      expect(tiktok.isVertical, isTrue);

      final fbReel = VideoPlatformHelper.detect('https://www.facebook.com/reel/123456789');
      expect(fbReel.isVertical, isTrue);
    });
  });
}
