import 'package:flutter/material.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/core/services/app_update_service.dart';
import 'package:smartcard_flutter/core/utils/app_haptics.dart';

/// Professional iOS App Store update dialog.
/// Supports both optional updates (with a "Later" button)
/// and mandatory updates (non-dismissible with forced "Update Now" button).
class AppUpdateDialog extends StatelessWidget {
  final AppUpdateInfo updateInfo;
  final VoidCallback? onLater;

  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
    this.onLater,
  });

  bool get isMandatory => updateInfo.isMandatory;

  /// Display the dialog modally.
  /// When [updateInfo.isMandatory] is true, [barrierDismissible] and [canPop] are set to false.
  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo updateInfo,
    VoidCallback? onLater,
  }) async {
    final isMandatory = updateInfo.isMandatory;

    await showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (ctx) => PopScope(
        canPop: !isMandatory,
        child: AppUpdateDialog(
          updateInfo: updateInfo,
          onLater: onLater,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E28) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primaryRed.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Header Badge
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMandatory
                    ? Icons.system_security_update_warning_rounded
                    : Icons.system_update_rounded,
                color: AppColors.primaryRed,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),

            // Dialog Title
            Text(
              isMandatory ? 'Update Required' : 'New Update Available',
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),

            // Requirement 6 message text
            Text(
              isMandatory
                  ? 'A mandatory app update is required to continue using the application. Please update to get the latest features and security improvements.'
                  : 'A new version of the app is available. Please update to get the latest features and improvements.',
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.45,
              ),
            ),

            if (updateInfo.latestVersion.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Latest Version: ${updateInfo.latestVersion}',
                  style: AppFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Primary Action Button: "Update Now"
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  await AppHaptics.medium();
                  await AppUpdateService.launchAppStore(updateInfo.appStoreUrl);
                },
                child: Text(
                  'Update Now',
                  style: AppFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),

            // Secondary Action Button: "Later" (Only shown for optional updates)
            if (!isMandatory) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () async {
                    await AppHaptics.light();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                    if (onLater != null) {
                      onLater!();
                    }
                  },
                  child: Text(
                    'Later',
                    style: AppFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
