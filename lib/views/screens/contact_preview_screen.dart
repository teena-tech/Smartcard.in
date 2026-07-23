import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/scanned_contact_model.dart';
import '../../core/services/backend_sync_service.dart';
import '../widgets/common_drawer.dart';
import '../widgets/global_bottom_nav.dart';
import '../../core/database/hive_database.dart';
import '../../core/services/contact_saver_service.dart';
import '../../viewmodels/contact_viewmodel.dart';

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

  late TextEditingController _nameController;
  late TextEditingController _companyController;
  late TextEditingController _designationController;
  late TextEditingController _phoneController;
  late TextEditingController _altPhoneController;
  late TextEditingController _landlineController;
  late TextEditingController _whatsAppController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _addressController;
  late TextEditingController _pinCodeController;
  late TextEditingController _socialsController;

  bool _saveToDevice = true;
  bool _uploadToCloud = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact.name);
    _companyController = TextEditingController(text: widget.contact.company);
    _designationController = TextEditingController(text: widget.contact.designation);
    _phoneController = TextEditingController(text: widget.contact.phone);
    _altPhoneController = TextEditingController(text: widget.contact.alternativePhone ?? '');
    _landlineController = TextEditingController(text: widget.contact.landline ?? '');
    _whatsAppController = TextEditingController(text: widget.contact.whatsApp ?? '');
    _emailController = TextEditingController(text: widget.contact.email);
    _websiteController = TextEditingController(text: widget.contact.website);
    _addressController = TextEditingController(text: widget.contact.address);
    _pinCodeController = TextEditingController(text: widget.contact.pinCode ?? '');
    _socialsController = TextEditingController(text: widget.contact.socialLinks.join('\n'));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _designationController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _landlineController.dispose();
    _whatsAppController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _pinCodeController.dispose();
    _socialsController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final socials = _socialsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Prepare updated ScannedContactModel
    var updatedContact = widget.contact.copyWith(
      name: _nameController.text.trim(),
      company: _companyController.text.trim(),
      designation: _designationController.text.trim(),
      phone: _phoneController.text.trim(),
      alternativePhone: _altPhoneController.text.trim().isNotEmpty ? _altPhoneController.text.trim() : '',
      landline: _landlineController.text.trim().isNotEmpty ? _landlineController.text.trim() : '',
      whatsApp: _whatsAppController.text.trim().isNotEmpty ? _whatsAppController.text.trim() : '',
      email: _emailController.text.trim(),
      website: _websiteController.text.trim(),
      address: _addressController.text.trim(),
      pinCode: _pinCodeController.text.trim().isNotEmpty ? _pinCodeController.text.trim() : '',
      socialLinks: socials,
      imagePath: widget.imagePath,
      syncStatus: 'pending',
    );

    // Validation bypassed: save directly on user confirmation regardless of empty values.

    final contactVm = context.read<ContactViewModel>();

    try {
      // 1. Save locally in Hive Box FIRST
      await HiveDatabase.saveContact(updatedContact);

      // 2. Add to ViewModel
      await contactVm.addScannedContact(updatedContact);

      // 3. Do tasks in background
      bool phoneSaved = true;
      bool apiSaved = true;
      String? phoneError;
      String? apiError;

      if (_saveToDevice) {
        try {
          phoneSaved = await ContactSaverService.saveToDevice(updatedContact);
          if (!phoneSaved) {
            phoneError = 'Permission denied or save aborted.';
          }
        } catch (e) {
          phoneSaved = false;
          phoneError = e.toString().replaceFirst('Exception: ', '');
          debugPrint('🚨 Native contact save failed: $phoneError');
        }
      }

      if (_uploadToCloud) {
        try {
          final syncService = BackendSyncService();
          final cloudSuccess = await syncService.uploadContact(updatedContact);
          if (cloudSuccess) {
            updatedContact = updatedContact.copyWith(syncStatus: 'synced');
            await HiveDatabase.saveContact(updatedContact);
          } else {
            // uploadContact returned false (non-exception failure, e.g. 4xx)
            apiSaved = false;
            apiError = 'Sync failed — server rejected the request.';
          }
        } on Exception catch (e) {
          // Exception is thrown by BackendSyncService with the real server message
          apiSaved = false;
          apiError = e.toString().replaceFirst('Exception: ', '');
        } catch (e) {
          apiSaved = false;
          apiError = e.toString();
        }
      }

        if (!mounted) return;

        // 4. Success UI notification
        String message;
        if (apiSaved) {
          message = 'Contact saved to SmartCard successfully!';
          if (_saveToDevice && !phoneSaved) {
            message += ' (Phone address book permission optional)';
          }
        } else {
          message = 'SmartCard save failed: $apiError';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: apiSaved ? Colors.green : Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Pop/redirect when SmartCard backend & local database save succeeds
        if (apiSaved) {
          Navigator.pop(context);
        }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isQrCode = widget.contact.contactType == 'qr' ||
        widget.contact.source == 'qr' ||
        (widget.contact.id.isNotEmpty && !widget.contact.id.startsWith('manual_'));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      drawer: const CommonDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Verify Contact Details',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, size: 28, color: Colors.white),
            onPressed: _isSaving ? null : _handleSave,
          ),
        ],
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F0F1A), Color(0xFF1E1E3F)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Captured Card Preview
                  if (widget.imagePath != null)
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.file(
                        File(widget.imagePath!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Extracted Form
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI OCR EXTRACTED DETAILS',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white38,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isQrCode ? _nameController.text.isNotEmpty : true)
                          _buildInputField('Full Name', _nameController, Icons.person_outline),
                        if (isQrCode ? _designationController.text.isNotEmpty : true)
                          _buildInputField('Designation / Job Title', _designationController, Icons.badge_outlined),
                        if (isQrCode ? _companyController.text.isNotEmpty : true)
                          _buildInputField('Company Name', _companyController, Icons.business_outlined),
                        if (isQrCode ? _phoneController.text.isNotEmpty : true)
                          _buildInputField('Mobile Number', _phoneController, Icons.phone_outlined, keyboardType: TextInputType.phone),
                        if (isQrCode ? _altPhoneController.text.isNotEmpty : true)
                          _buildInputField('Alternative Number', _altPhoneController, Icons.phone_android_outlined, keyboardType: TextInputType.phone),
                        if (isQrCode ? _landlineController.text.isNotEmpty : true)
                          _buildInputField('Landline Number', _landlineController, Icons.phone_callback_outlined, keyboardType: TextInputType.phone),
                        if (isQrCode ? _whatsAppController.text.isNotEmpty : true)
                          _buildInputField('WhatsApp Number', _whatsAppController, Icons.chat_outlined, keyboardType: TextInputType.multiline, maxLines: _whatsAppController.text.split('\n').length > 1 ? _whatsAppController.text.split('\n').length : 1),
                        if (isQrCode ? _emailController.text.isNotEmpty : true)
                          _buildInputField('Email Address', _emailController, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                        if (isQrCode ? _websiteController.text.isNotEmpty : true)
                          _buildInputField('Website URL', _websiteController, Icons.language_outlined, keyboardType: TextInputType.multiline, maxLines: _websiteController.text.split('\n').length > 1 ? _websiteController.text.split('\n').length : 1),
                        if (isQrCode ? _addressController.text.isNotEmpty : true)
                          _buildInputField('Office Address', _addressController, Icons.location_on_outlined, maxLines: 2),
                        if (isQrCode ? _pinCodeController.text.isNotEmpty : true)
                          _buildInputField('PIN Code / ZIP Code', _pinCodeController, Icons.pin_drop_outlined, keyboardType: TextInputType.number),
                        if (isQrCode ? _socialsController.text.isNotEmpty : true)
                          _buildInputField('Social Links', _socialsController, Icons.share_outlined, keyboardType: TextInputType.multiline, maxLines: _socialsController.text.split('\n').length > 1 ? _socialsController.text.split('\n').length : 1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Settings Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text(
                            'Save to Device Address Book',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          subtitle: Text(
                            'Exports contact card fields automatically.',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                          ),
                          value: _saveToDevice,
                          activeThumbColor: Colors.redAccent,
                          onChanged: (val) {
                            setState(() {
                              _saveToDevice = val;
                            });
                          },
                        ),
                        Divider(color: Colors.white.withValues(alpha: 0.2)),
                        SwitchListTile(
                          title: Text(
                            'Sync to Cloud Server',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          subtitle: Text(
                            'Secures backup on backend cloud account.',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                          ),
                          value: _uploadToCloud,
                          activeThumbColor: Colors.redAccent,
                          onChanged: (val) {
                            setState(() {
                              _uploadToCloud = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save Contact Button (Matching First Sheet style)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5252),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFFF5252).withValues(alpha: 0.6),
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Save Contact',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Scan Again Button
                  Center(
                    child: TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: Text(
                        'Scan Again',
                        style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          if (_isSaving)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2E),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.redAccent),
                        const SizedBox(height: 24),
                        Text(
                          'Saving Contact Data...',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.redAccent, width: 2),
          ),
        ),
      ),
    );
  }
}
