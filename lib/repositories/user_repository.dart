import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_config.dart';
import '../models/user_model.dart';
import '../models/card_model.dart';
import '../core/utils/international_phone_helper.dart';

class UserRepository {
  final DioClient _dioClient;

  UserRepository([DioClient? dioClient]) : _dioClient = dioClient ?? DioClient();

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
    Map<String, dynamic> updateData,
  ) async {
    try {
      Response response;
      try {
        response = await _dioClient.dio.put(
          ApiConfig.userProfile(userId),
          data: updateData,
        );
      } on DioException catch (putErr) {
        final statusCode = putErr.response?.statusCode;
        if (statusCode == 403 || statusCode == 405) {
          response = await _dioClient.dio.post(
            ApiConfig.userProfile(userId),
            data: updateData,
          );
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map) {
          final candidate = data['user'] ?? (data['data'] is Map ? data['data'] : null);
          if (candidate is Map && (candidate['id'] != null || candidate['email'] != null)) {
            return UserModel.fromJson(Map<String, dynamic>.from(candidate));
          }
        }
        return (await getUserProfile(userId)) ?? UserModel(id: userId);
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to update profile');
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
      
      // Determine extension â€” strip query params first (blob URLs on web may have none)
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
      // Server requires crop data â€” always send it
      final cropData = crop ?? {'width': 512, 'height': 512, 'x': 0, 'y': 0};
      formData.fields.add(MapEntry('crop', jsonEncode(cropData)));
      // work_profile_id goes in query string only â€” Multer only allows 'image' + 'crop' in body

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
      // Determine extension â€” strip query params first (blob URLs on web may have none)
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

      final formData = FormData();
      MultipartFile logoFile;
      if (kIsWeb) {
        final r = await http.get(Uri.parse(filePath));
        logoFile = MultipartFile.fromBytes(
          r.bodyBytes,
          filename: filename,
          contentType: mediaType,
        );
      } else {
        logoFile = await MultipartFile.fromFile(
          filePath,
          filename: filename,
          contentType: mediaType,
        );
      }
      formData.files.add(MapEntry('image', logoFile));
      final cropData = crop ?? {'width': 512, 'height': 512, 'x': 0, 'y': 0};
      formData.fields.add(MapEntry('crop', jsonEncode(cropData)));

      final response = await _dioClient.dio.post(
        ApiConfig.companyLogo(userId),
        data: formData,
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;    } on DioException catch (e) {
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
    int limit = 30,
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
      debugPrint('ðŸ“© getDashboardMessages raw type: ${data.runtimeType}');
      debugPrint('ðŸ“© getDashboardMessages raw data: $data');

      // Handle direct List response
      if (data is List) {
        debugPrint('ðŸ“© Messages: direct list, count=${data.length}');
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
            debugPrint('ðŸ“© Messages found in wrapper, count=${candidate.length}');
            return candidate.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          }
        }
        // Last resort: if it's a single message object, wrap it
        if (data.containsKey('id') || data.containsKey('title')) {
          debugPrint('ðŸ“© Single message object â€” wrapping in list');
          return [Map<String, dynamic>.from(data)];
        }
        debugPrint('ðŸ“© No known list key found in Map response. Keys: ${data.keys.toList()}');
      }

      debugPrint('ðŸ“© getDashboardMessages: unrecognised response shape, returning []');
      return const [];
    } on DioException catch (e) {
      debugPrint('ðŸ“© getDashboardMessages ERROR: ${e.response?.statusCode} â€” ${e.response?.data}');
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
        ApiConfig.updateMessageAction(messageId),
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

  /// Updates suspension status for a specific work profile / card
  Future<Map<String, dynamic>?> updateCardSuspension(
    String userId,
    int workProfileId, {
    required bool suspend,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConfig.cardSuspension(userId, workProfileId),
        data: {'action': suspend ? 'suspend' : 'activate'},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : {'success': true, 'is_card_suspended': suspend};
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
        return updateCardProfileDetails(
          userId,
          {'is_suspended': suspend ? 1 : 0},
          workProfileId: workProfileId,
        );
      }
      throw DioClient.getErrorMessage(e, 'Failed to update card suspension');
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
    final trimmedOtp = otp.trim();
    if (requestId.trim().isEmpty || !RegExp(r'^\d{6}$').hasMatch(trimmedOtp)) {
      throw 'Please enter a valid 6-digit OTP.';
    }
    try {
      final response = await _dioClient.dio.post(
        ApiConfig.verifyProfileOtp(userId),
        data: {'request_id': requestId.trim(), 'otp': trimmedOtp},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to verify OTP');
    }
  }

  /// Fetches physical NFC card orders for a user
  Future<List<dynamic>> getNfcOrders(String userId) async {
    try {
      final response = await _dioClient.dio.get(ApiConfig.nfcOrders(userId));
      if (response.data is Map) {
        final map = response.data as Map;
        if (map['orders'] is List) {
          return map['orders'] as List<dynamic>;
        }
        if (map['data'] is List) {
          return map['data'] as List<dynamic>;
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Places a new physical NFC card order
  Future<Map<String, dynamic>?> placeNfcOrder(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConfig.nfcOrders(userId),
        data: payload,
      );
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to place NFC order');
    }
  }
}
