import 'package:flutter/foundation.dart';
import '../core/services/dio_client.dart';
import '../core/services/api_config.dart';

class LandingViewModel extends ChangeNotifier {
  List<Map<String, dynamic>> _slides = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> get slides => _slides;
  bool get isLoading => _isLoading;

  Future<void> fetchSlides() async {
    _isLoading = true;
    notifyListeners();

    try {
      final dio = DioClient().dio;

      final response = await dio.get(
        ApiConfig.welcomeSlides, 
      );

      if (response.data != null) {
        final data = response.data;
        List<dynamic> list = [];

        if (data is List) {
          list = data;
        } else if (data is Map && data['data'] is List) {
          list = data['data'];
        }

        if (list.isNotEmpty) {
          _slides = list.map((e) => Map<String, dynamic>.from(e)).toList();
          _isLoading = false;
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('Welcome Slides API Error: $e');
    }

    // Default fallback slides when local/remote API is not reachable or empty
    _slides = [
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
    ];
    _isLoading = false;
    notifyListeners();
  }
}