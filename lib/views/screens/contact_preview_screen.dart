import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/scanned_contact_model.dart';
import '../../core/services/backend_sync_service.dart';
import '../../core/database/sqlite_database.dart';
import '../../core/services/contact_saver_service.dart';
import '../../viewmodels/contact_viewmodel.dart';
import '../../core/utils/upload_url_resolver.dart';
import '../../core/constants/app_colors.dart';

class PhoneEntry {
  TextEditingController controller;
  String countryCode;
  String typeLabel;

  PhoneEntry({
    required this.controller,
    this.countryCode = '+91',
    this.typeLabel = 'Mobile',
  });
}

class EmailEntry {
  TextEditingController controller;
  String typeLabel;

  EmailEntry({
    required this.controller,
    this.typeLabel = 'Work',
  });
}

class ContactPreviewScreen extends StatefulWidget {
  final ScannedContactModel contact;
  final String? imagePath;

  const ContactPreviewScreen({
    super.key,
    required this.contact,
    this.imagePath,
  });

  @override
  State<ContactPreviewScreen> createState() => _ContactPreviewScreenState();
}

class _ContactPreviewScreenState extends State<ContactPreviewScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _companyController;
  late TextEditingController _designationController;
  late List<PhoneEntry> _phoneEntries;
  late List<EmailEntry> _emailEntries;
  late TextEditingController _websiteController;
  late TextEditingController _addressController;
  late TextEditingController _pinCodeController;
  late TextEditingController _socialsController;
  late TextEditingController _notesController;
  late TextEditingController _birthdayController;

  String _addressLabel = 'Home';
  String _socialLabel = 'AIM';
  String _birthdayLabel = 'Birthday';

  final bool _saveToDevice = true;
  bool _isSaving = false;
  bool _isExpanded = false;
  String? _capturedProfilePath;
  String? _liveDevicePhoto;

  static const Color _redTheme = Color(0xFFE53935);

  final List<Map<String, String>> _countryCodes = [
    {'code': '+91', 'flag': '🇮🇳', 'name': '+91 🇮🇳'},
  ];

  String _capitalizeWords(String str) {
    final clean = _cleanText(str);
    if (clean.isEmpty) return '';
    return clean.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + (word.length > 1 ? word.substring(1) : '');
    }).join(' ');
  }

  @override
  void initState() {
    super.initState();
    _fetchLiveDevicePhoto();
    final rawName = _cleanText(widget.contact.name);
    String firstName = '';
    String lastName = '';
    if (rawName.isNotEmpty) {
      final parts = rawName.split(RegExp(r'\s+'));
      if (parts.length > 1) {
        firstName = parts.first;
        lastName = parts.sublist(1).join(' ');
      } else {
        firstName = rawName;
        lastName = '';
      }
    }

    _firstNameController = TextEditingController(text: _capitalizeWords(firstName));
    _lastNameController = TextEditingController(text: _capitalizeWords(lastName));
    _companyController = TextEditingController(text: _capitalizeWords(widget.contact.company));
    _designationController = TextEditingController(text: _capitalizeWords(widget.contact.designation));

    // Initialize phones list with country codes
    final List<PhoneEntry> phoneList = [];
    void addParsedPhone(String? raw, String defaultType) {
      if (raw == null || raw.trim().isEmpty) return;
      final cleanP = _cleanText(raw);
      if (cleanP.isEmpty) return;

      String code = '+91';
      String numOnly = cleanP;

      for (var cc in _countryCodes) {
        if (cleanP.startsWith(cc['code']!)) {
          code = cc['code']!;
          numOnly = cleanP.substring(code.length).trim();
          break;
        }
      }

      phoneList.add(PhoneEntry(
        controller: TextEditingController(text: numOnly),
        countryCode: code,
        typeLabel: defaultType,
      ));
    }

    addParsedPhone(widget.contact.phone, 'Mobile');
    addParsedPhone(widget.contact.alternativePhone, 'Home');
    addParsedPhone(widget.contact.landline, 'Work');
    addParsedPhone(widget.contact.whatsApp, 'WhatsApp');

    if (phoneList.isEmpty) {
      phoneList.add(PhoneEntry(
        controller: TextEditingController(text: ''),
        countryCode: '+91',
        typeLabel: 'Mobile',
      ));
    }
    _phoneEntries = phoneList;

    // Initialize emails list
    final List<EmailEntry> emailList = [];
    if (widget.contact.email.isNotEmpty) {
      emailList.add(EmailEntry(
        controller: TextEditingController(text: _cleanEmail(widget.contact.email)),
        typeLabel: 'Personal',
      ));
    } else {
      emailList.add(EmailEntry(
        controller: TextEditingController(text: ''),
        typeLabel: 'Personal',
      ));
    }
    _emailEntries = emailList;

    _websiteController = TextEditingController(text: _cleanWebsite(widget.contact.website));
    _addressController = TextEditingController(text: _cleanText(widget.contact.address));
    _pinCodeController = TextEditingController(text: _cleanText(widget.contact.pinCode));
    _socialsController = TextEditingController(
      text: widget.contact.socialLinks.map((s) => _cleanText(s)).where((s) => s.isNotEmpty).join('\n'),
    );
    _notesController = TextEditingController();
    _birthdayController = TextEditingController();
  }

  Future<void> _fetchLiveDevicePhoto() async {
    final photo = widget.contact.profileImage;
    if (photo == null || photo.trim().isEmpty) {
      if (widget.contact.id.startsWith('phone_') || widget.contact.source == 'phone') {
        try {
          final status = await Permission.contacts.status;
          if (!status.isGranted && !status.isLimited) return;

          final rawId = widget.contact.id.replaceFirst('phone_', '');
          final devContact = await FlutterContacts.getContact(rawId);
          if (devContact != null) {
            final bytes = devContact.photo ?? devContact.photoOrThumbnail;
            if (bytes != null && bytes.isNotEmpty) {
              final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
              if (mounted) {
                setState(() {
                  _liveDevicePhoto = base64Str;
                });
              }
            }
          }
        } catch (e) {
          debugPrint('Live photo fetch error: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _companyController.dispose();
    _designationController.dispose();
    for (final p in _phoneEntries) {
      p.controller.dispose();
    }
    for (final e in _emailEntries) {
      e.controller.dispose();
    }
    _websiteController.dispose();
    _addressController.dispose();
    _pinCodeController.dispose();
    _socialsController.dispose();
    _notesController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  String _cleanText(String? input) {
    if (input == null || input.isEmpty) return '';
    String result = input.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '').trim();
    result = result.replaceAll(RegExp(r'[ \t]+'), ' ');
    result = result.replaceAll(RegExp(r'[,;/]+$'), '').trim();
    return result;
  }

  String _cleanEmail(String? input) {
    if (input == null || input.isEmpty) return '';
    return input.replaceAll(RegExp(r'\s+'), '').trim().toLowerCase();
  }

  String _cleanWebsite(String? input) {
    if (input == null || input.isEmpty) return '';
    String cleaned = input.replaceAll(RegExp(r'\s+'), '').trim();
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null && mounted) {
        setState(() {
          _capturedProfilePath = picked.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking profile image: $e');
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Profile Photo',
              style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _redTheme),
              title: Text('Take Photo with Camera', style: GoogleFonts.inter(color: Colors.black87)),
              onTap: () {
                Navigator.pop(ctx);
                _pickProfileImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _redTheme),
              title: Text('Choose from Gallery', style: GoogleFonts.inter(color: Colors.black87)),
              onTap: () {
                Navigator.pop(ctx);
                _pickProfileImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(String? photoSource) {
    final effectiveSource = (photoSource != null && photoSource.trim().isNotEmpty)
        ? photoSource
        : _liveDevicePhoto;

    if (effectiveSource == null || effectiveSource.trim().isEmpty) {
      return _buildFallbackAvatarIcon();
    }

    final trimmed = effectiveSource.trim();

    if (trimmed.startsWith('data:image')) {
      try {
        final bytes = base64Decode(trimmed.split(',').last);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => _buildFallbackAvatarIcon(),
        );
      } catch (_) {
        return _buildFallbackAvatarIcon();
      }
    }

    final resolved = UploadUrlResolver.resolve(trimmed, type: 'profile');
    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return Image.network(
        resolved,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => _buildFallbackAvatarIcon(),
      );
    }

    final file = File(resolved);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => _buildFallbackAvatarIcon(),
      );
    }

    return _buildFallbackAvatarIcon();
  }

  Widget _buildFallbackAvatarIcon() {
    final nameText = _firstNameController.text.trim();
    final initial = nameText.isNotEmpty
        ? nameText[0].toUpperCase()
        : (widget.contact.name.trim().isNotEmpty ? widget.contact.name.trim()[0].toUpperCase() : '?');

    return Container(
      color: const Color(0xFFFFEBEE),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            color: _redTheme,
            fontSize: 42,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _addPhoneField() {
    setState(() {
      _phoneEntries.add(PhoneEntry(
        controller: TextEditingController(),
        countryCode: '+91',
        typeLabel: 'Mobile',
      ));
    });
  }

  void _addEmailField() {
    setState(() {
      _emailEntries.add(EmailEntry(
        controller: TextEditingController(),
        typeLabel: 'Work',
      ));
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final contactViewModel = context.read<ContactViewModel>();

      final phoneNumbers = _phoneEntries
          .map((p) {
            final num = _cleanText(p.controller.text);
            return num.isNotEmpty ? '${p.countryCode} $num' : '';
          })
          .where((s) => s.isNotEmpty)
          .toList();

      final emails = _emailEntries
          .map((e) => _cleanEmail(e.controller.text))
          .where((s) => s.isNotEmpty)
          .toList();

      final socials = _socialsController.text
          .split(RegExp(r'[\n,;]'))
          .map((s) => _cleanText(s))
          .where((s) => s.isNotEmpty)
          .toList();

      final fullName = '${_cleanText(_firstNameController.text)} ${_cleanText(_lastNameController.text)}'.trim();

      final mainPhone = phoneNumbers.isNotEmpty ? phoneNumbers.first : widget.contact.phone;
      final altPhone = phoneNumbers.length > 1 ? phoneNumbers[1] : '';
      final landline = phoneNumbers.length > 2 ? phoneNumbers[2] : '';
      final whatsApp = phoneNumbers.length > 3 ? phoneNumbers[3] : mainPhone;
      final mainEmail = emails.isNotEmpty ? emails.first : widget.contact.email;

      final profilePath = _capturedProfilePath ?? widget.contact.profileImage;

      final updatedContact = widget.contact.copyWith(
        name: fullName.isNotEmpty ? fullName : widget.contact.name,
        company: _cleanText(_companyController.text),
        designation: _cleanText(_designationController.text),
        phone: mainPhone,
        alternativePhone: altPhone,
        landline: landline,
        whatsApp: whatsApp,
        email: mainEmail,
        website: _cleanWebsite(_websiteController.text),
        address: _cleanText(_addressController.text),
        pinCode: _cleanText(_pinCodeController.text),
        socialLinks: socials,
        source: (widget.contact.source != null && widget.contact.source!.isNotEmpty && widget.contact.source != 'phone') ? widget.contact.source! : 'scanned',
        profileImage: profilePath,
        imagePath: widget.imagePath ?? widget.contact.imagePath,
        syncStatus: 'pending',
      );

      // 1. Save directly to local SQLite DB & native device phonebook via ViewModel
      await contactViewModel.addScannedContact(updatedContact);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${updatedContact.name} saved successfully!',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e, stack) {
      debugPrint('🚨 Save error: $e\n$stack');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activePhoto = _capturedProfilePath ?? widget.contact.profileImage ?? widget.imagePath;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Color(0xFFFFF0F0),
              Color(0xFFFFEAEA),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header Bar with X on left, Edit Contact center, Checkmark on right
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black87, size: 26),
                      onPressed: _isSaving
                          ? null
                          : () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            },
                    ),
                    Text(
                      'Edit contact',
                      style: GoogleFonts.inter(
                        color: Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: _redTheme, strokeWidth: 2.5),
                            )
                          : const Icon(Icons.check, color: Colors.black87, size: 28),
                      onPressed: _isSaving ? null : _handleSave,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Profile Avatar Header
                        Center(
                          child: Stack(
                            children: [
                              InkWell(
                                onTap: _showImagePickerModal,
                                borderRadius: BorderRadius.circular(60),
                                child: Container(
                                  width: 104,
                                  height: 104,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFFFEBEE),
                                    border: Border.all(color: _redTheme, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withValues(alpha: 0.15),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: _buildProfileAvatar(activePhoto),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: const BoxDecoration(
                                    color: _redTheme,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Card Box 1: Name Group (First Name & Last Name)
                        _buildRedBorderCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_outline, color: Colors.black87, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildSimpleInput('First name', _firstNameController),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                                ],
                              ),
                              const Divider(height: 20, color: Color(0xFFF0F0F0)),
                              Padding(
                                padding: const EdgeInsets.only(left: 34.0),
                                child: _buildSimpleInput('Last name', _lastNameController),
                              ),
                            ],
                          ),
                        ),

                        // Card Box 2: Company & Title Group
                        _buildRedBorderCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.business_outlined, color: Colors.black87, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildSimpleInput('Company', _companyController),
                                  ),
                                ],
                              ),
                              const Divider(height: 20, color: Color(0xFFF0F0F0)),
                              Padding(
                                padding: const EdgeInsets.only(left: 34.0),
                                child: _buildSimpleInput('Title', _designationController),
                              ),
                            ],
                          ),
                        ),

                        // Card Box 3: Phone Numbers Group (with Country Code & Type Dropdown)
                        _buildRedBorderCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...List.generate(_phoneEntries.length, (index) {
                                final entry = _phoneEntries[index];
                                return Column(
                                  children: [
                                    if (index > 0) const Divider(height: 20, color: Color(0xFFF0F0F0)),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        if (index == 0)
                                          const Icon(Icons.phone_outlined, color: Colors.black87, size: 22)
                                        else
                                          const SizedBox(width: 22),
                                        const SizedBox(width: 12),
                                        // Type selector dropdown (Mobile, Home, Work, etc.)
                                        DropdownButton<String>(
                                          value: entry.typeLabel,
                                          underline: const SizedBox.shrink(),
                                          icon: const Icon(Icons.unfold_more, size: 18, color: Colors.black54),
                                          style: GoogleFonts.inter(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
                                          items: ['Mobile', 'Home', 'Work', 'Main', 'WhatsApp', 'Other'].map((t) {
                                            return DropdownMenuItem(value: t, child: Text(t));
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) setState(() => entry.typeLabel = val);
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const SizedBox(width: 34),
                                        // Country code static badge (India +91 - no dropdown icon)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFEBEE),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: _redTheme.withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('🇮🇳', style: TextStyle(fontSize: 14)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '+91',
                                                style: GoogleFonts.inter(
                                                  color: Colors.black87,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextFormField(
                                            controller: entry.controller,
                                            keyboardType: TextInputType.phone,
                                            style: GoogleFonts.inter(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                                            decoration: InputDecoration(
                                              hintText: 'Phone number',
                                              hintStyle: GoogleFonts.inter(color: Colors.black38, fontSize: 14),
                                              isDense: true,
                                              border: InputBorder.none,
                                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                            ),
                                          ),
                                        ),
                                        if (_phoneEntries.length > 1)
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle, color: _redTheme, size: 22),
                                            onPressed: () {
                                              setState(() {
                                                entry.controller.dispose();
                                                _phoneEntries.removeAt(index);
                                              });
                                            },
                                          ),
                                      ],
                                    ),
                                  ],
                                );
                              }),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _addPhoneField,
                                icon: const Icon(Icons.add, color: _redTheme, size: 18),
                                label: Text(
                                  'Add phone',
                                  style: GoogleFonts.inter(color: _redTheme, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Card Box 4: Email Group (with Type Dropdown)
                        _buildRedBorderCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...List.generate(_emailEntries.length, (index) {
                                final entry = _emailEntries[index];
                                return Column(
                                  children: [
                                    if (index > 0) const Divider(height: 20, color: Color(0xFFF0F0F0)),
                                    Row(
                                      children: [
                                        if (index == 0)
                                          const Icon(Icons.email_outlined, color: Colors.black87, size: 22)
                                        else
                                          const SizedBox(width: 22),
                                        const SizedBox(width: 12),
                                        DropdownButton<String>(
                                          value: entry.typeLabel,
                                          underline: const SizedBox.shrink(),
                                          icon: const Icon(Icons.unfold_more, size: 18, color: Colors.black54),
                                          style: GoogleFonts.inter(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
                                          items: ['Personal', 'Work', 'Other'].map((t) {
                                            return DropdownMenuItem(value: t, child: Text(t));
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) setState(() => entry.typeLabel = val);
                                          },
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 34.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: entry.controller,
                                              keyboardType: TextInputType.emailAddress,
                                              style: GoogleFonts.inter(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                                              decoration: InputDecoration(
                                                hintText: 'Email address',
                                                hintStyle: GoogleFonts.inter(color: Colors.black38, fontSize: 14),
                                                isDense: true,
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                              ),
                                            ),
                                          ),
                                          if (_emailEntries.length > 1)
                                            IconButton(
                                              icon: const Icon(Icons.remove_circle, color: _redTheme, size: 22),
                                              onPressed: () {
                                                setState(() {
                                                  entry.controller.dispose();
                                                  _emailEntries.removeAt(index);
                                                });
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _addEmailField,
                                icon: const Icon(Icons.add, color: _redTheme, size: 18),
                                label: Text(
                                  'Add email',
                                  style: GoogleFonts.inter(color: _redTheme, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Card Box 5: Address Group
                        _buildRedBorderCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, color: Colors.black87, size: 22),
                                  const SizedBox(width: 12),
                                  DropdownButton<String>(
                                    value: _addressLabel,
                                    underline: const SizedBox.shrink(),
                                    icon: const Icon(Icons.unfold_more, size: 18, color: Colors.black54),
                                    style: GoogleFonts.inter(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
                                    items: ['Home', 'Work', 'Other'].map((t) {
                                      return DropdownMenuItem(value: t, child: Text(t));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _addressLabel = val);
                                    },
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 34.0, top: 4.0),
                                child: _buildSimpleInput('Street address', _addressController, maxLines: 2),
                              ),
                              const Divider(height: 16, color: Color(0xFFF0F0F0)),
                              Padding(
                                padding: const EdgeInsets.only(left: 34.0),
                                child: _buildSimpleInput('PIN / ZIP Code', _pinCodeController, keyboardType: TextInputType.number),
                              ),
                            ],
                          ),
                        ),

                        // Expandable Secondary Fields (Birthday, Social Links, Notes)
                        if (_isExpanded) ...[
                          // Birthday Card Box
                          _buildRedBorderCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.cake_outlined, color: Colors.black87, size: 22),
                                    const SizedBox(width: 12),
                                    DropdownButton<String>(
                                      value: _birthdayLabel,
                                      underline: const SizedBox.shrink(),
                                      icon: const Icon(Icons.unfold_more, size: 18, color: Colors.black54),
                                      style: GoogleFonts.inter(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
                                      items: ['Birthday', 'Anniversary'].map((t) {
                                        return DropdownMenuItem(value: t, child: Text(t));
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _birthdayLabel = val);
                                      },
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 34.0, top: 4.0),
                                  child: _buildSimpleInput('Date (YYYY-MM-DD)', _birthdayController),
                                ),
                              ],
                            ),
                          ),

                          // Social & Website Card Box
                          _buildRedBorderCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.chat_bubble_outline, color: Colors.black87, size: 22),
                                    const SizedBox(width: 12),
                                    DropdownButton<String>(
                                      value: _socialLabel,
                                      underline: const SizedBox.shrink(),
                                      icon: const Icon(Icons.unfold_more, size: 18, color: Colors.black54),
                                      style: GoogleFonts.inter(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
                                      items: ['AIM', 'LinkedIn', 'Instagram', 'Twitter'].map((t) {
                                        return DropdownMenuItem(value: t, child: Text(t));
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _socialLabel = val);
                                      },
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 34.0, top: 4.0),
                                  child: _buildSimpleInput('Social media account / handle', _socialsController),
                                ),
                                const Divider(height: 16, color: Color(0xFFF0F0F0)),
                                Row(
                                  children: [
                                    const Icon(Icons.link, color: Colors.black87, size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildSimpleInput('Website URL', _websiteController, keyboardType: TextInputType.url),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Notes Card Box
                          _buildRedBorderCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.edit_note, color: Colors.black87, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSimpleInput('Notes', _notesController, maxLines: 3),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // "Expand" toggle button matching native phone contact edit screenshot!
                        TextButton(
                          onPressed: () {
                            setState(() => _isExpanded = !_isExpanded);
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isExpanded ? 'Collapse' : 'Expand',
                                style: GoogleFonts.inter(
                                  color: AppColors.primaryRed,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: AppColors.primaryRed,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds each card container box with clean rounded corners, pure white background, and RED BORDER matching app theme!
  Widget _buildRedBorderCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _redTheme, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSimpleInput(
    String hintText,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.words,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      style: GoogleFonts.inter(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(color: Colors.black38, fontSize: 14),
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
      ),
    );
  }
}
