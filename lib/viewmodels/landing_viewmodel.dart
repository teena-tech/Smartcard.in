import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';

class LandingViewModel extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  List<Map<String, dynamic>> _slides = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> get slides => _slides;
  bool get isLoading => _isLoading;

  Future<void> fetchSlides() async {
    _isLoading = true;
    notifyListeners();

    try {
      final list = await _authRepository.fetchWelcomeSlides();
      if (list.isNotEmpty) {
        _slides = list;
        _isLoading = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Welcome Slides API Error: $e');
    }

    // Default fallback slides when local/remote API is not reachable or empty
    _slides = [
      {
        'title': 'Smart Cards',
        'subtitle': 'The modern way to share your contact information and build professional connections.',
        'image_path': 'assets/images/welcome_page_sc.png',
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