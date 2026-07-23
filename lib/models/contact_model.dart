class ContactModel {
  final String id;
  final String name;
  final String designation;
  final String companyName;
  final String? profileImageInitial;
  final String? companyInitial;
  final String? phone;
  final String? email;
  final String? address;
  final String? website;
  final String? profileImageName;
  final String? companyLogo;
  final String? backgroundImage;
  final String? backgroundColor;
  final String? textColor;
  final String? bgImageColor;
  final dynamic opacity;

  ContactModel({
    required this.id,
    required this.name,
    required this.designation,
    required this.companyName,
    this.profileImageInitial,
    this.companyInitial,
    this.phone,
    this.email,
    this.address,
    this.website,
    this.profileImageName,
    this.companyLogo,
    this.backgroundImage,
    this.backgroundColor,
    this.textColor,
    this.bgImageColor,
    this.opacity,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'designation': designation,
      'companyName': companyName,
      'profileImageInitial': profileImageInitial,
      'companyInitial': companyInitial,
      'phone': phone,
      'email': email,
      'address': address,
      'website': website,
      'profileImageName': profileImageName,
      'companyLogo': companyLogo,
      'backgroundImage': backgroundImage,
      'backgroundColor': backgroundColor,
      'textColor': textColor,
      'bgImageColor': bgImageColor,
      'opacity': opacity,
    };
  }

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? '',
      profileImageInitial: json['profileImageInitial']?.toString(),
      companyInitial: json['companyInitial']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      website: json['website']?.toString(),
      profileImageName: json['profileImageName']?.toString(),
      companyLogo: json['companyLogo']?.toString(),
      backgroundImage: json['backgroundImage']?.toString(),
      backgroundColor: json['backgroundColor']?.toString(),
      textColor: json['textColor']?.toString(),
      bgImageColor: json['bgImageColor']?.toString(),
      opacity: json['opacity'],
    );
  }
}
