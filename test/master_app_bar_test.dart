import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:smartcard_flutter/core/widgets/master_app_bar.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
import 'package:smartcard_flutter/features/profile_screen/data/models/user_model.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/viewmodel/profile_viewmodel.dart';

class _FakeAuthViewModel extends AuthViewModel {
  final UserModel _user;
  _FakeAuthViewModel(this._user);

  @override
  AuthUiState build() => AuthUiState(
        currentUser: _user,
        status: AuthStatus.authenticated,
      );
}

class _FakeProfileViewModel extends ProfileViewModel {
  final UserModel _user;
  _FakeProfileViewModel(this._user);

  @override
  ProfileUiState build() => ProfileUiState(
        user: _user,
        status: ProfileStatus.loaded,
      );

  @override
  Future<void> loadProfile(String userId) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('MasterAppBar renders curved Dashboard header cleanly', (tester) async {
    final boundaryKey = GlobalKey();
    final testUser = UserModel(
      id: '1069',
      firstName: 'Remakanth',
      lastName: 'R',
      email: 'remakanth@gmail.com',
      phone: '9995955999',
    );

    tester.view.physicalSize = const Size(1080, 720);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => _FakeAuthViewModel(testUser)),
          profileViewModelProvider.overrideWith(() => _FakeProfileViewModel(testUser)),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: boundaryKey,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(400, 266),
                padding: EdgeInsets.only(top: 32),
              ),
              child: Scaffold(
                backgroundColor: const Color(0xFFFFF5F6),
                appBar: const MasterAppBar(
                  titleText: 'Dashboard',
                  showBackButton: false,
                  showThemeToggle: false,
                ),
                body: Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF5F6),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: const Text(
                    'Hello, Remakanth R',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Hello, Remakanth R'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final previewPath = Platform.environment['APPBAR_PREVIEW_OUT'];
    if (previewPath != null && previewPath.isNotEmpty) {
      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          await File(previewPath).writeAsBytes(byteData.buffer.asUint8List());
        }
      });
    }
  });

  testWidgets('MasterAppBar renders back button safely on inner routes', (tester) async {
    final testUser = UserModel(
      id: '1069',
      firstName: 'Remakanth',
      lastName: 'R',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => _FakeAuthViewModel(testUser)),
          profileViewModelProvider.overrideWith(() => _FakeProfileViewModel(testUser)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            appBar: MasterAppBar(
              titleText: 'Contact Groups',
              showBackButton: true,
            ),
            body: SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Contact Groups'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
