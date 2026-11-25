import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/services/dio_client.dart';
import 'package:smartcard_flutter/core/services/api_config.dart';

@immutable
class LandingState {
  final List<Map<String, dynamic>> slides;
  final bool isLoading;

  const LandingState({
    this.slides = const [],
    this.isLoading = true,
  });

  LandingState copyWith({
    List<Map<String, dynamic>>? slides,
    bool? isLoading,
  }) {
    return LandingState(
      slides: slides ?? this.slides,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class LandingViewModel extends Notifier<LandingState> {
  @override
  LandingState build() {
    Future.microtask(() => fetchSlides());
    return const LandingState();
  }

  List<Map<String, dynamic>> get slides => state.slides;
  bool get isLoading => state.isLoading;

  Future<void> fetchSlides() async {
    state = state.copyWith(isLoading: true);

    try {
      final dio = DioClient().dio;
      final response = await dio.get(ApiConfig.welcomeSlides);

      if (response.data != null) {
        final data = response.data;
        List<dynamic> list = [];

        if (data is List) {
          list = data;
        } else if (data is Map && data['data'] is List) {
          list = data['data'];
        }

        if (list.isNotEmpty) {
          state = state.copyWith(
            slides: list.map((e) => Map<String, dynamic>.from(e)).toList(),
            isLoading: false,
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Welcome Slides API Error: $e');
    }

    state = state.copyWith(
      slides: [
        {
          'title': 'Smart Cards',
          'subtitle': 'The modern way to share your contact information and build professional connections.',
          'image_path': 'assets/images/welcome pageSC WelcomeSC Welcome.png',
        },
        {
          'title': 'Digital Connections',
          'subtitle': 'Build and customize your professional profile and digital business card instantly.',
          'image_path': 'assets/images/background-image.jpg',
        },
      ],
      isLoading: false,
    );
  }
}

final landingViewModelProvider =
    NotifierProvider<LandingViewModel, LandingState>(LandingViewModel.new);
