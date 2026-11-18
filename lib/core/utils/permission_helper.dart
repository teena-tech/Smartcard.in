import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

enum ContactPermissionState {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

class PermissionHelper {
  static bool get isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  /// Check current status of Contacts permission
  static Future<ContactPermissionState> checkContactsPermission() async {
    if (kIsWeb || isDesktop) return ContactPermissionState.granted;
    try {
      final status = await Permission.contacts.status;
      if (status.isGranted || status.isLimited) {
        return ContactPermissionState.granted;
      } else if (status.isPermanentlyDenied) {
        return ContactPermissionState.permanentlyDenied;
      } else if (status.isRestricted) {
        return ContactPermissionState.restricted;
      } else {
        return ContactPermissionState.denied;
      }
    } catch (_) {
      return ContactPermissionState.denied;
    }
  }

  /// Request contacts permission with platform dialog
  static Future<ContactPermissionState> requestContactsPermission() async {
    if (kIsWeb || isDesktop) return ContactPermissionState.granted;
    try {
      final status = await Permission.contacts.request();
      if (status.isGranted || status.isLimited) {
        return ContactPermissionState.granted;
      } else if (status.isPermanentlyDenied) {
        return ContactPermissionState.permanentlyDenied;
      } else if (status.isRestricted) {
        return ContactPermissionState.restricted;
      } else {
        return ContactPermissionState.denied;
      }
    } catch (_) {
      return ContactPermissionState.denied;
    }
  }

  /// Open System App Settings for manual permission grant
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Show standard dialog explaining why permission is required
  static Future<bool?> showPermissionRationaleDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    VoidCallback? onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(ctx).primaryColor.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.contacts_rounded,
                color: Theme.of(ctx).primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: Theme.of(ctx).colorScheme.onSurface.withAlpha(200),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx, true);
              onConfirm?.call();
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}
