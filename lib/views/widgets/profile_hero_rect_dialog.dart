import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/upload_url_resolver.dart';

/// Custom RectTween using Material curved arc for natural fluid motion
class ProfileHeroArcTween extends RectTween {
  ProfileHeroArcTween({super.begin, super.end});

  @override
  Rect lerp(double t) {
    if (begin == null || end == null) {
      return super.lerp(t) ?? begin ?? end ?? const Rect.fromLTWH(0, 0, 84, 84);
    }
    // Use Material arc path
    return MaterialRectCenterArcTween(begin: begin, end: end).lerp(t);
  }
}

/// Flight shuttle builder that morphs corner radius between circular (42) and rounded rectangle (22)
Widget profileHeroFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final Hero toHero = toHeroContext.widget as Hero;
  final Hero fromHero = fromHeroContext.widget as Hero;
  final Widget activeChild = flightDirection == HeroFlightDirection.push
      ? toHero.child
      : fromHero.child;

  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final double progress = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      ).value;

      // When push: progress 0.0 -> 1.0 (from circle 42.0 to rect 22.0)
      // When pop: Flutter automatically reverses animation 1.0 -> 0.0
      final double radius = lerpDouble(42.0, 22.0, progress) ?? 22.0;

      return Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 290,
              height: 360,
              child: activeChild,
            ),
          ),
        ),
      );
    },
  );
}

/// Transparent PageRoute that hosts the Hero rectangular preview dialog
class ProfileHeroDialogRoute<T> extends PageRoute<T> {
  ProfileHeroDialogRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : _builder = builder;

  final WidgetBuilder _builder;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 280);

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      child: child,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _builder(context);
  }
}

/// Small rectangular preview dialog for profile image with Hero animation
class ProfileHeroRectDialog extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final String fullName;
  final String initials;

  const ProfileHeroRectDialog({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    required this.fullName,
    required this.initials,
  });

  /// Convenient helper to push this dialog with Hero animation
  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
    required String heroTag,
    required String fullName,
    required String initials,
  }) {
    return Navigator.of(context).push(
      ProfileHeroDialogRoute(
        builder: (ctx) => ProfileHeroRectDialog(
          imageUrl: imageUrl,
          heroTag: heroTag,
          fullName: fullName,
          initials: initials,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String resolvedUrl = UploadUrlResolver.resolve(imageUrl, type: 'profile');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background dismiss barrier with blur
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
              ),
            ),
          ),

          // Centered small rectangular box
          Center(
            child: SizedBox(
              width: 290,
              height: 360,
              child: Hero(
                tag: heroTag,
                createRectTween: (begin, end) => ProfileHeroArcTween(begin: begin, end: end),
                flightShuttleBuilder: profileHeroFlightShuttleBuilder,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E222D),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 30,
                          spreadRadius: 2,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: AppColors.primaryRed.withValues(alpha: 0.22),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Crystal clear profile image
                        CachedNetworkImage(
                          imageUrl: resolvedUrl,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          fadeInDuration: const Duration(milliseconds: 150),
                          fadeOutDuration: const Duration(milliseconds: 150),
                          placeholder: (ctx, url) => Container(
                            color: const Color(0xFF1E222D),
                            child: const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryRed,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (_, _, _) => Container(
                            color: const Color(0xFF1E222D),
                            alignment: Alignment.center,
                            child: Text(
                              initials.isNotEmpty ? initials : 'U',
                              style: GoogleFonts.outfit(
                                color: AppColors.primaryRed,
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        // Top bar overlay with gradient, name and close X button
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 12, 12, 20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withValues(alpha: 0.72),
                                  Colors.transparent,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    fullName,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 17,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Bottom bar overlay with subtle branding / status
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.65),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF22C55E),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Profile Photo',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
