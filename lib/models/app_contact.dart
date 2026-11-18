import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import '../core/utils/safe_base64.dart';

class ContactPhone {
  final String number;
  final String label;
  final bool isPrimary;

  ContactPhone({
    required this.number,
    this.label = 'Mobile',
    this.isPrimary = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'label': label,
      'isPrimary': isPrimary,
    };
  }

  factory ContactPhone.fromMap(Map<String, dynamic> map) {
    return ContactPhone(
      number: map['number'] ?? '',
      label: map['label'] ?? 'Mobile',
      isPrimary: map['isPrimary'] == true || map['isPrimary'] == 1,
    );
  }

  factory ContactPhone.fromDevicePhone(fc.Phone p) {
    String labelStr;
    if (p.label.customLabel != null && p.label.customLabel!.trim().isNotEmpty) {
      labelStr = p.label.customLabel!.trim();
    } else {
      labelStr = _phoneLabelToString(p.label.label);
    }
    return ContactPhone(
      number: p.number,
      label: labelStr.isNotEmpty ? labelStr : 'Mobile',
      isPrimary: p.isPrimary ?? false,
    );
  }

  static String _phoneLabelToString(fc.PhoneLabel label) {
    switch (label) {
      case fc.PhoneLabel.mobile:
        return 'Mobile';
      case fc.PhoneLabel.work:
        return 'Work';
      case fc.PhoneLabel.home:
        return 'Home';
      case fc.PhoneLabel.main:
        return 'Main';
      case fc.PhoneLabel.companyMain:
        return 'Office';
      case fc.PhoneLabel.workMobile:
        return 'Work Mobile';
      case fc.PhoneLabel.workPager:
        return 'Work Pager';
      case fc.PhoneLabel.workFax:
        return 'Fax (Work)';
      case fc.PhoneLabel.homeFax:
        return 'Fax (Home)';
      case fc.PhoneLabel.otherFax:
        return 'Fax (Other)';
      case fc.PhoneLabel.pager:
        return 'Pager';
      case fc.PhoneLabel.assistant:
        return 'Assistant';
      case fc.PhoneLabel.radio:
        return 'Radio';
      case fc.PhoneLabel.mms:
        return 'MMS';
      case fc.PhoneLabel.callback:
        return 'Callback';
      case fc.PhoneLabel.car:
        return 'Car';
      case fc.PhoneLabel.school:
        return 'School';
      case fc.PhoneLabel.isdn:
        return 'ISDN';
      case fc.PhoneLabel.iPhone:
        return 'iPhone';
      case fc.PhoneLabel.telex:
        return 'Telex';
      case fc.PhoneLabel.ttyTdd:
        return 'TTY/TDD';
      case fc.PhoneLabel.appleWatch:
        return 'Apple Watch';
      case fc.PhoneLabel.other:
        return 'Other';
      case fc.PhoneLabel.custom:
        return 'Custom';
    }
  }

  fc.Phone toDevicePhone() {
    fc.PhoneLabel? pl;
    final lbl = label.trim().toLowerCase();
    if (lbl == 'mobile') {
      pl = fc.PhoneLabel.mobile;
    } else if (lbl == 'work') {
      pl = fc.PhoneLabel.work;
    } else if (lbl == 'home') {
      pl = fc.PhoneLabel.home;
    } else if (lbl == 'main') {
      pl = fc.PhoneLabel.main;
    } else if (lbl == 'office') {
      pl = fc.PhoneLabel.companyMain;
    } else if (lbl == 'work mobile') {
      pl = fc.PhoneLabel.workMobile;
    } else if (lbl == 'work pager') {
      pl = fc.PhoneLabel.workPager;
    } else if (lbl == 'fax (work)' || lbl == 'fax work') {
      pl = fc.PhoneLabel.workFax;
    } else if (lbl == 'fax (home)' || lbl == 'fax home') {
      pl = fc.PhoneLabel.homeFax;
    } else if (lbl == 'fax (other)' || lbl == 'fax other') {
      pl = fc.PhoneLabel.otherFax;
    } else if (lbl == 'pager') {
      pl = fc.PhoneLabel.pager;
    } else if (lbl == 'assistant') {
      pl = fc.PhoneLabel.assistant;
    } else if (lbl == 'radio') {
      pl = fc.PhoneLabel.radio;
    } else if (lbl == 'mms') {
      pl = fc.PhoneLabel.mms;
    } else if (lbl == 'callback') {
      pl = fc.PhoneLabel.callback;
    } else if (lbl == 'car') {
      pl = fc.PhoneLabel.car;
    } else if (lbl == 'school') {
      pl = fc.PhoneLabel.school;
    } else if (lbl == 'iphone') {
      pl = fc.PhoneLabel.iPhone;
    } else if (lbl == 'telex') {
      pl = fc.PhoneLabel.telex;
    } else if (lbl == 'tty/tdd') {
      pl = fc.PhoneLabel.ttyTdd;
    } else if (lbl == 'apple watch') {
      pl = fc.PhoneLabel.appleWatch;
    } else if (lbl == 'isdn') {
      pl = fc.PhoneLabel.isdn;
    } else if (lbl == 'other') {
      pl = fc.PhoneLabel.other;
    }

    final fc.Label<fc.PhoneLabel> phoneLabel = pl != null
        ? fc.Label(pl)
        : fc.Label(fc.PhoneLabel.custom, label.trim().isNotEmpty ? label.trim() : 'Mobile');

    return fc.Phone(
      number: number.trim(),
      label: phoneLabel,
      isPrimary: isPrimary,
    );
  }
}

class ContactEmail {
  final String address;
  final String label;

  ContactEmail({required this.address, this.label = 'Home'});

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'label': label,
    };
  }

  factory ContactEmail.fromMap(Map<String, dynamic> map) {
    return ContactEmail(
      address: map['address'] ?? '',
      label: map['label'] ?? 'Home',
    );
  }

  factory ContactEmail.fromDeviceEmail(fc.Email e) {
    return ContactEmail(
      address: e.address,
      label: _emailLabelToString(e.label.label),
    );
  }

  static String _emailLabelToString(fc.EmailLabel label) {
    switch (label) {
      case fc.EmailLabel.work:
        return 'Work';
      case fc.EmailLabel.home:
        return 'Home';
      default:
        return 'Other';
    }
  }

  fc.Email toDeviceEmail() {
    fc.EmailLabel el = fc.EmailLabel.home;
    if (label.toLowerCase() == 'work') el = fc.EmailLabel.work;
    return fc.Email(address: address.trim(), label: fc.Label(el));
  }
}

class ContactWebsite {
  final String url;
  final String label;

  ContactWebsite({required this.url, this.label = 'Homepage'});

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'label': label,
    };
  }

  factory ContactWebsite.fromMap(Map<String, dynamic> map) {
    return ContactWebsite(
      url: map['url'] ?? '',
      label: map['label'] ?? 'Homepage',
    );
  }

  factory ContactWebsite.fromDeviceWebsite(fc.Website w) {
    return ContactWebsite(
      url: w.url,
      label: _websiteLabelToString(w.label.label),
    );
  }

  static String _websiteLabelToString(fc.WebsiteLabel label) {
    switch (label) {
      case fc.WebsiteLabel.work:
        return 'Work';
      case fc.WebsiteLabel.home:
        return 'Home';
      case fc.WebsiteLabel.blog:
        return 'Blog';
      case fc.WebsiteLabel.profile:
        return 'Profile';
      case fc.WebsiteLabel.ftp:
        return 'FTP';
      default:
        return 'Homepage';
    }
  }

  fc.Website toDeviceWebsite() {
    fc.WebsiteLabel wl = fc.WebsiteLabel.homepage;
    if (label.toLowerCase() == 'work') wl = fc.WebsiteLabel.work;
    if (label.toLowerCase() == 'home') wl = fc.WebsiteLabel.home;
    if (label.toLowerCase() == 'blog') wl = fc.WebsiteLabel.blog;
    if (label.toLowerCase() == 'profile') wl = fc.WebsiteLabel.profile;
    return fc.Website(url: url.trim(), label: fc.Label(wl));
  }
}

class ContactAddress {
  final String address;
  final String label;
  final String? street;
  final String? city;
  final String? postalCode;
  final String? country;

  ContactAddress({
    required this.address,
    this.label = 'Home',
    this.street,
    this.city,
    this.postalCode,
    this.country,
  });

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'label': label,
      'street': street,
      'city': city,
      'postal_code': postalCode,
      'country': country,
    };
  }

  /// Sanitizes and deduplicates repeated segments/pincodes inside an address string.
  static String sanitizeAddressString(String? input) {
    if (input == null || input.trim().isEmpty) return '';
    final raw = input.trim();

    final parts = raw.split(RegExp(r'[\n,]'));
    final List<String> cleanTokens = [];
    final Set<String> seen = {};

    for (final p in parts) {
      final token = p.trim();
      if (token.isEmpty) continue;
      final lower = token.toLowerCase();
      if (seen.add(lower)) {
        cleanTokens.add(token);
      }
    }

    if (cleanTokens.isEmpty) return '';
    return cleanTokens.join(', ');
  }

  factory ContactAddress.fromMap(Map<String, dynamic> map) {
    return ContactAddress(
      address: sanitizeAddressString(map['address']?.toString() ?? ''),
      label: map['label']?.toString() ?? 'Home',
      street: map['street']?.toString(),
      city: map['city']?.toString(),
      postalCode: map['postal_code']?.toString(),
      country: map['country']?.toString(),
    );
  }

  factory ContactAddress.fromDeviceAddress(fc.Address a) {
    String formattedAddress = a.formatted?.isNotEmpty ?? false ? a.formatted! : '';

    if (formattedAddress.isEmpty) {
      formattedAddress = [a.street, a.city, a.postalCode, a.country]
          .where((s) => s != null && s.trim().isNotEmpty)
          .join(', ');
    }

    final sanitized = sanitizeAddressString(formattedAddress);

    return ContactAddress(
      address: sanitized,
      label: _addressLabelToString(a.label.label),
      street: a.street,
      city: a.city,
      postalCode: a.postalCode,
      country: a.country,
    );
  }

  static String _addressLabelToString(fc.AddressLabel label) {
    switch (label) {
      case fc.AddressLabel.work:
        return 'Work';
      case fc.AddressLabel.home:
        return 'Home';
      default:
        return 'Other';
    }
  }

  fc.Address toDeviceAddress() {
    fc.AddressLabel al = fc.AddressLabel.home;
    if (label.toLowerCase() == 'work') al = fc.AddressLabel.work;
    final cleanAddr = sanitizeAddressString(address);
    return fc.Address(
      formatted: cleanAddr,
      label: fc.Label(al),
      street: null,
      city: null,
      postalCode: null,
      country: null,
    );
  }
}

class AppContact {
  final String id;
  final String displayName;
  final String? givenName;
  final String? familyName;
  final String? middleName;
  final String? company;
  final String? jobTitle;
  final Uint8List? photo;
  final List<ContactPhone> phones;
  final List<ContactEmail> emails;
  final List<ContactWebsite> websites;
  final List<ContactAddress> addresses;
  final List<String> groupNames;
  final List<String> groupIds;
  final String? notes;
  final bool isFavorite;
  final bool isDeviceContact;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppContact({
    required this.id,
    required this.displayName,
    this.givenName,
    this.familyName,
    this.middleName,
    this.company,
    this.jobTitle,
    this.photo,
    this.phones = const [],
    this.emails = const [],
    this.websites = const [],
    this.addresses = const [],
    this.groupNames = const [],
    this.groupIds = const [],
    this.notes,
    this.isFavorite = false,
    this.isDeviceContact = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get primaryPhone {
    if (phones.isNotEmpty) {
      final primary = phones.firstWhere(
        (p) => p.isPrimary,
        orElse: () => phones.first,
      );
      return primary.number;
    }
    return '';
  }

  String get primaryEmail {
    if (emails.isNotEmpty) {
      return emails.first.address;
    }
    return '';
  }

  String get primaryWebsite {
    if (websites.isNotEmpty) {
      return websites.first.url;
    }
    return '';
  }

  String get primaryAddress {
    if (addresses.isNotEmpty) {
      return addresses.first.address;
    }
    return '';
  }

  String get initials {
    if (displayName.trim().isNotEmpty) {
      final parts = displayName.trim().split(RegExp(r'\s+'));
      if (parts.length == 1) {
        return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
      }
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return '?';
  }

  AppContact copyWith({
    String? id,
    String? displayName,
    String? givenName,
    String? familyName,
    String? middleName,
    String? company,
    String? jobTitle,
    Uint8List? photo,
    bool clearPhoto = false,
    List<ContactPhone>? phones,
    List<ContactEmail>? emails,
    List<ContactWebsite>? websites,
    List<ContactAddress>? addresses,
    List<String>? groupNames,
    List<String>? groupIds,
    String? notes,
    bool? isFavorite,
    bool? isDeviceContact,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppContact(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      givenName: givenName ?? this.givenName,
      familyName: familyName ?? this.familyName,
      middleName: middleName ?? this.middleName,
      company: company ?? this.company,
      jobTitle: jobTitle ?? this.jobTitle,
      photo: clearPhoto ? null : (photo ?? this.photo),
      phones: phones ?? this.phones,
      emails: emails ?? this.emails,
      websites: websites ?? this.websites,
      addresses: addresses ?? this.addresses,
      groupNames: groupNames ?? this.groupNames,
      groupIds: groupIds ?? this.groupIds,
      notes: notes ?? this.notes,
      isFavorite: isFavorite ?? this.isFavorite,
      isDeviceContact: isDeviceContact ?? this.isDeviceContact,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Construct AppContact from native Android flutter_contacts Contact
  factory AppContact.fromDeviceContact(
    fc.Contact deviceContact, {
    bool isFavorite = false,
    List<String> groupNames = const [],
    List<String> groupIds = const [],
    String? localNotes,
  }) {
    final String fullName = (deviceContact.displayName?.isNotEmpty ?? false)
        ? deviceContact.displayName!
        : '${deviceContact.name?.first ?? ''} ${deviceContact.name?.last ?? ''}'.trim();

    String noteText = '';
    if (deviceContact.notes.isNotEmpty) {
      noteText = deviceContact.notes.map((n) => n.note).join('\n');
    }
    if (localNotes != null && localNotes.isNotEmpty) {
      noteText = noteText.isNotEmpty ? '$noteText\n$localNotes' : localNotes;
    }

    return AppContact(
      id: deviceContact.id ?? '',
      displayName: fullName.isNotEmpty ? fullName : 'Unnamed Contact',
      givenName: deviceContact.name?.first,
      familyName: deviceContact.name?.last,
      middleName: deviceContact.name?.middle,
      company: deviceContact.organizations.isNotEmpty
          ? deviceContact.organizations.first.name
          : null,
      jobTitle: deviceContact.organizations.isNotEmpty
          ? deviceContact.organizations.first.jobTitle
          : null,
      photo: deviceContact.photo?.fullSize ?? deviceContact.photo?.thumbnail,
      phones: deviceContact.phones.map((p) => ContactPhone.fromDevicePhone(p)).toList(),
      emails: deviceContact.emails.map((e) => ContactEmail.fromDeviceEmail(e)).toList(),
      websites: deviceContact.websites.map((w) => ContactWebsite.fromDeviceWebsite(w)).toList(),
      addresses: () {
        final List<ContactAddress> list = [];
        final Set<String> seen = {};
        for (final a in deviceContact.addresses) {
          final ca = ContactAddress.fromDeviceAddress(a);
          final clean = ca.address.trim();
          if (clean.isNotEmpty && seen.add(clean.toLowerCase())) {
            list.add(ca);
          }
        }
        return list;
      }(),
      groupNames: groupNames,
      groupIds: groupIds,
      notes: noteText.isNotEmpty ? noteText : null,
      isFavorite: isFavorite,
      isDeviceContact: true,
    );
  }

  /// Convert AppContact to native flutter_contacts Contact with full Android 14/15/16 sanitization
  fc.Contact toDeviceContact({fc.Contact? existing}) {
    final first = givenName?.trim() ?? (displayName.isNotEmpty ? displayName.split(' ').first : '');
    final last = familyName?.trim() ??
        (displayName.split(' ').length > 1
            ? displayName.split(' ').sublist(1).join(' ')
            : '');
    final middle = middleName?.trim() ?? '';

    final comp = company?.trim() ?? '';
    final title = jobTitle?.trim() ?? '';

    final noteStr = notes?.trim() ?? '';

    return fc.Contact(
      id: existing?.id ?? (id.isNotEmpty ? id : null),
      name: fc.Name(
        first: first.isNotEmpty ? first : null,
        last: last.isNotEmpty ? last : null,
        middle: middle.isNotEmpty ? middle : null,
      ),
      organizations: (comp.isNotEmpty || title.isNotEmpty)
          ? [
              fc.Organization(
                name: comp.isNotEmpty ? comp : null,
                jobTitle: title.isNotEmpty ? title : null,
              ),
            ]
          : const [],
      phones: phones
          .where((p) => p.number.trim().isNotEmpty)
          .map((p) => p.toDevicePhone())
          .toList(),
      emails: emails
          .where((e) => e.address.trim().isNotEmpty)
          .map((e) => e.toDeviceEmail())
          .toList(),
      websites: websites
          .where((w) => w.url.trim().isNotEmpty)
          .map((w) => w.toDeviceWebsite())
          .toList(),
      addresses: addresses
          .where((a) => a.address.trim().isNotEmpty || (a.street?.trim().isNotEmpty ?? false))
          .map((a) => a.toDeviceAddress())
          .toList(),
      notes: noteStr.isNotEmpty ? [fc.Note(note: noteStr)] : const [],
      photo: photo != null ? fc.Photo(fullSize: photo) : existing?.photo,
      metadata: existing?.metadata,
    );
  }

  /// Map representation for serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'given_name': givenName,
      'family_name': familyName,
      'middle_name': middleName,
      'company': company,
      'job_title': jobTitle,
      'photo_base64': photo != null ? base64Encode(photo!) : null,
      'phones_json': jsonEncode(phones.map((p) => p.toMap()).toList()),
      'emails_json': jsonEncode(emails.map((e) => e.toMap()).toList()),
      'websites_json': jsonEncode(websites.map((w) => w.toMap()).toList()),
      'addresses_json': jsonEncode(addresses.map((a) => a.toMap()).toList()),
      'group_names_json': jsonEncode(groupNames),
      'group_ids_json': jsonEncode(groupIds),
      'notes': notes,
      'is_favorite': isFavorite ? 1 : 0,
      'is_device_contact': isDeviceContact ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Factory from Map
  factory AppContact.fromMap(Map<String, dynamic> map) {
    Uint8List? photoBytes;
    if (map['photo_base64'] != null && (map['photo_base64'] as String).isNotEmpty) {
      photoBytes = safeBase64Decode(map['photo_base64']);
    }

    List<ContactPhone> phoneList = [];
    if (map['phones_json'] != null) {
      try {
        final decoded = jsonDecode(map['phones_json']) as List;
        phoneList = decoded.map((p) => ContactPhone.fromMap(p)).toList();
      } catch (_) {}
    }

    List<ContactEmail> emailList = [];
    if (map['emails_json'] != null) {
      try {
        final decoded = jsonDecode(map['emails_json']) as List;
        emailList = decoded.map((e) => ContactEmail.fromMap(e)).toList();
      } catch (_) {}
    }

    List<ContactWebsite> websiteList = [];
    if (map['websites_json'] != null) {
      try {
        final decoded = jsonDecode(map['websites_json']) as List;
        websiteList = decoded.map((w) => ContactWebsite.fromMap(w)).toList();
      } catch (_) {}
    }

    List<ContactAddress> addressList = [];
    if (map['addresses_json'] != null) {
      try {
        final decoded = jsonDecode(map['addresses_json']) as List;
        addressList = decoded.map((a) => ContactAddress.fromMap(a)).toList();
      } catch (_) {}
    }

    List<String> groupNames = [];
    if (map['group_names_json'] != null) {
      try {
        groupNames = List<String>.from(jsonDecode(map['group_names_json']));
      } catch (_) {}
    }

    List<String> groupIds = [];
    if (map['group_ids_json'] != null) {
      try {
        groupIds = List<String>.from(jsonDecode(map['group_ids_json']));
      } catch (_) {}
    }

    return AppContact(
      id: map['id'] ?? '',
      displayName: map['display_name'] ?? 'Unnamed Contact',
      givenName: map['given_name'],
      familyName: map['family_name'],
      middleName: map['middle_name'],
      company: map['company'],
      jobTitle: map['job_title'],
      photo: photoBytes,
      phones: phoneList,
      emails: emailList,
      websites: websiteList,
      addresses: addressList,
      groupNames: groupNames,
      groupIds: groupIds,
      notes: map['notes'],
      isFavorite: (map['is_favorite'] == 1),
      isDeviceContact: (map['is_device_contact'] == 1),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
    );
  }
}
