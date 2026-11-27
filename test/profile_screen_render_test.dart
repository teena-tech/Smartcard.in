import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/view/profile_screen.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/viewmodel/profile_viewmodel.dart';
import 'package:smartcard_flutter/features/subscription_screen/presentation/viewmodel/subscription_viewmodel.dart';
import 'package:smartcard_flutter/features/subscription_screen/data/models/subscription_model.dart';
import 'package:smartcard_flutter/features/profile_screen/data/models/user_model.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';

class FakeAuthViewModel extends AuthViewModel {
  final UserModel _fakeUser;
  FakeAuthViewModel(this._fakeUser);

  @override
  AuthUiState build() => AuthUiState(
        currentUser: _fakeUser,
        status: AuthStatus.authenticated,
      );
}

class FakeProfileViewModel extends ProfileViewModel {
  final UserModel _fakeUser;
  FakeProfileViewModel(this._fakeUser);

  @override
  ProfileUiState build() => ProfileUiState(
        user: _fakeUser,
        status: ProfileStatus.loaded,
      );

  @override
  Future<void> loadProfile(String userId) async {}
}

class FakeSubscriptionViewModel extends SubscriptionViewModel {
  @override
  SubscriptionState build() => SubscriptionState(
        subscription: SubscriptionModel(
          membership: 'PREMIUM',
          subscriptionStart: '2026-01-01',
          subscriptionEnd: '2026-12-31',
          daysRemaining: 365,
          linkedCards: 1,
          isActive: true,
        ),
      );

  @override
  Future<void> fetchSubscription(String userId) async {}
}

void main() {
  testWidgets('ProfileScreen renders cleanly without blank or layout errors', (tester) async {
    final testUser = UserModel(
      id: '1069',
      firstName: 'Teena',
      lastName: 'Davis',
      email: 'teena@example.com',
      phone: '9876543210',
      countryCode: '+91',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => FakeAuthViewModel(testUser)),
          profileViewModelProvider.overrideWith(() => FakeProfileViewModel(testUser)),
          subscriptionViewModelProvider.overrideWith(FakeSubscriptionViewModel.new),
        ],
        child: const MaterialApp(
          home: ProfileScreen(),
        ),
      ),
    );

    await tester.pump();

    // Verify AppBar rendered with "My Profile"
    expect(find.text('My Profile'), findsOneWidget);

    // Verify personal details section is visible and not blank
    expect(find.text('PERSONAL DETAILS'), findsOneWidget);
    expect(find.text('Teena Davis'), findsWidgets);
  });
}
