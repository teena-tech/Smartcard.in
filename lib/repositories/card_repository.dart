import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_config.dart';
import '../models/card_model.dart';

class CardRepository {
  final DioClient _dioClient;

  CardRepository([DioClient? dioClient]) : _dioClient = dioClient ?? DioClient();

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
      throw DioClient.getErrorMessage(e, 'Failed to fetch subscription cards');
    }
  }
}
