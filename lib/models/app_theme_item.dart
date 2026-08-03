import 'package:flutter/foundation.dart';
import '../core/utils/upload_url_resolver.dart';

class AppThemeItem {
  final String id;
  final String name;
  final String frontImage;
  final String backImage;
  final String thumbnail;
  final bool isDefault;
  final bool isFree;
  final String? templateKey;

  const AppThemeItem({
    required this.id,
    required this.name,
    required this.frontImage,
    required this.backImage,
    required this.thumbnail,
    this.isDefault = false,
    this.isFree = true,
    this.templateKey,
  });

  /// Built-in Default Theme used on fresh install or fallback
  static const AppThemeItem defaultTheme = AppThemeItem(
    id: 'default_theme_01',
    name: 'SmartCard Classic',
    frontImage: 'assets/images/smartlogo.png',
    backImage: 'assets/images/smartlogo.png',
    thumbnail: 'assets/images/smartlogo.png',
    isDefault: true,
  );

  static List<AppThemeItem> get builtinTemplates => const [
        defaultTheme,
        AppThemeItem(
          id: 'template_02',
          name: 'Corporate Navy',
          frontImage: 'assets/images/smartlogo.png',
          backImage: 'assets/images/smartlogo.png',
          thumbnail: 'assets/images/smartlogo.png',
        ),
        AppThemeItem(
          id: 'template_03',
          name: 'Modern Minimalist',
          frontImage: 'assets/images/smartlogo.png',
          backImage: 'assets/images/smartlogo.png',
          thumbnail: 'assets/images/smartlogo.png',
        ),
        AppThemeItem(
          id: 'template_04',
          name: 'Royal Crimson',
          frontImage: 'assets/images/smartlogo.png',
          backImage: 'assets/images/smartlogo.png',
          thumbnail: 'assets/images/smartlogo.png',
          isFree: false,
        ),
        AppThemeItem(
          id: 'template_05',
          name: 'Executive Dark',
          frontImage: 'assets/images/smartlogo.png',
          backImage: 'assets/images/smartlogo.png',
          thumbnail: 'assets/images/smartlogo.png',
          isFree: false,
        ),
        AppThemeItem(
          id: 'template_06',
          name: 'Cyber Obsidian',
          frontImage: 'assets/images/smartlogo.png',
          backImage: 'assets/images/smartlogo.png',
          thumbnail: 'assets/images/smartlogo.png',
          isFree: false,
        ),
        AppThemeItem(
          id: 'template_07',
          name: 'Sunset Emerald',
          frontImage: 'assets/images/smartlogo.png',
          backImage: 'assets/images/smartlogo.png',
          thumbnail: 'assets/images/smartlogo.png',
          isFree: false,
        ),
        AppThemeItem(
          id: 'template_08',
          name: 'Sapphire Luxe',
          frontImage: 'assets/images/smartlogo.png',
          backImage: 'assets/images/smartlogo.png',
          thumbnail: 'assets/images/smartlogo.png',
          isFree: false,
        ),
      ];

  factory AppThemeItem.fromMap(Map<String, dynamic> map, {int index = 0}) {
    final id = map['id']?.toString() ??
        map['template_id']?.toString() ??
        map['template_key']?.toString() ??
        map['file_name']?.toString() ??
        'theme_$index';

    final name = map['name']?.toString() ??
        map['title']?.toString() ??
        map['template_name']?.toString() ??
        'Theme ${index + 1}';

    final rawFront = map['front_image']?.toString() ??
        map['frontImage']?.toString() ??
        map['bg_image']?.toString() ??
        map['bgimage']?.toString() ??
        map['background_image']?.toString() ??
        map['backgroundImage']?.toString() ??
        map['image_url']?.toString() ??
        map['imageUrl']?.toString() ??
        map['url']?.toString() ??
        map['image']?.toString() ??
        '';

    final rawBack = map['back_image']?.toString() ??
        map['backImage']?.toString() ??
        rawFront;

    final rawThumb = map['thumbnail']?.toString() ??
        map['thumbnail_url']?.toString() ??
        map['thumb']?.toString() ??
        map['file_name']?.toString() ??
        rawFront;

    final effectiveFront = rawFront.isNotEmpty ? rawFront : rawThumb;

    final frontUrl = effectiveFront.isNotEmpty
        ? ((effectiveFront.startsWith('assets/') || effectiveFront.startsWith('http://') || effectiveFront.startsWith('https://'))
            ? effectiveFront
            : UploadUrlResolver.resolve(effectiveFront, type: 'card-bg'))
        : AppThemeItem.defaultTheme.frontImage;

    final backUrl = rawBack.isNotEmpty
        ? ((rawBack.startsWith('assets/') || rawBack.startsWith('http://') || rawBack.startsWith('https://'))
            ? rawBack
            : UploadUrlResolver.resolve(rawBack, type: 'card-bg'))
        : frontUrl;

    final thumbUrl = rawThumb.isNotEmpty
        ? ((rawThumb.startsWith('assets/') || rawThumb.startsWith('http://') || rawThumb.startsWith('https://'))
            ? rawThumb
            : UploadUrlResolver.resolve(rawThumb, type: 'card-bg'))
        : frontUrl;

    // Parse is_free attribute from backend database (1/true = free, 0/false = paid/premium)
    bool isFreeTheme = true;
    if (map.containsKey('is_free')) {
      final rawFree = map['is_free'];
      if (rawFree is bool) {
        isFreeTheme = rawFree;
      } else if (rawFree != null) {
        final str = rawFree.toString().trim().toLowerCase();
        isFreeTheme = str == '1' || str == 'true';
      }
    } else if (map.containsKey('is_premium')) {
      final rawPrem = map['is_premium'];
      if (rawPrem is bool) {
        isFreeTheme = !rawPrem;
      } else if (rawPrem != null) {
        final str = rawPrem.toString().trim().toLowerCase();
        isFreeTheme = str == '0' || str == 'false';
      }
    } else {
      // Fallback index-based rule if backend does not pass flag: first 3 free, remaining premium
      isFreeTheme = index < 3;
    }

    final templateKey = map['file_name']?.toString() ?? map['template_key']?.toString();

    return AppThemeItem(
      id: id,
      name: name,
      frontImage: frontUrl,
      backImage: backUrl,
      thumbnail: thumbUrl,
      isDefault: false,
      isFree: isFreeTheme,
      templateKey: templateKey,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'frontImage': frontImage,
      'backImage': backImage,
      'thumbnail': thumbnail,
      'isDefault': isDefault,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppThemeItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
