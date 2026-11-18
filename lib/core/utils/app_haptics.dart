import 'package:flutter/services.dart';

/// Helper utility for iOS Apple Taptic Engine & Android Haptic Feedback.
/// Provides subtle physical touch feedback for buttons, card scans, and actions.
class AppHaptics {
  /// Subtle light impact (e.g. tapping icons, toggling switches)
  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium impact (e.g. saving contacts, button submission)
  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact (e.g. deleting cards, error alerts)
  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  /// Selection click feedback (e.g. scrolling lists, picking tabs)
  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }

  /// Success vibration notification
  static Future<void> success() async {
    await HapticFeedback.vibrate();
  }
}
