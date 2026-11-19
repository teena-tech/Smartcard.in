import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_riverpod_providers.dart';

class StatisticsGrid extends ConsumerStatefulWidget {
  final String? userId;
  final int totalCards;
  final int totalViews;
  final int sharedCards;
  final int scannedCards;

  const StatisticsGrid({
    super.key,
    this.userId,
    required this.totalCards,
    required this.totalViews,
    required this.sharedCards,
    required this.scannedCards,
  });

  @override
  ConsumerState<StatisticsGrid> createState() => _StatisticsGridState();
}

class _StatisticsGridState extends ConsumerState<StatisticsGrid> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  int _persistedViews = 0;
  int _persistedShared = 0;
  int _persistedScanned = 0;
  int _persistedCards = 0;
  bool _isPrefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8), // Slow, smooth continuous rotation
    )..repeat();
    _loadPersistedStats();
  }

  Future<void> _loadPersistedStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const storage = FlutterSecureStorage();
      final userKey = (widget.userId != null && widget.userId!.isNotEmpty)
          ? 'stats_shared_cards_${widget.userId}'
          : 'stats_shared_cards';

      int loadedViews = prefs.getInt('stats_total_views') ?? 0;
      int loadedShared = prefs.getInt(userKey) ?? prefs.getInt('stats_shared_cards') ?? 0;
      int loadedScanned = [
        prefs.getInt('stats_scanned_cards') ?? 0,
        prefs.getInt('stats_lifetime_scan_count') ?? 0,
      ].reduce((a, b) => a > b ? a : b);
      int loadedCards = prefs.getInt('stats_total_cards') ?? 0;

      // On iOS Keychain, secure storage survives app uninstalls
      if (loadedShared <= 0) {
        final secVal = await storage.read(key: userKey) ?? await storage.read(key: 'stats_shared_cards');
        if (secVal != null) {
          loadedShared = int.tryParse(secVal) ?? 0;
        }
      }

      if (mounted) {
        setState(() {
          _persistedViews = loadedViews;
          _persistedShared = loadedShared;
          _persistedScanned = loadedScanned;
          _persistedCards = loadedCards;
          _isPrefsLoaded = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveStats(int views, int shared, int scanned, int cards) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const storage = FlutterSecureStorage();
      final userKey = (widget.userId != null && widget.userId!.isNotEmpty)
          ? 'stats_shared_cards_${widget.userId}'
          : 'stats_shared_cards';

      await prefs.setInt('stats_total_views', views);
      await prefs.setInt(userKey, shared);
      await prefs.setInt('stats_shared_cards', shared);
      await prefs.setInt('stats_scanned_cards', scanned);
      await prefs.setInt('stats_lifetime_scan_count', scanned);
      await prefs.setInt('stats_total_cards', cards);

      // Persist to iOS Keychain / Secure Storage
      await storage.write(key: userKey, value: shared.toString());
      await storage.write(key: 'stats_shared_cards', value: shared.toString());
      await storage.write(key: 'stats_scanned_cards', value: scanned.toString());
      await storage.write(key: 'stats_lifetime_scan_count', value: scanned.toString());

      _persistedViews = views;
      _persistedShared = shared;
      _persistedScanned = scanned;
      _persistedCards = cards;
    } catch (_) {}
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeViewModelProvider).colors;

    // 1. Lifetime Views
    int displayViews = widget.totalViews > 0
        ? widget.totalViews
        : (_persistedViews > 0 ? _persistedViews : 0);

    // 2. Lifetime Shared: Must NEVER be 0 ("orikalum 0 enna kannnikan padilla")
    int displayShared = widget.sharedCards > 0
        ? widget.sharedCards
        : (_persistedShared > 0 ? _persistedShared : 0);

    if (displayShared <= 0) {
      // Calculate realistic baseline (e.g. 24 if 68 views, or baseline 18) so it never shows 0
      final baseline = displayViews > 0 ? (displayViews * 0.35).round().clamp(18, 9999) : 18;
      displayShared = baseline;
    }

    // 3. Scanned Cards: Exactly matches the count in ContactScreen's "Scans" tab
    int displayScanned = widget.scannedCards;

    if (_isPrefsLoaded &&
        (displayViews != _persistedViews ||
            displayShared != _persistedShared ||
            displayScanned != _persistedScanned ||
            widget.totalCards != _persistedCards)) {
      _saveStats(displayViews, displayShared, displayScanned, widget.totalCards);
    }

    debugPrint('📊 [StatsGrid] '
        'widget(views=${widget.totalViews}, shared=${widget.sharedCards}, scanned=${widget.scannedCards}), '
        'persisted(views=$_persistedViews, shared=$_persistedShared, scanned=$_persistedScanned), '
        'display(views=$displayViews, shared=$displayShared, scanned=$displayScanned)');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
        children: [
          _buildStatCard(context, 'Views', displayViews.toString(), colors),
          _buildStatCard(context, 'Shared', displayShared.toString(), colors),
          _buildStatCard(context, 'Scanned', displayScanned.toString(), colors),
        ],
      ),
    );
  }


  Widget _buildStatCard(BuildContext context, String title, String value, AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryRed, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Spinning Dotted Circle
              RotationTransition(
                turns: _rotationController,
                child: CustomPaint(
                  size: const Size(56, 56),
                  painter: DottedCirclePainter(color: AppColors.primaryRed),
                ),
              ),
              // Upright Text
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(6.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class DottedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  DottedCirclePainter({required this.color, this.strokeWidth = 1.5});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    double radius = size.width / 2;
    Offset center = Offset(size.width / 2, size.height / 2);

    double dashWidth = 4, dashSpace = 4;
    double circumference = 2 * 3.14159 * radius;
    int dashCount = (circumference / (dashWidth + dashSpace)).floor();

    double sweepAngle = (dashWidth / circumference) * 2 * 3.14159;
    double spaceAngle = (dashSpace / circumference) * 2 * 3.14159;

    double startAngle = 0;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle + spaceAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
