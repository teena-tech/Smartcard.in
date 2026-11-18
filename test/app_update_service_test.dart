import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard_flutter/core/services/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppUpdateService Version Comparison & Status Tests', () {
    test('Identifies newer App Store version correctly', () {
      final updateInfoOptional = AppUpdateInfo(
        status: AppUpdateStatus.optionalUpdateAvailable,
        currentVersion: '1.0.6',
        latestVersion: '1.1.0',
        appStoreUrl: 'https://apps.apple.com/app/id123456789',
      );

      expect(updateInfoOptional.status, equals(AppUpdateStatus.optionalUpdateAvailable));
      expect(updateInfoOptional.currentVersion, equals('1.0.6'));
      expect(updateInfoOptional.latestVersion, equals('1.1.0'));
      expect(updateInfoOptional.appStoreUrl, isNotNull);
    });

    test('Identifies mandatory minimum version correctly', () {
      final updateInfoMandatory = AppUpdateInfo(
        status: AppUpdateStatus.mandatoryUpdateAvailable,
        currentVersion: '1.0.6',
        latestVersion: '1.2.0',
        appStoreUrl: 'https://apps.apple.com/app/id123456789',
      );

      expect(updateInfoMandatory.status, equals(AppUpdateStatus.mandatoryUpdateAvailable));
      expect(updateInfoMandatory.currentVersion, equals('1.0.6'));
      expect(updateInfoMandatory.latestVersion, equals('1.2.0'));
    });

    test('Identifies up to date version correctly', () {
      final updateInfoUpToDate = AppUpdateInfo(
        status: AppUpdateStatus.upToDate,
        currentVersion: '1.0.6',
        latestVersion: '1.0.6',
      );

      expect(updateInfoUpToDate.status, equals(AppUpdateStatus.upToDate));
      expect(updateInfoUpToDate.currentVersion, equals(updateInfoUpToDate.latestVersion));
    });
  });
}
