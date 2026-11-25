import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/core/database/sqlite_database.dart';
import 'package:smartcard_flutter/core/database/hive_scan_database.dart';
import 'package:smartcard_flutter/core/services/contact_photo_resolver.dart';
import 'package:smartcard_flutter/core/services/contact_photo_service.dart';
import 'package:smartcard_flutter/core/services/contact_saver_service.dart';
import 'package:smartcard_flutter/core/utils/app_haptics.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_notifier.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_viewmodel.dart';
import 'package:smartcard_flutter/core/widgets/master_app_bar.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/core/widgets/circular_profile_avatar.dart';
import 'package:smartcard_flutter/features/contact_form_screen/presentation/view/contact_form_screen.dart';

class ContactPreviewScreen extends ConsumerStatefulWidget {
  final ScannedContactModel contact;
  final ScannedContactModel? existingContact;
  final String? imagePath;

  const ContactPreviewScreen({
    super.key,
    required this.contact,
    this.existingContact,
    this.imagePath,
  });

  @override
  ConsumerState<ContactPreviewScreen> createState() => _ContactPreviewScreenState();
}

class _ContactPreviewScreenState extends ConsumerState<ContactPreviewScreen> {
  late TextEditingController _nameController;
  late TextEditingController _companyController;
  late TextEditingController _designationController;
  late TextEditingController _phoneController;
  late TextEditingController _alternativePhoneController;
  final List<TextEditingController> _additionalPhoneControllers = [];
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _websiteController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _nameController = TextEditingController(text: c.name);
    _companyController = TextEditingController(text: c.company);
    _designationController = TextEditingController(text: c.designation);
    _phoneController = TextEditingController(text: c.phone);
    _alternativePhoneController = TextEditingController(text: c.alternativePhone ?? '');
    for (final ap in c.additionalPhones) {
      if (ap.trim().isNotEmpty) {
        _additionalPhoneControllers.add(TextEditingController(text: ap.trim()));
      }
    }
    _emailController = TextEditingController(text: c.email);
    _addressController = TextEditingController(text: c.address);
    _websiteController = TextEditingController(text: c.website);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _designationController.dispose();
    _phoneController.dispose();
    _alternativePhoneController.dispose();
    for (final ctrl in _additionalPhoneControllers) {
      ctrl.dispose();
    }
    _emailController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  void _addAdditionalPhoneField() {
    setState(() {
      _additionalPhoneControllers.add(TextEditingController());
    });
  }

  void _removeAdditionalPhoneField(int index) {
    setState(() {
      _additionalPhoneControllers[index].dispose();
      _additionalPhoneControllers.removeAt(index);
    });
  }

  Future<void> _handleSaveContact() async {
    if (_nameController.text.trim().isEmpty && _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least a Name or Phone number.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    AppHaptics.medium();

    try {
      final List<String> extraNumbers = _additionalPhoneControllers
          .map((ctrl) => ctrl.text.trim())
          .where((txt) => txt.isNotEmpty)
          .toList();

      final preservedPhoto = ContactPhotoResolver.firstValidSource([
        widget.contact.profileImage,
        widget.contact.matchedProfileImage,
        widget.existingContact?.profileImage,
        widget.existingContact?.matchedProfileImage,
      ]);

      var updatedContact = widget.contact.copyWith(
        deviceContactId:
            widget.contact.deviceContactId ?? widget.existingContact?.deviceContactId,
        name: _nameController.text.trim(),
        company: _companyController.text.trim(),
        designation: _designationController.text.trim(),
        phone: _phoneController.text.trim(),
        alternativePhone: _alternativePhoneController.text.trim().isNotEmpty
            ? _alternativePhoneController.text.trim()
            : null,
        clearAlternativePhone: _alternativePhoneController.text.trim().isEmpty,
        additionalPhones: extraNumbers,
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        website: _websiteController.text.trim(),
        profileImage: preservedPhoto,
        matchedProfileImage: ContactPhotoResolver.firstValidSource([
          widget.contact.matchedProfileImage,
          preservedPhoto,
        ]),
        imagePath: widget.imagePath ?? widget.contact.imagePath,
        syncStatus: 'synced',
        updatedAt: DateTime.now(),
      );

      // Cache photo bytes and sync into native phone contacts when permitted
      final resolvedBytes = await ContactSaverService.resolvePhotoBytes(updatedContact);
      if (resolvedBytes != null && resolvedBytes.isNotEmpty) {
        ContactPhotoService.cachePhoto(
          contactId: updatedContact.id,
          phone: updatedContact.phone,
          photoBytes: resolvedBytes,
        );
      }
      final savedDeviceId = await ContactSaverService.saveToDevice(
        updatedContact,
        requestPermission: true,
      );
      if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
        updatedContact = updatedContact.copyWith(deviceContactId: savedDeviceId);
        if (resolvedBytes != null && resolvedBytes.isNotEmpty) {
          ContactPhotoService.cachePhoto(
            contactId: savedDeviceId,
            phone: updatedContact.phone,
            photoBytes: resolvedBytes,
          );
        }
      }

      // Save to SQLite & Hive (Offline-first persistence across app restarts)
      await SqliteDatabase.saveContact(updatedContact);
      await HiveScanDatabase.saveScannedRecord(updatedContact);
      if (updatedContact.isSmartCardUser) {
        await HiveScanDatabase.saveSmartCardRecord(updatedContact);
      }

      // Refresh ContactViewModel so Scans and Smart Card tabs update instantly
      if (mounted) {
        final cvm = ref.read(contactViewModelProvider.notifier);
        await cvm.saveScannedContact(updatedContact);
        try {
          if (mounted && savedDeviceId != null) {
            await ref.read(contactNotifierProvider.notifier).syncWithDevice(silent: true);
          }
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryRed,
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Contact saved successfully!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Error saving preview contact: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save contact: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _openAdvancedForm() {
    final List<String> extraNumbers = _additionalPhoneControllers
        .map((ctrl) => ctrl.text.trim())
        .where((txt) => txt.isNotEmpty)
        .toList();

    final staged = widget.contact.copyWith(
      name: _nameController.text.trim(),
      company: _companyController.text.trim(),
      designation: _designationController.text.trim(),
      phone: _phoneController.text.trim(),
      alternativePhone: _alternativePhoneController.text.trim().isNotEmpty
          ? _alternativePhoneController.text.trim()
          : null,
      additionalPhones: extraNumbers,
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      website: _websiteController.text.trim(),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ContactFormScreen(
          scannedContactToEdit: staged,
          existingContact: widget.existingContact,
          cardImagePath: widget.imagePath,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeViewModelProvider);
    final colors = theme.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.backgroundStart,
      appBar: MasterAppBar(
        titleText: 'Contact Capture Preview',
        showBackButton: true,
        extraActions: [
          TextButton.icon(
            onPressed: _openAdvancedForm,
            icon: const Icon(Icons.tune_rounded, size: 16, color: Colors.white70),
            label: Text(
              'Advanced',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scanned Profile Image Avatar (when present from QR vCard, API, or existing match)
            if (ContactPhotoResolver.firstValidSource([
                  ContactPhotoResolver.resolveScannedPhotoSource(widget.contact),
                  ContactPhotoResolver.resolveScannedPhotoSource(widget.existingContact),
                ])
                case final previewPhoto?) ...[
              Center(
                child: CircularProfileAvatar(
                  radius: 38,
                  imageUrl: previewPhoto,
                  fallbackText: widget.contact.name.isNotEmpty
                      ? widget.contact.name[0].toUpperCase()
                      : 'U',
                  animateRing: false,
                ),
              ),
              const SizedBox(height: 14),
            ],
            // Business Card Image Banner (if available)
            if (widget.imagePath != null && widget.imagePath!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    border: Border.all(color: colors.border.withValues(alpha: 0.2)),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(widget.imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => const Center(
                          child: Icon(Icons.credit_card, size: 40, color: Colors.white54),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 12,
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'ML Kit OCR Extracted Details',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── CONTACT DETAILS FORM SECTION ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151B28) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Extracted Contact Details',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: colors.text),
                  ),
                  const SizedBox(height: 12),
                  _buildFormField(label: 'Full Name', controller: _nameController, icon: Icons.person_outline, colors: colors, isDark: isDark),
                  _buildFormField(label: 'Company Name', controller: _companyController, icon: Icons.business_outlined, colors: colors, isDark: isDark),
                  _buildFormField(label: 'Designation / Job Title', controller: _designationController, icon: Icons.badge_outlined, colors: colors, isDark: isDark),
                  _buildFormField(label: 'Primary Phone Number', controller: _phoneController, icon: Icons.phone_outlined, keyboardType: TextInputType.phone, colors: colors, isDark: isDark),
                  if (_alternativePhoneController.text.isNotEmpty || _additionalPhoneControllers.isNotEmpty)
                    _buildFormField(label: 'Alternative Phone Number', controller: _alternativePhoneController, icon: Icons.phone_android_outlined, keyboardType: TextInputType.phone, colors: colors, isDark: isDark),
                  ..._additionalPhoneControllers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ctrl = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Additional Phone ${index + 1}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: colors.muted)),
                              GestureDetector(
                                onTap: () => _removeAdditionalPhoneField(index),
                                child: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.phone,
                            style: GoogleFonts.inter(fontSize: 12, color: colors.text),
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.phone_outlined, size: 18, color: colors.muted),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              isDense: true,
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0C1322) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: colors.border.withValues(alpha: 0.15)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          if (_alternativePhoneController.text.isEmpty && _additionalPhoneControllers.isEmpty) {
                            setState(() {
                              _alternativePhoneController.text = ' ';
                              _alternativePhoneController.text = '';
                            });
                          } else {
                            _addAdditionalPhoneField();
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.primaryRed),
                        label: Text(
                          '+ Add Another Phone Number',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryRed),
                        ),
                      ),
                    ),
                  ),
                  _buildFormField(label: 'Email Address', controller: _emailController, icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, colors: colors, isDark: isDark),
                  _buildFormField(label: 'Official Website', controller: _websiteController, icon: Icons.language_outlined, colors: colors, isDark: isDark),
                  _buildFormField(label: 'Office Location / Address', controller: _addressController, icon: Icons.location_on_outlined, maxLines: 2, colors: colors, isDark: isDark),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── SUBMIT BUTTON ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSaveContact,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isSaving ? 'Saving Contact...' : 'Save Contact',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required dynamic colors,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: colors.muted)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: GoogleFonts.inter(fontSize: 12, color: colors.text),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 18, color: colors.muted),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              isDense: true,
              filled: true,
              fillColor: isDark ? const Color(0xFF0C1322) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colors.border.withValues(alpha: 0.15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
