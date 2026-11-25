import 'package:flutter/material.dart';

/// Generates a stable, unique Hero tag for a contact based on its unique ID.
/// Strictly avoids random IDs or volatile timestamps so rebuilds never break Hero animations.
String contactHeroTag({
  required String? id,
  String? phone,
  String? name,
}) {
  final cleanId = id?.trim();
  if (cleanId != null && cleanId.isNotEmpty && cleanId.toLowerCase() != 'null') {
    return 'contact_profile_$cleanId';
  }

  // Deterministic fallback based on digits
  final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.isNotEmpty) {
    return 'contact_profile_phone_$digits';
  }

  // Deterministic fallback based on name
  final cleanName = (name ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  if (cleanName.isNotEmpty) {
    return 'contact_profile_name_$cleanName';
  }

  return 'contact_profile_default';
}

/// Custom RectTween for smooth, natural curved Hero flight.
/// Uses Material curved arc interpolation so width, height, and position
/// are 100% synchronized with zero stretching, distortion, or ballooning.
class GenieRectTween extends RectTween {
  MaterialRectCenterArcTween? _arcTween;

  GenieRectTween({super.begin, super.end}) {
    if (begin != null && end != null) {
      _arcTween = MaterialRectCenterArcTween(begin: begin, end: end);
    }
  }

  @override
  set begin(Rect? value) {
    super.begin = value;
    if (value != null && end != null) {
      _arcTween = MaterialRectCenterArcTween(begin: value, end: end);
    }
  }

  @override
  set end(Rect? value) {
    super.end = value;
    if (begin != null && value != null) {
      _arcTween = MaterialRectCenterArcTween(begin: begin, end: value);
    }
  }

  @override
  Rect lerp(double t) {
    if (_arcTween != null) {
      return _arcTween!.lerp(t);
    }
    return super.lerp(t) ?? begin ?? end ?? const Rect.fromLTWH(0, 0, 48, 48);
  }
}

/// Custom Hero flight shuttle builder that maintains visual continuity and aspect ratio.
/// - Preserves aspect ratio with BoxFit.cover
/// - During push: scales destination child into place
/// - During pop (reverse): preserves loaded detail avatar so image never disappears or flashes
Widget genieFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final Hero toHero = toHeroContext.widget as Hero;
  final Hero fromHero = fromHeroContext.widget as Hero;

  // Use the loaded detail child during pop to ensure zero flickering or image disappearance
  final Widget activeChild = flightDirection == HeroFlightDirection.push
      ? toHero.child
      : fromHero.child;

  return Material(
    color: Colors.transparent,
    child: FittedBox(
      fit: BoxFit.cover,
      child: activeChild,
    ),
  );
}

/// Custom PageRoute with smooth background fade synchronized with Hero animation
class GeniePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  GeniePageRoute({
    required this.page,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 450),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: curvedAnimation,
              child: child,
            );
          },
        );
}
