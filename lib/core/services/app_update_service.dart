import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_update/in_app_update.dart' as play_update;
import '../../views/widgets/app_update_dialog.dart';

/// Enum representing the status of the iOS App Store update check.
enum AppUpdateStatus {
  upToDate,
  optionalUpdateAvailable,
  mandatoryUpdateAvailable,
  error,
}

/// Data class holding update details returned by the App Store lookup.
class AppUpdateInfo {
  final AppUpdateStatus status;
  final String currentVersion;
  final String latestVersion;
  final String? appStoreUrl;
  final String? releaseNotes;

  AppUpdateInfo({
    required this.status,
    required this.currentVersion,
    required this.latestVersion,
    this.appStoreUrl,
    this.releaseNotes,
  });

  bool get isUpdateAvailable =>
      status == AppUpdateStatus.optionalUpdateAvailable ||
      status == AppUpdateStatus.mandatoryUpdateAvailable;

  bool get isMandatory =>
      status == AppUpdateStatus.mandatoryUpdateAvailable;
}

/// ============================================================================
/// CONFIGURATION FOR IOS APP STORE UPDATES
/// ============================================================================
/// Update these configuration parameters for your release build.
class AppUpdateConfig {
  /// Enter your numeric Apple App Store ID here once registered on App Store Connect.
  /// Example: static const String appStoreId = '6441234567';
  /// If left empty (''), the lookup API will fall back to using your iOS bundle identifier.
  static const String appStoreId = '';

  /// Optional explicit App Store URL override (e.g. 'https://apps.apple.com/app/id6441234567').
  /// If left empty, the URL is resolved automatically from iTunes lookup or appStoreId.
  static const String customAppStoreUrl = '';

  /// Set to [true] for a mandatory/critical update where the user cannot dismiss the dialog.
  /// When true, the "Later" button is removed and back-navigation is disabled.
  static const bool forceUpdate = true;

  /// Optional minimum required version (e.g. '1.0.5').
  /// If the currently installed version is lower than this value, forceUpdate is automatically enforced.
  static const String? minimumRequiredVersion = null;

  /// Country code for iTunes lookup API region (e.g. 'us', 'in', 'gb').
  static const String appStoreCountry = 'in';
}

/// ============================================================================
/// IOS AUTOMATIC APP UPDATE SERVICE
/// ============================================================================
/// A dedicated, reusable service that checks for newer versions on the Apple App Store,
/// compares versions semantically, and opens the official App Store page.
class AppUpdateService {
  /// Session lock flag to prevent repeated dialog prompts during the same app launch session.
  static bool _hasCheckedThisSession = false;

  /// Checks whether a newer version of the iOS app is available on the Apple App Store.
  /// 
  /// Rules:
  /// - Restricted exclusively to iOS (`Platform.isIOS`). Returns [AppUpdateStatus.upToDate] on Android.
  /// - Runs once per app session unless [forceCheck] is set to `true`.
  /// - Safely handles offline status, API errors, missing apps, and invalid version formats.
  static Future<AppUpdateInfo> checkForUpdate({
    bool forceCheck = false,
    String? appStoreId,
    String? customAppStoreUrl,
    bool? forceUpdate,
    String? minimumRequiredVersion,
    String? country,
  }) async {
    // 1. Android Google Play in-app update check
    if (Platform.isAndroid) {
      if (_hasCheckedThisSession && !forceCheck) {
        debugPrint('ℹ️ AppUpdateService: Android update check already completed in this session.');
        return AppUpdateInfo(
          status: AppUpdateStatus.upToDate,
          currentVersion: '',
          latestVersion: '',
        );
      }
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;
        final playInfo = await play_update.InAppUpdate.checkForUpdate();
        _hasCheckedThisSession = true;

        if (playInfo.updateAvailability == play_update.UpdateAvailability.updateAvailable) {
          final isForced = forceUpdate ?? (playInfo.immediateUpdateAllowed && !playInfo.flexibleUpdateAllowed);
          return AppUpdateInfo(
            status: isForced
                ? AppUpdateStatus.mandatoryUpdateAvailable
                : AppUpdateStatus.optionalUpdateAvailable,
            currentVersion: currentVersion,
            latestVersion: playInfo.availableVersionCode != null ? 'Build ${playInfo.availableVersionCode}' : currentVersion,
            appStoreUrl: 'https://play.google.com/store/apps/details?id=${packageInfo.packageName}',
          );
        }
      } catch (e) {
        debugPrint('ℹ️ Android InAppUpdate check (handled): $e');
      }
      _hasCheckedThisSession = true;
      return AppUpdateInfo(
        status: AppUpdateStatus.upToDate,
        currentVersion: '',
        latestVersion: '',
      );
    }

    if (!Platform.isIOS) {
      debugPrint('ℹ️ AppUpdateService: Unsupported platform detected. Skipping update check.');
      return AppUpdateInfo(
        status: AppUpdateStatus.upToDate,
        currentVersion: '',
        latestVersion: '',
      );
    }

    // 2. Prevent repeat dialog prompts during the same app session.
    if (_hasCheckedThisSession && !forceCheck) {
      debugPrint('ℹ️ AppUpdateService: Update check already completed in this session.');
      return AppUpdateInfo(
        status: AppUpdateStatus.upToDate,
        currentVersion: '',
        latestVersion: '',
      );
    }

    try {
      // Retrieve currently installed package information safely
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. '1.0.6'
      final bundleId = packageInfo.packageName;   // e.g. 'com.smartcards.app'

      final targetAppStoreId = appStoreId ?? AppUpdateConfig.appStoreId;
      final targetCountry = country ?? AppUpdateConfig.appStoreCountry;
      final isForced = forceUpdate ?? AppUpdateConfig.forceUpdate;
      final minReqVersion = minimumRequiredVersion ?? AppUpdateConfig.minimumRequiredVersion;

      // Build official iTunes Lookup API endpoint
      Uri lookupUri;
      if (targetAppStoreId.isNotEmpty) {
        lookupUri = Uri.parse(
          'https://itunes.apple.com/lookup?id=$targetAppStoreId&country=$targetCountry',
        );
      } else {
        lookupUri = Uri.parse(
          'https://itunes.apple.com/lookup?bundleId=$bundleId&country=$targetCountry',
        );
      }

      debugPrint('🔍 AppUpdateService: Querying iTunes API: $lookupUri');

      // Requirement 10: 8-second HTTP request timeout to prevent hanging on weak network
      final response = await http.get(lookupUri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        final results = jsonMap['results'] as List?;

        // Handle case where app is not yet published on App Store or lookup returns 0 items
        if (results == null || results.isEmpty) {
          debugPrint('ℹ️ AppUpdateService: No App Store entry found for bundleId/appStoreId ($bundleId).');
          _hasCheckedThisSession = true;
          return AppUpdateInfo(
            status: AppUpdateStatus.upToDate,
            currentVersion: currentVersion,
            latestVersion: currentVersion,
          );
        }

        final appData = results.first as Map<String, dynamic>;
        final latestVersion = appData['version'] as String? ?? currentVersion;
        final trackId = appData['trackId']?.toString();
        final releaseNotes = appData['releaseNotes'] as String?;

        // Resolve App Store deep link / store URL
        String finalAppStoreUrl = AppUpdateConfig.customAppStoreUrl;
        if (customAppStoreUrl != null && customAppStoreUrl.isNotEmpty) {
          finalAppStoreUrl = customAppStoreUrl;
        } else if (finalAppStoreUrl.isEmpty) {
          final trackViewUrl = appData['trackViewUrl'] as String?;
          if (trackViewUrl != null && trackViewUrl.isNotEmpty) {
            finalAppStoreUrl = trackViewUrl;
          } else if (trackId != null && trackId.isNotEmpty) {
            finalAppStoreUrl = 'https://apps.apple.com/app/id$trackId';
          } else if (targetAppStoreId.isNotEmpty) {
            finalAppStoreUrl = 'https://apps.apple.com/app/id$targetAppStoreId';
          } else {
            finalAppStoreUrl = 'https://apps.apple.com/app/id$bundleId';
          }
        }

        // Compare versions semantically
        final isNewerAvailable = _isVersionOlder(currentVersion, latestVersion);
        final isBelowMinimum = _isVersionOlder(currentVersion, minReqVersion);

        _hasCheckedThisSession = true;

        if (isForced || isBelowMinimum) {
          if (isNewerAvailable || isBelowMinimum) {
            return AppUpdateInfo(
              status: AppUpdateStatus.mandatoryUpdateAvailable,
              currentVersion: currentVersion,
              latestVersion: latestVersion,
              appStoreUrl: finalAppStoreUrl,
              releaseNotes: releaseNotes,
            );
          }
        } else if (isNewerAvailable) {
          return AppUpdateInfo(
            status: AppUpdateStatus.optionalUpdateAvailable,
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            appStoreUrl: finalAppStoreUrl,
            releaseNotes: releaseNotes,
          );
        }
      }
    } catch (e) {
      // Requirement 10: Gracefully handle network exceptions, timeouts, format errors without crashing
      debugPrint('⚠️ AppUpdateService error (handled gracefully): $e');
    }

    _hasCheckedThisSession = true;
    return AppUpdateInfo(
      status: AppUpdateStatus.upToDate,
      currentVersion: '1.0.0',
      latestVersion: '1.0.0',
    );
  }

  /// Helper method to execute update check and display the update dialog automatically.
  static Future<void> checkAndShowUpdateDialog(
    BuildContext context, {
    bool forceCheck = false,
    VoidCallback? onLater,
  }) async {
    // Android Google Play Immediate Update Flow (WhatsApp-style: no restart buttons)
    if (Platform.isAndroid) {
      try {
        final playInfo = await play_update.InAppUpdate.checkForUpdate();

        // 1. Resume interrupted update if one was already started
        if (playInfo.updateAvailability == play_update.UpdateAvailability.developerTriggeredUpdateInProgress) {
          debugPrint('🔄 Resuming in-progress immediate update on Android...');
          await play_update.InAppUpdate.performImmediateUpdate();
          return;
        }

        // 2. Prevent repeat checks during the same session unless forced
        if (_hasCheckedThisSession && !forceCheck) {
          return;
        }

        // 3. Trigger WhatsApp-style Immediate update directly
        if (playInfo.updateAvailability == play_update.UpdateAvailability.updateAvailable) {
          _hasCheckedThisSession = true;
          debugPrint('🚨 Starting WhatsApp-style IMMEDIATE in-app update...');
          if (playInfo.immediateUpdateAllowed) {
            final result = await play_update.InAppUpdate.performImmediateUpdate();
            if (result == play_update.AppUpdateResult.userDeniedUpdate && context.mounted) {
              _showMandatoryUpdateDeniedDialog(context);
            }
            return;
          } else if (playInfo.flexibleUpdateAllowed) {
            // If device only permits flexible, download and automatically complete without restart buttons
            final result = await play_update.InAppUpdate.startFlexibleUpdate();
            if (result == play_update.AppUpdateResult.success) {
              await play_update.InAppUpdate.completeFlexibleUpdate();
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('ℹ️ Android InAppUpdate check/prompt error: $e');
      }

      _hasCheckedThisSession = true;

      if (forceCheck) {
        final updateInfo = await checkForUpdate(forceCheck: forceCheck);
        if (updateInfo.isUpdateAvailable && context.mounted) {
          await AppUpdateDialog.show(
            context,
            updateInfo: updateInfo,
            onLater: onLater,
          );
        }
      }
      return;
    }

    if (!Platform.isIOS) return;

    final updateInfo = await checkForUpdate(forceCheck: forceCheck);

    if (updateInfo.isUpdateAvailable && context.mounted) {
      await AppUpdateDialog.show(
        context,
        updateInfo: updateInfo,
        onLater: onLater,
      );
    }
  }

  /// Launch official Google Play Store or Apple App Store page via url_launcher.
  static Future<bool> launchAppStore([String? customUrl]) async {
    try {
      if (Platform.isAndroid) {
        final packageInfo = await PackageInfo.fromPlatform();
        final pkg = packageInfo.packageName.isNotEmpty ? packageInfo.packageName : 'com.antz_media_solutions.SmartCards';
        final marketUri = Uri.parse('market://details?id=$pkg');
        final webUri = Uri.parse('https://play.google.com/store/apps/details?id=$pkg');
        if (await canLaunchUrl(marketUri)) {
          return await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        } else if (await canLaunchUrl(webUri)) {
          return await launchUrl(webUri, mode: LaunchMode.externalApplication);
        }
        return false;
      }

      String urlString = customUrl ?? AppUpdateConfig.customAppStoreUrl;

      if (urlString.isEmpty && AppUpdateConfig.appStoreId.isNotEmpty) {
        urlString = 'https://apps.apple.com/app/id${AppUpdateConfig.appStoreId}';
      }

      if (urlString.isEmpty) {
        final packageInfo = await PackageInfo.fromPlatform();
        urlString = 'https://apps.apple.com/app/id${packageInfo.packageName}';
      }

      final uri = Uri.parse(urlString);
      debugPrint('🚀 AppUpdateService: Opening App Store page: $urlString');

      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('⚠️ Error launching App Store URL: $e');
    }
    return false;
  }

  /// Reset session lock flag to allow checking again in the current session if needed.
  static void resetSessionCheck() {
    _hasCheckedThisSession = false;
  }

  /// Compares version numbers (e.g. "1.0.6" vs "1.0.7"). Returns true if [installed] < [target].
  static bool _isVersionOlder(String installed, String? target) {
    if (target == null || target.trim().isEmpty) return false;

    try {
      final installedClean = installed.split('+').first.split('-').first.trim();
      final targetClean = target.split('+').first.split('-').first.trim();

      final installedParts = installedClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final targetParts = targetClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = installedParts.length > targetParts.length
          ? installedParts.length
          : targetParts.length;

      for (int i = 0; i < maxLength; i++) {
        final v1 = i < installedParts.length ? installedParts[i] : 0;
        final v2 = i < targetParts.length ? targetParts[i] : 0;
        if (v1 < v2) return true;
        if (v1 > v2) return false;
      }
    } catch (e) {
      debugPrint('⚠️ Version comparison parsing error ($installed vs $target): $e');
    }
    return false;
  }

  static void _showMandatoryUpdateDeniedDialog(BuildContext context) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Update Required'),
          content: const Text('A critical update is required to continue using the app. Please update to proceed.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                checkAndShowUpdateDialog(context, forceCheck: true);
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }
}
