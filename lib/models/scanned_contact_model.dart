import 'package:equatable/equatable.dart';

class ScannedContactModel extends Equatable {
  final String id;
  final String name;
  final String company;
  final String designation;
  final String phone;
  final String? alternativePhone;
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
  final String? source;

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

  const ScannedContactModel({
    required this.id,
    required this.name,
    required this.company,
    required this.designation,
    required this.phone,
    this.alternativePhone,
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
    this.source,
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
  });

  ScannedContactModel copyWith({
    String? id,
    String? name,
    String? company,
    String? designation,
    String? phone,
    String? alternativePhone,
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
    String? source,
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
  }) {
    return ScannedContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      company: company ?? this.company,
      designation: designation ?? this.designation,
      phone: phone ?? this.phone,
      alternativePhone: alternativePhone ?? this.alternativePhone,
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
      source: source ?? this.source,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'company': company,
      'designation': designation,
      'phone': phone,
      'alternativePhone': alternativePhone,
      'landline': landline,
      'whatsApp': whatsApp,
      'email': email,
      'website': website,
      'address': address,
      'pinCode': pinCode,
      'socialLinks': socialLinks,
      'imagePath': imagePath,
      'syncStatus': syncStatus,
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'source': source,
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
    };
  }

  factory ScannedContactModel.fromJson(Map<String, dynamic> json) {
    return ScannedContactModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      company: json['company']?.toString() ?? json['company_name']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['phone_numbers']?.toString() ?? '',
      alternativePhone: json['alternativePhone']?.toString(),
      landline: json['landline']?.toString(),
      whatsApp: json['whatsApp']?.toString(),
      email: json['email']?.toString() ?? json['email_addresses']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      pinCode: json['pinCode']?.toString() ?? json['pincode']?.toString(),
      socialLinks: (json['socialLinks'] as Iterable?)?.map((e) => e.toString()).toList() ?? [],
      imagePath: json['imagePath']?.toString(),
      syncStatus: json['syncStatus']?.toString() ?? 'pending',
      isFavorite: json['isFavorite'] == true,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : (json['scanned_at'] != null ? DateTime.parse(json['scanned_at'].toString()) : DateTime.now()),
      source: json['source']?.toString(),
      profileImage: json['profileImage']?.toString() ?? json['profile_image']?.toString(),
      companyLogo: json['companyLogo']?.toString() ?? json['company_logo']?.toString(),
      district: json['district']?.toString(),
      stateName: json['stateName']?.toString() ?? json['state_name']?.toString(),
      gender: json['gender']?.toString(),
      contactType: json['contactType']?.toString() ?? json['contact_type']?.toString(),
      backgroundImage: json['backgroundImage']?.toString(),
      backgroundColor: json['backgroundColor']?.toString(),
      textColor: json['textColor']?.toString(),
      bgImageColor: json['bgImageColor']?.toString(),
      opacity: json['opacity']?.toString(),
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
        source,
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
      ];
}
