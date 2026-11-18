import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:smartcard_flutter/views/widgets/international_phone_input.dart';
import 'package:smartcard_flutter/views/widgets/otp_channel_banner.dart';
import 'package:smartcard_flutter/views/widgets/otp_input_field.dart';
import 'package:smartcard_flutter/views/widgets/primary_button.dart';

void main() {
  testWidgets('OtpChannelBanner shows SMS icon, split flag & number, Change on single line without overflow', (tester) async {
    var changeTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220, // Tight narrow-phone container width
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
                child: OtpChannelBanner(
                  isWhatsAppMode: false,
                  phoneDisplay: '🇮🇳 +91 8086750402',
                  onChangePressed: () => changeTapped = true,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.smartphone_rounded), findsOneWidget);
    expect(find.text('🇮🇳'), findsOneWidget);
    expect(find.text('+91 8086750402'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    expect(find.textContaining('OTP Sent via'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Change'));
    await tester.pump();
    expect(changeTapped, isTrue);
  });

  testWidgets('OtpChannelBanner and OtpSwitchChannelLink work cleanly in WhatsApp and SMS modes', (tester) async {
    var switched = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              OtpChannelBanner(
                isWhatsAppMode: true,
                phoneDisplay: '🇮🇳 +91 8086750402',
                onChangePressed: () {},
              ),
              OtpSwitchChannelLink(
                isWhatsAppMode: false,
                isLoading: false,
                onSwitchPressed: () => switched = true,
              ),
              const OtpStatusNotice(
                statusMessage: 'OTP sent successfully. Check your SMS.',
                errorMessage: '',
                isWhatsAppMode: false,
              ),
              PrimaryButton(
                text: 'VERIFY OTP',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(FaIcon), findsNWidgets(2));
    expect(find.text('Get OTP via WhatsApp'), findsOneWidget);
    expect(find.text('OTP sent successfully. Check your SMS.'), findsOneWidget);
    expect(find.text('VERIFY OTP'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Get OTP via WhatsApp'));
    await tester.pump();
    expect(switched, isTrue);
  });

  testWidgets('OTPInputField fits 6 boxes without overflow on narrow screens', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 215,
            child: OTPInputField(controller: controller),
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('InternationalPhoneInput renders unified phone box in SMS and WhatsApp modes without overflow', (tester) async {
    final phoneCtrl = TextEditingController(text: '8086750402');
    addTearDown(phoneCtrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            child: Column(
              children: [
                InternationalPhoneInput(
                  phoneController: phoneCtrl,
                  isWhatsAppMode: false,
                  selectedCountryCode: '+91',
                  allowSeparateWhatsApp: false,
                  onWhatsAppModeChanged: (_) {},
                  onCountryCodeChanged: (_) {},
                ),
                const SizedBox(height: 12),
                InternationalPhoneInput(
                  phoneController: phoneCtrl,
                  isWhatsAppMode: true,
                  selectedCountryCode: '+91',
                  allowSeparateWhatsApp: false,
                  onWhatsAppModeChanged: (_) {},
                  onCountryCodeChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Phone Number'), findsOneWidget);
    expect(find.text('WhatsApp Number'), findsOneWidget);
    expect(find.text('SMS OTP mode active. OTP will arrive via SMS only.'), findsOneWidget);
    expect(find.text('WhatsApp OTP mode active. OTP will arrive via WhatsApp only.'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting international country in SMS mode opens bottom bar with Change to WhatsApp action', (tester) async {
    final phoneCtrl = TextEditingController();
    addTearDown(phoneCtrl.dispose);
    var switchedToWhatsApp = false;
    var selectedCode = '+91';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: InternationalPhoneInput(
                phoneController: phoneCtrl,
                isWhatsAppMode: false,
                selectedCountryCode: selectedCode,
                allowSeparateWhatsApp: false,
                onWhatsAppModeChanged: (val) => switchedToWhatsApp = val,
                onCountryCodeChanged: (c) => selectedCode = c.code,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('+91'));
    await tester.pumpAndSettle();

    expect(find.text('United States'), findsOneWidget);
    await tester.tap(find.text('United States'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Indian users (+91)'), findsOneWidget);
    expect(find.text('Change to WhatsApp'), findsOneWidget);

    await tester.tap(find.text('Change to WhatsApp'));
    await tester.pumpAndSettle();
    expect(switchedToWhatsApp, isTrue);
    expect(selectedCode, '+1');
  });
}
