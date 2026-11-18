import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'app_contact.dart';

class ScannedContactModel extends Equatable {
  final String id;
  final String name;
  final String company;
  final String designation;
  final String phone;
  final String? alternativePhone;
  final List<String> additionalPhones; // Extra phones added via merge/multi-scan
  final String? landline;
  final String? whatsApp;
  final String email;
  final String website;
  final String address;
  final String? pinCode;
  final List<String> socialLinks;
  final String? imagePath;
  final String syncStatus; // 'pending' or 'synced'
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? source;

  // Native Device Contact Reference
  final String? deviceContactId;

  // Customization & Web Fields
  final String? profileImage;
  final String? companyLogo;
  final String? district;
  final String? stateName;
  final String? gender;
  final String? contactType;
  
  final String? backgroundImage;
  final String? backgroundColor;
  final String? textColor;
  final String? bgImageColor;
  final String? opacity;

  // Multi-Company Support: Structured list of additional company entries for the same phone number
  final List<Map<String, dynamic>> additionalCompanies;

  // Corporate Lead & Workspace Context
  final bool isCorporate;
  final String? corporateGroup; // e.g. 'Client', 'Partner', 'Vendor'
  final String? corporateDepartment;
  final List<String> corporateTags;
  final String? companyId;

  // System SmartCard Match Fields
  final bool isMatched;
  final String? matchedUserId;
  final int? totalCardsCount;
  final String? primaryDesignation;
  final String? cardUrl;
  final String? matchedProfileImage;
  final List<Map<String, dynamic>>? matchedCards;

  /// Stable unique profile ID across Hive, Firebase, Scan, Contacts, Device sync
  String get profileId => id;
  String get firebaseDocId => id;

  /// Unified source-of-truth definition for whether a contact is a digital Smart Card user
  bool get isSmartCardUser =>
      isMatched ||
      source == 'smart_card' ||
      id.startsWith('matched_') ||
      (cardUrl != null && cardUrl!.trim().isNotEmpty && cardUrl!.trim().toLowerCase() != 'null') ||
      (matchedUserId != null && matchedUserId!.trim().isNotEmpty && matchedUserId!.trim().toLowerCase() != 'null') ||
      (matchedCards != null && matchedCards!.isNotEmpty);

  /// Returns all unique company names associated with this contact
  List<String> get allCompanies {
    final Set<String> comps = {};
    if (company.trim().isNotEmpty) comps.add(company.trim());
    for (final ac in additionalCompanies) {
      final name = ac['company']?.toString().trim();
      if (name != null && name.isNotEmpty) comps.add(name);
    }
    return comps.toList();
  }

  /// Returns all phone numbers associated with this single profile in normalized order
  List<String> get allPhoneNumbers {
    final List<String> list = [];
    final Set<String> seen = {};
    void addP(String? p) {
      if (p == null) return;
      var t = p.trim();
      if (t.contains(':')) {
        t = t.split(':').last.trim();
      }
      if (t.isEmpty) return;
      final clean = t.replaceAll(RegExp(r'\D'), '');
      final key = clean.length >= 7 ? (clean.length >= 10 ? clean.substring(clean.length - 10) : clean) : clean;
      if (seen.add(key.isNotEmpty ? key : t)) {
        list.add(t);
      }
    }
    addP(phone);
    addP(alternativePhone);
    for (final ap in additionalPhones) {
      addP(ap);
    }
    addP(whatsApp);
    addP(landline);
    return list;
  }

  const ScannedContactModel({
    required this.id,
    required this.name,
    required this.company,
    required this.designation,
    required this.phone,
    this.alternativePhone,
    this.additionalPhones = const [],
    this.additionalCompanies = const [],
    this.landline,
    this.whatsApp,
    required this.email,
    required this.website,
    required this.address,
    this.pinCode,
    required this.socialLinks,
    this.imagePath,
    this.syncStatus = 'pending',
    this.isFavorite = false,
    required this.createdAt,
    this.updatedAt,
    this.source,
    this.deviceContactId,
    this.profileImage,
    this.companyLogo,
    this.district,
    this.stateName,
    this.gender,
    this.contactType,
    this.backgroundImage,
    this.backgroundColor,
    this.textColor,
    this.bgImageColor,
    this.opacity,
    this.isCorporate = false,
    this.corporateGroup,
    this.corporateDepartment,
    this.corporateTags = const [],
    this.companyId,
    this.isMatched = false,
    this.matchedUserId,
    this.totalCardsCount,
    this.primaryDesignation,
    this.cardUrl,
    this.matchedProfileImage,
    this.matchedCards,
  });

  ScannedContactModel copyWith({
    String? id,
    String? name,
    String? company,
    String? designation,
    String? phone,
    String? alternativePhone,
    bool clearAlternativePhone = false,
    bool clearCardUrl = false,
    bool clearMatchedUserId = false,
    bool clearMatchedCards = false,
    List<String>? additionalPhones,
    List<Map<String, dynamic>>? additionalCompanies,
    String? landline,
    String? whatsApp,
    String? email,
    String? website,
    String? address,
    String? pinCode,
    List<String>? socialLinks,
    String? imagePath,
    String? syncStatus,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? source,
    String? deviceContactId,
    String? profileImage,
    String? companyLogo,
    String? district,
    String? stateName,
    String? gender,
    String? contactType,
    String? backgroundImage,
    String? backgroundColor,
    String? textColor,
    String? bgImageColor,
    String? opacity,
    bool? isCorporate,
    String? corporateGroup,
    String? corporateDepartment,
    List<String>? corporateTags,
    String? companyId,
    bool? isMatched,
    String? matchedUserId,
    int? totalCardsCount,
    String? primaryDesignation,
    String? cardUrl,
    String? matchedProfileImage,
    List<Map<String, dynamic>>? matchedCards,
  }) {
    return ScannedContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      company: company ?? this.company,
      designation: designation ?? this.designation,
      phone: phone ?? this.phone,
      alternativePhone: clearAlternativePhone ? null : (alternativePhone ?? this.alternativePhone),
      additionalPhones: additionalPhones ?? this.additionalPhones,
      additionalCompanies: additionalCompanies ?? this.additionalCompanies,
      landline: landline ?? this.landline,
      whatsApp: whatsApp ?? this.whatsApp,
      email: email ?? this.email,
      website: website ?? this.website,
      address: address ?? this.address,
      pinCode: pinCode ?? this.pinCode,
      socialLinks: socialLinks ?? this.socialLinks,
      imagePath: imagePath ?? this.imagePath,
      syncStatus: syncStatus ?? this.syncStatus,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt ?? DateTime.now(),
      source: source ?? this.source,
      deviceContactId: deviceContactId ?? this.deviceContactId,
      profileImage: profileImage ?? this.profileImage,
      companyLogo: companyLogo ?? this.companyLogo,
      district: district ?? this.district,
      stateName: stateName ?? this.stateName,
      gender: gender ?? this.gender,
      contactType: contactType ?? this.contactType,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      bgImageColor: bgImageColor ?? this.bgImageColor,
      opacity: opacity ?? this.opacity,
      isCorporate: isCorporate ?? this.isCorporate,
      corporateGroup: corporateGroup ?? this.corporateGroup,
      corporateDepartment: corporateDepartment ?? this.corporateDepartment,
      corporateTags: corporateTags ?? this.corporateTags,
      companyId: companyId ?? this.companyId,
      isMatched: isMatched ?? this.isMatched,
      matchedUserId: clearMatchedUserId ? null : (matchedUserId ?? this.matchedUserId),
      totalCardsCount: totalCardsCount ?? this.totalCardsCount,
      primaryDesignation: primaryDesignation ?? this.primaryDesignation,
      cardUrl: clearCardUrl ? null : (cardUrl ?? this.cardUrl),
      matchedProfileImage: matchedProfileImage ?? this.matchedProfileImage,
      matchedCards: clearMatchedCards ? null : (matchedCards ?? this.matchedCards),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profileId': id,
      'name': name,
      'company': company,
      'designation': designation,
      'phone': phone,
      'alternativePhone': alternativePhone,
      'additionalPhones': additionalPhones,
      'additional_companies': additionalCompanies,
      'additionalCompanies': additionalCompanies,
      'landline': landline,
      'whatsApp': whatsApp,
      'email': email,
      'website': website,
      'address': address,
      'pinCode': pinCode,
      'socialLinks': socialLinks,
      'imagePath': imagePath,
      'syncStatus': syncStatus,
      'sync_status': syncStatus,
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': (updatedAt ?? createdAt).toIso8601String(),
      'updated_at': (updatedAt ?? createdAt).toIso8601String(),
      'source': source,
      'deviceContactId': deviceContactId,
      'device_contact_id': deviceContactId,
      'profileImage': profileImage,
      'companyLogo': companyLogo,
      'district': district,
      'stateName': stateName,
      'gender': gender,
      'contactType': contactType,
      'backgroundImage': backgroundImage,
      'backgroundColor': backgroundColor,
      'textColor': textColor,
      'bgImageColor': bgImageColor,
      'opacity': opacity,
      'isCorporate': isCorporate,
      'is_corporate': isCorporate ? 1 : 0,
      'corporateGroup': corporateGroup,
      'corporate_group': corporateGroup,
      'corporateDepartment': corporateDepartment,
      'corporate_department': corporateDepartment,
      'corporateTags': corporateTags,
      'corporate_tags': corporateTags,
      'companyId': companyId,
      'company_id': companyId,
      'isMatched': isMatched,
      'matchedUserId': matchedUserId,
      'totalCardsCount': totalCardsCount,
      'primaryDesignation': primaryDesignation,
      'cardUrl': cardUrl,
      'matchedProfileImage': matchedProfileImage,
      'matchedCards': matchedCards,
    };
  }

  Map<String, dynamic> toMap() => toJson();
  factory ScannedContactModel.fromMap(Map<String, dynamic> map) => ScannedContactModel.fromJson(map);

  factory ScannedContactModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedAdditionalPhones = [];
    if (json['additionalPhones'] is Iterable) {
      parsedAdditionalPhones = (json['additionalPhones'] as Iterable).map((e) => e.toString()).toList();
    } else if (json['additional_phones'] is Iterable) {
      parsedAdditionalPhones = (json['additional_phones'] as Iterable).map((e) => e.toString()).toList();
    } else if (json['additional_phones'] is String && json['additional_phones'].toString().trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(json['additional_phones'].toString());
        if (decoded is List) parsedAdditionalPhones = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    List<Map<String, dynamic>> parsedAdditionalCompanies = [];
    final rawComps = json['additionalCompanies'] ?? json['additional_companies'];
    if (rawComps is Iterable) {
      parsedAdditionalCompanies = rawComps.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else if (rawComps is String && rawComps.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawComps);
        if (decoded is List) {
          parsedAdditionalCompanies = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
    }
    List<String> parsedSocials = [];
    if (json['socialLinks'] is Iterable) {
      parsedSocials = (json['socialLinks'] as Iterable).map((e) => e.toString()).toList();
    } else if (json['social_links'] is Iterable) {
      parsedSocials = (json['social_links'] as Iterable).map((e) => e.toString()).toList();
    } else if (json['social_links'] is String && json['social_links'].toString().trim().isNotEmpty) {
      parsedSocials = json['social_links'].toString().split(RegExp(r'[\n,]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }

    List<String> parsedCorporateTags = [];
    final rawCorpTags = json['corporateTags'] ?? json['corporate_tags'];
    if (rawCorpTags is Iterable) {
      parsedCorporateTags = rawCorpTags.map((e) => e.toString()).toList();
    } else if (rawCorpTags is String && rawCorpTags.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCorpTags);
        if (decoded is List) parsedCorporateTags = decoded.map((e) => e.toString()).toList();
      } catch (_) {
        parsedCorporateTags = rawCorpTags.split(RegExp(r'[\n,]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
    }

    DateTime parsedDate = DateTime.now();
    final rawDate = json['createdAt'] ?? json['created_at'] ?? json['scanned_at'];
    if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    }

    DateTime? parsedUpdatedDate;
    final rawUpdateDate = json['updatedAt'] ?? json['updated_at'];
    if (rawUpdateDate != null) {
      parsedUpdatedDate = DateTime.tryParse(rawUpdateDate.toString());
    }

    final rawId = json['id'] ?? json['profileId'] ?? json['profile_id'];

    return ScannedContactModel(
      additionalPhones: parsedAdditionalPhones,
      additionalCompanies: parsedAdditionalCompanies,
      id: (rawId != null && rawId.toString().trim().isNotEmpty && rawId.toString().trim() != 'null')
          ? rawId.toString().trim()
          : 'scan_${DateTime.now().microsecondsSinceEpoch}_${(json['phone']?.toString().hashCode ?? 0).abs()}',
      name: json['name']?.toString() ?? '',
      company: json['company']?.toString() ?? json['company_name']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      phone: json['phone']?.toString() ?? (json['phone_numbers'] is List && (json['phone_numbers'] as List).isNotEmpty ? json['phone_numbers'][0].toString() : ''),
      alternativePhone: json['alternativePhone']?.toString() ?? json['alternative_phone']?.toString(),
      landline: json['landline']?.toString(),
      whatsApp: json['whatsApp']?.toString() ?? json['whatsapp']?.toString(),
      email: json['email']?.toString() ?? (json['email_addresses'] is List && (json['email_addresses'] as List).isNotEmpty ? json['email_addresses'][0].toString() : ''),
      website: json['website']?.toString() ?? json['url']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      pinCode: json['pinCode']?.toString() ?? json['pincode']?.toString() ?? json['pin_code']?.toString(),
      socialLinks: parsedSocials,
      imagePath: json['imagePath']?.toString() ?? json['image_path']?.toString(),
      syncStatus: json['syncStatus']?.toString() ?? json['sync_status']?.toString() ?? 'synced',
      isFavorite: json['isFavorite'] == true || json['is_favorite'] == true || json['is_favorite'] == 1,
      createdAt: parsedDate,
      updatedAt: parsedUpdatedDate,
      source: json['source']?.toString() ?? 'scanned',
      deviceContactId: json['deviceContactId']?.toString() ?? json['device_contact_id']?.toString(),
      profileImage: json['profileImage']?.toString() ??
          json['profile_image']?.toString() ??
          json['profile_image_name']?.toString() ??
          json['profileImageName']?.toString() ??
          json['user_image']?.toString() ??
          json['userImage']?.toString() ??
          json['avatar']?.toString(),
      companyLogo: json['companyLogo']?.toString() ?? json['company_logo']?.toString(),
      district: json['district']?.toString(),
      stateName: json['stateName']?.toString() ?? json['state_name']?.toString(),
      gender: json['gender']?.toString(),
      contactType: json['contactType']?.toString() ?? json['contact_type']?.toString(),
      backgroundImage: json['backgroundImage']?.toString() ?? json['background_image']?.toString(),
      backgroundColor: json['backgroundColor']?.toString() ?? json['background_color']?.toString(),
      textColor: json['textColor']?.toString() ?? json['text_color']?.toString(),
      bgImageColor: json['bgImageColor']?.toString() ?? json['bg_image_color']?.toString(),
      opacity: json['opacity']?.toString(),
      isMatched: json['isMatched'] == true || json['is_matched'] == true || json['is_matched'] == 1,
      matchedUserId: json['matchedUserId']?.toString() ?? json['matched_user_id']?.toString() ?? json['userId']?.toString(),
      totalCardsCount: json['totalCardsCount'] != null 
          ? int.tryParse(json['totalCardsCount'].toString()) 
          : (json['total_cards_count'] != null ? int.tryParse(json['total_cards_count'].toString()) : json['cardCount'] as int?),
      primaryDesignation: json['primaryDesignation']?.toString() ?? json['primary_designation']?.toString(),
      cardUrl: json['cardUrl']?.toString() ?? json['card_url']?.toString(),
      matchedProfileImage: json['matchedProfileImage']?.toString() ?? json['matched_profile_image']?.toString(),
      matchedCards: (json['matchedCards'] as Iterable?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ??
          (json['matched_cards'] as Iterable?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ??
          (json['cards'] as Iterable?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      isCorporate: json['isCorporate'] == true || json['is_corporate'] == true || json['is_corporate'] == 1,
      corporateGroup: json['corporateGroup']?.toString() ?? json['corporate_group']?.toString(),
      corporateDepartment: json['corporateDepartment']?.toString() ?? json['corporate_department']?.toString(),
      corporateTags: parsedCorporateTags,
      companyId: json['companyId']?.toString() ?? json['company_id']?.toString(),
    );
  }

  factory ScannedContactModel.fromAppContact(AppContact appContact) {
    String phone = '';
    String? altPhone;
    String email = '';
    String address = '';
    String website = '';
    String company = '';
    String designation = '';
    String? photoBase64;

    try {
      phone = appContact.primaryPhone;
      if (appContact.phones.length > 1) {
        final alts = appContact.phones
            .skip(1)
            .map((p) => p.number.trim())
            .where((n) => n.isNotEmpty)
            .toList();
        if (alts.isNotEmpty) {
          altPhone = alts.join(', ');
        }
      }
      email = appContact.primaryEmail;
      address = appContact.primaryAddress;
      website = appContact.primaryWebsite;
      company = appContact.company ?? '';
      designation = appContact.jobTitle ?? '';

      if (appContact.photo != null && appContact.photo!.isNotEmpty) {
        photoBase64 = 'data:image/jpeg;base64,${base64Encode(appContact.photo!)}';
      }
    } catch (_) {}

    final id = appContact.id.isNotEmpty ? appContact.id : 'device_${DateTime.now().millisecondsSinceEpoch}';
    final displayName = appContact.displayName.isNotEmpty ? appContact.displayName : 'Device Contact';

    return ScannedContactModel(
      id: id,
      name: displayName,
      company: company,
      designation: designation,
      phone: phone,
      alternativePhone: altPhone,
      email: email,
      website: website,
      address: address,
      socialLinks: const [],
      profileImage: photoBase64,
      syncStatus: 'synced',
      isFavorite: appContact.isFavorite,
      createdAt: appContact.createdAt,
      source: 'phone',
      isMatched: false,
      cardUrl: null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        company,
        designation,
        phone,
        alternativePhone,
        additionalPhones,
        additionalCompanies,
        landline,
        whatsApp,
        email,
        website,
        address,
        pinCode,
        socialLinks,
        imagePath,
        syncStatus,
        isFavorite,
        createdAt,
        updatedAt,
        source,
        deviceContactId,
        profileImage,
        companyLogo,
        district,
        stateName,
        gender,
        contactType,
        backgroundImage,
        backgroundColor,
        textColor,
        bgImageColor,
        opacity,
        isMatched,
        matchedUserId,
        totalCardsCount,
        primaryDesignation,
        cardUrl,
        matchedProfileImage,
        matchedCards,
        isCorporate,
        corporateGroup,
        corporateDepartment,
        corporateTags,
        companyId,
      ];
}

