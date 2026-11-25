import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smartcard_flutter/core/services/dio_client.dart';
import 'package:smartcard_flutter/core/services/api_config.dart';
import 'package:smartcard_flutter/features/profile_screen/data/models/user_model.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/data/models/card_model.dart';
import 'package:smartcard_flutter/core/utils/international_phone_helper.dart';

class UserRepository {
  final DioClient _dioClient = DioClient();

  /// Fetches the user profile by user ID
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final response = await _dioClient.dio.get(ApiConfig.userProfile(userId));

      if (response.statusCode == 200) {
        final data = response.data;
        final userData = data['user'] ?? data['data'] ?? data;
        return UserModel.fromJson(userData);
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to load profile');
    }
  }

  /// Updates the user profile
  Future<UserModel?> updateUserProfile(
    String userId,
    Map<String, dynamic> updateData, {
    int? workProfileId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      final payload = Map<String, dynamic>.from(updateData);
      payload.remove('address2');
      payload.remove('youtube_links');

      final isAddressOnly = payload.containsKey('address') || payload.containsKey('pincode');
      final wpId = isAddressOnly
          ? null
          : (workProfileId ?? (payload['work_profile_id'] is int ? payload['work_profile_id'] as int : null));
      if (wpId != null && wpId > 0) {
        queryParams['work_profile_id'] = wpId.toString();
        payload['work_profile_id'] = wpId;
      } else {
        payload.remove('work_profile_id');
      }

      Response response;
      try {
        response = await _dioClient.dio.put(
          ApiConfig.userProfile(userId),
          data: payload,
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
        );
      } on DioException catch (putErr) {
        final statusCode = putErr.response?.statusCode;
        if (statusCode == 403 || statusCode == 405) {
          response = await _dioClient.dio.post(
            ApiConfig.userProfile(userId),
            data: payload,
            queryParameters: queryParams.isNotEmpty ? queryParams : null,
          );
        } else {
          final errStr = putErr.response?.data?.toString() ?? putErr.message ?? '';
          if (errStr.contains('address2') || errStr.contains('user_work_profile') || errStr.contains('youtube_links')) {
            final fallbackPayload = Map<String, dynamic>.from(payload)
              ..remove('work_profile_id')
              ..remove('address2')
              ..remove('youtube_links');
            response = await _dioClient.dio.put(
              ApiConfig.userProfile(userId),
              data: fallbackPayload,
            );
            if (response.statusCode == 200 || response.statusCode == 201) {
              final data = response.data;
              final userData = data['user'] ?? data['data'] ?? data;
              return UserModel.fromJson(userData);
            }
          }
          rethrow;
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final userData = data['user'] ?? data['data'] ?? data;
        return UserModel.fromJson(userData);
      }
      return null;
    } on DioException catch (e) {
      final errStr = e.response?.data?.toString() ?? e.message ?? '';
      if (errStr.contains('address2') || errStr.contains('user_work_profile')) {
        try {
          final wpId = workProfileId ?? (updateData['work_profile_id'] is int ? updateData['work_profile_id'] as int : null);
          await updateCardProfileDetails(userId, updateData, workProfileId: wpId);
          return await getUserProfile(userId);
        } catch (_) {}
      }
      throw DioClient.getErrorMessage(e, 'Failed to update profile');
    }
  }

  /// Changes the user password
  Future<Map<String, dynamic>?> changeUserPassword(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConfig.passwordChange(userId),
        data: payload,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data;
        }
        return Map<String, dynamic>.from(data as Map);
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to change password');
    }
  }

  /// Fetches detailed profile (combined user + work profile details) for a specific card profile ID
  Future<CardProfileDetails?> getCardProfileDetails(
    String userId, {
    int? workProfileId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (workProfileId != null && workProfileId > 0) {
        queryParams['work_profile_id'] = workProfileId.toString();
      }
      final response = await _dioClient.dio.get(
        ApiConfig.userProfile(userId),
        queryParameters: queryParams,
        options: Options(headers: {'x-background-sync': 'true'}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CardProfileDetails.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to load card profile details');
    }
  }

  /// Updates detailed profile details for a specific card profile ID
  Future<Map<String, dynamic>?> updateCardProfileDetails(
    String userId,
    Map<String, dynamic> updateData, {
    int? workProfileId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (workProfileId != null && workProfileId > 0) {
        queryParams['work_profile_id'] = workProfileId.toString();
      }

      // Inject work_profile_id to payload if exists, mimicking React: withWorkProfilePayload
      final payload = Map<String, dynamic>.from(updateData);
      if (workProfileId != null && workProfileId > 0) {
        payload['work_profile_id'] = workProfileId;
      }

      Response response;
      try {
        response = await _dioClient.dio.put(
          ApiConfig.userProfile(userId),
          data: payload,
          queryParameters: queryParams,
        );
      } on DioException catch (putErr) {
        final statusCode = putErr.response?.statusCode;
        if (statusCode == 403 || statusCode == 405) {
          response = await _dioClient.dio.post(
            ApiConfig.userProfile(userId),
            data: payload,
            queryParameters: queryParams,
          );
        } else {
          rethrow;
        }
      }
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to save changes');
    }
  }

  /// Fetches the user gallery (photos list + YouTube links)
  Future<Map<String, dynamic>?> getUserGallery(
    String userId, {
    int? workProfileId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (workProfileId != null && workProfileId > 0) {
        queryParams['work_profile_id'] = workProfileId.toString();
      }
      final response = await _dioClient.dio.get(
        ApiConfig.userGallery(userId),
        queryParameters: queryParams,
        options: Options(headers: {'x-background-sync': 'true'}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to load gallery data');
    }
  }

  /// Uploads profile image
  Future<Map<String, dynamic>?> uploadProfileImage(
    String userId,
    String filePath,
    Map<String, dynamic>? crop, {
    int? workProfileId,
  }) async {
    try {
      final formData = FormData();
      
      // Determine extension — strip query params first (blob URLs on web may have none)
      final cleanPath = filePath.split('?').first;
      final extension = cleanPath.contains('.')
          ? cleanPath.split('.').last.toLowerCase()
          : 'jpg';
      final mimeType = (extension == 'png')
          ? 'image/png'
          : (extension == 'webp' ? 'image/webp' : 'image/jpeg');
      final filename = 'profile_image.$extension';
      final mediaType = MediaType.parse(mimeType);

      MultipartFile imageFile;
      if (kIsWeb) {
        final response = await http.get(Uri.parse(filePath));
        imageFile = MultipartFile.fromBytes(
          response.bodyBytes,
          filename: filename,
          contentType: mediaType,
        );
      } else {
        imageFile = await MultipartFile.fromFile(
          filePath,
          filename: filename,
          contentType: mediaType,
        );
      }
      formData.files.add(MapEntry('image', imageFile));
      // Server requires crop data — always send it
      final cropData = crop ?? {'width': 512, 'height': 512, 'x': 0, 'y': 0};
      formData.fields.add(MapEntry('crop', jsonEncode(cropData)));
      // work_profile_id goes in query string only — Multer only allows 'image' + 'crop' in body

      final queryParams = <String, dynamic>{};
      if (workProfileId != null && workProfileId > 0) {
        queryParams['work_profile_id'] = workProfileId.toString();
      }

      final response = await _dioClient.dio.post(
        ApiConfig.userProfileImage(userId),
        data: formData,
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to upload profile image');
    }
  }

  Future<Map<String, dynamic>?> uploadCompanyLogo(
    String userId,
    String filePath,
    Map<String, dynamic>? crop, {
    int? workProfileId,
  }) async {
    try {
      // Determine extension — strip query params first (blob URLs on web may have none)
      final cleanPath = filePath.split('?').first;
      final extension = cleanPath.contains('.')
          ? cleanPath.split('.').last.toLowerCase()
          : 'jpg';
      final mimeType = (extension == 'png')
          ? 'image/png'
          : (extension == 'webp'
              ? 'image/webp'
              : (extension == 'gif' ? 'image/gif' : 'image/jpeg'));
      final filename = 'company_logo.$extension';
      final mediaType = MediaType.parse(mimeType);

      final queryParams = <String, dynamic>{};
      if (workProfileId != null && workProfileId > 0) {
        queryParams['work_profile_id'] = workProfileId.toString();
      }

      // Auto-probe: try each possible Multer field name until one succeeds
      // The backend rejects unknown field names with 400 "Unexpected field"
      const candidateFields = ['company_logo', 'logo', 'image', 'file', 'logo_file'];
      for (final fieldName in candidateFields) {
        try {
          final fd = FormData();
          // Re-create the multipart file for each attempt (body can't be reused)
          MultipartFile attempt;
          if (kIsWeb) {
            final r = await http.get(Uri.parse(filePath));
            attempt = MultipartFile.fromBytes(r.bodyBytes, filename: filename, contentType: mediaType);
          } else {
            attempt = await MultipartFile.fromFile(filePath, filename: filename, contentType: mediaType);
          }
          fd.files.add(MapEntry(fieldName, attempt));
          
          // Server requires crop data — always send it
          final cropData = crop ?? {'width': 512, 'height': 512, 'x': 0, 'y': 0};
          fd.fields.add(MapEntry('crop', jsonEncode(cropData)));

          final response = await _dioClient.dio.post(
            ApiConfig.companyLogo(userId),
            data: fd,
            queryParameters: queryParams,
          );
          if (response.statusCode == 200 || response.statusCode == 201) {
            debugPrint('✅ Company logo uploaded successfully with field: "$fieldName"');
            return response.data;
          }
        } on DioException catch (e) {
          final msg = e.response?.data?.toString() ?? e.message ?? '';
          debugPrint('❌ Field "$fieldName" failed: $msg');
          // "Unexpected field" → try next; any other error → rethrow
          if (!msg.contains('Unexpected field') && !msg.contains('unexpected field')) {
            throw DioClient.getErrorMessage(e, 'Failed to upload company logo');
          }
          // else continue to next field name
        }
      }
      throw 'Company logo upload failed: no valid field name found. Tried: $candidateFields';
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to upload company logo');
    }
  }

  /// Deletes profile image
  Future<bool> deleteProfileImage(String userId, {int? workProfileId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (workProfileId != null && workProfileId > 0) {
        queryParams['work_profile_id'] = workProfileId.toString();
      }
      final response = await _dioClient.dio.delete(
        ApiConfig.userProfileImage(userId),
        queryParameters: queryParams,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      try {
        await updateUserProfile(userId, {'profile_image': '', 'image': ''});
        return true;
      } catch (e) {
        throw DioClient.getErrorMessage(e, 'Failed to delete profile image');
      }
    }
  }

  /// Deletes company logo
  Future<bool> deleteCompanyLogo(String userId, {int? workProfileId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (workProfileId != null && workProfileId > 0) {
        queryParams['work_profile_id'] = workProfileId.toString();
      }
      final response = await _dioClient.dio.delete(
        ApiConfig.companyLogo(userId),
        queryParameters: queryParams,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      try {
        await updateUserProfile(userId, {'logo': '', 'company_logo': ''});
        return true;
      } catch (e) {
        throw DioClient.getErrorMessage(e, 'Failed to delete company logo');
      }
    }
  }

  /// Loads the dashboard messages used by the Messages page
  Future<List<Map<String, dynamic>>> getDashboardMessages({
    int limit = 200,
    bool includeRead = true,
  }) async {
    try {
      final response = await _dioClient.dio.get(
        ApiConfig.getMessages,
        queryParameters: {
          'limit': limit,
          'include_read': includeRead ? '1' : '0',
        },
      );
      final data = response.data;
      debugPrint('📩 getDashboardMessages raw type: ${data.runtimeType}');
      debugPrint('📩 getDashboardMessages raw data: $data');

      // Handle direct List response
      if (data is List) {
        debugPrint('📩 Messages: direct list, count=${data.length}');
        return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }

      if (data is Map) {
        // Try every known wrapper key
        final candidates = [
          data['data'],
          data['messages'],
          data['items'],
          data['rows'],
          data['notifications'],
          data['results'],
          data['list'],
        ];
        for (final candidate in candidates) {
          if (candidate is List) {
            debugPrint('📩 Messages found in wrapper, count=${candidate.length}');
            return candidate.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          }
        }
        // Last resort: if it's a single message object, wrap it
        if (data.containsKey('id') || data.containsKey('title')) {
          debugPrint('📩 Single message object — wrapping in list');
          return [Map<String, dynamic>.from(data)];
        }
        debugPrint('📩 No known list key found in Map response. Keys: ${data.keys.toList()}');
      }

      debugPrint('📩 getDashboardMessages: unrecognised response shape, returning []');
      return const [];
    } on DioException catch (e) {
      debugPrint('📩 getDashboardMessages ERROR: ${e.response?.statusCode} — ${e.response?.data}');
      throw DioClient.getErrorMessage(e, 'Failed to load messages');
    }
  }

  /// Updates dashboard message action state
  Future<Map<String, dynamic>?> updateDashboardMessageAction(
    String messageId,
    String action,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        '${ApiConfig.getMessages}/$messageId/action',
        data: {'action': action},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      return Map<String, dynamic>.from(data as Map);
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to update message action');
    }
  }

  /// Loads the current user's support context.
  Future<Map<String, dynamic>?> getSupportContext(String userId) async {
    try {
      final response = await _dioClient.dio.get(
        ApiConfig.supportContext(userId),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map && data['data'] is Map) {
          return Map<String, dynamic>.from(data['data'] as Map);
        }
        if (data is Map<String, dynamic>) {
          return Map<String, dynamic>.from(data);
        }
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to load support context');
    }
  }

  /// Loads support chat messages.
  Future<List<Map<String, dynamic>>> getSupportMessages(
    String userId, {
    int limit = 100,
    int? afterId,
    int? beforeId,
  }) async {
    try {
      final queryParameters = <String, dynamic>{'limit': limit};
      if (afterId != null && afterId > 0) {
        queryParameters['after_id'] = afterId;
      } else if (beforeId != null && beforeId > 0) {
        queryParameters['before_id'] = beforeId;
      }

      final response = await _dioClient.dio.get(
        ApiConfig.supportMessages(userId),
        queryParameters: queryParameters,
      );

      final data = response.data;
      final rows = data is Map
          ? (data['messages'] ?? data['data'] ?? data['items'] ?? data['rows'])
          : data;

      if (rows is List) {
        return rows
            .whereType<Map>()
            .map(
              (item) =>
                  _normalizeSupportMessage(Map<String, dynamic>.from(item)),
            )
            .toList();
      }

      return const [];
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to load support messages');
    }
  }

  Map<String, dynamic> _normalizeSupportMessage(Map<String, dynamic> message) {
    dynamic pick(List<String> keys) {
      for (final key in keys) {
        if (message.containsKey(key) && message[key] != null) {
          final value = message[key];
          if (value is String && value.trim().isEmpty) continue;
          return value;
        }
      }
      return null;
    }

    String textOf(List<String> keys, [String fallback = '']) {
      final value = pick(keys);
      return value?.toString().trim() ?? fallback;
    }

    final normalized = Map<String, dynamic>.from(message);
    normalized['id'] = pick(['id', 'message_id', 'messageId']);
    normalized['sender_type'] = textOf([
      'sender_type',
      'senderType',
      'from_user',
      'fromUser',
      'author_type',
      'authorType',
      'role',
      'type',
    ]);
    normalized['message_text'] = textOf([
      'message_text',
      'messageText',
      'text',
      'message',
      'body',
      'content',
    ]);
    normalized['attachment_path'] = textOf([
      'attachment_path',
      'attachmentPath',
      'attachment',
      'file_path',
      'filePath',
      'media_url',
      'mediaUrl',
    ]);
    normalized['attachment_type'] = textOf([
      'attachment_type',
      'attachmentType',
      'mime_type',
      'mimeType',
      'content_type',
      'contentType',
    ]);
    normalized['chat_state'] = pick(['chat_state', 'chatState']) ?? 0;
    normalized['created_at'] = textOf([
      'created_at',
      'createdAt',
      'sent_at',
      'sentAt',
      'timestamp',
      'time',
    ]);
    normalized['delivered_at'] = textOf(['delivered_at', 'deliveredAt']);
    normalized['read_at'] = textOf(['read_at', 'readAt']);
    normalized['reply_to_id'] = pick(['reply_to_id', 'replyToId']);
    return normalized;
  }

  /// Sends a support chat message.
  Future<Map<String, dynamic>?> sendSupportMessage(
    String userId, {
    required String messageText,
    String? chatState,
    String? agentId,
    String? messageTag,
    String? attachmentPath,
  }) async {
    try {
      final formData = FormData();
      formData.fields.add(MapEntry('text', messageText));
      if (chatState != null && chatState.trim().isNotEmpty) {
        formData.fields.add(MapEntry('chatState', chatState.trim()));
      }
      if (agentId != null && agentId.trim().isNotEmpty) {
        formData.fields.add(MapEntry('agentId', agentId.trim()));
      }
      if (messageTag != null && messageTag.trim().isNotEmpty) {
        formData.fields.add(MapEntry('message_tag', messageTag.trim()));
      }
      if (attachmentPath != null && attachmentPath.trim().isNotEmpty) {
        formData.files.add(
          MapEntry('attachment', await MultipartFile.fromFile(attachmentPath)),
        );
      }

      final response = await _dioClient.dio.post(
        ApiConfig.supportMessages(userId),
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data;
        }
        return Map<String, dynamic>.from(data as Map);
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to send support message');
    }
  }

  Future<List<Map<String, dynamic>>> getMessages() async {
    return await getDashboardMessages();
  }

  Future<Map<String, dynamic>?> updateMessageAction(
    String messageId,
    String action,
  ) async {
    return await updateDashboardMessageAction(messageId, action);
  }

  /// Loads all user reports.
  Future<List<Map<String, dynamic>>> getUserReports() async {
    try {
      final response = await _dioClient.dio.get(ApiConfig.userReports);
      final data = response.data;
      var rows = data is List
          ? data
          : data is Map
          ? (data['data'] ?? data['reports'] ?? data['items'] ?? data['rows'])
          : null;

      if (rows is Map && rows.containsKey('reports')) {
        rows = rows['reports'];
      }

      if (rows is List) {
        return rows
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }

      return const [];
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to load reports');
    }
  }

  /// Creates a new user report.
  Future<Map<String, dynamic>?> createUserReport(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConfig.userReports,
        data: payload,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data;
        }
        return Map<String, dynamic>.from(data as Map);
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to create report');
    }
  }

  /// Loads a single report.
  Future<Map<String, dynamic>?> getUserReportDetails(String reportId) async {
    try {
      final response = await _dioClient.dio.get(ApiConfig.userReport(reportId));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map && data['report'] is Map) {
          return Map<String, dynamic>.from(data['report'] as Map);
        }
        if (data is Map<String, dynamic>) {
          return Map<String, dynamic>.from(data);
        }
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to load report details');
    }
  }

  /// Replies to a report.
  Future<Map<String, dynamic>?> replyToUserReport(
    String reportId,
    String message,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConfig.replyUserReport(reportId),
        data: {'message': message},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data;
        }
        return Map<String, dynamic>.from(data as Map);
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to reply to report');
    }
  }

  /// Uploads gallery images
  Future<Map<String, dynamic>?> uploadGalleryImages(
    String userId,
    List<XFile> files, {
    int? workProfileId,
  }) async {
    try {
      final formData = FormData();
      for (final xfile in files) {
        final bytes = await xfile.readAsBytes();
        final filename = xfile.name.isNotEmpty ? xfile.name : 'image.jpg';
        formData.files.add(
          MapEntry(
            'images',
            MultipartFile.fromBytes(bytes, filename: filename),
          ),
        );
      }
      if (workProfileId != null && workProfileId > 0) {
        formData.fields.add(
          MapEntry('work_profile_id', workProfileId.toString()),
        );
      }

      final queryParams = <String, dynamic>{};
      if (workProfileId != null && workProfileId > 0) {
        queryParams['work_profile_id'] = workProfileId.toString();
      }

      final response = await _dioClient.dio.post(
        ApiConfig.galleryImages(userId),
        data: formData,
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to upload gallery images');
    }
  }

  /// Deletes the user account
  Future<bool> deleteUserAccount(String userId) async {
    try {
      Response response;
      try {
        // 1. Try POST endpoint first (bypasses LiteSpeed / proxy HTTP DELETE blocks)
        response = await _dioClient.dio.post(
          ApiConfig.deleteUserAccountPost(userId),
        );
      } on DioException catch (e) {
        // Fallback for environments with different routing or HTTP method support
        if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
          try {
            response = await _dioClient.dio.delete(
              ApiConfig.deleteUserAccount(userId),
            );
          } on DioException catch (e2) {
            if (e2.response?.statusCode == 404 ||
                e2.response?.statusCode == 403 ||
                e2.response?.statusCode == 405) {
              try {
                response = await _dioClient.dio.post(
                  ApiConfig.deleteUserAccountMePost,
                );
              } on DioException catch (_) {
                response = await _dioClient.dio.delete(
                  ApiConfig.deleteUserAccountMe,
                );
              }
            } else {
              rethrow;
            }
          }
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 200 || response.statusCode == 204) {
        final data = response.data;
        if (data is Map && data['success'] == false) {
          final errMsg = data['message']?.toString() ??
              data['error']?.toString() ??
              'Failed to delete account';
          throw errMsg;
        }
        return true;
      }
      return false;
    } on DioException catch (e) {
      final resData = e.response?.data;
      if (resData is Map) {
        final msg = resData['error']?.toString() ?? resData['message']?.toString();
        if (msg != null && msg.trim().isNotEmpty) {
          throw msg;
        }
      }
      throw DioClient.getErrorMessage(e, 'Failed to delete account');
    }
  }


  /// Deletes a gallery image
  Future<Map<String, dynamic>?> deleteGalleryImage(
    String userId,
    String filename, {
    int? workProfileId,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'filename': filename,
      };
      if (workProfileId != null && workProfileId > 0) {
        queryParams['work_profile_id'] = workProfileId.toString();
      }

      final payload = <String, dynamic>{'filename': filename};
      if (workProfileId != null && workProfileId > 0) {
        payload['work_profile_id'] = workProfileId;
      }

      Response response;
      try {
        response = await _dioClient.dio.delete(
          ApiConfig.galleryImages(userId),
          data: payload,
          queryParameters: queryParams,
        );
      } on DioException catch (delErr) {
        final statusCode = delErr.response?.statusCode;
        if (statusCode == 403 || statusCode == 404 || statusCode == 405) {
          response = await _dioClient.dio.post(
            ApiConfig.deleteGalleryImage(userId),
            data: payload,
            queryParameters: queryParams,
          );
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to delete gallery image');
    }
  }

  /// Fetches video gallery links and rich metadata
  Future<Map<String, dynamic>?> getVideoGallery(
    String userId, {
    int? workProfileId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (workProfileId != null && workProfileId > 0) {
        queryParams['work_profile_id'] = workProfileId.toString();
      }
      final response = await _dioClient.dio.get(
        ApiConfig.galleryYoutubeLinks(userId),
        queryParameters: queryParams,
        options: Options(headers: {'x-background-sync': 'true'}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Updates video gallery links & metadata (supports Option A 'links' and Option B 'videos')
  Future<Map<String, dynamic>?> updateYoutubeLinks(
    String userId,
    List<String> links, {
    List<Map<String, dynamic>>? videos,
    int? workProfileId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (workProfileId != null && workProfileId > 0) {
        queryParams['work_profile_id'] = workProfileId.toString();
      }

      final payload = <String, dynamic>{
        'links': links,
        if (videos != null && videos.isNotEmpty) 'videos': videos,
      };
      if (workProfileId != null && workProfileId > 0) {
        payload['work_profile_id'] = workProfileId;
      }

      final response = await _dioClient.dio.post(
        ApiConfig.galleryYoutubeLinks(userId),
        data: payload,
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to update video links');
    }
  }

  /// Creates a new additional card profile for the user
  Future<Map<String, dynamic>?> createUserAdditionalCard(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConfig.additionalCard(userId),
        data: payload,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to create additional card');
    }
  }

  /// Deletes a specific additional card profile
  Future<Map<String, dynamic>?> deleteUserAdditionalCard(
    String userId,
    int cardUserId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dioClient.dio.delete(
        ApiConfig.deleteAdditionalCard(userId, cardUserId),
        data: payload,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to delete card');
    }
  }

  /// Sets a specific card profile as primary
  Future<Map<String, dynamic>?> setUserPrimaryCard(
    String userId,
    int cardUserId,
    Map<String, dynamic> payload,
  ) async {
    try {
      Response response;
      try {
        response = await _dioClient.dio.put(
          ApiConfig.primaryCard(userId, cardUserId),
          data: payload,
        );
      } on DioException catch (putErr) {
        final statusCode = putErr.response?.statusCode;
        if (statusCode == 403 || statusCode == 405) {
          response = await _dioClient.dio.post(
            ApiConfig.primaryCard(userId, cardUserId),
            data: payload,
          );
        } else {
          rethrow;
        }
      }
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to update primary card');
    }
  }

  /// Suspends or reactivates self-suspension of the user account
  Future<Map<String, dynamic>?> updateSelfSuspension(
    String userId, {
    required String action,
    String? reason,
    String? notes,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConfig.selfSuspension(userId),
        data: {'action': action, 'reason': reason, 'notes': notes},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to update suspension status');
    }
  }

  /// Sends OTP for updating personal details
  Future<Map<String, dynamic>?> sendProfileOtp(
    String userId,
    String phone, {
    String channel = 'phone',
    String countryCode = '+91',
    String? whatsappNumber,
  }) async {
    try {
      final formattedPhone = InternationalPhoneHelper.formatForBackend(
        phone: phone,
        countryCode: countryCode,
      );
      final e164 = InternationalPhoneHelper.toE164(
        phone: phone,
        countryCode: countryCode,
      );

      final isWhatsApp = channel.toLowerCase() == 'whatsapp';
      final deliveryChannel = isWhatsApp ? 'whatsapp' : 'phone';

      final Map<String, dynamic> data = {
        'phone': formattedPhone,
        'country_code': countryCode,
        'full_phone': e164,
        'channel': deliveryChannel,
        'otp_channel': deliveryChannel,
        'delivery_method': deliveryChannel,
      };

      if (isWhatsApp) {
        if (whatsappNumber != null && whatsappNumber.trim().isNotEmpty) {
          data['whatsapp_number'] = InternationalPhoneHelper.formatForBackend(
            phone: whatsappNumber,
            countryCode: countryCode,
          );
        } else {
          data['whatsapp_number'] = formattedPhone;
        }
      }

      final response = await _dioClient.dio.post(
        ApiConfig.sendProfileOtp(userId),
        data: data,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to send OTP');
    }
  }

  /// Verifies OTP for updating personal details
  Future<Map<String, dynamic>?> verifyProfileOtp(
    String userId,
    String requestId,
    String otp,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConfig.verifyProfileOtp(userId),
        data: {'request_id': requestId, 'otp': otp},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to verify OTP');
    }
  }
}
