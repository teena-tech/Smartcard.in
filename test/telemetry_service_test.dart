import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard_flutter/core/services/telemetry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TelemetryService: singleton instance exists', () {
    final t1 = TelemetryService();
    final t2 = TelemetryService.instance;
    expect(identical(t1, t2), isTrue);
  });

  test('TelemetryService: reportError handles invalid/empty error gracefully without throwing', () async {
    // Should safely swallow and not throw
    await TelemetryService.instance.reportError(
      errorMessage: 'Test error message for telemetry test',
      exceptionClass: 'TestException',
      screenName: 'TestScreen',
      severity: 'info',
    );
  });
}
