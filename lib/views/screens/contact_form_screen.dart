import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/contact_photo_resolver.dart';
import '../../core/services/contact_saver_service.dart';
import '../../core/utils/avatar_helper.dart';
import '../../core/utils/upload_url_resolver.dart';
import '../../core/database/sqlite_database.dart';
import '../../models/app_contact.dart';
import '../../models/scanned_contact_model.dart';
import '../../providers/contact_provider.dart';
import '../../providers/group_provider.dart';
import '../../viewmodels/contact_viewmodel.dart';
import '../../core/services/contact_photo_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/image_cropper_widget.dart';
import '../widgets/master_app_bar.dart';
import '../widgets/global_bottom_nav.dart';
import '../widgets/genie_hero_route.dart';
import '../widgets/duplicate_field_swipe_widget.dart';

class _PhoneEntry {
  final TextEditingController numberController;
  String label;
  bool isPrimary;

  _PhoneEntry({
    String number = '',
    this.label = 'Mobile',
    this.isPrimary = false,
  }) : numberController = TextEditingController(text: number);

  void dispose() {
    numberController.dispose();
  }
}

class _EmailEntry {
  final TextEditingController emailController;
  String label;
  _EmailEntry({String email = '', this.label = 'Home'})
      : emailController = TextEditingController(text: email);

  void dispose() {
    emailController.dispose();
  }
}

class _WebsiteEntry {
  final TextEditingController urlController;
  String label;
  _WebsiteEntry({String url = '', this.label = 'Homepage'})
      : urlController = TextEditingController(text: url);

  void dispose() {
    urlController.dispose();
  }
}

class _AddressEntry {
  final TextEditingController addressController;
  String label;
  _AddressEntry({String address = '', this.label = 'Home'})
      : addressController = TextEditingController(text: address);

  void dispose() {
    addressController.dispose();
  }
}

class _CompanyEntry {
  final TextEditingController companyController;
  final TextEditingController designationController;

  _CompanyEntry({String company = '', String designation = ''})
      : companyController = TextEditingController(text: company),
        designationController = TextEditingController(text: designation);

  void dispose() {
    companyController.dispose();
    designationController.dispose();
  }
}

class ContactFormScreen extends StatefulWidget {
  final AppContact? contactToEdit;
  final ScannedContactModel? scannedContactToEdit;
  final ScannedContactModel? existingContact;
  final String? cardImagePath;
  final String? heroTag;

  const ContactFormScreen({
    super.key,
    this.contactToEdit,
    this.scannedContactToEdit,
    this.existingContact,
    this.cardImagePath,
    this.heroTag,
  });

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _companyController;
  late TextEditingController _jobTitleController;
  late TextEditingController _notesController;

  final List<_PhoneEntry> _phones = [];
  final List<_EmailEntry> _emails = [];
  final List<_WebsiteEntry> _websites = [];
  final List<_AddressEntry> _addresses = [];
  final Set<String> _selectedGroupIds = {};

  Uint8List? _photoBytes;
  String? _photoUrl;
  bool _isFavorite = false;
  bool _isSaving = false;
  bool _isInitializing = false; // true while async SQLite enrichment is running
  bool get isInitializing => _isInitializing;
  bool _hasUserEdited = false;  // guards against overwriting user edits with late SQLite data

  // Additional companies for multi-company single profile support
  final List<_CompanyEntry> _additionalCompanies = [];

  // Duplicate Phone Detection
  ScannedContactModel? _existingRecord;

  bool _useNewName = true;
  bool _useNewEmail = true;
  bool _useNewWebsite = true;
  bool _useNewAddress = true;

  bool get isEditMode => widget.contactToEdit != null || widget.scannedContactToEdit != null;
  bool get isCardContact =>
      widget.scannedContactToEdit != null ||
      widget.cardImagePath != null ||
      widget.existingContact != null;
  // Duplicate comparison swipe toggle is disabled so form stays as a clean single profile without toggle buttons
  bool get isScanDuplicateEdit => false;

  @override
  void initState() {
    super.initState();
    final contactProvider = context.read<ContactProvider>();
    AppContact? c = widget.contactToEdit;
    ScannedContactModel? sc = widget.scannedContactToEdit;

    final bool isFromScannerDuplicate = widget.existingContact != null && widget.contactToEdit == null;
    _existingRecord = isFromScannerDuplicate ? widget.existingContact : null;

    if (!isFromScannerDuplicate) {
      if (c == null && sc != null) {
        c = contactProvider.findContactByDeviceContactIdOrDetails(
              sc.deviceContactId,
              sc.phone,
              sc.email,
              company: sc.company,
              name: sc.name,
            ) ??
            contactProvider.findContactById(sc.id);
      } else if (sc == null && c != null) {
        final contactVm = context.read<ContactViewModel>();
        final phoneToMatch = c.primaryPhone.trim();
        if (phoneToMatch.isNotEmpty) {
          for (final item in contactVm.allContacts) {
            if (item.phone == phoneToMatch ||
                (phoneToMatch.length >= 10 &&
                    item.phone.endsWith(phoneToMatch.substring(phoneToMatch.length - 10)))) {
              sc = item;
              break;
            }
          }
        }
      }
    }

    String initialFirst = '';
    String initialLast = '';
    String comp = '';
    String job = '';
    String notes = '';

    if (!isFromScannerDuplicate) {
      if (c != null) {
        initialFirst = c.givenName ?? (c.displayName.isNotEmpty ? c.displayName.split(' ').first : '');
        initialLast = c.familyName ?? (c.displayName.split(' ').length > 1 ? c.displayName.split(' ').sublist(1).join(' ') : '');
      } else if (sc != null) {
        final nameParts = sc.name.trim().split(RegExp(r'\s+'));
        initialFirst = nameParts.isNotEmpty ? nameParts.first : '';
        initialLast = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      }

      if (c?.company != null && c!.company!.trim().isNotEmpty) {
        comp = c.company!.trim();
      }
      if (comp.isEmpty && sc?.company != null && sc!.company.trim().isNotEmpty) {
        comp = sc.company.trim();
      }
      if (_isPlaceholderCompany(comp)) {
        comp = '';
      }

      if (c?.jobTitle != null && c!.jobTitle!.trim().isNotEmpty) {
        job = c.jobTitle!.trim();
      }
      if (job.isEmpty && sc?.designation != null && sc!.designation.trim().isNotEmpty) {
        job = sc.designation.trim();
      }
      if (job.isEmpty && sc?.primaryDesignation != null && sc!.primaryDesignation!.trim().isNotEmpty) {
        job = sc.primaryDesignation!.trim();
      }
      if (_isPlaceholderJobTitle(job)) {
        job = '';
      }
      notes = c?.notes ?? '';
    }

    _firstNameController = TextEditingController(text: initialFirst);
    _lastNameController = TextEditingController(text: initialLast);
    _companyController = TextEditingController(text: comp);
    _jobTitleController = TextEditingController(text: job);
    _notesController = TextEditingController(text: notes);

    _photoBytes = c?.photo;
    _isFavorite = c?.isFavorite ?? sc?.isFavorite ?? false;

    final scannedPhotoSource = ContactPhotoResolver.firstValidSource([
      ContactPhotoResolver.resolveScannedPhotoSource(sc),
      ContactPhotoResolver.resolveScannedPhotoSource(widget.existingContact),
    ]);
    _photoUrl = scannedPhotoSource;

    if (widget.cardImagePath != null && widget.cardImagePath!.isNotEmpty && _photoBytes == null) {
      try {
        if (!kIsWeb && File(widget.cardImagePath!).existsSync()) {
          _photoBytes = File(widget.cardImagePath!).readAsBytesSync();
        }
      } catch (e) {
        debugPrint('Error loading cardImagePath bytes: $e');
      }
    } else if (sc?.imagePath != null && sc!.imagePath!.isNotEmpty && _photoBytes == null && !kIsWeb) {
      try {
        final f = File(sc.imagePath!);
        if (f.existsSync()) {
          _photoBytes = f.readAsBytesSync();
        }
      } catch (_) {}
    }

    if (_photoBytes == null && sc != null && scannedPhotoSource != null) {
      ContactSaverService.resolvePhotoBytes(sc).then((bytes) {
        if (bytes != null && bytes.isNotEmpty && mounted && !_hasUserEdited && _photoBytes == null) {
          setState(() {
            _photoBytes = bytes;
          });
        }
      });
    }

    // Phone contact book photo ALWAYS takes priority over smart card user's profile image
    final String? targetId = c?.id ?? sc?.id;
    final String? targetPhone = c?.primaryPhone ?? sc?.phone;

    if (targetPhone != null && targetPhone.trim().isNotEmpty) {
      _loadLiveDevicePhotoForEdit(targetPhone.trim());
    }

    ContactPhotoService.getBestPhoto(contactId: targetId, phone: targetPhone).then((best) {
      if (best != null && best.isNotEmpty && mounted) {
        setState(() {
          _photoBytes = best;
        });
      }
    });

    if (c != null && c.groupIds.isNotEmpty) {
      _selectedGroupIds.addAll(c.groupIds);
    }

    // Initialize phones — from device contact (AppContact) or scanned model
    if (isFromScannerDuplicate) {
      final phoneToKeep = widget.scannedContactToEdit?.phone.trim().isNotEmpty == true
          ? widget.scannedContactToEdit!.phone.trim()
          : (widget.existingContact?.phone.trim() ?? '');
      if (phoneToKeep.isNotEmpty) {
        _phones.add(_PhoneEntry(number: phoneToKeep, label: 'Mobile', isPrimary: true));
      }
    } else {
      AppContact? linkedDevContact;
      if (c == null && sc != null) {
        try {
          final cp = context.read<ContactProvider>();
          linkedDevContact = cp.findContactById(sc.id) ??
              cp.findContactByPhoneOrEmail(sc.phone, sc.email, name: sc.name);
        } catch (_) {}
      }

      final effectiveAppContact = c ?? linkedDevContact;

      if (effectiveAppContact != null && effectiveAppContact.phones.isNotEmpty) {
        for (final p in effectiveAppContact.phones) {
          _phones.add(_PhoneEntry(
            number: p.number,
            label: p.label,
            isPrimary: p.isPrimary,
          ));
        }
      } else if (sc != null) {
        if (sc.phone.isNotEmpty) {
          _phones.add(_PhoneEntry(number: sc.phone, label: 'Mobile', isPrimary: true));
        }
        if (sc.alternativePhone != null && sc.alternativePhone!.isNotEmpty) {
          final alt = sc.alternativePhone!.trim();
          if (alt.contains(':') && !alt.startsWith('http')) {
            final parts = alt.split(':');
            _phones.add(_PhoneEntry(number: parts.sublist(1).join(':').trim(), label: parts[0].trim()));
          } else {
            _phones.add(_PhoneEntry(number: alt, label: 'Home'));
          }
        }
        // Show additional merged phones (from multi-scan merge or device import)
        for (final extra in sc.additionalPhones) {
          if (extra.isNotEmpty) {
            if (extra.contains(':') && !extra.startsWith('http')) {
              final parts = extra.split(':');
              final num = parts.sublist(1).join(':').trim();
              final lbl = parts[0].trim();
              if (num != sc.phone && num != sc.alternativePhone) {
                _phones.add(_PhoneEntry(number: num, label: lbl.isNotEmpty ? lbl : 'Work'));
              }
            } else if (extra != sc.phone && extra != sc.alternativePhone) {
              _phones.add(_PhoneEntry(number: extra, label: 'Work'));
            }
          }
        }
        if (sc.whatsApp != null && sc.whatsApp!.isNotEmpty && sc.whatsApp != sc.phone) {
          _phones.add(_PhoneEntry(number: sc.whatsApp!, label: 'WhatsApp'));
        }
        if (sc.landline != null && sc.landline!.isNotEmpty) {
          _phones.add(_PhoneEntry(number: sc.landline!, label: 'Landline'));
        }
      }
    }

    if (_phones.isEmpty) {
      _phones.add(_PhoneEntry(isPrimary: true));
    }

    // Guarantee at least one phone is marked primary
    if (_phones.isNotEmpty && !_phones.any((p) => p.isPrimary)) {
      _phones.first.isPrimary = true;
    }

    if (!isFromScannerDuplicate) {
      // Initialize emails
      if (c != null && c.emails.isNotEmpty) {
        for (final e in c.emails) {
          _emails.add(_EmailEntry(email: e.address, label: e.label));
        }
      } else if (sc != null && sc.email.isNotEmpty) {
        _emails.add(_EmailEntry(email: sc.email, label: 'Work'));
      }

      // Initialize websites
      if (c != null && c.websites.isNotEmpty) {
        for (final w in c.websites) {
          _websites.add(_WebsiteEntry(url: w.url, label: w.label));
        }
      } else if (sc != null && sc.website.isNotEmpty) {
        _websites.add(_WebsiteEntry(url: sc.website, label: 'Work'));
      }

      // Initialize addresses
      if (c != null && c.addresses.isNotEmpty) {
        final seen = <String>{};
        for (final a in c.addresses) {
          final clean = ContactAddress.sanitizeAddressString(a.address);
          if (clean.isNotEmpty && seen.add(clean.toLowerCase())) {
            _addresses.add(_AddressEntry(address: clean, label: a.label));
          }
        }
      } else if (sc != null && sc.address.isNotEmpty) {
        final clean = ContactAddress.sanitizeAddressString(sc.address);
        if (clean.isNotEmpty) {
          _addresses.add(_AddressEntry(address: clean, label: 'Work'));
        }
      }

      // Initialize additional companies for this profile
      if (sc != null) {
        for (final ac in sc.additionalCompanies) {
          final cName = ac['company']?.toString().trim() ?? '';
          final cDesig = ac['designation']?.toString().trim() ?? '';
          if (cName.isNotEmpty && cName.toLowerCase() != comp.toLowerCase() &&
              !_additionalCompanies.any((e) => e.companyController.text.trim().toLowerCase() == cName.toLowerCase())) {
            _additionalCompanies.add(_CompanyEntry(company: cName, designation: cDesig));
          }
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().loadGroups();

      // Async enrichment: fetch full SQLite record if the passed model is thin
      // (i.e., scannedContactToEdit has no email/address/website populated)
      final sc = widget.scannedContactToEdit;
      if (!isFromScannerDuplicate && sc != null && widget.contactToEdit == null) {
        final isThin = sc.email.isEmpty && sc.address.isEmpty && sc.website.isEmpty
            && sc.alternativePhone == null && sc.additionalPhones.isEmpty;
        if (isThin && sc.id.isNotEmpty) {
          _enrichFromSqlite(sc);
        }
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _companyController.dispose();
    _jobTitleController.dispose();
    _notesController.dispose();
    for (final p in _phones) {
      p.dispose();
    }
    for (final e in _emails) {
      e.dispose();
    }
    for (final w in _websites) {
      w.dispose();
    }
    for (final a in _addresses) {
      a.dispose();
    }
    for (final c in _additionalCompanies) {
      c.dispose();
    }
    super.dispose();
  }

  /// Enriches the edit form with a full contact record fetched from SQLite.
  /// Only fills in fields that are currently empty, and only if the user has not
  /// started editing yet (guarded by [_hasUserEdited]).
  Future<void> _enrichFromSqlite(ScannedContactModel thin) async {
    if (!mounted) return;
    setState(() => _isInitializing = true);

    try {
      final full = await SqliteDatabase.getContactByIdOrPhone(
        thin.id,
        phone: thin.phone.isNotEmpty ? thin.phone : null,
      );

      if (!mounted || full == null || _hasUserEdited) return;

      // Enrich name fields
      if (_firstNameController.text.trim().isEmpty && full.name.isNotEmpty) {
        final parts = full.name.trim().split(RegExp(r'\s+'));
        _firstNameController.text = parts.first;
        if (parts.length > 1) _lastNameController.text = parts.sublist(1).join(' ');
      }

      // Enrich company / job title / notes
      if (_companyController.text.trim().isEmpty && full.company.isNotEmpty) {
        _companyController.text = full.company;
      }
      if (_jobTitleController.text.trim().isEmpty && full.designation.isNotEmpty) {
        _jobTitleController.text = full.designation;
      }

      // Add missing emails
      final existingEmails = _emails.map((e) => e.emailController.text.trim().toLowerCase()).toSet();
      if (full.email.isNotEmpty && !existingEmails.contains(full.email.trim().toLowerCase())) {
        _emails.add(_EmailEntry(email: full.email, label: 'Work'));
      }

      // Add missing websites
      final existingUrls = _websites.map((w) => w.urlController.text.trim().toLowerCase()).toSet();
      if (full.website.isNotEmpty && !existingUrls.contains(full.website.trim().toLowerCase())) {
        _websites.add(_WebsiteEntry(url: full.website, label: 'Work'));
      }

      // Add missing addresses
      final existingAddrs = _addresses.map((a) => a.addressController.text.trim().toLowerCase()).toSet();
      if (full.address.isNotEmpty) {
        final clean = ContactAddress.sanitizeAddressString(full.address);
        if (clean.isNotEmpty && !existingAddrs.contains(clean.toLowerCase())) {
          _addresses.add(_AddressEntry(address: clean, label: 'Work'));
        }
      }

      // Add missing additional phones
      final existingNums = _phones.map((p) => p.numberController.text.replaceAll(RegExp(r'\D'), '')).toSet();
      for (final extra in full.additionalPhones) {
        final digits = extra.replaceAll(RegExp(r'\D'), '');
        if (digits.isNotEmpty && !existingNums.contains(digits)) {
          _phones.add(_PhoneEntry(number: extra, label: 'Other'));
          existingNums.add(digits);
        }
      }
      if (full.alternativePhone != null && full.alternativePhone!.isNotEmpty) {
        final altDigits = full.alternativePhone!.replaceAll(RegExp(r'\D'), '');
        if (!existingNums.contains(altDigits)) {
          _phones.add(_PhoneEntry(number: full.alternativePhone!, label: 'Alternative'));
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('_enrichFromSqlite error: $e');
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  bool _isPlaceholderCompany(String text) {
    final clean = text.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    if (clean.isEmpty) return true;
    return clean == 'unknown company' ||
        clean == 'unknown' ||
        clean == 'unknown organization' ||
        clean == 'unknown corp' ||
        clean == 'unknown corporation' ||
        clean == 'n a' ||
        clean == 'na' ||
        clean == 'none' ||
        clean == 'not available' ||
        clean == 'not specified' ||
        clean == 'company' ||
        clean == 'organization' ||
        clean.contains('unknown company') ||
        clean.contains('unknown organization');
  }

  bool _isPlaceholderJobTitle(String text) {
    final clean = text.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    if (clean.isEmpty) return true;
    return clean == 'professional' ||
        clean == 'profession' ||
        clean == 'unknown' ||
        clean == 'unknown designation' ||
        clean == 'unknown job title' ||
        clean == 'unknown job' ||
        clean == 'n a' ||
        clean == 'na' ||
        clean == 'none' ||
        clean == 'not available' ||
        clean == 'not specified' ||
        clean == 'job title' ||
        clean == 'designation' ||
        clean == 'title' ||
        clean.contains('professional') ||
        clean.contains('profession');
  }

  Widget _buildFormInitial(double width, double height) {
    final name = _firstNameController.text.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final gradient = AvatarHelper.getGradient(name.isNotEmpty ? name : 'New Contact');

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 64,
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1440,
        maxHeight: 1440,
        imageQuality: 98,
      );
      if (picked != null) {
        CroppedFile? cropped;
        try {
          cropped = await ImageCropperHelper.cropProfileImage(
            picked.path,
            context: context,
          );
        } catch (_) {}

        final imageFile = cropped != null ? File(cropped.path) : File(picked.path);
        final bytes = await imageFile.readAsBytes();
        if (mounted) {
          setState(() {
            _photoBytes = bytes;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _loadLiveDevicePhotoForEdit(String phone) {
    if (kIsWeb) return;
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return;
    final p10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    if (p10.length < 7) return;

    Future(() async {
      try {
        final contactProvider = context.read<ContactProvider>();
        for (final appC in contactProvider.contacts) {
          if (appC.photo != null && appC.photo!.isNotEmpty) {
            final matchFound = appC.phones.any((p) {
              final pClean = p.number.replaceAll(RegExp(r'\D'), '');
              final cp10 = pClean.length >= 10 ? pClean.substring(pClean.length - 10) : pClean;
              return cp10.length >= 7 && (cp10 == p10 || pClean.endsWith(p10) || cleanPhone.endsWith(cp10));
            });
            if (matchFound) {
              if (mounted) {
                setState(() {
                  _photoBytes = appC.photo;
                });
              }
              return;
            }
          }
        }

        final status = await Permission.contacts.status;
        if (!status.isGranted && !status.isLimited) return;

        final matches = await fc.FlutterContacts.getAll(
          properties: {
            fc.ContactProperty.name,
            fc.ContactProperty.phone,
          },
        );
        for (final c in matches) {
          final matchFound = c.phones.any((p) {
            final pClean = p.number.replaceAll(RegExp(r'\D'), '');
            final cp10 = pClean.length >= 10 ? pClean.substring(pClean.length - 10) : pClean;
            return cp10.length >= 7 && (cp10 == p10 || pClean.endsWith(p10) || cleanPhone.endsWith(cp10));
          });
          if (matchFound && c.id != null) {
            final devContact = await fc.FlutterContacts.get(
              c.id!,
              properties: fc.ContactProperties.all,
            );
            final bytes = devContact?.photo?.fullSize ?? devContact?.photo?.thumbnail;
            if (bytes != null && bytes.isNotEmpty && mounted) {
              setState(() {
                _photoBytes = bytes;
              });
            }
            break;
          }
        }
      } catch (e) {
        debugPrint('Error loading device photo for edit: $e');
      }
    });
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF4285F4), Color(0xFF9B72CF), Color(0xFFD96570)],
                    ).createShader(bounds),
                    child: const Icon(Icons.auto_awesome_rounded, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Profile Photo',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF4285F4)),
                ),
                title: Text('Take a Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B72CF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF9B72CF)),
                ),
                title: Text('Choose from Gallery', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_photoBytes != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.deleteRed),
                  ),
                  title: Text('Remove Photo', style: GoogleFonts.inter(color: AppColors.deleteRed, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _photoBytes = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickCreateGroupDialog() {
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Create Group', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: textController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. Family, Office, Friends',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (val) => val == null || val.trim().isEmpty ? 'Enter group name' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final name = textController.text.trim();
                Navigator.pop(ctx);
                final groupProvider = context.read<GroupProvider>();
                final created = await groupProvider.createGroup(name);
                if (created?.id != null) {
                  setState(() {
                    _selectedGroupIds.add(created!.id!);
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DUPLICATE DIALOG (shown when new contact matches an existing one)
  // ---------------------------------------------------------------------------

  Future<_FormDuplicateAction> _showDuplicateDialog(
    ScannedContactModel existing,
    ScannedContactModel incoming,
  ) async {
    final result = await showDialog<_FormDuplicateAction>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
              child: Icon(Icons.person_search_rounded, color: Colors.orange.shade700, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Contact Already Exists', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${existing.name}" already exists with a matching phone or email.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            if (incoming.phone.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.phone_rounded, size: 14, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 6),
                Flexible(child: Text(incoming.phone, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
            ],
            const SizedBox(height: 14),
            const Text('What would you like to do?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _FormDuplicateAction.cancel),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, _FormDuplicateAction.saveAnyway),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCC0000)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Anyway', style: TextStyle(color: Color(0xFFCC0000))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _FormDuplicateAction.merge),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCC0000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Merge'),
          ),
        ],
      ),
    );
    return result ?? _FormDuplicateAction.cancel;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final company = _companyController.text.trim();
    final jobTitle = _jobTitleController.text.trim();
    final notes = _notesController.text.trim();

    if (first.isEmpty && last.isEmpty && company.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least a name or company'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final displayName = [first, last].where((s) => s.isNotEmpty).join(' ');
    final finalName = displayName.isNotEmpty ? displayName : company;

    // Collect phones with non-empty sanitization
    final List<ContactPhone> phoneList = [];
    for (final p in _phones) {
      final num = p.numberController.text.trim();
      if (num.isNotEmpty) {
        phoneList.add(ContactPhone(
          number: num,
          label: p.label,
          isPrimary: p.isPrimary,
        ));
      }
    }

    // Collect emails with non-empty sanitization
    final List<ContactEmail> emailList = [];
    for (final e in _emails) {
      final mail = e.emailController.text.trim();
      if (mail.isNotEmpty) {
        emailList.add(ContactEmail(address: mail, label: e.label));
      }
    }

    // Collect websites with non-empty sanitization
    final List<ContactWebsite> websiteList = [];
    for (final w in _websites) {
      final url = w.urlController.text.trim();
      if (url.isNotEmpty) {
        websiteList.add(ContactWebsite(url: url, label: w.label));
      }
    }

    // Collect addresses with non-empty sanitization and deduplication
    final List<ContactAddress> addressList = [];
    final Set<String> seenAddrs = {};
    for (final a in _addresses) {
      final addr = ContactAddress.sanitizeAddressString(a.addressController.text);
      if (addr.isNotEmpty && seenAddrs.add(addr.toLowerCase())) {
        addressList.add(ContactAddress(address: addr, label: a.label));
      }
    }

    setState(() => _isSaving = true);

    final provider = context.read<ContactProvider>();
    final groupProvider = context.read<GroupProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (isEditMode) {
      if (widget.contactToEdit != null) {
        final updated = widget.contactToEdit!.copyWith(
          displayName: finalName,
          givenName: first.isNotEmpty ? first : null,
          familyName: last.isNotEmpty ? last : null,
          company: company.isNotEmpty ? company : null,
          jobTitle: jobTitle.isNotEmpty ? jobTitle : null,
          photo: _photoBytes,
          clearPhoto: _photoBytes == null,
          phones: phoneList,
          emails: emailList,
          websites: websiteList,
          addresses: addressList,
          notes: notes.isNotEmpty ? notes : null,
          isFavorite: _isFavorite,
        );

        final result = await provider.updateContact(
          updated,
          newGroupIds: _selectedGroupIds.toList(),
          previousGroupIds: widget.contactToEdit?.groupIds,
        );

        // Simultaneously sync edits to ContactViewModel (SQLite + Live Backend)
        final contactVm = context.read<ContactViewModel>();
        String? photoString;
        if (_photoBytes != null) {
          photoString = 'data:image/jpeg;base64,${base64Encode(_photoBytes!)}';
        } else if (_photoUrl != null && _photoUrl!.isNotEmpty) {
          photoString = _photoUrl;
        }

        final mainPhone = phoneList.firstWhere(
          (p) => p.isPrimary,
          orElse: () => phoneList.isNotEmpty ? phoneList.first : ContactPhone(number: ''),
        );
        final otherPhoneList = phoneList.where((p) => p != mainPhone).toList();
        final altPhone = otherPhoneList.isNotEmpty ? otherPhoneList.first.number : null;
        final extraPhones = otherPhoneList.length > 1
            ? otherPhoneList.skip(1).map((p) => '${p.label}:${p.number}').toList()
            : <String>[];

        // Collect all companies for this single profile
        final List<Map<String, dynamic>> appContactCompanies = [];
        for (final entry in _additionalCompanies) {
          final cName = entry.companyController.text.trim();
          final cDesig = entry.designationController.text.trim();
          if (cName.isNotEmpty && cName.toLowerCase() != company.toLowerCase()) {
            appContactCompanies.add({
              'company': cName,
              'designation': cDesig,
            });
          }
        }

        final syncedScanned = ScannedContactModel(
          id: widget.contactToEdit!.id,
          name: finalName,
          company: company,
          designation: jobTitle,
          additionalCompanies: appContactCompanies,
          phone: mainPhone.number,
          alternativePhone: altPhone,
          additionalPhones: extraPhones,
          email: emailList.isNotEmpty ? emailList.first.address : '',
          website: websiteList.isNotEmpty ? websiteList.first.url : '',
          address: addressList.isNotEmpty ? addressList.first.address : '',
          profileImage: photoString,
          socialLinks: const [],
          isFavorite: _isFavorite,
          createdAt: DateTime.now(),
        );

        await contactVm.addScannedContact(syncedScanned);
        if (mounted) setState(() => _isSaving = false);

        if (result != null) {
          await groupProvider.loadGroups();
          messenger.showSnackBar(
            SnackBar(
              content: Text('${result.displayName} updated in phone contacts'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          navigator.pop(result);
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Failed to update contact in Android Contacts Provider'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (widget.scannedContactToEdit != null) {
        final sc = widget.scannedContactToEdit!;

        String? photoString;
        if (_photoBytes != null && _photoBytes!.isNotEmpty) {
          photoString = 'data:image/jpeg;base64,${base64Encode(_photoBytes!)}';
        } else {
          photoString = ContactPhotoResolver.firstValidSource([
            _photoUrl,
            ContactPhotoResolver.resolveScannedPhotoSource(sc),
          ]);
        }

        final mainPhone = phoneList.firstWhere(
          (p) => p.isPrimary,
          orElse: () => phoneList.isNotEmpty ? phoneList.first : ContactPhone(number: ''),
        );
        final otherPhoneList = phoneList.where((p) => p != mainPhone).toList();
        final altPhone = otherPhoneList.isNotEmpty ? otherPhoneList.first.number : null;
        final extraPhones = otherPhoneList.length > 1
            ? otherPhoneList.skip(1).map((p) => '${p.label}:${p.number}').toList()
            : <String>[];

        final contactVm = context.read<ContactViewModel>();
        final bool isDuplicateSave = widget.existingContact != null;
        final String profileId = isDuplicateSave
            ? 'scan_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}'
            : ((sc.id.trim().isNotEmpty && sc.id != 'null')
                ? sc.id
                : 'scan_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}');

        // If saving a new profile for a second company with same phone, also add to device contacts
        String? createdDeviceContactId;
        if (isDuplicateSave) {
          final devicePhotoBytes = _photoBytes ??
              await ContactSaverService.resolvePhotoBytes(
                sc.copyWith(profileImage: photoString ?? sc.profileImage),
              );
          final newAppContact = AppContact(
            id: '',
            displayName: finalName,
            givenName: first.isNotEmpty ? first : null,
            familyName: last.isNotEmpty ? last : null,
            company: company.isNotEmpty ? company : null,
            jobTitle: jobTitle.isNotEmpty ? jobTitle : null,
            photo: devicePhotoBytes,
            phones: phoneList,
            emails: emailList,
            websites: websiteList,
            addresses: addressList,
            notes: notes.isNotEmpty ? notes : null,
            isFavorite: _isFavorite,
          );
          final res = await provider.addContact(newAppContact);
          createdDeviceContactId = res?.id;
        }

        // Collect all companies for this profile
        final List<Map<String, dynamic>> compiledAdditionalCompanies = [];
        for (final entry in _additionalCompanies) {
          final cName = entry.companyController.text.trim();
          final cDesig = entry.designationController.text.trim();
          if (cName.isNotEmpty && cName.toLowerCase() != company.toLowerCase()) {
            compiledAdditionalCompanies.add({
              'company': cName,
              'designation': cDesig,
            });
          }
        }

        final updatedScanned = sc.copyWith(
          id: profileId,
          deviceContactId: createdDeviceContactId ?? sc.deviceContactId,
          name: finalName,
          company: company,
          designation: jobTitle,
          additionalCompanies: compiledAdditionalCompanies,
          phone: mainPhone.number,
          alternativePhone: altPhone,
          additionalPhones: extraPhones,
          email: emailList.isNotEmpty ? emailList.first.address : '',
          website: websiteList.isNotEmpty ? websiteList.first.url : '',
          address: addressList.isNotEmpty ? addressList.first.address : '',
          profileImage: photoString,
          isFavorite: _isFavorite,
          updatedAt: DateTime.now(),
        );

        ScannedContactModel? savedResult;
        if (isDuplicateSave) {
          await contactVm.addScannedContact(updatedScanned);
          savedResult = updatedScanned;
        } else {
          savedResult = await contactVm.saveOrUpdateProfile(updatedScanned);
        }

        // Immediately update provider so Contact screen & native contacts reflect changes without restart
        await provider.syncWithDevice(silent: true);
        await groupProvider.loadGroups();

        if (mounted) setState(() => _isSaving = false);

        messenger.showSnackBar(
          SnackBar(
            content: Text('$finalName saved successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        navigator.pop(savedResult);
      }
    } else {
      // ─── NEW CONTACT PATH ───────────────────────────────────────────────────────
      // Before saving a fresh scanned contact, check for duplicates
      final contactVm = context.read<ContactViewModel>();
      final firstPhone = phoneList.isNotEmpty ? phoneList.first.number : '';
      final firstEmail = emailList.isNotEmpty ? emailList.first.address : '';

      final tempCheck = ScannedContactModel(
        id: '',
        name: finalName,
        company: company,
        designation: jobTitle,
        phone: firstPhone,
        email: firstEmail,
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      final duplicate = contactVm.findDuplicate(tempCheck);
      if (duplicate != null && mounted) {
        setState(() => _isSaving = false);
        final action = await _showDuplicateDialog(duplicate, tempCheck);
        if (!mounted) return;

        if (action == _FormDuplicateAction.merge) {
          await contactVm.mergeScannedContact(duplicate, tempCheck);
          messenger.showSnackBar(
            SnackBar(
              content: Text('Merged with existing contact: ${duplicate.name}'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          navigator.pop(null);
          return;
        } else if (action == _FormDuplicateAction.cancel) {
          return; // Stay on form
        }
        // _FormDuplicateAction.saveAnyway — fall through to normal save
        setState(() => _isSaving = true);
      }
      final newContact = AppContact(
        id: '',
        displayName: finalName,
        givenName: first.isNotEmpty ? first : null,
        familyName: last.isNotEmpty ? last : null,
        company: company.isNotEmpty ? company : null,
        jobTitle: jobTitle.isNotEmpty ? jobTitle : null,
        photo: _photoBytes,
        phones: phoneList,
        emails: emailList,
        websites: websiteList,
        addresses: addressList,
        notes: notes.isNotEmpty ? notes : null,
        isFavorite: _isFavorite,
      );

      final result = await provider.addContact(
        newContact,
        assignGroupIds: _selectedGroupIds.toList(),
      );
      if (mounted) setState(() => _isSaving = false);

      if (result != null) {
        final List<Map<String, dynamic>> compiledAdditionalCompanies = [];
        for (final entry in _additionalCompanies) {
          final cName = entry.companyController.text.trim();
          final cDesig = entry.designationController.text.trim();
          if (cName.isNotEmpty && cName.toLowerCase() != company.toLowerCase()) {
            compiledAdditionalCompanies.add({
              'company': cName,
              'designation': cDesig,
            });
          }
        }
        if (compiledAdditionalCompanies.isNotEmpty || isCardContact) {
          final sc = ScannedContactModel(
            id: result.id,
            name: finalName,
            company: company,
            designation: jobTitle,
            additionalCompanies: compiledAdditionalCompanies,
            phone: firstPhone,
            email: firstEmail,
            website: websiteList.isNotEmpty ? websiteList.first.url : '',
            address: addressList.isNotEmpty ? addressList.first.address : '',
            profileImage: _photoBytes != null && _photoBytes!.isNotEmpty
                ? 'data:image/jpeg;base64,${base64Encode(_photoBytes!)}'
                : _photoUrl,
            socialLinks: const [],
            isFavorite: _isFavorite,
            createdAt: DateTime.now(),
          );
          await contactVm.addScannedContact(sc);
        }
        await groupProvider.loadGroups();
        messenger.showSnackBar(
          SnackBar(
            content: Text('${result.displayName} added to phone contacts'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        navigator.pop(result);
      } else {
        // Fallback for desktop/local when device contacts provider returns null
        final fallbackId = 'contact_${DateTime.now().millisecondsSinceEpoch}';
        final sc = ScannedContactModel(
          id: fallbackId,
          name: finalName,
          company: company,
          designation: jobTitle,
          phone: firstPhone,
          email: firstEmail,
          website: websiteList.isNotEmpty ? websiteList.first.url : '',
          address: addressList.isNotEmpty ? addressList.first.address : '',
          profileImage: _photoBytes != null && _photoBytes!.isNotEmpty
              ? 'data:image/jpeg;base64,${base64Encode(_photoBytes!)}'
              : _photoUrl,
          socialLinks: const [],
          isFavorite: _isFavorite,
          createdAt: DateTime.now(),
        );
        await contactVm.addScannedContact(sc);
        await groupProvider.loadGroups();
        messenger.showSnackBar(
          SnackBar(
            content: Text('$finalName saved successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        navigator.pop(sc);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupProvider = context.watch<GroupProvider>();

    return Scaffold(
      appBar: MasterAppBar(
        titleText: isEditMode ? 'Edit Contact' : 'New Contact',
        showBackButton: true,
        extraActions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _isFavorite ? AppColors.favoriteGold : Colors.white,
            ),
            tooltip: _isFavorite ? 'Unmark Favorite' : 'Mark as Favorite',
            onPressed: () {
              setState(() {
                _isFavorite = !_isFavorite;
              });
            },
          ),
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : Container(
                  margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626), // RED BG
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Save',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
        ],
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16.0),
              children: [
            // Large Rounded Rectangular Profile Image Card with Genie Hero Effect
            Builder(
              builder: (ctx) {
                final String targetId = widget.contactToEdit?.id ?? widget.scannedContactToEdit?.id ?? '';
                final String effectiveHeroTag = widget.heroTag ?? (targetId.isNotEmpty ? 'profile_$targetId' : 'new_contact_hero');
                final screenWidth = MediaQuery.of(ctx).size.width;
                final rectWidth = (screenWidth * 0.86).clamp(260.0, 360.0);
                const double rectHeight = 220.0;

                return Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Hero(
                        tag: effectiveHeroTag,
                        createRectTween: (begin, end) => GenieRectTween(begin: begin, end: end),
                        flightShuttleBuilder: genieFlightShuttleBuilder,
                        child: Material(
                          color: Colors.transparent,
                          child: GestureDetector(
                            onTap: _showImageSourcePicker,
                            child: Container(
                              width: rectWidth,
                              height: rectHeight,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primaryRed,
                                  width: 2.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryRed.withValues(alpha: 0.18),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: SizedBox(
                                  width: rectWidth,
                                  height: rectHeight,
                                  child: FutureBuilder<Uint8List?>(
                                    future: (_photoBytes != null && _photoBytes!.isNotEmpty)
                                        ? Future.value(_photoBytes)
                                        : ContactPhotoService.getBestPhoto(
                                            contactId: widget.contactToEdit?.id ?? widget.scannedContactToEdit?.id,
                                            phone: widget.contactToEdit?.primaryPhone ?? widget.scannedContactToEdit?.phone,
                                          ),
                                    builder: (ctx, snapshot) {
                                      final effectiveBytes = snapshot.data ?? _photoBytes;
                                      if (effectiveBytes != null && effectiveBytes.isNotEmpty) {
                                        return Image.memory(
                                          effectiveBytes,
                                          width: rectWidth,
                                          height: rectHeight,
                                          fit: BoxFit.cover,
                                          filterQuality: FilterQuality.high,
                                          isAntiAlias: true,
                                        );
                                      }
                                      if (_photoUrl != null && _photoUrl!.isNotEmpty) {
                                        final resolved = UploadUrlResolver.resolve(_photoUrl!, type: 'profile');
                                        if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
                                          return CachedNetworkImage(
                                            imageUrl: resolved,
                                            width: rectWidth,
                                            height: rectHeight,
                                            fit: BoxFit.cover,
                                            filterQuality: FilterQuality.high,
                                            placeholder: (_, _) => _buildFormInitial(rectWidth, rectHeight),
                                            errorWidget: (_, _, _) => _buildFormInitial(rectWidth, rectHeight),
                                          );
                                        }
                                      }
                                      return _buildFormInitial(rectWidth, rectHeight);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -10,
                        right: 12,
                        child: GestureDetector(
                          onTap: _showImageSourcePicker,
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Basic Info Section
            _buildSection(
              title: 'Basic Information',
              children: [
                if (isScanDuplicateEdit)
                  DuplicateFieldSwipeWidget(
                    label: 'Full Name',
                    existingValue: _existingRecord!.name,
                    newValue: widget.scannedContactToEdit?.name ?? '${_firstNameController.text} ${_lastNameController.text}'.trim(),
                    useNew: _useNewName,
                    onSelectionChanged: (val) {
                      setState(() {
                        _useNewName = val;
                        final targetName = val
                            ? (widget.scannedContactToEdit?.name ?? '')
                            : _existingRecord!.name;
                        final parts = targetName.trim().split(' ');
                        _firstNameController.text = parts.isNotEmpty ? parts.first : '';
                        _lastNameController.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
                      });
                    },
                  ),
                CustomTextField(
                  controller: _firstNameController,
                  label: 'First Name',
                  prefixIcon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) {
                    _hasUserEdited = true;
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _lastNameController,
                  label: 'Last Name',
                  prefixIcon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Groups Section
            _buildSection(
              title: 'Assign Groups',
              action: TextButton.icon(
                onPressed: _showQuickCreateGroupDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New Group', style: TextStyle(fontSize: 12)),
              ),
              children: [
                if (groupProvider.groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'No groups yet',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _showQuickCreateGroupDialog,
                          child: const Text('+ Create Group'),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        ...groupProvider.groups.map((group) {
                          final isSelected = _selectedGroupIds.contains(group.id);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Text(group.name),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    if (group.id != null) _selectedGroupIds.add(group.id!);
                                  } else {
                                    _selectedGroupIds.remove(group.id);
                                  }
                                });
                              },
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : null,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              showCheckmark: false,
                              avatar: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
                            ),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: ActionChip(
                            avatar: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                            label: const Text(
                              'New Group',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: Colors.transparent,
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.4),
                            ),
                            onPressed: _showQuickCreateGroupDialog,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Phone Numbers Section
            _buildSection(
              title: 'Phone Numbers',
              children: [
                ..._phones.asMap().entries.map((entry) {
                  final index = entry.key;
                  final phone = entry.value;
                  final isLockedPhone = isCardContact && (phone.isPrimary || index == 0);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Primary star toggle
                        Padding(
                          padding: const EdgeInsets.only(top: 22.0, right: 2.0),
                          child: Tooltip(
                            message: phone.isPrimary ? 'Primary number' : 'Set as primary',
                            child: GestureDetector(
                              onTap: isCardContact
                                  ? null
                                  : () {
                                      setState(() {
                                        for (int i = 0; i < _phones.length; i++) {
                                          _phones[i].isPrimary = (i == index);
                                        }
                                      });
                                    },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  phone.isPrimary ? Icons.star_rounded : Icons.star_outline_rounded,
                                  key: ValueKey(phone.isPrimary),
                                  color: phone.isPrimary ? const Color(0xFFFFC107) : Colors.grey.shade400,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: CustomTextField(
                            controller: phone.numberController,
                            readOnly: isLockedPhone,
                            suffixIcon: isLockedPhone
                                ? const Tooltip(
                                    message: 'Card primary contact number is locked',
                                    child: Icon(Icons.lock_rounded, size: 20, color: Color(0xFF2563EB)),
                                  )
                                : null,
                            label: '${phone.label} Phone',
                            labelWidget: isLockedPhone
                                ? Text(
                                    '${phone.label} Phone (Locked)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface.withAlpha(200),
                                    ),
                                  )
                                : PopupMenuButton<String>(
                                    initialValue: phone.label,
                                    tooltip: 'Select Phone Type',
                                    onSelected: (val) {
                                      setState(() {
                                        phone.label = val;
                                      });
                                    },
                                    itemBuilder: (ctx) => [
                                          'Mobile',
                                          'Work',
                                          'Home',
                                          'Main',
                                          'Office',
                                          'Work Mobile',
                                          'Assistant',
                                          'Pager',
                                          'Car',
                                          'School',
                                          'Other',
                                        ]
                                        .map((lbl) => PopupMenuItem(value: lbl, child: Text(lbl)))
                                        .toList(),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${phone.label} Phone',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurface.withAlpha(200),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.primary),
                                      ],
                                    ),
                                  ),
                            prefixIcon: isLockedPhone ? Icons.lock_outline_rounded : Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        if (_phones.length > 1 && !isLockedPhone)
                          Padding(
                            padding: const EdgeInsets.only(top: 24.0, left: 4.0),
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.deleteRed),
                              tooltip: 'Remove Phone Number',
                              onPressed: () {
                                setState(() {
                                  final wasP = phone.isPrimary;
                                  phone.dispose();
                                  _phones.removeAt(index);
                                  // If we removed the primary, promote the first remaining one
                                  if (wasP && _phones.isNotEmpty && !_phones.any((p) => p.isPrimary)) {
                                    _phones.first.isPrimary = true;
                                  }
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _phones.add(_PhoneEntry(isPrimary: false));
                    });
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Phone Number'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Emails Section
            _buildSection(
              title: 'Email Addresses',
              children: [
                if (isScanDuplicateEdit)
                  DuplicateFieldSwipeWidget(
                    label: 'Email',
                    existingValue: _existingRecord!.email,
                    newValue: widget.scannedContactToEdit?.email ?? (_emails.isNotEmpty ? _emails.first.emailController.text : ''),
                    useNew: _useNewEmail,
                    onSelectionChanged: (val) {
                      setState(() {
                        _useNewEmail = val;
                        final targetEmail = val
                            ? (widget.scannedContactToEdit?.email ?? '')
                            : _existingRecord!.email;
                        if (_emails.isEmpty) {
                          _emails.add(_EmailEntry(email: targetEmail));
                        } else {
                          _emails.first.emailController.text = targetEmail;
                        }
                      });
                    },
                  ),
                ..._emails.asMap().entries.map((entry) {
                  final index = entry.key;
                  final email = entry.value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: email.emailController,
                            label: '${email.label} Email',
                            labelWidget: PopupMenuButton<String>(
                              initialValue: email.label,
                              tooltip: 'Select Email Type',
                              onSelected: (val) {
                                setState(() {
                                  email.label = val;
                                });
                              },
                              itemBuilder: (ctx) => ['Home', 'Work', 'Other']
                                  .map((lbl) => PopupMenuItem(value: lbl, child: Text(lbl)))
                                  .toList(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${email.label} Email',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface.withAlpha(200),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.primary),
                                ],
                              ),
                            ),
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        if (_emails.length > 1) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 24.0, left: 4.0),
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.deleteRed),
                              tooltip: 'Remove Email',
                              onPressed: () {
                                setState(() {
                                  email.dispose();
                                  _emails.removeAt(index);
                                });
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _emails.add(_EmailEntry());
                    });
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Email Address'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Websites / Links Section
            _buildSection(
              title: 'Websites & Links',
              children: [
                if (isScanDuplicateEdit)
                  DuplicateFieldSwipeWidget(
                    label: 'Website',
                    existingValue: _existingRecord!.website,
                    newValue: widget.scannedContactToEdit?.website ?? (_websites.isNotEmpty ? _websites.first.urlController.text : ''),
                    useNew: _useNewWebsite,
                    onSelectionChanged: (val) {
                      setState(() {
                        _useNewWebsite = val;
                        final targetWeb = val
                            ? (widget.scannedContactToEdit?.website ?? '')
                            : _existingRecord!.website;
                        if (_websites.isEmpty) {
                          _websites.add(_WebsiteEntry(url: targetWeb));
                        } else {
                          _websites.first.urlController.text = targetWeb;
                        }
                      });
                    },
                  ),
                ..._websites.asMap().entries.map((entry) {
                  final index = entry.key;
                  final web = entry.value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: web.urlController,
                            label: '${web.label} URL',
                            labelWidget: PopupMenuButton<String>(
                              initialValue: web.label,
                              tooltip: 'Select Link Type',
                              onSelected: (val) {
                                setState(() {
                                  web.label = val;
                                });
                              },
                              itemBuilder: (ctx) => ['Homepage', 'Work', 'Blog', 'Profile', 'Other']
                                  .map((lbl) => PopupMenuItem(value: lbl, child: Text(lbl)))
                                  .toList(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${web.label} URL',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface.withAlpha(200),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.primary),
                                ],
                              ),
                            ),
                            prefixIcon: Icons.language_rounded,
                            keyboardType: TextInputType.url,
                            hint: 'https://example.com',
                          ),
                        ),
                        if (_websites.length > 1) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 24.0, left: 4.0),
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.deleteRed),
                              tooltip: 'Remove Website',
                              onPressed: () {
                                setState(() {
                                  web.dispose();
                                  _websites.removeAt(index);
                                });
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _websites.add(_WebsiteEntry());
                    });
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Website / Link'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Addresses Section
            _buildSection(
              title: 'Addresses',
              children: [
                if (isScanDuplicateEdit)
                  DuplicateFieldSwipeWidget(
                    label: 'Address',
                    existingValue: _existingRecord!.address,
                    newValue: widget.scannedContactToEdit?.address ?? (_addresses.isNotEmpty ? _addresses.first.addressController.text : ''),
                    useNew: _useNewAddress,
                    onSelectionChanged: (val) {
                      setState(() {
                        _useNewAddress = val;
                        final targetAddr = val
                            ? (widget.scannedContactToEdit?.address ?? '')
                            : _existingRecord!.address;
                        if (_addresses.isEmpty) {
                          _addresses.add(_AddressEntry(address: targetAddr));
                        } else {
                          _addresses.first.addressController.text = targetAddr;
                        }
                      });
                    },
                  ),
                ..._addresses.asMap().entries.map((entry) {
                  final index = entry.key;
                  final addr = entry.value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: addr.addressController,
                            label: '${addr.label} Address',
                            labelWidget: PopupMenuButton<String>(
                              initialValue: addr.label,
                              tooltip: 'Select Address Type',
                              onSelected: (val) {
                                setState(() {
                                  addr.label = val;
                                });
                              },
                              itemBuilder: (ctx) => ['Home', 'Work', 'Other']
                                  .map((lbl) => PopupMenuItem(value: lbl, child: Text(lbl)))
                                  .toList(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${addr.label} Address',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface.withAlpha(200),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.primary),
                                ],
                              ),
                            ),
                            prefixIcon: Icons.location_on_outlined,
                            keyboardType: TextInputType.streetAddress,
                            hint: 'Street, City, Postal Code',
                          ),
                        ),
                        if (_addresses.length > 1) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 24.0, left: 4.0),
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.deleteRed),
                              tooltip: 'Remove Address',
                              onPressed: () {
                                setState(() {
                                  addr.dispose();
                                  _addresses.removeAt(index);
                                });
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _addresses.add(_AddressEntry());
                    });
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Address'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Work Section
            _buildSection(
              title: 'Work Information',
              children: [
                CustomTextField(
                  controller: _companyController,
                  label: 'Company / Organization',
                  prefixIcon: Icons.business_rounded,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _jobTitleController,
                  label: 'Job Title',
                  prefixIcon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
                if (_additionalCompanies.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ..._additionalCompanies.asMap().entries.map((entry) {
                    final index = entry.key;
                    final comp = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.dividerColor.withAlpha(60),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Company ${index + 2}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface.withAlpha(200),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.deleteRed, size: 20),
                                tooltip: 'Remove Company',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    comp.dispose();
                                    _additionalCompanies.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: comp.companyController,
                            label: 'Additional Company',
                            prefixIcon: Icons.business_rounded,
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: comp.designationController,
                            label: 'Job Title',
                            prefixIcon: Icons.badge_outlined,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _additionalCompanies.add(_CompanyEntry());
                    });
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Another Company'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Notes Section
            _buildSection(
              title: 'Notes',
              children: [
                CustomTextField(
                  controller: _notesController,
                  label: 'Notes',
                  prefixIcon: Icons.notes_rounded,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bottom Action Buttons: Cancel (GREEN bg) & Save (RED bg)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A), // GREEN background
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.close_rounded, size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Cancel',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626), // RED background
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_rounded, size: 20, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  'Save',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Android System Editor Fallback Option
            OutlinedButton.icon(
              onPressed: () async {
                final first = _firstNameController.text.trim();
                final last = _lastNameController.text.trim();
                final displayName = [first, last].where((s) => s.isNotEmpty).join(' ');

                final fallback = AppContact(
                  id: widget.contactToEdit?.id ?? '',
                  displayName: displayName.isNotEmpty ? displayName : 'New Contact',
                  givenName: first.isNotEmpty ? first : null,
                  familyName: last.isNotEmpty ? last : null,
                  company: _companyController.text.trim().isNotEmpty ? _companyController.text.trim() : null,
                  jobTitle: _jobTitleController.text.trim().isNotEmpty ? _jobTitleController.text.trim() : null,
                  phones: _phones
                      .where((p) => p.numberController.text.trim().isNotEmpty)
                      .map((p) => ContactPhone(number: p.numberController.text.trim(), label: p.label, isPrimary: p.isPrimary))
                      .toList(),
                  emails: _emails
                      .where((e) => e.emailController.text.trim().isNotEmpty)
                      .map((e) => ContactEmail(address: e.emailController.text.trim(), label: e.label))
                      .toList(),
                  websites: _websites
                      .where((w) => w.urlController.text.trim().isNotEmpty)
                      .map((w) => ContactWebsite(url: w.urlController.text.trim(), label: w.label))
                      .toList(),
                  addresses: _addresses
                      .where((a) => a.addressController.text.trim().isNotEmpty)
                      .map((a) => ContactAddress(address: a.addressController.text.trim(), label: a.label))
                      .toList(),
                  notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
                );

                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                final created = await context.read<ContactProvider>().openNativeCreator(initialData: fallback);
                if (created != null) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('${created.displayName} saved via System Contact Editor'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  navigator.pop();
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Open in Device System Editor',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ],
  ),
);
  }

  Widget _buildSection({
    required String title,
    Widget? action,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 8),
                action,
              ],
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

/// Actions the user can take when a duplicate contact is detected in the form save flow.
enum _FormDuplicateAction { merge, saveAnyway, cancel }
