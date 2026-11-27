import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcard_flutter/core/services/dio_client.dart';
import 'package:smartcard_flutter/core/services/api_config.dart';

const List<Map<String, dynamic>> _defaultWelcomeSlides = [
  {
    'title': 'Smart Cards',
    'subtitle': 'The modern way to share your contact information and build professional connections.',
    'image_path': 'assets/images/welcome_page_sc.webp',
  },
  {
    'title': 'Digital Connections',
    'subtitle': 'Build and customize your professional profile and digital business card instantly.',
    'image_path': 'assets/images/welcome_page_sc.webp',
  },
];

@immutable
class LandingState {
  final List<Map<String, dynamic>> slides;
  final bool isLoading;

  const LandingState({
    this.slides = _defaultWelcomeSlides,
    this.isLoading = false,
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
    _loadCachedSlidesAndFetch();
    return const LandingState();
  }

  List<Map<String, dynamic>> get slides => state.slides;
  bool get isLoading => state.isLoading;

  Future<void> _loadCachedSlidesAndFetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_welcome_slides');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        if (decoded.isNotEmpty) {
          state = state.copyWith(
            slides: decoded.map((e) => Map<String, dynamic>.from(e)).toList(),
            isLoading: false,
          );
        }
      }
    } catch (_) {}

    await fetchSlides();
  }

  Future<void> fetchSlides() async {
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
          final mappedSlides = list.map((e) {
            final map = Map<String, dynamic>.from(e);
            final rawPath = (map['image_path'] ?? '').toString();
            if (rawPath.startsWith('/') && !rawPath.startsWith('http')) {
              map['image_path'] = '${ApiConfig.publicWebBaseUrl}$rawPath';
            }
            return map;
          }).toList();

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('cached_welcome_slides', jsonEncode(mappedSlides));
          } catch (_) {}

          state = state.copyWith(
            slides: mappedSlides,
            isLoading: false,
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Welcome Slides API Error: $e');
    }

    if (state.slides.isEmpty) {
      state = state.copyWith(
        slides: _defaultWelcomeSlides,
        isLoading: false,
      );
    }
  }
}

final landingViewModelProvider =
    NotifierProvider<LandingViewModel, LandingState>(LandingViewModel.new);
