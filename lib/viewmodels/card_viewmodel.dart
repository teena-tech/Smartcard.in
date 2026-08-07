import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/card_model.dart';
import '../models/user_model.dart';
import '../repositories/card_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/theme_repository.dart';
import '../repositories/auth_repository.dart';
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

  CardModel? get primaryCard {
    if (_cards.isEmpty) return null;
    return _cards.firstWhere((c) => c.isPrimary, orElse: () => _cards.first);
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
            final templateId = theme['template_id']?.toString();
            final templateKey = theme['template_key']?.toString();

            updatedCard = updatedCard.copyWith(
              backgroundImage: bgImage,
              backgroundColor: bgColor,
              textColor: textColor,
              bgImageColor: bgImageColor,
              opacity: opacity,
              templateId: templateId,
              templateKey: templateKey,
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
      final targetUserId = card.accountUserId > 0 ? card.accountUserId.toString() : userId;
      final details = await _userRepository.getCardProfileDetails(
        targetUserId,
        workProfileId: card.workProfileId,
      );
      if (details != null) {
        try {
          final galleryData = await _userRepository.getUserGallery(
            targetUserId,
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
      } else {
        _createFallbackCardDetails(card);
      }
    } catch (_) {
      _createFallbackCardDetails(card);
    }
  }

  void _createFallbackCardDetails(CardModel card) {
    _selectedCardDetails = CardProfileDetails(
      firstName: card.name,
      companyName: card.companyName,
      email: card.email ?? '',
      phone: card.phone,
      profileImageName: card.profileImageName ?? '',
      companyLogoName: card.companyLogo ?? '',
    );
  }

  Future<void> setCurrentIndex(int index) async {
    if (index >= 0 && index < _cards.length) {
      _currentIndex = index;
      _createFallbackCardDetails(_cards[index]);
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      await _loadDetailedProfile(_cards[index]);
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
  String get userId => currentCard?.accountUserId.toString() ?? (_cards.isNotEmpty ? _cards.first.accountUserId.toString() : '');

  void clearMessages() {
    _errorMessage = null;
    _successMessage = '';
    notifyListeners();
  }
  void openSection(String sectionId) {}
  void closeSection({bool keepChanges = false}) {}
  Future<void> handleAddMoreCard(BuildContext context, {UserModel? masterProfile}) async {
    final bool? confirmCreate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create New Card'),
        content: const Text('Do you want to create a new smart card profile?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmCreate != true) return;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final activeUserIdStr = userId.isNotEmpty ? userId : (masterProfile?.id ?? '');
      final activeUserId = int.tryParse(activeUserIdStr) ?? 0;

      final defaultFirstName = (masterProfile?.firstName != null && masterProfile!.firstName!.trim().isNotEmpty)
          ? masterProfile.firstName!.trim()
          : (_selectedCardDetails?.firstName ?? 'New');
      final defaultLastName = (masterProfile?.lastName != null && masterProfile!.lastName!.trim().isNotEmpty)
          ? masterProfile.lastName!.trim()
          : (_selectedCardDetails?.lastName ?? 'User');
      final defaultProfileImg = (masterProfile?.profileImage != null && masterProfile!.profileImage!.trim().isNotEmpty)
          ? masterProfile.profileImage!.trim()
          : (_selectedCardDetails?.profileImageName ?? '');
      final defaultCompany = _selectedCardDetails?.companyName ?? '';
      final defaultDesignation = _selectedCardDetails?.designation ?? '';
      final defaultLogo = _selectedCardDetails?.companyLogoName ?? '';
      final defaultWebsites = _selectedCardDetails?.website != null 
          ? List<Map<String, String>>.from(_selectedCardDetails!.website.map((w) => Map<String, String>.from(w)))
          : <Map<String, String>>[];

      // 1. Instantly create local CardModel pre-filled with existing profile name and image
      final newCardNo = _cards.length + 1;
      final newCard = CardModel(
        userId: activeUserId,
        cardId: DateTime.now().millisecondsSinceEpoch % 1000000,
        workProfileId: DateTime.now().millisecondsSinceEpoch % 1000000,
        accountUserId: activeUserId,
        cardNo: newCardNo,
        name: '$defaultFirstName $defaultLastName'.trim().isNotEmpty 
            ? '$defaultFirstName $defaultLastName'.trim() 
            : 'Card $newCardNo',
        companyName: defaultCompany,
        phone: masterProfile?.phone ?? _selectedCardDetails?.phone ?? '',
        email: masterProfile?.email ?? _selectedCardDetails?.email ?? '',
        designation: defaultDesignation,
        companyLogo: defaultLogo.isNotEmpty ? defaultLogo : null,
        qrCode: 'https://thesmartcards.in?sc=$newCardNo',
        tabLabel: 'Card $newCardNo',
        captionName: 'Card $newCardNo',
        isPrimary: false,
        isTemporary: false,
        backgroundImage: null,
        profileImageName: defaultProfileImg,
      );

      _cards.add(newCard);
      _currentIndex = _cards.length - 1;
      notifyListeners();

      // 2. Persist to backend API in background
      if (activeUserIdStr.isNotEmpty) {
        final newCardPayload = {
          'first_name': defaultFirstName,
          'last_name': defaultLastName,
          'phone': masterProfile?.phone ?? _selectedCardDetails?.phone ?? '',
          'email': masterProfile?.email ?? _selectedCardDetails?.email ?? '',
          'designation': defaultDesignation,
          'company_name': defaultCompany,
          'company_address': _selectedCardDetails?.companyAddress ?? '',
          'company_pincode': _selectedCardDetails?.companyPincode ?? '',
          'company_city_id': _selectedCardDetails?.companyCityId ?? '',
          'company_state_id': _selectedCardDetails?.companyStateId ?? '',
          'company_city': _selectedCardDetails?.companyCity ?? '',
          'company_state': _selectedCardDetails?.companyState ?? '',
          'company_district': _selectedCardDetails?.companyDistrict ?? '',
          'company_email': _selectedCardDetails?.companyEmails ?? [],
          'company_phone': masterProfile?.phone != null && masterProfile!.phone!.isNotEmpty ? [masterProfile.phone!] : [],
          'whatsapp_number': _selectedCardDetails?.whatsappNumbers ?? [],
          'facebook_link': _selectedCardDetails?.fbLink ?? '',
          'instagram_link': _selectedCardDetails?.instaLink ?? '',
          'linkedin_link': _selectedCardDetails?.linkedin ?? '',
          'twitter_link': _selectedCardDetails?.xLink ?? '',
          'website': defaultWebsites,
          'description': _selectedCardDetails?.aboutCompany ?? '',
          'youtube_links': _selectedCardDetails?.youtubeLinks ?? [],
          'profile_image': defaultProfileImg,
          'company_logo': defaultLogo,
        };

        try {
          await _userRepository.createUserAdditionalCard(activeUserIdStr, newCardPayload);
          _successMessage = 'New card created successfully!';
          await fetchCards(activeUserIdStr);
          if (_cards.isNotEmpty) {
            _currentIndex = _cards.length - 1;
          }
        } catch (apiErr) {
          debugPrint('Backend sync note: $apiErr');
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New card created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _errorMessage = 'Failed to create card: $e';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create card: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isBusy = false;
      notifyListeners();
    }
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
    final targetWorkProfileId = currentCard!.workProfileId;
    final targetUserId = userId;
    if (targetUserId.isEmpty || targetWorkProfileId <= 0) return;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    AppLoadingService.instance.startTask();
    try {
      await _userRepository.setUserPrimaryCard(targetUserId, targetWorkProfileId, {});
      
      // Update local cards list primary flags immediately
      _cards = _cards.map((c) {
        return c.copyWith(isPrimary: c.workProfileId == targetWorkProfileId);
      }).toList();

      _successMessage = 'Primary card updated successfully!';
      
      await fetchCards(targetUserId);

      final newIndex = _cards.indexWhere((c) => c.workProfileId == targetWorkProfileId);
      if (newIndex >= 0) {
        _currentIndex = newIndex;
        await _loadDetailedProfile(_cards[_currentIndex]);
      }
    } catch (e) {
      _errorMessage = 'Failed to set primary card: $e';
    } finally {
      _isBusy = false;
      notifyListeners();
      AppLoadingService.instance.endTask();
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
      if (_cards.isNotEmpty) {
        _currentIndex = 0;
        await _loadDetailedProfile(_cards[0]);
      }
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

  Future<void> toggleSuspensionForCardIndex(int index) async {
    if (index < 0 || index >= _cards.length) return;
    final targetCard = _cards[index];
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final newSuspendedState = !targetCard.isSuspended;
      await _userRepository.updateCardProfileDetails(
        userId,
        {'is_suspended': newSuspendedState ? 1 : 0},
        workProfileId: targetCard.workProfileId,
      );

      final updatedCard = targetCard.copyWith(isSuspended: newSuspendedState);
      _cards[index] = updatedCard;
      if (_currentIndex == index && _selectedCardDetails != null) {
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

  void clearProfileImage() {
    if (_cards.isNotEmpty && _currentIndex >= 0 && _currentIndex < _cards.length) {
      _cards[_currentIndex] = _cards[_currentIndex].copyWith(profileImageName: '');
    }
    if (_selectedCardDetails != null) {
      _selectedCardDetails!.profileImageName = '';
    }
    UploadUrlResolver.bustCache();
    notifyListeners();
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

  Future<void> handleRemoveProfileImage([String? passedUserId]) async {
    final targetUserId = (passedUserId != null && passedUserId.isNotEmpty) ? passedUserId : userId;
    if (targetUserId.isEmpty) return;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    AppLoadingService.instance.startTask();
    try {
      await _userRepository.deleteProfileImage(
        targetUserId,
        workProfileId: currentCard?.workProfileId,
      );
      UploadUrlResolver.bustCache();
      if (_selectedCardDetails != null) {
        _selectedCardDetails!.profileImageName = '';
      }
      if (_cards.isNotEmpty && _currentIndex >= 0 && _currentIndex < _cards.length) {
        _cards[_currentIndex] = _cards[_currentIndex].copyWith(profileImageName: '');
      }
      _successMessage = 'Profile photo removed successfully!';
      try {
        await fetchCards(targetUserId);
      } catch (_) {}
    } catch (e) {
      _errorMessage = 'Failed to remove profile photo: $e';
    } finally {
      _isBusy = false;
      notifyListeners();
      AppLoadingService.instance.endTask();
    }
  }

  Future<void> handleRemoveCompanyLogo([String? passedUserId]) async {
    final targetUserId = (passedUserId != null && passedUserId.isNotEmpty) ? passedUserId : userId;
    if (targetUserId.isEmpty) return;

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    AppLoadingService.instance.startTask();
    try {
      await _userRepository.deleteCompanyLogo(
        targetUserId,
        workProfileId: currentCard?.workProfileId,
      );
      UploadUrlResolver.bustCache();
      if (_selectedCardDetails != null) {
        _selectedCardDetails!.companyLogoName = '';
      }
      if (_cards.isNotEmpty && _currentIndex >= 0 && _currentIndex < _cards.length) {
        _cards[_currentIndex] = _cards[_currentIndex].copyWith(companyLogo: '');
      }
      _successMessage = 'Company logo removed successfully!';
      try {
        await fetchCards(targetUserId);
      } catch (_) {}
    } catch (e) {
      _errorMessage = 'Failed to remove company logo: $e';
    } finally {
      _isBusy = false;
      notifyListeners();
      AppLoadingService.instance.endTask();
    }
  }

  void clearCompanyLogo() {
    if (_selectedCardDetails != null) {
      _selectedCardDetails!.companyLogoName = '';
    }
    UploadUrlResolver.bustCache();
    notifyListeners();
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

  void updateActiveCardTheme({
    String? backgroundImage,
    String? backgroundColor,
    String? textColor,
    String? bgImageColor,
    String? opacity,
    String? templateId,
    String? templateKey,
  }) {
    if (_cards.isEmpty) return;
    final updatedCard = _cards[_currentIndex].copyWith(
      backgroundImage: backgroundImage,
      backgroundColor: backgroundColor,
      textColor: textColor,
      bgImageColor: bgImageColor,
      opacity: opacity,
      templateId: templateId,
      templateKey: templateKey,
    );
    _cards[_currentIndex] = updatedCard;
    notifyListeners();
  }
}

