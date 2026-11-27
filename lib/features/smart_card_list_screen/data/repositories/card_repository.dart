import 'package:dio/dio.dart';
import 'package:smartcard_flutter/core/services/dio_client.dart';
import 'package:smartcard_flutter/core/services/api_config.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/data/models/card_model.dart';

class CardRepository {
  final DioClient _dioClient = DioClient();

  Future<List<CardModel>> getCards(
    String userId, {
    String fallbackName = '',
    String fallbackPhone = '',
    String? fallbackEmail,
  }) async {
    try {
      final response = await _dioClient.dio.get(
        ApiConfig.subscriptionDetails(userId),
        options: Options(headers: {'x-background-sync': 'true'}),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'] ?? response.data;
        final cardsList = data['cards']?['items'] as List? ?? [];
        final parsedUserId = int.tryParse(userId) ?? 0;
        
        final mappedCards = <CardModel>[];
        for (int i = 0; i < cardsList.length; i++) {
          final item = cardsList[i] as Map<String, dynamic>;
          mappedCards.add(CardModel.fromJson(
            item,
            i,
            parsedUserId,
            fallbackName,
            fallbackPhone,
            fallbackEmail,
          ));
        }

        // If cards list is empty, build fallback list matching React logic:
        if (mappedCards.isEmpty) {
          mappedCards.add(CardModel(
            userId: parsedUserId,
            cardId: parsedUserId,
            workProfileId: parsedUserId,
            accountUserId: parsedUserId,
            cardNo: 1,
            name: fallbackName.isEmpty ? 'Card 1' : fallbackName,
            companyName: '',
            phone: fallbackPhone,
            email: fallbackEmail,
            qrCode: null,
            isPrimary: true,
            tabLabel: 'Card 1',
            captionName: fallbackName.isEmpty ? 'Card 1' : fallbackName,
          ));
        }

        // Sort them (primary first, then by cardNo, then by ID)
        mappedCards.sort((left, right) {
          final leftPriority = left.isPrimary ? 0 : 1;
          final rightPriority = right.isPrimary ? 0 : 1;
          if (leftPriority != rightPriority) {
            return leftPriority.compareTo(rightPriority);
          }
          final leftCardNo = left.cardNo;
          final rightCardNo = right.cardNo;
          if (leftCardNo != rightCardNo) {
            return leftCardNo.compareTo(rightCardNo);
          }
          return left.userId.compareTo(right.userId);
        });

        // Return all cards returned by the backend without truncation.

        // Update tab labels and caption names after sorting / indexing
        int secondaryCounter = 0;
        final finalCards = <CardModel>[];
        for (final card in mappedCards) {
          int indexLabel = 1;
          if (!card.isPrimary) {
            secondaryCounter += 1;
            indexLabel = secondaryCounter + 1;
          }
          final tabLabel = card.companyName.trim().isNotEmpty
              ? card.companyName.trim()
              : 'Card $indexLabel';
          
          final captionName = card.companyName.trim().isNotEmpty
              ? card.companyName.trim()
              : (card.name.trim().isNotEmpty ? card.name.trim() : tabLabel);

          finalCards.add(card.copyWith(
            tabLabel: tabLabel,
            captionName: captionName,
          ));
        }

        return finalCards;
      }
      return [];
    } on DioException catch (e) {
      if (e.response != null) {
        try {
          final fallbackCards = await _fetchFallbackCardsFromProfile(
            userId,
            fallbackName: fallbackName,
            fallbackPhone: fallbackPhone,
            fallbackEmail: fallbackEmail,
          );
          if (fallbackCards.isNotEmpty) {
            return fallbackCards;
          }
        } catch (_) {}
      }
      throw DioClient.getErrorMessage(e, 'Failed to fetch subscription cards');
    }
  }

  Future<List<CardModel>> _fetchFallbackCardsFromProfile(
    String userId, {
    required String fallbackName,
    required String fallbackPhone,
    String? fallbackEmail,
  }) async {
    final response = await _dioClient.dio.get(
      ApiConfig.userProfile(userId),
      options: Options(headers: {'x-background-sync': 'true'}),
    );
    if (response.data is! Map) {
      return [];
    }
    final raw = Map<String, dynamic>.from(response.data as Map);
    final payload = raw['data'] is Map
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : raw;

    final userMap = payload['user'] is Map
        ? Map<String, dynamic>.from(payload['user'] as Map)
        : payload;
    final workMap = payload['work'] is Map
        ? Map<String, dynamic>.from(payload['work'] as Map)
        : (payload['work_profile'] is Map
            ? Map<String, dynamic>.from(payload['work_profile'] as Map)
            : null);

    final parsedUserId =
        int.tryParse(userId) ?? int.tryParse('${userMap['id'] ?? ''}') ?? 0;
    if (parsedUserId <= 0) {
      return [];
    }

    final first = '${userMap['first_name'] ?? ''}'.trim();
    final last = '${userMap['last_name'] ?? ''}'.trim();
    final combinedName = '$first $last'.trim();
    final resolvedName = combinedName.isNotEmpty
        ? combinedName
        : (fallbackName.isEmpty ? 'Card 1' : fallbackName);
    final phone = '${userMap['phone'] ?? fallbackPhone}'.trim();
    final email = userMap['email']?.toString() ?? fallbackEmail;

    dynamic rawCards = payload['cards'];
    if (rawCards is Map && rawCards['items'] is List) {
      rawCards = rawCards['items'];
    } else if (rawCards is! List && payload['work_profiles'] is List) {
      rawCards = payload['work_profiles'];
    }
    if (rawCards is List && rawCards.isNotEmpty) {
      final parsed = <CardModel>[];
      for (var i = 0; i < rawCards.length; i++) {
        final item = rawCards[i];
        if (item is Map) {
          parsed.add(
            CardModel.fromJson(
              Map<String, dynamic>.from(item),
              i,
              parsedUserId,
              resolvedName,
              phone,
              email,
            ),
          );
        }
      }
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    final workProfileId = int.tryParse(
          '${workMap?['id'] ?? workMap?['work_profile_id'] ?? userMap['work_profile_id'] ?? parsedUserId}',
        ) ??
        parsedUserId;
    final companyName = '${workMap?['company_name'] ?? ''}'.trim();
    final qrCode =
        workMap?['qr_code']?.toString() ?? userMap['qr_code']?.toString();
    final profileUrl =
        workMap?['profile_url']?.toString() ?? userMap['profile_url']?.toString();
    final tabLabel = companyName.isNotEmpty
        ? companyName
        : (resolvedName.isNotEmpty ? resolvedName : 'Card 1');
    final captionName = companyName.isNotEmpty ? companyName : resolvedName;

    return [
      CardModel(
        userId: parsedUserId,
        cardId: workProfileId,
        workProfileId: workProfileId,
        accountUserId: parsedUserId,
        cardNo: 1,
        name: resolvedName,
        companyName: companyName,
        phone: phone,
        email: email,
        qrCode: qrCode,
        isPrimary: true,
        tabLabel: tabLabel,
        captionName: captionName,
        companyLogo:
            workMap?['company_logo']?.toString() ?? workMap?['logo']?.toString(),
        designation: workMap?['designation']?.toString(),
        profileImageName:
            userMap['profile_image']?.toString() ?? userMap['image']?.toString(),
        profileUrl: profileUrl,
      ),
    ];
  }

  /// Fetches subscription details response maps
  Future<Map<String, dynamic>?> getSubscriptionDetails(String userId) async {
    try {
      final response = await _dioClient.dio.get(
        ApiConfig.subscriptionDetails(userId),
        options: Options(headers: {'x-background-sync': 'true'}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['data'] ?? response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to fetch subscription details');
    }
  }

  /// Coupon verification
  Future<Map<String, dynamic>?> applyCoupon(String userId, String couponCode) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConfig.subscriptionCoupon(userId),
        data: {'code': couponCode},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to apply coupon');
    }
  }

  /// Confirm payment
  Future<Map<String, dynamic>?> confirmPayment(String userId, Map<String, dynamic> payload) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConfig.subscriptionConfirm(userId),
        data: payload,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to confirm payment');
    }
  }
}
