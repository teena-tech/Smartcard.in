import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/card_model.dart';
import '../models/user_model.dart';
import '../repositories/card_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/theme_repository.dart';
import '../repositories/auth_repository.dart';
import '../views/screens/manage_cards/manage_card_screens.dart';
import '../core/utils/upload_url_resolver.dart';
import '../core/state/app_loading_service.dart';

class CardViewModel extends ChangeNotifier {
  final CardRepository _cardRepository;
  final UserRepository _userRepository = UserRepository();
  final ThemeRepository _themeRepository = ThemeRepository();

  CardViewModel({required CardRepository cardRepository}) : _cardRepository = cardRepository;

  List<CardModel> _cards = [];
  int _currentIndex = 0;
  bool _isLoading = false;
  bool _isBusy = false;
  String? _errorMessage;
  String _successMessage = '';
  CardProfileDetails? _selectedCardDetails;

  String _fallbackName = '';
  String _fallbackPhone = '';
  String? _fallbackEmail;

  List<CardModel> get cards => _cards;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get successMessage => _successMessage;
  bool get isBusy => _isBusy;
  CardModel? get currentCard {
    if (_cards.isEmpty) return null;
    if (_currentIndex >= _cards.length || _currentIndex < 0) return _cards.first;
    return _cards[_currentIndex];
  }

  CardProfileDetails? get selectedCardDetails => _selectedCardDetails;

  Future<void> fetchCards(
    String userId, {
    String? fallbackName,
    String? fallbackPhone,
    String? fallbackEmail,
  }) async {
    if (fallbackName != null && fallbackName.isNotEmpty) {
      _fallbackName = fallbackName;
    }
    if (fallbackPhone != null && fallbackPhone.isNotEmpty) {
      _fallbackPhone = fallbackPhone;
    }
    if (fallbackEmail != null && fallbackEmail.isNotEmpty) {
      _fallbackEmail = fallbackEmail;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _cards = await _cardRepository.getCards(
        userId,
        fallbackName: _fallbackName,
        fallbackPhone: _fallbackPhone,
        fallbackEmail: _fallbackEmail,
      );
      if (_cards.isNotEmpty) {
        final futures = _cards.map((card) async {
          CardProfileDetails? details;
          try {
            details = await _userRepository.getCardProfileDetails(
              userId,
              workProfileId: card.workProfileId,
            );
            if (details != null) {
              final galleryData = await _userRepository.getUserGallery(
                userId,
                workProfileId: card.workProfileId,
              );
              if (galleryData != null) {
                final rawData = galleryData['data'] is Map ? galleryData['data'] as Map : galleryData;
                final photosList = rawData['photos'] ?? rawData['gallery'] ?? rawData['images'] ?? [];
                final youtubeList = rawData['youtube_links'] ?? rawData['youtube'] ?? [];
                if (photosList is List) {
                  details.existingPhotos = photosList.map((e) => e.toString()).toList();
                }
                if (youtubeList is List) {
                  details.youtubeLinks = youtubeList.map((e) => e.toString()).toList();
                }
              }
            }
          } catch (_) {}

          Map<String, dynamic>? theme;
          try {
            theme = await _themeRepository.getTheme(
              userId,
              workProfileId: card.workProfileId,
            );
          } catch (_) {}

          var updatedCard = card;
          if (details != null) {
            final name = '${details.firstName} ${details.lastName}'.trim();
            final companyName = details.companyName.trim();
            
            // Recalculate tab label and caption name
            final cardNo = card.cardNo;
            final tabLabel = companyName.isNotEmpty 
                ? companyName 
                : (name.isNotEmpty 
                    ? name 
                    : (card.name.isNotEmpty ? card.name : 'Card $cardNo'));
            final captionName = companyName.isNotEmpty ? companyName : (name.isNotEmpty ? name : tabLabel);

            updatedCard = updatedCard.copyWith(
              name: name.isNotEmpty ? name : updatedCard.name,
              companyName: companyName,
              designation: details.designation,
              companyLogo: details.companyLogoName.isNotEmpty ? details.companyLogoName : null,
              profileImageName: details.profileImageName.isNotEmpty ? details.profileImageName : updatedCard.profileImageName,
              tabLabel: tabLabel,
              captionName: captionName,
            );
          }
          if (theme != null) {
            final bgImage = theme['bg_image']?.toString();
            final bgColor = theme['bg_color']?.toString();
            final textColor = theme['text_color']?.toString();
            final bgImageColor = theme['bg_image_color']?.toString();
            final opacity = theme['opacity']?.toString();

            updatedCard = updatedCard.copyWith(
              backgroundImage: bgImage,
              backgroundColor: bgColor,
              textColor: textColor,
              bgImageColor: bgImageColor,
              opacity: opacity,
            );
          }
          return updatedCard;
        }).toList();

        _cards = await Future.wait(futures);

        // Load active card details
        await _loadDetailedProfile(_cards[_currentIndex]);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadDetailedProfile(CardModel card) async {
    try {
      final details = await _userRepository.getCardProfileDetails(
        userId, // Account user ID
        workProfileId: card.workProfileId,
      );
      if (details != null) {
        try {
          final galleryData = await _userRepository.getUserGallery(
            userId,
            workProfileId: card.workProfileId,
          );
          if (galleryData != null) {
            final rawData = galleryData['data'] is Map ? galleryData['data'] as Map : galleryData;
            final photosList = rawData['photos'] ?? rawData['gallery'] ?? rawData['images'] ?? [];
            final youtubeList = rawData['youtube_links'] ?? rawData['youtube'] ?? [];
            if (photosList is List) {
              details.existingPhotos = photosList.map((e) => e.toString()).toList();
            } else if (photosList is String) {
              try {
                final decoded = jsonDecode(photosList);
                if (decoded is List) {
                  details.existingPhotos = decoded.map((e) => e.toString()).toList();
                }
              } catch (_) {
                if (photosList.isNotEmpty) details.existingPhotos = [photosList];
              }
            }
            if (youtubeList is List) {
              details.youtubeLinks = youtubeList.map((e) => e.toString()).toList();
            } else if (youtubeList is String) {
              try {
                final decoded = jsonDecode(youtubeList);
                if (decoded is List) {
                  details.youtubeLinks = decoded.map((e) => e.toString()).toList();
                }
              } catch (_) {
                if (youtubeList.isNotEmpty) details.youtubeLinks = [youtubeList];
              }
            }
          }
        } catch (_) {}
        _selectedCardDetails = details;
      }
    } catch (e) {
      _errorMessage = 'Failed to load card details: $e';
    }
  }

  Future<void> setCurrentIndex(int index) async {
    if (index >= 0 && index < _cards.length) {
      _currentIndex = index;
      _selectedCardDetails = null;
      _isLoading = true;
      notifyListeners(); // Show loading state briefly if needed
      await _loadDetailedProfile(_cards[index]);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setCurrentCardById(String? cardId) async {
    if (cardId == null) return;
    final index = _cards.indexWhere((c) => c.userId.toString() == cardId || c.cardId.toString() == cardId);
    if (index >= 0) {
      await setCurrentIndex(index);
    }
  }

  Future<void> init({
    required String userId,
    required String fallbackName,
    required String fallbackPhone,
    String? fallbackEmail,
  }) async {
    _fallbackName = fallbackName;
    _fallbackPhone = fallbackPhone;
    _fallbackEmail = fallbackEmail;
    await fetchCards(
      userId,
      fallbackName: fallbackName,
      fallbackPhone: fallbackPhone,
      fallbackEmail: fallbackEmail,
    );
  }

  void nextCard() {
    if (_cards.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _cards.length;
    notifyListeners();
  }

  void prevCard() {
    if (_cards.isEmpty) return;
    _currentIndex = (_currentIndex - 1 + _cards.length) % _cards.length;
    notifyListeners();
  }

  // --- STUBS for Manage Cards Screen (Ported from legacy UI) ---
  bool get isSaving => _isBusy;
  bool get canSetSelectedAsPrimary => currentCard != null && !currentCard!.isPrimary;
  bool get canDeleteSelectedCard => _cards.length > 1 && !isPrimaryCardSelected;
  bool get isPrimaryCardSelected => currentCard?.isPrimary ?? false;
  bool get isSuspended => currentCard?.isSuspended ?? false;
  String get userId => _cards.isNotEmpty ? _cards.first.accountUserId.toString() : '';

  void clearMessages() {
    _errorMessage = null;
    _successMessage = '';
    notifyListeners();
  }
  void openSection(String sectionId) {}
  void closeSection({bool keepChanges = false}) {}
  void handleAddMoreCard(BuildContext context, {UserModel? masterProfile}) {
    // Copy company and website from existing details if available
    final defaultCompany = _selectedCardDetails?.companyName ?? '';
    final defaultWebsites = _selectedCardDetails?.website != null 
        ? List<Map<String, String>>.from(_selectedCardDetails!.website.map((w) => Map<String, String>.from(w)))
        : <Map<String, String>>[];

    // Create a new blank card instance locally for the UI flow
    final newCard = CardModel(
      userId: int.tryParse(userId) ?? 0,
      cardId: 0,
      workProfileId: 0,
      accountUserId: int.tryParse(userId) ?? 0,
      cardNo: _cards.length + 1,
      name: 'Card ${_cards.length + 1}',
      companyName: defaultCompany,
      phone: masterProfile?.phone ?? '',
      email: masterProfile?.email ?? '',
      designation: '',
      companyLogo: null,
      qrCode: null,
      tabLabel: 'Card ${_cards.length + 1}',
      captionName: 'Card ${_cards.length + 1}',
      isPrimary: false,
      isTemporary: true,
      backgroundImage: null,
    );
    _cards.add(newCard);
    
    // Set default details populated with master profile information
    _selectedCardDetails = CardProfileDetails(
      firstName: masterProfile?.firstName ?? 'New',
      lastName: masterProfile?.lastName ?? 'User',
      phone: masterProfile?.phone ?? '',
      email: masterProfile?.email ?? '',
      designation: '',
      companyName: defaultCompany,
      companyAddress: '',
      companyCity: '',
      companyState: '',
      companyDistrict: '',
      companyPincode: '',
      companyEmails: [],
      contactNumbers: masterProfile?.phone != null && masterProfile!.phone!.isNotEmpty ? [masterProfile.phone!] : [],
      whatsappNumbers: [],
      aboutCompany: '',
      website: defaultWebsites,
      youtubeLinks: [],
      fbLink: '',
      instaLink: '',
      linkedin: '',
      xLink: '',
      existingPhotos: [],
    );
    
    _currentIndex = _cards.length - 1;
    notifyListeners();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManageCardsScreen(isTab: false),
      ),
    ).then((_) {
      // Refresh cards after returning so new card appears in Home & My Cards
      if (userId.isNotEmpty) {
        fetchCards(userId);
      }
    });
  }

  Future<bool> handleDuplicateCard(CardModel card) async {
    // existing method unchanged
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final details = await _userRepository.getCardProfileDetails(
        userId,
        workProfileId: card.workProfileId,
      );
      if (details == null) throw Exception('Failed to load card details for duplication');
      
      final duplicatePayload = {
        'first_name': '${details.firstName} (Copy)',
        'last_name': details.lastName,
        'phone': details.phone,
        'email': details.email,
        'designation': details.designation,
        'company_name': details.companyName,
        'company_address': details.companyAddress,
        'company_email': details.companyEmails,
        'company_phone': details.contactNumbers,
        'whatsapp_number': details.whatsappNumbers,
        'facebook_link': details.fbLink,
        'instagram_link': details.instaLink,
        'linkedin_link': details.linkedin,
        'twitter_link': details.xLink,
        'website': details.website,
        'description': details.aboutCompany,
        'youtube_links': details.youtubeLinks,
      };

      await _userRepository.createUserAdditionalCard(userId, duplicatePayload);
      _successMessage = 'Card duplicated successfully!';
      await fetchCards(userId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to duplicate card: $e';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  // Clone current card wrapper
  Future<bool> cloneCurrentCard(BuildContext context) async {
    if (currentCard == null) return false;
    return await handleDuplicateCard(currentCard!);
  }


  Future<void> handleSetPrimaryCard() async {
    if (currentCard == null) return;
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _userRepository.setUserPrimaryCard(userId, currentCard!.cardId, {});
      _successMessage = 'Primary card updated!';
      await fetchCards(userId);
    } catch (e) {
      _errorMessage = 'Failed to set primary card: $e';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> handleDeleteCard() async {
    if (currentCard == null) return;
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _userRepository.deleteUserAdditionalCard(userId, currentCard!.cardId, {});
      _successMessage = 'Card deleted successfully!';
      _currentIndex = 0;
      await fetchCards(userId);
    } catch (e) {
      _errorMessage = 'Failed to delete card: $e';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> handleToggleSuspension() async {
    if (currentCard == null) return;
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final newSuspendedState = !isSuspended;
      await _userRepository.updateCardProfileDetails(
        userId,
        {'is_suspended': newSuspendedState ? 1 : 0},
        workProfileId: currentCard!.workProfileId,
      );
      
      // Update local state without fetching all cards to be fast
      final updatedCard = currentCard!.copyWith(isSuspended: newSuspendedState);
      _cards[_currentIndex] = updatedCard;
      if (_selectedCardDetails != null) {
        _selectedCardDetails!.isSuspended = newSuspendedState;
      }
      
      _successMessage = newSuspendedState ? 'Card suspended successfully!' : 'Card reactivated successfully!';
    } catch (e) {
      _errorMessage = 'Failed to toggle suspension: $e';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> fetchPincodeDetails(String pincode) async {
    try {
      final authRepo = AuthRepository();
      return await authRepo.fetchPincodeDetails(pincode);
    } catch (e) {
      debugPrint('Error fetching pincode: $e');
      return null;
    }
  }

  Future<void> handleUploadGalleryImages(List<XFile> newFiles) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    AppLoadingService.instance.startTask();
    try {
      await _userRepository.uploadGalleryImages(
        userId,
        newFiles,
        workProfileId: currentCard?.workProfileId,
      );
      UploadUrlResolver.bustCache();
      _successMessage = 'Gallery images updated successfully!';
      await fetchCards(userId);
    } catch (e) {
      _errorMessage = 'Failed to upload gallery images: $e';
    } finally {
      _isBusy = false;
      notifyListeners();
      AppLoadingService.instance.endTask();
    }
  }

  Future<bool> handleFormSubmit() async {
    if (_selectedCardDetails == null || currentCard == null) return false;
    
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final updateData = {
        'first_name': _selectedCardDetails!.firstName,
        'last_name': _selectedCardDetails!.lastName,
        'phone': _selectedCardDetails!.phone,
        'email': _selectedCardDetails!.email,
        'gender': _selectedCardDetails!.gender,
        'address': _selectedCardDetails!.address,
        'pincode': _selectedCardDetails!.pincode,
        'city_id': _selectedCardDetails!.cityId,
        'state_id': _selectedCardDetails!.stateId,
        'city': _selectedCardDetails!.city,
        'state': _selectedCardDetails!.state,
        'district': _selectedCardDetails!.district,
        'designation': _selectedCardDetails!.designation,
        'company_name': _selectedCardDetails!.companyName,
        'company_address': _selectedCardDetails!.companyAddress,
        'company_pincode': _selectedCardDetails!.companyPincode,
        'company_city_id': _selectedCardDetails!.companyCityId,
        'company_state_id': _selectedCardDetails!.companyStateId,
        'company_city': _selectedCardDetails!.companyCity,
        'company_state': _selectedCardDetails!.companyState,
        'company_district': _selectedCardDetails!.companyDistrict,
        'company_email': _selectedCardDetails!.companyEmails,
        'company_phone': _selectedCardDetails!.contactNumbers,
        'whatsapp_number': _selectedCardDetails!.whatsappNumbers,
        'facebook_link': _selectedCardDetails!.fbLink,
        'instagram_link': _selectedCardDetails!.instaLink,
        'linkedin_link': _selectedCardDetails!.linkedin,
        'twitter_link': _selectedCardDetails!.xLink,
        'website': _selectedCardDetails!.website,
        'description': _selectedCardDetails!.aboutCompany,
        'youtube_links': _selectedCardDetails!.youtubeLinks,
      };
      
      if (currentCard!.isTemporary) {
        await _userRepository.createUserAdditionalCard(userId, updateData);
        _successMessage = 'Card created successfully!';
      } else {
        await _userRepository.updateCardProfileDetails(
          userId,
          updateData,
          workProfileId: currentCard!.workProfileId,
        );
        await _userRepository.updateYoutubeLinks(
          userId,
          _selectedCardDetails!.youtubeLinks,
          workProfileId: currentCard!.workProfileId,
        );
        _successMessage = 'Card updated successfully!';
      }
      
      // Refresh cards list to get latest details
      await fetchCards(userId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save card: $e';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> handleUploadProfileImage(String path, dynamic crop) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    AppLoadingService.instance.startTask();
    try {
      await _userRepository.uploadProfileImage(
        userId,
        path,
        crop as Map<String, dynamic>?,
        workProfileId: currentCard?.workProfileId,
      );
      UploadUrlResolver.bustCache();
      _successMessage = 'Profile image updated successfully!';
      await fetchCards(userId);
    } catch (e) {
      _errorMessage = 'Failed to upload profile image: $e';
    } finally {
      _isBusy = false;
      notifyListeners();
      AppLoadingService.instance.endTask();
    }
  }

  Future<void> handleUploadCompanyLogo(String path, dynamic crop) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    AppLoadingService.instance.startTask();
    try {
      await _userRepository.uploadCompanyLogo(
        userId,
        path,
        crop as Map<String, dynamic>?,
        workProfileId: currentCard?.workProfileId,
      );
      UploadUrlResolver.bustCache();
      _successMessage = 'Company logo updated successfully!';
      await fetchCards(userId);
    } catch (e) {
      _errorMessage = 'Failed to upload company logo: $e';
    } finally {
      _isBusy = false;
      notifyListeners();
      AppLoadingService.instance.endTask();
    }
  }

  Future<void> handleRemoveGalleryImage(String photo) async {
    if (currentCard == null) return;
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _userRepository.deleteGalleryImage(
        userId,
        photo,
        workProfileId: currentCard!.workProfileId,
      );
      _successMessage = 'Image removed successfully!';
      await fetchCards(userId);
    } catch (e) {
      _errorMessage = 'Failed to remove image: $e';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
