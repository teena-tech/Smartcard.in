import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AvatarHelper {
  /// Extracts the single uppercase first letter of the first name.
  static String getFirstLetter(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final cleanName = name.trim();
    final parts = cleanName.split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty ? parts[0] : cleanName;
    for (int i = 0; i < firstName.length; i++) {
      final char = firstName[i];
      if (RegExp(r'[a-zA-Z0-9]').hasMatch(char)) {
        return char.toUpperCase();
      }
    }
    return firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
  }

  /// Generates a consistent 2-letter uppercase initials string from a name.
  static String getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';

    final cleanName = name.trim();
    final parts = cleanName.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    } else {
      final first = parts[0].isNotEmpty ? parts[0][0] : '';
      final last = parts[parts.length - 1].isNotEmpty ? parts[parts.length - 1][0] : '';
      final initials = '$first$last'.toUpperCase();
      return initials.isNotEmpty ? initials : '?';
    }
  }

  /// Selects a deterministic gradient pair based on string hash.
  static List<Color> getGradient(String? seed) {
    if (seed == null || seed.isEmpty) {
      return AppColors.avatarGradients[0];
    }
    final int hash = seed.hashCode.abs();
    final int index = hash % AppColors.avatarGradients.length;
    return AppColors.avatarGradients[index];
  }
}
