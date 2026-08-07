import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/scanned_contact_model.dart';
import '../../../viewmodels/contact_viewmodel.dart';

class ContactReviewScreen extends StatefulWidget {
  final ScannedContactModel contact;
  final String? imagePath;

  const ContactReviewScreen({
    super.key,
    required this.contact,
    this.imagePath,
  });

  @override
  State<ContactReviewScreen> createState() => _ContactReviewScreenState();
}

class _ContactReviewScreenState extends State<ContactReviewScreen> {
  late TextEditingController _nameController;
  late TextEditingController _companyController;
  late TextEditingController _designationController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _addressController;

  bool _isSaving = false;
  bool _isSaveSuccess = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact.name);
    _companyController = TextEditingController(text: widget.contact.company);
    _designationController = TextEditingController(text: widget.contact.designation);
    _phoneController = TextEditingController(text: widget.contact.phone);
    _emailController = TextEditingController(text: widget.contact.email);
    _websiteController = TextEditingController(text: widget.contact.website);
    _addressController = TextEditingController(text: widget.contact.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _designationController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final updatedContact = widget.contact.copyWith(
      name: _nameController.text.trim(),
      company: _companyController.text.trim(),
      designation: _designationController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      website: _websiteController.text.trim(),
      address: _addressController.text.trim(),
      imagePath: widget.imagePath,
    );

    try {
      final contactViewModel = Provider.of<ContactViewModel>(context, listen: false);
      await contactViewModel.addScannedContact(updatedContact);

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isSaveSuccess = true;
      });

      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 900));

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('Save contact error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save contact: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Business Card Found',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Image Thumbnail Preview
              if (widget.imagePath != null && File(widget.imagePath!).existsSync()) ...[
                Text(
                  'CARD PREVIEW',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Image.file(
                      File(widget.imagePath!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],

              Text(
                'Contact Information',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Review and edit parsed fields before saving',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Form Input Fields
              _ReviewTextField(label: 'Name', controller: _nameController, icon: Icons.person_outline),
              const SizedBox(height: 16),
              _ReviewTextField(label: 'Company', controller: _companyController, icon: Icons.business_outlined),
              const SizedBox(height: 16),
              _ReviewTextField(label: 'Designation', controller: _designationController, icon: Icons.badge_outlined),
              const SizedBox(height: 16),
              _ReviewTextField(label: 'Phone', controller: _phoneController, icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _ReviewTextField(label: 'Email', controller: _emailController, icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _ReviewTextField(label: 'Website', controller: _websiteController, icon: Icons.language_outlined, keyboardType: TextInputType.url),
              const SizedBox(height: 16),
              _ReviewTextField(label: 'Address', controller: _addressController, icon: Icons.location_on_outlined, maxLines: 2),

              const SizedBox(height: 36),

              // Save Contact Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isSaving || _isSaveSuccess) ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5252),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: _isSaving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Text('Saving contact...', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        )
                      : _isSaveSuccess
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 24)
                                    .animate()
                                    .scale(duration: 300.ms, curve: Curves.easeOutBack),
                                const SizedBox(width: 10),
                                Text('Saved successfully ✓', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF00E676))),
                              ],
                            )
                          : Text(
                              'Save Contact',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType keyboardType;
  final int maxLines;

  const _ReviewTextField({
    required this.label,
    required this.controller,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFFFF5252), size: 20),
            filled: true,
            fillColor: const Color(0xFF1B1B2F),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
