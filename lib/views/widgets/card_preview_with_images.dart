import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'image_cropper_widget.dart';

class CardPreviewWithImageCustomization extends StatefulWidget {
  final dynamic colors;
  final String cardName;
  final Function(String backgroundImagePath)? onBackgroundImageSelected;
  final Function(String profileImagePath)? onProfileImageSelected;
  final Function(String logoImagePath)? onLogoImageSelected;

  const CardPreviewWithImageCustomization({
    super.key,
    required this.colors,
    required this.cardName,
    this.onBackgroundImageSelected,
    this.onProfileImageSelected,
    this.onLogoImageSelected,
  });

  @override
  State<CardPreviewWithImageCustomization> createState() =>
      _CardPreviewWithImageCustomizationState();
}

class _CardPreviewWithImageCustomizationState
    extends State<CardPreviewWithImageCustomization> {
  String? _backgroundImagePath;
  String? _profileImagePath;
  String? _logoImagePath;
  final ImagePicker _imagePicker = ImagePicker();

  void _pickAndCropImage(String cropType) {
    _showImageSourceSheet(cropType);
  }

  Future<XFile?> _pickImageFromSource(ImageSource source) async {
    if (kIsWeb && source == ImageSource.camera) {
      source = ImageSource.gallery;
    }

    try {
      return await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _handlePickAndCropImage(String cropType, ImageSource source) async {
    final pickedFile = await _pickImageFromSource(source);
    if (pickedFile == null || !context.mounted) return;

    try {
      switch (cropType) {
        case 'background':
          final croppedFile = await ImageCropperHelper.cropBackgroundImage(
            pickedFile.path,
            context: context,
          );
          if (croppedFile != null) {
            setState(() => _backgroundImagePath = croppedFile.path);
            widget.onBackgroundImageSelected?.call(croppedFile.path);
          }
          break;
        case 'profile':
          final croppedFile = await ImageCropperHelper.cropProfileImage(
            pickedFile.path,
            context: context,
          );
          if (croppedFile != null) {
            setState(() => _profileImagePath = croppedFile.path);
            widget.onProfileImageSelected?.call(croppedFile.path);
          }
          break;
        case 'logo':
          final croppedFile = await ImageCropperHelper.cropCompanyLogo(
            pickedFile.path,
            context: context,
          );
          if (croppedFile != null) {
            setState(() => _logoImagePath = croppedFile.path);
            widget.onLogoImageSelected?.call(croppedFile.path);
          }
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _showImageSourceSheet(String cropType) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                cropType == 'logo' ? 'Upload Company Logo' : cropType == 'profile' ? 'Upload Profile Photo' : 'Upload Image',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: AppColors.primaryRed),
                ),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _handlePickAndCropImage(cropType, ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: AppColors.primaryRed),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _handlePickAndCropImage(cropType, ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Card Preview
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.colors?.border ?? Colors.grey.withValues(alpha: 0.15),
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              // Background Image
              if (_backgroundImagePath != null)
                Image.file(
                  File(_backgroundImagePath!),
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryRed.withValues(alpha: 0.15),
                        AppColors.primaryRed.withValues(alpha: 0.15),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Tap to Customize Background',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: widget.colors?.muted ?? Colors.grey,
                      ),
                    ),
                  ),
                ),
              // Customize Button
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => _pickAndCropImage('background'),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.asset(
                      'assets/images/edit.png',
                      color: Colors.white,
                      width: 20,
                      height: 20,
                    ),
                  ),
                ),
              ),
              // Profile Image + Logo
              Positioned(
                bottom: 12,
                left: 12,
                child: Row(
                  children: [
                    // Profile Photo
                    GestureDetector(
                      onTap: () => _pickAndCropImage('profile'),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: _profileImagePath != null
                              ? Image.file(
                                  File(_profileImagePath!),
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.grey.shade300,
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Company Logo
                    GestureDetector(
                      onTap: () => _pickAndCropImage('logo'),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _logoImagePath != null
                              ? Image.file(
                                  File(_logoImagePath!),
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.grey.shade300,
                                  child: const Icon(
                                    Icons.business,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Image Upload Sections
        _buildImageSection(
          title: 'Profile Photo',
          cropType: 'profile',
          imagePath: _profileImagePath,
          description: 'Square crop 512x512',
        ),
        const SizedBox(height: 16),
        _buildImageSection(
          title: 'Company Logo',
          cropType: 'logo',
          imagePath: _logoImagePath,
          description: 'Square crop 512x512',
        ),
        const SizedBox(height: 16),
        _buildImageSection(
          title: 'Background Image',
          cropType: 'background',
          imagePath: _backgroundImagePath,
          description: 'Customize any aspect ratio',
        ),
      ],
    );
  }

  Widget _buildImageSection({
    required String title,
    required String cropType,
    required String? imagePath,
    required String description,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.colors?.border ?? Colors.grey.withValues(alpha: 0.15),
          width: 1.5,
        ),
        color: widget.colors?.card ?? Colors.white,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.colors?.text ?? Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: widget.colors?.muted ?? Colors.grey,
                    ),
                  ),
                ],
              ),
              if (imagePath != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '✓ Done',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _pickAndCropImage(cropType),
              icon: const Icon(Icons.add_photo_alternate),
              label: Text(imagePath == null ? 'Pick & Crop' : 'Change'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
