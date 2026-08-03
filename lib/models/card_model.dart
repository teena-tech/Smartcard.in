import 'dart:convert';

class CardModel {
  final int userId; // matches card.user_id (which is work_profile_id)
  final int cardId;
  final int workProfileId;
  final int accountUserId;
  final int cardNo;
  final String name;
  final String companyName;
  final String phone;
  final String? email;
  final String? qrCode;
  final bool isPrimary;
  final String tabLabel;
  final String captionName;
  final bool isTemporary;
  final String? companyLogo;
  final String? designation;
  final String? backgroundImage;
  final String? backgroundColor;
  final String? textColor;
  final String? bgImageColor;
  final String? opacity;
  final String? profileImageName;
  final bool isSuspended;
  final String? profileUrl; // Computed profile link from backend (CARD_BASE_URL/profile/{id})
  final String? templateId;
  final String? templateKey;

  /// The URL to encode into the QR code and display/share.
  /// Reads directly from database `qr_code` field (e.g., https://thesmartcards.com/?sc=...) 
  /// matching the Preview button logic.
  String get qrData {
    final rawQr = (qrCode ?? '').trim();
    if (rawQr.isNotEmpty) {
      if (rawQr.startsWith('http://') || rawQr.startsWith('https://')) {
        return rawQr;
      }
    }
    if (profileUrl != null && profileUrl!.isNotEmpty) {
      return profileUrl!;
    }
    return 'https://thesmartcards.com/profile/$workProfileId';
  }


    CardModel({
    required this.userId,
    required this.cardId,
    required this.workProfileId,
    required this.accountUserId,
    required this.cardNo,
    required this.name,
    required this.companyName,
    required this.phone,
    required this.email,
    required this.qrCode,
    required this.isPrimary,
    required this.tabLabel,
    required this.captionName,
    this.isTemporary = false,
    this.companyLogo,
    this.designation,
    this.backgroundImage,
    this.backgroundColor,
    this.textColor,
    this.bgImageColor,
    this.opacity,
    this.profileImageName,
    this.isSuspended = false,
    this.profileUrl,
    this.templateId,
    this.templateKey,
  });


  factory CardModel.fromJson(Map<String, dynamic> json, int index, int fallbackUserId, String fallbackName, String fallbackPhone, String? fallbackEmail) {
    final workProfileId = json['work_profile_id'] as int? ?? json['card_id'] as int? ?? json['user_id'] as int? ?? json['id'] as int? ?? 0;
    final cardId = json['card_id'] as int? ?? workProfileId;
    final accountUserId = json['account_user_id'] as int? ?? json['accountUserId'] as int? ?? json['owner_user_id'] as int? ?? fallbackUserId;
    
    final companyName = json['company_name']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    final cardNo = json['card_no'] as int? ?? (index + 1);

    // Tab label logic
    String tabLabel = companyName.trim().isNotEmpty 
        ? companyName.trim() 
        : (name.trim().isNotEmpty 
            ? name.trim() 
            : (fallbackName.trim().isNotEmpty ? fallbackName.trim() : 'Card $cardNo'));
    final captionName = companyName.trim().isNotEmpty ? companyName.trim() : (name.trim().isNotEmpty ? name.trim() : tabLabel);

    return CardModel(
      userId: workProfileId,
      cardId: cardId,
      workProfileId: workProfileId,
      accountUserId: accountUserId,
      cardNo: cardNo,
      name: name.isEmpty ? (fallbackName.isNotEmpty ? fallbackName : 'Card $cardNo') : name,
      companyName: companyName,
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      qrCode: json['qr_code']?.toString(),
      isPrimary: json['is_primary'] == true || json['is_primary'] == 1 || json['is_primary'] == '1',
      tabLabel: tabLabel,
      captionName: captionName,
      isTemporary: false,
      companyLogo: json['company_logo']?.toString() ?? json['logo']?.toString(),
      designation: json['designation']?.toString(),
      backgroundImage: json['background_image']?.toString() ?? json['bg_image']?.toString(),
      backgroundColor: json['bg_color']?.toString() ?? json['background_color']?.toString(),
      textColor: json['text_color']?.toString(),
      bgImageColor: json['bg_image_color']?.toString(),
      opacity: json['opacity']?.toString(),
      profileImageName: json['profile_image']?.toString() ?? json['image']?.toString(),
      isSuspended: json['is_suspended'] == 1 || json['is_suspended'] == true || json['is_suspended'] == '1',
      profileUrl: json['profile_url']?.toString(),
    );
  }

  CardModel copyWith({
    int? userId,
    int? cardId,
    int? workProfileId,
    int? accountUserId,
    int? cardNo,
    String? name,
    String? companyName,
    String? phone,
    String? email,
    String? qrCode,
    bool? isPrimary,
    String? tabLabel,
    String? captionName,
    bool? isTemporary,
    String? companyLogo,
    String? designation,
    String? backgroundImage,
    String? backgroundColor,
    String? textColor,
    String? bgImageColor,
    String? opacity,
    String? profileImageName,
    bool? isSuspended,
    String? profileUrl,
    String? templateId,
    String? templateKey,
  }) {
    return CardModel(
      userId: userId ?? this.userId,
      cardId: cardId ?? this.cardId,
      workProfileId: workProfileId ?? this.workProfileId,
      accountUserId: accountUserId ?? this.accountUserId,
      cardNo: cardNo ?? this.cardNo,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      qrCode: qrCode ?? this.qrCode,
      isPrimary: isPrimary ?? this.isPrimary,
      tabLabel: tabLabel ?? this.tabLabel,
      captionName: captionName ?? this.captionName,
      isTemporary: isTemporary ?? this.isTemporary,
      companyLogo: companyLogo == '' ? '' : (companyLogo ?? this.companyLogo),
      designation: designation ?? this.designation,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      bgImageColor: bgImageColor ?? this.bgImageColor,
      opacity: opacity ?? this.opacity,
      profileImageName: profileImageName == '' ? '' : (profileImageName ?? this.profileImageName),
      isSuspended: isSuspended ?? this.isSuspended,
      profileUrl: profileUrl ?? this.profileUrl,
      templateId: templateId ?? this.templateId,
      templateKey: templateKey ?? this.templateKey,
    );
  }
}

class CardProfileDetails {
  // Main User fields
  String firstName;
  String lastName;
  String email;
  String phone;
  String gender;
  String pincode;
  String cityId;
  String stateId;
  String city;
  String state;
  String district;
  bool officeSelected;
  String address;

  // Work Profile fields
  String companyName;
  String designation;
  String companyAddress;
  String companyPincode;
  String companyCityId;
  String companyStateId;
  String companyCity;
  String companyState;
  String companyDistrict;
  bool companyOfficeSelected;
  List<String> companyEmails;
  List<String> contactNumbers;
  List<String> whatsappNumbers;
  String fbLink;
  String instaLink;
  String linkedin;
  String xLink;
  List<Map<String, String>> website; // website links: name/url
  String aboutCompany;
  List<String> youtubeLinks;
  List<String> existingPhotos;
  String profileImageName;
  String companyLogoName;
  String qrLink;
  bool isSuspended;

  CardProfileDetails({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.gender = '',
    this.pincode = '',
    this.cityId = '',
    this.stateId = '',
    this.city = '',
    this.state = '',
    this.district = '',
    this.officeSelected = false,
    this.address = '',
    this.companyName = '',
    this.designation = '',
    this.companyAddress = '',
    this.companyPincode = '',
    this.companyCityId = '',
    this.companyStateId = '',
    this.companyCity = '',
    this.companyState = '',
    this.companyDistrict = '',
    this.companyOfficeSelected = false,
    this.companyEmails = const [],
    this.contactNumbers = const [],
    this.whatsappNumbers = const [],
    this.fbLink = '',
    this.instaLink = '',
    this.linkedin = '',
    this.xLink = '',
    this.website = const [],
    this.aboutCompany = '',
    this.youtubeLinks = const [],
    this.existingPhotos = const [],
    this.profileImageName = '',
    this.companyLogoName = '',
    this.qrLink = '',
    this.isSuspended = false,
  });

  factory CardProfileDetails.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    final work = json['work'] as Map<String, dynamic>? ?? {};
    
    // Process list fields
    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      if (val is String && val.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) {
            return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          }
        } catch (_) {}
        return [val.trim()];
      }
      return [];
    }

    List<Map<String, String>> parseWebsites(dynamic val) {
      List<Map<String, String>> result = [];
      if (val is List) {
        for (var item in val) {
          if (item is String) {
            result.add({'name': '', 'url': item});
          } else if (item is Map) {
            result.add({
              'name': item['name']?.toString() ?? '',
              'url': item['url']?.toString() ?? '',
            });
          }
        }
      } else if (val is String && val.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) {
            for (var item in decoded) {
              if (item is String) {
                result.add({'name': '', 'url': item});
              } else if (item is Map) {
                result.add({
                  'name': item['name']?.toString() ?? '',
                  'url': item['url']?.toString() ?? '',
                });
              }
            }
          }
        } catch (_) {}
      }
      return result;
    }

    final companyEmails = parseList(work['email'] ?? work['company_email']);
    final contactNumbers = parseList(work['phone'] ?? work['company_phone']);
    final whatsappNumbers = parseList(work['whatsapp_number']);

    final resolvedCompanyAddress = work['address1']?.toString() ?? work['company_address']?.toString() ?? work['address']?.toString() ?? '';
    final resolvedCompanyPincode = work['pincode']?.toString() ?? work['company_pincode']?.toString() ?? '';
    final resolvedCompanyCityId = work['city_id']?.toString() ?? work['company_city_id']?.toString() ?? '';
    final resolvedCompanyStateId = work['state_id']?.toString() ?? work['company_state_id']?.toString() ?? '';

    return CardProfileDetails(
      firstName: user['first_name']?.toString() ?? '',
      lastName: user['last_name']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
      phone: user['phone']?.toString() ?? user['mobile']?.toString() ?? '',
      gender: user['gender']?.toString() ?? '',
      pincode: user['pincode'] != null ? user['pincode'].toString() : '',
      cityId: user['city_id'] != null ? user['city_id'].toString() : '',
      stateId: user['state_id'] != null ? user['state_id'].toString() : '',
      city: user['city']?.toString() ?? '',
      state: user['state']?.toString() ?? '',
      district: user['district']?.toString() ?? '',
      officeSelected: user['pincode'] != null && user['city_id'] != null,
      address: user['address']?.toString() ?? '',
      companyName: work['company_name']?.toString() ?? '',
      designation: work['designation']?.toString() ?? '',
      companyAddress: resolvedCompanyAddress,
      companyPincode: resolvedCompanyPincode,
      companyCityId: resolvedCompanyCityId,
      companyStateId: resolvedCompanyStateId,
      companyCity: work['city']?.toString() ?? '',
      companyState: work['state']?.toString() ?? '',
      companyDistrict: work['district']?.toString() ?? '',
      companyOfficeSelected: resolvedCompanyPincode.isNotEmpty && resolvedCompanyCityId.isNotEmpty,
      companyEmails: companyEmails,
      contactNumbers: contactNumbers,
      whatsappNumbers: whatsappNumbers,
      fbLink: work['facebook_link']?.toString() ?? '',
      instaLink: work['instagram_link']?.toString() ?? '',
      linkedin: work['linkedin_link']?.toString() ?? '',
      xLink: work['twitter_link']?.toString() ?? '',
      website: parseWebsites(work['website']),
      aboutCompany: work['description']?.toString() ?? '',
      youtubeLinks: parseList(work['youtube_links']).isNotEmpty ? parseList(work['youtube_links']) : const [''],
      existingPhotos: const [], // Loaded later or defaulted
      profileImageName: work['profile_image']?.toString() ?? user['image']?.toString() ?? '',
      companyLogoName: work['logo']?.toString() ?? '',
      qrLink: work['qr_code']?.toString() ?? user['qr_code']?.toString() ?? '',
      isSuspended: work['is_suspended'] == 1 || work['is_suspended'] == true || work['is_suspended'] == '1',
    );
  }

  CardProfileDetails clone() {
    return CardProfileDetails(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      gender: gender,
      pincode: pincode,
      cityId: cityId,
      stateId: stateId,
      city: city,
      state: state,
      district: district,
      officeSelected: officeSelected,
      address: address,
      companyName: companyName,
      designation: designation,
      companyAddress: companyAddress,
      companyPincode: companyPincode,
      companyCityId: companyCityId,
      companyStateId: companyStateId,
      companyCity: companyCity,
      companyState: companyState,
      companyDistrict: companyDistrict,
      companyOfficeSelected: companyOfficeSelected,
      companyEmails: List.from(companyEmails),
      contactNumbers: List.from(contactNumbers),
      whatsappNumbers: List.from(whatsappNumbers),
      fbLink: fbLink,
      instaLink: instaLink,
      linkedin: linkedin,
      xLink: xLink,
      website: website.map((e) => Map<String, String>.from(e)).toList(),
      aboutCompany: aboutCompany,
      youtubeLinks: List.from(youtubeLinks),
      existingPhotos: List.from(existingPhotos),
      profileImageName: profileImageName,
      companyLogoName: companyLogoName,
      qrLink: qrLink,
      isSuspended: isSuspended,
    );
  }
}
