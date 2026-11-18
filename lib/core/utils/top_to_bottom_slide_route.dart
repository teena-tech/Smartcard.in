import 'package:flutter/material.dart';

/// Dynamic Top-to-Bottom slide-down animation
/// (Offset(0.0, -1.0) to Offset.zero with Curves.easeOutCubic)
/// across ALL tabs.
class TopToBottomSlideRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  TopToBottomSlideRoute({
    required this.page,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 450),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          fullscreenDialog: true,
          opaque: false,
          barrierColor: Colors.black54,
          barrierDismissible: true,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
              reverseCurve: Curves.easeInCubic,
            );

            // Dynamic Top-to-bottom slide translation (from -100% Y down to 0% Y)
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0.0, -1.0),
              end: Offset.zero,
            ).animate(curvedAnimation);

            final fadeAnimation = Tween<double>(
              begin: 0.1,
              end: 1.0,
            ).animate(curvedAnimation);

            return FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: slideAnimation,
                child: child,
              ),
            );
          },
        );
}
