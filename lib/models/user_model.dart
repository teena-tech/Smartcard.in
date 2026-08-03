class UserModel {
  final String? id;
  final String? email;
  final String? phone;
  final String? firstName;
  final String? lastName;
  final int? cardViews;
  final int? contactScans;
  final int? shareCount;
  final String? memberId;
  final int? unreadSupportCount;
  final String? address;
  final String? profileImage;

  // ── Extended registration fields ──────────────────────────
  final String? gender;
  final String? dateOfBirth;
  final String? profession;
  final String? pincode;
  final String? district;
  final String? state;

  String get displayName => "${firstName ?? ''} ${lastName ?? ''}".trim();

  // Alias getters for UI compatibility
  String? get avatarUrl => profileImage;
  String? get fullName => displayName;
  String get initials {
    final first = firstName?.trim() ?? '';
    final last  = lastName?.trim()  ?? '';
    final fi = first.isNotEmpty ? first[0].toUpperCase() : '';
    final li = last.isNotEmpty  ? last[0].toUpperCase()  : '';
    final result = '$fi$li';
    return result.isNotEmpty ? result : '?';
  }

  // Legacy single-char initial (kept for existing code that uses it)
  String get initial => displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

  UserModel({
    this.id,
    this.email,
    this.phone,
    this.firstName,
    this.lastName,
    this.cardViews,
    this.contactScans,
    this.shareCount,
    this.memberId,
    this.unreadSupportCount,
    this.address,
    this.profileImage,
    this.gender,
    this.dateOfBirth,
    this.profession,
    this.pincode,
    this.district,
    this.state,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:                 json['id']?.toString()          ?? json['_id']?.toString(),
      email:              json['email'],
      phone:              json['phone']                   ?? json['mobile'],
      firstName:          json['first_name']              ?? json['name'],
      lastName:           json['last_name'],
      cardViews:          int.tryParse(json['card_views']?.toString() ?? json['views']?.toString() ?? ''),
      contactScans:       int.tryParse(json['contact_scans']?.toString() ?? ''),
      shareCount:         int.tryParse(json['share_count']?.toString() ?? json['shares']?.toString() ?? ''),
      memberId:           json['member_id']?.toString()   ?? json['user_code']?.toString(),
      unreadSupportCount: json['unread_support_count'] as int?,
      address:            json['address']?.toString(),
      profileImage:       json['profile_image']?.toString() ?? json['image']?.toString(),
      gender:             json['gender']?.toString(),
      dateOfBirth:        json['date_of_birth']?.toString() ?? json['dob']?.toString(),
      profession:         json['profession']?.toString()   ?? json['designation']?.toString(),
      pincode:            json['pincode']?.toString()      ?? json['pin_code']?.toString() ?? json['zip']?.toString(),
      district:           json['district']?.toString(),
      state:              json['state']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':                   id,
      'email':                email,
      'phone':                phone,
      'first_name':           firstName,
      'last_name':            lastName,
      'card_views':           cardViews,
      'contact_scans':        contactScans,
      'share_count':          shareCount,
      'member_id':            memberId,
      'unread_support_count': unreadSupportCount,
      'address':              address,
      'profile_image':        profileImage,
      'gender':               gender,
      'date_of_birth':        dateOfBirth,
      'profession':           profession,
      'pincode':              pincode,
      'district':             district,
      'state':                state,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? phone,
    String? firstName,
    String? lastName,
    int?    cardViews,
    int?    contactScans,
    int?    shareCount,
    String? memberId,
    int?    unreadSupportCount,
    String? address,
    String? profileImage,
    String? gender,
    String? dateOfBirth,
    String? profession,
    String? pincode,
    String? district,
    String? state,
  }) {
    return UserModel(
      id:                 id                 ?? this.id,
      email:              email              ?? this.email,
      phone:              phone              ?? this.phone,
      firstName:          firstName          ?? this.firstName,
      lastName:           lastName           ?? this.lastName,
      cardViews:          cardViews          ?? this.cardViews,
      contactScans:       contactScans       ?? this.contactScans,
      shareCount:         shareCount         ?? this.shareCount,
      memberId:           memberId           ?? this.memberId,
      unreadSupportCount: unreadSupportCount ?? this.unreadSupportCount,
      address:            address            ?? this.address,
      profileImage:       profileImage == '' ? '' : (profileImage ?? this.profileImage),
      gender:             gender             ?? this.gender,

      dateOfBirth:        dateOfBirth        ?? this.dateOfBirth,
      profession:         profession         ?? this.profession,
      pincode:            pincode            ?? this.pincode,
      district:           district           ?? this.district,
      state:              state              ?? this.state,
    );
  }
}
