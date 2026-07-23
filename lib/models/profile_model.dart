import 'user_model.dart';

class ProfileModel {
  final String? id;
  final String? email;
  final String? phone;
  final String? firstName;
  final String? lastName;
  final String? profileImagePath;
  final String? address;

  ProfileModel({
    this.id,
    this.email,
    this.phone,
    this.firstName,
    this.lastName,
    this.profileImagePath,
    this.address,
  });

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();
  String get displayName => fullName.isEmpty ? 'User' : fullName;
  
  String get initial {
    if (firstName != null && firstName!.isNotEmpty) {
      return firstName![0].toUpperCase();
    }
    return 'U';
  }

  factory ProfileModel.fromUserModel(UserModel user, {String? imagePath}) {
    return ProfileModel(
      id: user.id,
      email: user.email,
      phone: user.phone,
      firstName: user.firstName,
      lastName: user.lastName,
      profileImagePath: imagePath,
      address: user.address,
    );
  }

  ProfileModel copyWith({
    String? id,
    String? email,
    String? phone,
    String? firstName,
    String? lastName,
    String? profileImagePath,
    String? address,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      address: address ?? this.address,
    );
  }
}
