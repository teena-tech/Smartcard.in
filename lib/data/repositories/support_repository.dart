import 'package:dio/dio.dart';
import 'dart:io';
import '../../core/services/dio_client.dart';
import '../../core/services/api_config.dart';
import '../models/message_model.dart';

class SupportRepository {
  final DioClient _dioClient = DioClient();

  SupportRepository([dynamic _]);

  Future<List<MessageModel>> getChatMessages(String userId, {int? limit, int? afterId, int? beforeId}) async {
    final Map<String, dynamic> query = {};
    if (limit != null) query['limit'] = limit;
    if (afterId != null) query['after_id'] = afterId;
    if (beforeId != null) query['before_id'] = beforeId;

    final response = await _dioClient.dio.get(
      ApiConfig.supportMessages(userId),
      queryParameters: query,
    );
    
    final List<dynamic> data = response.data is List 
        ? response.data 
        : (response.data['messages'] ?? response.data['data'] ?? []);
    return data.map((e) => MessageModel.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getUserSupportContext(String userId) async {
    final response = await _dioClient.dio.get(
      ApiConfig.supportContext(userId),
    );
    return response.data;
  }

  Future<int> getUnreadMessageCount(String userId) async {
    final response = await _dioClient.dio.get(
      ApiConfig.supportUnreadCount(userId),
    );
    final rawCount = response.data['count'];
    if (rawCount is int) return rawCount;
    if (rawCount != null) return int.tryParse(rawCount.toString()) ?? 0;
    return 0;
  }

  Future<MessageModel> sendChatMessage(String userId, {required String text, File? attachment}) async {
    final formData = FormData.fromMap({
      'text': text,
      if (attachment != null) 'attachment': await MultipartFile.fromFile(attachment.path),
    });

    final response = await _dioClient.dio.post(
      ApiConfig.supportMessages(userId),
      data: formData,
    );
    
    final data = response.data;
    final messageData = (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>)
        ? data['data']
        : data;

    if (messageData is Map<String, dynamic> &&
        (messageData.containsKey('details') ||
            messageData.containsKey('text') ||
            messageData.containsKey('id') ||
            messageData.containsKey('message') ||
            messageData.containsKey('message_text'))) {
      return MessageModel.fromJson(messageData);
    }
    
    // Backend only returned success status, so construct the message locally
    return MessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      title: '',
      summary: text,
      details: text,
      source: 'user',
      createdAt: DateTime.now().toIso8601String(),
      reaction: 'none',
      likeCount: 0,
      dislikeCount: 0,
    );
  }

  Future<void> createUserReport(String reportType, String reportText) async {
    await _dioClient.dio.post(
      ApiConfig.userReports,
      data: {
        'report_type': reportType,
        'report_text': reportText,
      },
    );
  }
}
