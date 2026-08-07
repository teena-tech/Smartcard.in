import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/scanned_contact_model.dart';
import '../../core/services/backend_sync_service.dart';
import '../../core/database/hive_database.dart';
import '../../core/services/contact_saver_service.dart';
import '../../viewmodels/contact_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../core/utils/upload_url_resolver.dart';
import '../widgets/master_app_bar.dart';

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

  final bool _saveToDevice = true;
  bool _isSaving = false;
  String? _capturedProfilePath;

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
      backgroundColor: const Color(0xFF1E1E3F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Owner Profile Photo',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFFF5252)),
              title: Text('Take Photo with Camera', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickProfileImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFFF5252)),
              title: Text('Choose from Gallery', style: GoogleFonts.inter(color: Colors.white)),
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

  Widget _buildProfileImageWidget(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return Container(
        color: const Color(0xFF2A2A4A),
        child: const Icon(Icons.person_add_alt_1, size: 44, color: Colors.white70),
      );
    }
    final resolved = UploadUrlResolver.resolve(raw, type: 'profile');
    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return Image.network(
        resolved,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF2A2A4A),
          child: const Icon(Icons.person, size: 48, color: Colors.white60),
        ),
      );
    }
    final file = File(resolved);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF2A2A4A),
          child: const Icon(Icons.person, size: 48, color: Colors.white60),
        ),
      );
    }
    return Container(
      color: const Color(0xFF2A2A4A),
      child: const Icon(Icons.person, size: 48, color: Colors.white60),
    );
  }

  String _formatMultiLine(String? text) {
    if (text == null || text.trim().isEmpty) return '';
    final raw = text.trim();
    if (raw.contains('\n')) return raw;
    if (raw.contains('/')) {
      return raw.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).join('\n');
    }
    if (raw.contains(';')) {
      return raw.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).join('\n');
    }
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact.name);
    _companyController = TextEditingController(text: widget.contact.company);
    _designationController = TextEditingController(text: widget.contact.designation);

    String mainPhone = widget.contact.phone;
    String altPhone = widget.contact.alternativePhone ?? '';
    if (mainPhone.contains('/') && altPhone.isEmpty) {
      final parts = mainPhone.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (parts.isNotEmpty) mainPhone = parts[0];
      if (parts.length > 1) altPhone = parts[1];
    }

    _phoneController = TextEditingController(text: _formatMultiLine(mainPhone));
    _altPhoneController = TextEditingController(text: _formatMultiLine(altPhone));
    _landlineController = TextEditingController(text: _formatMultiLine(widget.contact.landline));
    _whatsAppController = TextEditingController(text: _formatMultiLine(widget.contact.whatsApp ?? mainPhone));
    _emailController = TextEditingController(text: _formatMultiLine(widget.contact.email));
    _websiteController = TextEditingController(text: _formatMultiLine(widget.contact.website));
    _addressController = TextEditingController(text: widget.contact.address);
    _pinCodeController = TextEditingController(text: widget.contact.pinCode ?? '');
    _socialsController = TextEditingController(text: _formatMultiLine(widget.contact.socialLinks.join('\n')));
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
    if (_isSaving) return;

    final contactViewModel = context.read<ContactViewModel>();
    final dashboardViewModel = context.read<DashboardViewModel>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);

    setState(() => _isSaving = true);

    final socials = _socialsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final updatedContact = widget.contact.copyWith(
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
      profileImage: _capturedProfilePath ?? widget.contact.profileImage ?? widget.imagePath,
      imagePath: widget.imagePath ?? widget.contact.imagePath,
      syncStatus: 'pending',
    );

    try {
      // addScannedContact internally calls HiveDatabase.saveContact — no need to call it separately
      await contactViewModel.addScannedContact(updatedContact);
    } catch (e) {
      debugPrint('❌ Local save failed: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        scaffoldMessenger.showSnackBar(SnackBar(
          content: Text('Save failed: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.redAccent,
        ));
      }
      return;
    }

    // Cloud sync — update status in Hive once confirmed
    bool isAlreadySaved = false;
    String toastMessage = 'Contact saved successfully!';
    try {
      final syncResult = await BackendSyncService().uploadContactDetails(updatedContact);
      if (syncResult['already_saved'] == true) {
        isAlreadySaved = true;
        toastMessage = syncResult['message']?.toString() ?? 'Contact already exists — updated with latest details!';
        await HiveDatabase.updateSyncStatus(updatedContact.id, 'synced');
      } else if (syncResult['success'] == true) {
        await HiveDatabase.updateSyncStatus(updatedContact.id, 'synced');
      }
    } catch (e) {
      debugPrint('🚨 Cloud upload check error: $e');
    }

    // Refresh viewmodel list to show updated content
    await contactViewModel.loadContactsFromBackend();

    if (!mounted) return;

    setState(() => _isSaving = false);

    // Show toast with proper indication
    scaffoldMessenger.showSnackBar(SnackBar(
      content: Text(
        toastMessage,
        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: isAlreadySaved ? Colors.deepOrange : Colors.green,
      duration: const Duration(seconds: 4),
    ));

    // Set scan tab FIRST, then pop on next frame
    dashboardViewModel.setIndex(1);
    await Future.microtask(() {});
    if (mounted) navigator.pop();

    // Background: device save
    final saveToDevice = _saveToDevice;
    if (saveToDevice) {
      unawaited(Future(() async {
        try { await ContactSaverService.saveToDevice(updatedContact); }
        catch (e) { debugPrint('🚨 Device save failed: $e'); }
      }));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isQrCode = widget.contact.contactType == 'qr' ||
        widget.contact.source == 'qr' ||
        (widget.contact.id.isNotEmpty && !widget.contact.id.startsWith('manual_'));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: MasterAppBar(
        titleText: 'Verify Contact Details',
        style: MasterHeaderStyle.transparent,
        showProfile: false,
        onBackTap: _isSaving
            ? null
            : () {
                context.read<DashboardViewModel>().setIndex(1);
                Navigator.of(context, rootNavigator: true).pop();
              },
        extraActions: [
          IconButton(
            icon: const Icon(Icons.check, size: 28, color: Colors.white),
            onPressed: _isSaving ? null : _handleSave,
          ),
        ],
      ),
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
                  const SizedBox(height: 8),

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
                          _buildInputField('Mobile Number', _phoneController, Icons.phone_outlined, keyboardType: TextInputType.multiline, maxLines: null),
                        if (isQrCode ? _altPhoneController.text.isNotEmpty : true)
                          _buildInputField('Alternative Number', _altPhoneController, Icons.phone_android_outlined, keyboardType: TextInputType.multiline, maxLines: null),
                        if (isQrCode ? _landlineController.text.isNotEmpty : true)
                          _buildInputField('Landline Number', _landlineController, Icons.phone_callback_outlined, keyboardType: TextInputType.multiline, maxLines: null),
                        if (isQrCode ? _whatsAppController.text.isNotEmpty : true)
                          _buildInputField('WhatsApp Number', _whatsAppController, Icons.chat_outlined, keyboardType: TextInputType.multiline, maxLines: null),
                        if (isQrCode ? _emailController.text.isNotEmpty : true)
                          _buildInputField('Email Address', _emailController, Icons.email_outlined, keyboardType: TextInputType.multiline, maxLines: null),
                        if (isQrCode ? _websiteController.text.isNotEmpty : true)
                          _buildInputField('Website URL', _websiteController, Icons.language_outlined, keyboardType: TextInputType.multiline, maxLines: null),
                        if (isQrCode ? _addressController.text.isNotEmpty : true)
                          _buildInputField('Office Address', _addressController, Icons.location_on_outlined, maxLines: null),
                        if (isQrCode ? _pinCodeController.text.isNotEmpty : true)
                          _buildInputField('PIN Code / ZIP Code', _pinCodeController, Icons.pin_drop_outlined, keyboardType: TextInputType.number),
                        if (isQrCode ? _socialsController.text.isNotEmpty : true)
                          _buildInputField('Social Links', _socialsController, Icons.share_outlined, keyboardType: TextInputType.multiline, maxLines: null),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const SizedBox(height: 24),

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
                      onPressed: _isSaving ? null : () {
                        context.read<DashboardViewModel>().setIndex(1);
                        Navigator.of(context, rootNavigator: true).pop();
                      },
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
    int? maxLines = 1,
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
