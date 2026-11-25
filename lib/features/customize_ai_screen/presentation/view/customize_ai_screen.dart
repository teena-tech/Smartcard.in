import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/core/utils/upload_url_resolver.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/presentation/viewmodel/card_viewmodel.dart';
import 'package:smartcard_flutter/features/customize_menu_screen/presentation/viewmodel/customize_viewmodel.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/core/widgets/profile_menu_bottom_sheet.dart';
import 'package:smartcard_flutter/features/customize_menu_screen/presentation/view/widgets/customize_flow_widgets.dart';
import 'package:smartcard_flutter/core/widgets/global_bottom_nav.dart';
import 'package:smartcard_flutter/core/utils/customize_utils.dart';
import 'package:smartcard_flutter/features/customize_ai_screen/presentation/view/widgets/editor_toolbar.dart';

const List<String> _defaultLogoPalette = [
  '#2563EB',
  '#0EA5E9',
  '#10B981',
  '#F59E0B',
  '#EF4444',
  '#8B5CF6',
  '#EC4899',
];

class CustomizeAiScreen extends ConsumerStatefulWidget {
  const CustomizeAiScreen({super.key});

  @override
  ConsumerState<CustomizeAiScreen> createState() => _CustomizeAiScreenState();
}

class _CustomizeAiScreenState extends ConsumerState<CustomizeAiScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ImagePicker _picker = ImagePicker();

  List<dynamic> _backgroundImages = [];
  int _currentImageIndex = 0;
  Uint8List? _uploadBytes;
  String? _uploadFileName;
  Color _overlayColor = const Color(0xFF1E40AF);
  Color _lastOverlayColor = const Color(0xFF1E40AF);
  double _opacity = 0.5;
  Color _bgColor = Colors.white;
  Color _textColor = const Color(0xFF000000);
  bool _backgroundImageEnabled = true;
  bool _backgroundColorEnabled = true;
  bool _textColorEnabled = true;
  bool _overlayEnabled = true;
  bool _loading = true;
  bool get isLoading => _loading;
  bool _saving = false;
  bool _showUploadBanner = true;
  bool get showUploadBanner => _showUploadBanner;
  String _message = '';
  String get message => _message;
  String _error = '';
  String get error => _error;
  List<String> _logoPalette = [];
  String _selectedFilterColor = '';
  String _activeSheet = '';
  String _filterApplyTarget = 'bg';
  int _majorColorStartIndex = 0;
  List<String> _logoFileNames = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureCardContextLoaded().then((_) => _loadData());
    });
    Timer(const Duration(seconds: 5), () {
      if (context.mounted) {
        setState(() => _showUploadBanner = false);
      }
    });
  }

  Future<void> _ensureCardContextLoaded() async {
    final authVm = ref.read(authViewModelProvider.notifier);
    final cardVm = ref.read(cardViewModelProvider.notifier);
    final user = authVm.currentUser;
    if (user == null) return;

    final userId = user.id ?? '';
    if (userId.isEmpty) return;

    if (cardVm.cards.isEmpty) {
      final name = '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim();
      cardVm.init(
        userId: userId,
        fallbackName: name.isNotEmpty ? name : 'User',
        fallbackPhone: user.phone ?? '',
        fallbackEmail: user.email,
      );
    }
  }

  Future<void> _loadData() async {
    final authVm = ref.read(authViewModelProvider.notifier);
    final cardVm = ref.read(cardViewModelProvider.notifier);
    final customizeVm = ref.read(customizeViewModelProvider.notifier);
    final user = authVm.currentUser;
    final userId = user?.id ?? '';
    final workProfileId = cardVm.currentCard?.workProfileId ?? cardVm.currentCard?.userId;

    if (userId.isEmpty) {
      if (!context.mounted) return;
      setState(() {
        _loading = false;
        _error = 'User id not found';
      });
      return;
    }

    if (!context.mounted) return;
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await Future.wait([
        customizeVm.fetchBackgroundImages(),
        customizeVm.fetchTheme(userId, workProfileId: workProfileId),
      ]);

      if (!context.mounted) return;
      final themeData = customizeVm.themeData ?? {};
      final bgImage = themeData['bg_image']?.toString().trim() ?? '';
      final bgColorHex = normalizeHex(themeData['bg_color'], '');
      final textColorHex = normalizeHex(themeData['text_color'], '#1E40AF');
      final overlayHex = normalizeHex(themeData['bg_image_color'], '');

      setState(() {
        _backgroundImages = customizeVm.backgroundImages;
        _backgroundImageEnabled = bgImage.isNotEmpty;
        _backgroundColorEnabled = bgColorHex.isNotEmpty;
        _textColorEnabled = textColorHex != '#000000' && textColorHex != '#00000000';
        _overlayEnabled = overlayHex.isNotEmpty;
        _overlayColor = overlayHex.isNotEmpty
            ? Color(int.parse('0xFF${overlayHex.replaceAll('#', '')}'))
            : const Color(0xFF1E40AF);
        _lastOverlayColor = _overlayColor;
        _opacity = normalizeOpacity(themeData['opacity'], fallback: 0.5);
        _bgColor = bgColorHex.isNotEmpty
            ? Color(int.parse('0xFF${bgColorHex.replaceAll('#', '')}'))
            : Colors.white;
        _textColor = Color(
          int.parse('0xFF${textColorHex.replaceAll('#', '')}'),
        );
        _logoPalette = [];
        _selectedFilterColor = '';
        _filterApplyTarget = 'bg';
        _majorColorStartIndex = 0;
        _logoFileNames = [];
        _uploadBytes = null;
        _uploadFileName = null;
        _message = '';
        _error = '';
      });

      _syncThemeImageSelection(bgImage);
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (context.mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _syncThemeImageSelection(String selectedKey) {
    if (selectedKey.isEmpty) return;
    final index = _backgroundImages.indexWhere((item) {
      final key = resolveBackgroundImageKey(item);
      return key == selectedKey ||
          resolveBackgroundImageUrl(item) == selectedKey;
    });
    if (index >= 0) {
      _currentImageIndex = index;
    }
  }

  String get _selectedLibraryKey {
    if (_backgroundImages.isEmpty ||
        _currentImageIndex < 0 ||
        _currentImageIndex >= _backgroundImages.length) {
      return '';
    }
    return resolveBackgroundImageKey(_backgroundImages[_currentImageIndex]);
  }

  String get _selectedLibraryUrl {
    if (_backgroundImages.isEmpty ||
        _currentImageIndex < 0 ||
        _currentImageIndex >= _backgroundImages.length) {
      return '';
    }
    return resolveBackgroundImageUrl(_backgroundImages[_currentImageIndex]);
  }

  String get _selectedImageUrl {
    if (_uploadBytes != null) return '';
    if (_backgroundImages.isEmpty) return '';
    if (_currentImageIndex >= 0 && _currentImageIndex < _backgroundImages.length) {
      final savedBgImage = ref.read(customizeViewModelProvider.notifier).themeData?['bg_image']?.toString().trim() ?? '';
      final isLibraryImage = _backgroundImages.any((item) => resolveBackgroundImageKey(item) == savedBgImage);
      if (!isLibraryImage && savedBgImage.isNotEmpty && _currentImageIndex == 0) {
        return UploadUrlResolver.resolve(savedBgImage, type: 'card-bg');
      }
      return _selectedLibraryUrl;
    }
    return '';
  }

  bool get _canNavigateImages => _backgroundImages.length > 1;
  int get _totalImageCount => _backgroundImages.length;
  int get currentImagePosition =>
      _totalImageCount == 0 ? 0 : _currentImageIndex + 1;
  int get _prevIndex => _totalImageCount == 0
      ? 0
      : (_currentImageIndex - 1 + _totalImageCount) % _totalImageCount;
  int get _nextIndex =>
      _totalImageCount == 0 ? 0 : (_currentImageIndex + 1) % _totalImageCount;
  String get prevImageUrl => _totalImageCount == 0
      ? ''
      : resolveBackgroundImageUrl(_backgroundImages[_prevIndex]);
  String get nextImageUrl => _totalImageCount == 0
      ? ''
      : resolveBackgroundImageUrl(_backgroundImages[_nextIndex]);

  bool get _hasChanges {
    if (_uploadBytes != null) return true;
    final customizeVm = ref.read(customizeViewModelProvider.notifier);
    final themeData = customizeVm.themeData ?? {};
    
    // Check background image enabled status
    final initialBgImage = themeData['bg_image']?.toString().trim() ?? '';
    if (_backgroundImageEnabled != initialBgImage.isNotEmpty) return true;
    
    // If background image is enabled, check if selected image changed
    if (_backgroundImageEnabled && _backgroundImages.isNotEmpty) {
      final savedBgImage = themeData['bg_image']?.toString().trim() ?? '';
      final isLibraryImage = _backgroundImages.any((item) => resolveBackgroundImageKey(item) == savedBgImage);
      final String currentBgImageKey;
      if (!isLibraryImage && savedBgImage.isNotEmpty && _currentImageIndex == 0) {
        currentBgImageKey = savedBgImage;
      } else {
        currentBgImageKey = _selectedLibraryKey;
      }
      if (currentBgImageKey != initialBgImage) return true;
    }
    
    // Check background color
    final initialBgColorHex = normalizeHex(themeData['bg_color'], '');
    if (_backgroundColorEnabled != initialBgColorHex.isNotEmpty) return true;
    if (_backgroundColorEnabled) {
      final currentBgHex = _colorToHex(_bgColor);
      if (currentBgHex != initialBgColorHex) return true;
    }
    
    // Check text color
    final initialTextColorHex = normalizeHex(themeData['text_color'], '#1E40AF');
    final currentTextHex = _textColorEnabled ? _colorToHex(_textColor) : '#000000';
    if (currentTextHex != initialTextColorHex) return true;
    
    // Check overlay
    final initialOverlayHex = normalizeHex(themeData['bg_image_color'], '');
    if (_overlayEnabled != initialOverlayHex.isNotEmpty) return true;
    if (_overlayEnabled) {
      final currentOverlayHex = _colorToHex(_overlayColor);
      if (currentOverlayHex != initialOverlayHex) return true;
      
      final initialOpacity = normalizeOpacity(themeData['opacity'], fallback: 0.5);
      if ((_opacity - initialOpacity).abs() > 0.01) return true;
    }
    
    // Check logo upload
    if (_logoFileNames.isNotEmpty) return true;

    return false;
  }

  String get _previewInitials {
    final cardVm = ref.read(cardViewModelProvider.notifier);
    final details = cardVm.selectedCardDetails;
    final first = details?.firstName.trim() ?? '';
    final last = details?.lastName.trim() ?? '';
    final name = '$first $last'.trim();
    final fallbackUser = ref.read(authViewModelProvider.notifier).currentUser;
    final displayName = name.isNotEmpty
        ? name
        : '${fallbackUser?.firstName ?? ''} ${fallbackUser?.lastName ?? ''}'
              .trim();
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((item) => item.trim().isNotEmpty)
        .take(2)
        .map((item) => item.trim()[0].toUpperCase())
        .toList();
    return parts.isNotEmpty ? parts.join() : 'U';
  }

  String get _previewName {
    final cardVm = ref.read(cardViewModelProvider.notifier);
    final details = cardVm.selectedCardDetails;
    if (details != null && details.companyName.trim().isNotEmpty) {
      return details.companyName.trim();
    }
    final first = details?.firstName.trim() ?? '';
    final last = details?.lastName.trim() ?? '';
    final name = '$first $last'.trim();
    if (name.isNotEmpty && !name.startsWith('Card ')) return name;
    final fallbackUser = ref.read(authViewModelProvider.notifier).currentUser;
    final fallback =
        '${fallbackUser?.firstName ?? ''} ${fallbackUser?.lastName ?? ''}'
            .trim();
    return fallback.isNotEmpty ? fallback : 'User Name';
  }

  String get _previewDesignation {
    final cardVm = ref.read(cardViewModelProvider.notifier);
    final details = cardVm.selectedCardDetails;
    final value = details?.designation.trim().isNotEmpty == true
        ? details!.designation.trim()
        : '';
    return value.isNotEmpty ? value : 'Designation';
  }

  String get _previewCompanyLogo {
    final details = ref.read(cardViewModelProvider.notifier).selectedCardDetails;
    final logoName = details?.companyLogoName.trim() ?? '';
    return UploadUrlResolver.resolve(
      logoName,
      type: 'logo',
      fallback: '',
    );
  }

  String get _previewProfileImage {
    final details = ref.read(cardViewModelProvider.notifier).selectedCardDetails;
    final imageName = details?.profileImageName.trim() ?? '';
    return UploadUrlResolver.resolve(
      imageName,
      type: 'profile',
      fallback: '',
    );
  }

  Widget _buildSummaryCard(String title, List<Widget> children, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: textColor.withValues(alpha: 0.15),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color textColor) {
    IconData getIcon(String lbl) {
      final l = lbl.toLowerCase();
      if (l.contains('email')) return Icons.email_outlined;
      if (l.contains('phone')) return Icons.phone_outlined;
      if (l.contains('whatsapp')) return Icons.chat_bubble_outline;
      if (l.contains('address')) return Icons.location_on_outlined;
      if (l.contains('pincode')) return Icons.pin_drop_outlined;
      if (l.contains('facebook')) return Icons.facebook_outlined;
      if (l.contains('instagram')) return Icons.camera_alt_outlined;
      if (l.contains('linkedin')) return Icons.work_outline;
      if (l.contains('twitter') || l.contains('x (')) return Icons.link;
      if (l.contains('professional')) return Icons.business_center_outlined;
      if (l.contains('designation')) return Icons.badge_outlined;
      return Icons.info_outline;
    }

    final iconColor = _backgroundColorEnabled ? _bgColor : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(getIcon(label), color: iconColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(color: textColor, fontSize: 13),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void toggleBgImage() {
    setState(() {
      _backgroundImageEnabled = !_backgroundImageEnabled;
      if (_backgroundImageEnabled && _backgroundImages.isNotEmpty) {
        _currentImageIndex = _currentImageIndex.clamp(
          0,
          _backgroundImages.length - 1,
        );
      }
    });
  }

  void toggleBgColor() {
    setState(() {
      _backgroundColorEnabled = !_backgroundColorEnabled;
    });
  }

  void toggleOverlay() {
    setState(() {
      if (_overlayEnabled) {
        _overlayEnabled = false;
      } else {
        _overlayEnabled = true;
        _overlayColor = _lastOverlayColor;
      }
    });
  }

  Future<XFile?> _pickImageFromSource(ImageSource source) async {
    if (kIsWeb && source == ImageSource.camera) {
      source = ImageSource.gallery;
    }

    try {
      return await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> pickBackgroundImage() async {
    final file = await _showImageSourceSheet(
      title: 'Upload Background Image',
      sourceLabel: 'Background Image',
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    setState(() {
      _uploadBytes = bytes;
      _uploadFileName = file.name.isNotEmpty ? file.name : 'background.jpg';
      _backgroundImageEnabled = true;
      _currentImageIndex = 0;
      _message = '';
      _error = '';
    });
  }

  Future<XFile?> _showImageSourceSheet({
    required String title,
    required String sourceLabel,
  }) async {
    return showModalBottomSheet<XFile?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: AppColors.primaryRed),
                  ),
                  title: Text(
                    'Take Photo',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  onTap: () async {
                    final file = await _pickImageFromSource(ImageSource.camera);
                    Navigator.pop(ctx, file);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_outlined, color: AppColors.primaryRed),
                  ),
                  title: Text(
                    'Choose from Gallery',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  onTap: () async {
                    final file = await _pickImageFromSource(ImageSource.gallery);
                    Navigator.pop(ctx, file);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void selectImageAt(int index) {
    if (_backgroundImages.isEmpty) return;
    final normalizedIndex =
        (index + _backgroundImages.length) % _backgroundImages.length;
    if (!context.mounted) return;
    setState(() {
      _currentImageIndex = normalizedIndex;
      _uploadBytes = null;
      _uploadFileName = null;
      _backgroundImageEnabled = true;
      _message = '';
      _error = '';
    });
  }

  Future<void> _pickLogo() async {
    final file = await _showImageSourceSheet(
      title: 'Upload Logo',
      sourceLabel: 'Logo',
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (!context.mounted) return;

    setState(() {
      _message = '';
      _error = '';
      _logoFileNames = [
        file.name.isNotEmpty ? file.name : 'logo.png',
        ..._logoFileNames.where((item) => item != file.name).take(4),
      ];
    });

    await _extractLogoColors(
      bytes,
      file.name.isNotEmpty ? file.name : 'logo.png',
    );
  }

  String _colorToHex(Color color) {
    final hex = color.value
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();
    return '#$hex';
  }

  Future<void> _extractLogoColors(Uint8List bytes, String fileName) async {
    final authVm = ref.read(authViewModelProvider.notifier);
    final cardVm = ref.read(cardViewModelProvider.notifier);
    final customizeVm = ref.read(customizeViewModelProvider.notifier);
    final userId = authVm.currentUser?.id ?? '';
    final workProfileId = cardVm.currentCard?.userId;

    if (userId.isEmpty) return;

    try {
      final success = await customizeVm.extractLogoColors(
        userId,
        '',
        fileName,
        bytes: bytes,
        workProfileId: workProfileId,
      );
      final themeData = customizeVm.themeData ?? {};
      final rawColors = (themeData['extracted_colors'] is List)
          ? List<dynamic>.from(themeData['extracted_colors'] as List)
          : <dynamic>[];
      final dedupedPalette = buildPalette(rawColors, _defaultLogoPalette);
      if (!success && dedupedPalette.isEmpty) {
        throw Exception('Failed to extract logo colors');
      }

      setState(() {
        _logoPalette = dedupedPalette;
        if (dedupedPalette.isNotEmpty) {
          _bgColor = Color(
            int.parse('0xFF${dedupedPalette[0].replaceAll('#', '')}'),
          );
          _textColor = dedupedPalette.length > 1
              ? Color(int.parse('0xFF${dedupedPalette[1].replaceAll('#', '')}'))
              : _textColor;
          _overlayColor = Color(
            int.parse('0xFF${dedupedPalette[0].replaceAll('#', '')}'),
          );
          _lastOverlayColor = _overlayColor;
        }
        _majorColorStartIndex = 0;
        _selectedFilterColor = '';
        _filterApplyTarget = 'bg';
        _opacity = 0.5;
        _showUploadBanner = false;
      });
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _logoPalette = _defaultLogoPalette;
        _error = e.toString();
      });
    }
  }

  Map<String, Color> _getAutoMajorColors(List<String> palette, int startIndex) {
    final validPalette = palette
        .where(
          (color) =>
              normalizeHex(color, '').isNotEmpty &&
              !isIgnoredPaletteColor(color),
        )
        .toList();
    if (validPalette.isEmpty) {
      return {'bg': _bgColor, 'text': _textColor, 'overlay': _overlayColor};
    }

    final count = validPalette.length;
    final normalizedStart = ((startIndex % count) + count) % count;
    String pickAt(int offset) =>
        validPalette[(normalizedStart + offset) % count];

    return {
      'bg': Color(int.parse('0xFF${pickAt(0).replaceAll('#', '')}')),
      'text': Color(int.parse('0xFF${pickAt(1).replaceAll('#', '')}')),
      'overlay': Color(int.parse('0xFF${pickAt(2).replaceAll('#', '')}')),
    };
  }

  void _applyMajorColorOrderFromIndex(int startIndex) {
    final nextColors = _getAutoMajorColors(_logoPalette, startIndex);
    setState(() {
      _majorColorStartIndex = startIndex;
      _bgColor = nextColors['bg']!;
      _textColor = nextColors['text']!;
      _overlayColor = nextColors['overlay']!;
      _lastOverlayColor = _overlayColor;
      _backgroundColorEnabled = true;
    });
  }

  void _rotateMajorColors(String direction) {
    if (_logoPalette.isEmpty) return;
    final step = direction == 'prev' ? -1 : 1;
    final nextStart =
        (_majorColorStartIndex + step + _logoPalette.length) %
        _logoPalette.length;
    _applyMajorColorOrderFromIndex(nextStart);
  }

    void _navigateImages(String direction) {
    if (!_canNavigateImages) return;
    setState(() {
      if (direction == 'next') {
        _currentImageIndex = _nextIndex;
      } else {
        _currentImageIndex = _prevIndex;
      }
      _backgroundImageEnabled = true;
    });
  }

  void _applyFilterColorToTarget(String color, [String? target]) {
    final normalized = normalizeHex(color, '');
    if (normalized.isEmpty) return;

    final nextTarget = target ?? _filterApplyTarget;
    if (nextTarget.isEmpty) return;

    final parsed = Color(int.parse('0xFF${normalized.replaceAll('#', '')}'));
    setState(() {
      if (nextTarget == 'bg') {
        _bgColor = parsed;
        _backgroundColorEnabled = true;
      } else if (nextTarget == 'text') {
        _textColor = parsed;
      } else {
        _overlayColor = parsed;
        _lastOverlayColor = parsed;
        _overlayEnabled = true;
      }
    });
  }

  Future<void> _pickColor({
    required String title,
    required Color initialColor,
    required ValueChanged<Color> onSelected,
  }) async {
    Color tempColor = initialColor;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colors = ref.read(themeViewModelProvider.notifier).colors;
        return AlertDialog(
          backgroundColor: colors.card,
          title: Text(title, style: GoogleFonts.inter(color: colors.text)),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: tempColor,
              onColorChanged: (color) => tempColor = color,
              enableAlpha: false,
              displayThumbColor: true,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: TextStyle(color: colors.muted)),
            ),
            TextButton(
              onPressed: () {
                onSelected(tempColor);
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Apply',
                style: TextStyle(color: AppColors.primaryRed),
              ),
            ),
          ],
        );
      },
    );
  }

  void _resetAlerts() {
    setState(() {
      _message = '';
      _error = '';
    });
  }

  Future<void> _saveChanges() async {
    _resetAlerts();

    final authVm = ref.read(authViewModelProvider.notifier);
    final cardVm = ref.read(cardViewModelProvider.notifier);
    final customizeVm = ref.read(customizeViewModelProvider.notifier);
    final userId = authVm.currentUser?.id ?? '';
    final workProfileId = cardVm.currentCard?.workProfileId ?? cardVm.currentCard?.userId;

    if (userId.isEmpty) {
      setState(() => _error = 'User id not found');
      return;
    }

    if (_backgroundImageEnabled &&
        _uploadBytes == null &&
        _selectedLibraryKey.isEmpty) {
      setState(() => _error = 'Select a background image');
      return;
    }

    setState(() => _saving = true);

    try {
      final cleanBgColor = _colorToHex(_bgColor);
      final cleanTextColor = _textColorEnabled ? _colorToHex(_textColor) : '#000000';
      final cleanOverlayColor = _overlayEnabled
          ? _colorToHex(_overlayColor)
          : '';
      final cleanOpacity = normalizeOpacity(_opacity, fallback: 0.5);
      final savedBgImage = customizeVm.themeData?['bg_image']?.toString().trim() ?? '';
      final isLibraryImage = _backgroundImages.any((item) => resolveBackgroundImageKey(item) == savedBgImage);
      final String? bgImageKey;
      if (_uploadBytes != null) {
        bgImageKey = null;
      } else if (_backgroundImageEnabled) {
        if (!isLibraryImage && savedBgImage.isNotEmpty && _currentImageIndex == 0) {
          bgImageKey = savedBgImage;
        } else {
          bgImageKey = _selectedLibraryKey;
        }
      } else {
        bgImageKey = null;
      }

      if (_backgroundImageEnabled) {
        if (_uploadBytes != null) {
          final success = await customizeVm.uploadBackgroundImage(
            userId,
            '',
            _uploadFileName ?? 'background.jpg',
            bytes: _uploadBytes,
            payload: {
              'mode': 'custom',
              'bg_image_color': cleanOverlayColor.isNotEmpty
                  ? cleanOverlayColor
                  : null,
              'opacity': cleanOverlayColor.isNotEmpty ? cleanOpacity : null,
            },
            workProfileId: workProfileId,
          );
          final themeData = customizeVm.themeData ?? {};
          final persisted =
              themeData['bg_image']?.toString().trim() ??
              themeData['filename']?.toString().trim() ??
              themeData['path']?.toString().trim() ??
              themeData['image_path']?.toString().trim() ??
              '';
          if (!success && persisted.isEmpty) {
            throw Exception('Failed to upload background image');
          }
          if (persisted.isNotEmpty) {
            _backgroundImages = List<dynamic>.from(_backgroundImages);
            setState(() {
              _uploadBytes = null;
              _uploadFileName = null;
            });
          }
        } else if (bgImageKey != null && bgImageKey.isNotEmpty) {
          await customizeVm.saveBackgroundSelection(userId, {
            'bg_image': bgImageKey,
            'mode': 'custom',
            'bg_image_color': cleanOverlayColor.isNotEmpty
                ? cleanOverlayColor
                : null,
            'opacity': cleanOpacity,
          }, workProfileId: workProfileId);
        }
      }

      String? activeBgImage;
      if (_backgroundImageEnabled) {
        final updatedTheme = customizeVm.themeData ?? {};
        final serverBgImage = updatedTheme['bg_image']?.toString().trim() ??
            updatedTheme['filename']?.toString().trim() ??
            updatedTheme['path']?.toString().trim() ??
            updatedTheme['image_path']?.toString().trim() ??
            '';
        if (serverBgImage.isNotEmpty) {
          activeBgImage = serverBgImage;
        } else if (_selectedLibraryKey.isNotEmpty) {
          activeBgImage = _selectedLibraryKey;
        }
      }

      await customizeVm.saveColorSelection(userId, {
        'bg_image': activeBgImage,
        'bg_color': _backgroundColorEnabled ? cleanBgColor : null,
        'text_color': cleanTextColor,
        'bg_image_color':
            _backgroundImageEnabled && cleanOverlayColor.isNotEmpty
            ? cleanOverlayColor
            : null,
        'opacity': _backgroundImageEnabled && cleanOverlayColor.isNotEmpty
            ? cleanOpacity
            : null,
        'clear_background': !_backgroundImageEnabled,
      }, workProfileId: workProfileId);

      // Refresh the cards list to reflect changes immediately
      await cardVm.fetchCards(
        userId,
        fallbackName: authVm.currentUser?.displayName,
        fallbackPhone: authVm.currentUser?.phone ?? '',
        fallbackEmail: authVm.currentUser?.email,
      );

      // Sync local state with saved theme on server to clear unsaved changes indicators
      await _loadData();

      if (context.mounted) {
        setState(() {
          _message = 'AI customization updated';
        });
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (context.mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildSheetHeaderActions(Color textColor) {
    return IconButton(
      icon: Icon(Icons.close, color: textColor),
      onPressed: () => setState(() => _activeSheet = ''),
    );
  }

  Widget _buildBgImageSheet(BuildContext context, Color bgColor, Color textColor) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Background Image', style: GoogleFonts.inter(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Switch(
                    value: _backgroundImageEnabled,
                    activeThumbColor: AppColors.primaryRed,
                    onChanged: (val) {
                      setState(() {
                        _backgroundImageEnabled = val;
                        if (_backgroundImageEnabled && _backgroundImages.isNotEmpty) {
                          // Ensure valid index when enabled
                          if (_currentImageIndex < 0 || _currentImageIndex >= _backgroundImages.length) {
                            _currentImageIndex = _backgroundImages.length > 2 ? 2 : 0;
                          }
                        }
                      });
                    },
                  ),
                ],
              ),
              _buildSheetHeaderActions(textColor),
            ],
          ),
          const SizedBox(height: 16),
          if (_backgroundImageEnabled && _backgroundImages.isNotEmpty) ...[
            // Horizontal Image List
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (_currentImageIndex > 0) {
                      setState(() => _currentImageIndex--);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.chevron_left, color: _currentImageIndex > 0 ? textColor : textColor.withValues(alpha: 0.15)),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _backgroundImages.length,
                      itemBuilder: (context, index) {
                        final img = _backgroundImages[index];
                        final url = resolveBackgroundImageUrl(img);
                        final isSelected = index == _currentImageIndex;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentImageIndex = index;
                            });
                          },
                          child: Container(
                            width: 80,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSelected ? AppColors.primaryRed : Colors.transparent, width: 3),
                              image: url.isNotEmpty ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_currentImageIndex < _backgroundImages.length - 1) {
                      setState(() => _currentImageIndex++);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.chevron_right, color: _currentImageIndex < _backgroundImages.length - 1 ? textColor : textColor.withValues(alpha: 0.15)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildColorsSheet(BuildContext context, Color bgColor, Color textColor) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Colors', style: GoogleFonts.inter(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              _buildSheetHeaderActions(textColor),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Left Part: Background Color
              Expanded(
                child: Column(
                  children: [
                    Text('Bg Color', style: GoogleFonts.inter(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_backgroundColorEnabled) {
                                _pickColor(
                                  title: 'Background Color',
                                  initialColor: _bgColor,
                                  onSelected: (c) {
                                    setState(() => _bgColor = c);
                                  },
                                );
                              }
                            },
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: _backgroundColorEnabled ? _bgColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primaryRed),
                              ),
                              child: !_backgroundColorEnabled
                                  ? const Center(
                                      child: Icon(Icons.close, color: Colors.red),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _backgroundColorEnabled,
                          activeThumbColor: AppColors.primaryRed,
                          onChanged: (val) {
                            setState(() {
                              _backgroundColorEnabled = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Vertical Divider
              Container(
                width: 1,
                height: 50,
                color: textColor.withValues(alpha: 0.15),
              ),
              const SizedBox(width: 16),
              // Right Part: Text Color
              Expanded(
                child: Column(
                  children: [
                    Text('Text Color', style: GoogleFonts.inter(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_textColorEnabled) {
                                _pickColor(
                                  title: 'Text Color',
                                  initialColor: _textColor,
                                  onSelected: (c) {
                                    setState(() => _textColor = c);
                                  },
                                );
                              }
                            },
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: _textColorEnabled ? _textColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primaryRed),
                              ),
                              child: !_textColorEnabled
                                  ? const Center(
                                      child: Icon(Icons.close, color: Colors.red),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _textColorEnabled,
                          activeThumbColor: AppColors.primaryRed,
                          onChanged: (val) {
                            setState(() {
                              _textColorEnabled = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOverlaySheet(BuildContext context, Color bgColor, Color textColor) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Overlay', style: GoogleFonts.inter(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              _buildSheetHeaderActions(textColor),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Overlay Color', style: GoogleFonts.inter(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  if (_overlayEnabled) {
                    _pickColor(
                      title: 'Overlay Color',
                      initialColor: _overlayColor,
                      onSelected: (c) {
                        setState(() {
                          _overlayColor = c;
                          _lastOverlayColor = c;
                        });
                      },
                    );
                  }
                },
                child: Container(
                  width: 50,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _overlayEnabled ? _overlayColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryRed),
                  ),
                  child: !_overlayEnabled
                      ? const Center(
                          child: Icon(Icons.close, color: Colors.red, size: 18),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: _overlayEnabled,
                activeThumbColor: AppColors.primaryRed,
                onChanged: (val) {
                  setState(() {
                    _overlayEnabled = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_overlayEnabled) ...[
            Text('Opacity: ${_opacity.toStringAsFixed(2)}', style: GoogleFonts.inter(color: textColor)),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primaryRed,
                thumbColor: AppColors.primaryRed,
              ),
              child: Slider(
                value: _opacity,
                min: 0,
                max: 1,
                divisions: 20,
                onChanged: (val) {
                  setState(() => _opacity = val);
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLogoSheet(BuildContext context, Color bgColor, Color textColor) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Logo & Filter', style: GoogleFonts.inter(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              _buildSheetHeaderActions(textColor),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _pickLogo();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Logo Image'),
            ),
          ),
          const SizedBox(height: 24),
          if (_logoPalette.isNotEmpty) ...[
            Text('Extracted Colors', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _rotateMajorColors('prev'),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.chevron_left, color: textColor),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _logoPalette.take(5).map((color) {
                          final isSelected = _selectedFilterColor == color;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFilterColor = color;
                                if (_filterApplyTarget.isNotEmpty) {
                                  _applyFilterColorToTarget(color, _filterApplyTarget);
                                }
                              });
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: Color(int.parse("0xFF${color.replaceFirst("#", "")}")),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryRed : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _rotateMajorColors('next'),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.chevron_right, color: textColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Apply Color To:', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      backgroundColor: _bgColor,
                      foregroundColor: _bgColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                      side: BorderSide(
                        color: _filterApplyTarget == 'bg' ? AppColors.primaryRed : Colors.grey.withValues(alpha: 0.15),
                        width: _filterApplyTarget == 'bg' ? 3 : 1,
                      ),
                    ),
                    onPressed: () {
                      setState(() => _filterApplyTarget = 'bg');
                      if (_selectedFilterColor.isNotEmpty) _applyFilterColorToTarget(_selectedFilterColor, 'bg');
                    },
                    child: const Text('Background', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      backgroundColor: _textColor,
                      foregroundColor: _textColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                      side: BorderSide(
                        color: _filterApplyTarget == 'text' ? AppColors.primaryRed : Colors.grey.withValues(alpha: 0.15),
                        width: _filterApplyTarget == 'text' ? 3 : 1,
                      ),
                    ),
                    onPressed: () {
                      setState(() => _filterApplyTarget = 'text');
                      if (_selectedFilterColor.isNotEmpty) _applyFilterColorToTarget(_selectedFilterColor, 'text');
                    },
                    child: const Text('Text', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      backgroundColor: _overlayColor,
                      foregroundColor: _overlayColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                      side: BorderSide(
                        color: _filterApplyTarget == 'overlay' ? AppColors.primaryRed : Colors.grey.withValues(alpha: 0.15),
                        width: _filterApplyTarget == 'overlay' ? 3 : 1,
                      ),
                    ),
                    onPressed: () {
                      setState(() => _filterApplyTarget = 'overlay');
                      if (_selectedFilterColor.isNotEmpty) _applyFilterColorToTarget(_selectedFilterColor, 'overlay');
                    },
                    child: const Text('Overlay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeViewModelProvider).colors;
    final cardVm = ref.watch(cardViewModelProvider);
    final details = cardVm.selectedCardDetails;
    
    final selectedImageUrl = _selectedImageUrl;
    
    final showSolidTopStrip =
        _backgroundImageEnabled &&
        _backgroundColorEnabled &&
        (selectedImageUrl.isNotEmpty || _uploadBytes != null);
    final hideShadeOverlay = showSolidTopStrip;
    final fallbackCardBgColor = _backgroundColorEnabled
        ? _bgColor
        : Colors.white;
    final previewTextColor = _textColorEnabled ? _textColor : Colors.black;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.backgroundStart,
      appBar: SmartCardsFlowAppBar(
        onMenuTap: () {},
        initials: _previewInitials,
        onProfileTap: () => ProfileMenuBottomSheet.show(context),
      ),
      bottomNavigationBar: const GlobalBottomNav(),
            body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        if (_activeSheet.isNotEmpty) {
                          setState(() => _activeSheet = '');
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                        decoration: BoxDecoration(
                          color: fallbackCardBgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.border),
                          image: _backgroundImageEnabled
                              ? (_uploadBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(_uploadBytes!),
                                      fit: BoxFit.cover,
                                    )
                                  : selectedImageUrl.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(selectedImageUrl),
                                          fit: BoxFit.cover,
                                        )
                                      : null)
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_overlayEnabled)
                                Container(
                                  color: _overlayColor.withValues(
                                    alpha: _opacity.clamp(0.0, 1.0),
                                  ),
                                ),
                              if (!hideShadeOverlay)
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.1),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              Positioned.fill(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: 140,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          alignment: Alignment.center,
                                          children: [
                                            Positioned(
                                              top: 0,
                                              left: 0,
                                              right: 0,
                                              height: 60,
                                              child: Container(
                                                color: _backgroundColorEnabled ? _bgColor : AppColors.primaryRed.withValues(alpha: 0.15),
                                              ),
                                            ),
                                            Positioned(
                                              top: 10,
                                              child: Container(
                                                width: 100,
                                                height: 100,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.white,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black12,
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                                padding: const EdgeInsets.all(3),
                                                child: ClipOval(
                                                  child: _previewProfileImage.isNotEmpty
                                                      ? Image.network(
                                                          _previewProfileImage,
                                                          fit: BoxFit.cover,
                                                        )
                                                      : Container(
                                                          color: Colors.grey[200],
                                                          child: Center(
                                                            child: Text(
                                                              _previewInitials,
                                                              style: GoogleFonts.inter(
                                                                fontSize: 28,
                                                                fontWeight: FontWeight.bold,
                                                                color: Colors.grey[600],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 16),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _previewName,
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(
                                                color: previewTextColor,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (_previewDesignation.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                _previewDesignation,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.inter(
                                                  color: previewTextColor.withValues(alpha: 0.15),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (_previewCompanyLogo.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          constraints: const BoxConstraints(maxHeight: 100),
                                          margin: const EdgeInsets.symmetric(horizontal: 16),
                                          child: Image.network(_previewCompanyLogo, fit: BoxFit.contain),
                                        ),
                                        if (details != null && details.companyName.trim().isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                            ),
                                            child: Text(
                                              details.companyName.trim(),
                                              style: GoogleFonts.inter(
                                                color: previewTextColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                      const SizedBox(height: 12),
                                      if (details != null &&
                                          (details.companyName.isNotEmpty ||
                                              details.designation.isNotEmpty ||
                                              details.companyAddress.isNotEmpty))
                                        _buildSummaryCard(
                                          'Professional Details',
                                          [
                                            if (details.companyName.isNotEmpty)
                                              _buildSummaryItem('Professional', details.companyName, previewTextColor),
                                            if (details.designation.isNotEmpty)
                                              _buildSummaryItem('Designation', details.designation, previewTextColor),
                                            if (details.companyAddress.isNotEmpty)
                                              _buildSummaryItem('Address', details.companyAddress, previewTextColor),
                                            if (details.companyPincode.isNotEmpty)
                                              _buildSummaryItem('Pincode', details.companyPincode, previewTextColor),
                                          ],
                                          previewTextColor,
                                        ),
                                      if (details != null &&
                                          (details.companyEmails.isNotEmpty ||
                                              details.contactNumbers.isNotEmpty ||
                                              details.whatsappNumbers.isNotEmpty))
                                        _buildSummaryCard(
                                          'Professional Contact Details',
                                          [
                                            ...details.companyEmails.asMap().entries.map((e) {
                                              final idx = e.key;
                                              final email = e.value;
                                              return _buildSummaryItem('Email${idx > 0 ? ' ${idx + 1}' : ''}', email, previewTextColor);
                                            }),
                                            ...details.contactNumbers.asMap().entries.map((e) {
                                              final idx = e.key;
                                              final phone = e.value;
                                              return _buildSummaryItem('Phone${idx > 0 ? ' ${idx + 1}' : ''}', phone, previewTextColor);
                                            }),
                                            ...details.whatsappNumbers.asMap().entries.map((e) {
                                              final idx = e.key;
                                              final wa = e.value;
                                              return _buildSummaryItem('WhatsApp${idx > 0 ? ' ${idx + 1}' : ''}', wa, previewTextColor);
                                            }),
                                          ],
                                          previewTextColor,
                                        ),
                                      if (details != null &&
                                          (details.fbLink.isNotEmpty ||
                                              details.instaLink.isNotEmpty ||
                                              details.linkedin.isNotEmpty ||
                                              details.xLink.isNotEmpty))
                                        _buildSummaryCard(
                                          'Social Links',
                                          [
                                            if (details.fbLink.isNotEmpty) _buildSummaryItem('Facebook', details.fbLink, previewTextColor),
                                            if (details.instaLink.isNotEmpty) _buildSummaryItem('Instagram', details.instaLink, previewTextColor),
                                            if (details.linkedin.isNotEmpty) _buildSummaryItem('LinkedIn', details.linkedin, previewTextColor),
                                            if (details.xLink.isNotEmpty) _buildSummaryItem('X (Twitter)', details.xLink, previewTextColor),
                                          ],
                                          previewTextColor,
                                        ),
                                      if (details != null && details.aboutCompany.isNotEmpty)
                                        _buildSummaryCard(
                                          'About Company',
                                          [
                                            Text(
                                              details.aboutCompany.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '').trim(),
                                              style: GoogleFonts.inter(
                                                color: previewTextColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                          previewTextColor,
                                        ),
                                      const SizedBox(height: 60),
                                    ],
                                  ),
                                ),
                              ),
                              // Top Left Preview Badge
                              Positioned(
                                top: 12,
                                left: 12,
                                child: GestureDetector(
                                  onTap: () async {
                                    final card = cardVm.currentCard;
                                    String liveLink = 'https://thesmartcards.in/profile/${card?.userId ?? cardVm.userId}';
                                    final dbQr = card?.qrCode ?? '';
                                    if (dbQr.isNotEmpty) {
                                      try {
                                        final dbUri = Uri.parse(dbQr);
                                        final scVal = dbUri.queryParameters['sc'];
                                        if (scVal != null && scVal.isNotEmpty) {
                                          liveLink = 'https://thesmartcards.in/?sc=$scVal';
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
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Preview',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Action Buttons when sheet is inactive
                              if (_hasChanges && _activeSheet.isEmpty)
                                Positioned(
                                  bottom: 16,
                                  right: 16,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Reject Button (X)
                                      GestureDetector(
                                        onTap: _loadData,
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFFEF4444),
                                            border: Border.all(color: Colors.white, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.3),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // Save Button (✓)
                                      GestureDetector(
                                        onTap: _saving ? null : _saveChanges,
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF22C55E),
                                            border: Border.all(color: Colors.white, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.3),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: _saving
                                              ? const Padding(
                                                  padding: EdgeInsets.all(9.0),
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Icon(Icons.check, color: Colors.white, size: 24),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_backgroundImageEnabled && _canNavigateImages) ...[
                                // Left Arrow
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: GestureDetector(
                                    onTap: () => _navigateImages('prev'),
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 12),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withValues(alpha: 0.1),
                                      ),
                                      child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                                    ),
                                  ),
                                ),
                                // Right Arrow
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap: () => _navigateImages('next'),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 12),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withValues(alpha: 0.1),
                                      ),
                                      child: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                  if (_activeSheet.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Floating Action Buttons sitting FULLY ABOVE the top-right corner of the popup!
                          if (_hasChanges)
                            Padding(
                              padding: const EdgeInsets.only(right: 16, bottom: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Reject Button (X)
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _loadData,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFFEF4444),
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Save Button (✓)
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _saving ? null : () async {
                                      await _saveChanges();
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF22C55E),
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: _saving
                                          ? const Padding(
                                              padding: EdgeInsets.all(9.0),
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.check, color: Colors.white, size: 24),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            decoration: BoxDecoration(
                              color: colors.section,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                              child: _activeSheet == 'bgImage' ? _buildBgImageSheet(context, colors.section, colors.text)
                                  : _activeSheet == 'colors' ? _buildColorsSheet(context, colors.section, colors.text)
                                  : _activeSheet == 'overlay' ? _buildOverlaySheet(context, colors.section, colors.text)
                                  : _buildLogoSheet(context, colors.section, colors.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            EditorToolbar(
              backgroundColor: colors.section,
              iconColor: colors.muted,
              textColor: colors.text,
              onBgImageTap: () => setState(() => _activeSheet = _activeSheet == 'bgImage' ? '' : 'bgImage'),
              onColorsTap: () => setState(() => _activeSheet = _activeSheet == 'colors' ? '' : 'colors'),
              onOverlayTap: () => setState(() => _activeSheet = _activeSheet == 'overlay' ? '' : 'overlay'),
              onLogoTap: () => setState(() => _activeSheet = _activeSheet == 'logo' ? '' : 'logo'),
            ),
          ],
        ),
      ),
    );
  }
}
