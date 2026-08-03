import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart'
    hide ImageSource;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../viewmodels/dashboard_viewmodel.dart';
import '../../../viewmodels/theme_viewmodel.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/card_viewmodel.dart';
import '../../../models/card_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/upload_url_resolver.dart';
import '../../widgets/manage_cards/widgets/manage_cards_header.dart';
import '../../widgets/manage_cards/widgets/manage_cards_summary.dart';
import '../../widgets/manage_cards/widgets/manage_cards_edit_sheet.dart';
import '../../widgets/image_confirm_sheet.dart';
import '../../widgets/image_cropper_widget.dart';

class ManageCardsScreen extends StatefulWidget {
  final bool isTab;
  const ManageCardsScreen({super.key, this.isTab = false});

  @override
  State<ManageCardsScreen> createState() => _ManageCardsScreenState();
}

class _ManageCardsScreenState extends State<ManageCardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = context.read<AuthViewModel>();
      final user = authViewModel.currentUser;
      if (user != null) {
        final name = '${user.firstName ?? ""} ${user.lastName ?? ""}'.trim();
        context.read<CardViewModel>().init(
          userId: user.id ?? "",
          fallbackName: name,
          fallbackPhone: user.phone ?? "",
          fallbackEmail: user.email,
        );
      }
    });
  }

  Future<String?> _cropImage(String filePath, bool isProfile) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: filePath,
        aspectRatio: isProfile
            ? const CropAspectRatio(ratioX: 1.0, ratioY: 1.0)
            : null,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: AppColors.primaryRed,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: isProfile
                ? CropAspectRatioPreset.square
                : CropAspectRatioPreset.original,
            lockAspectRatio: isProfile,
          ),
          IOSUiSettings(title: 'Crop Image', aspectRatioLockEnabled: isProfile),
        ],
      );
      return croppedFile?.path;
    } catch (_) {
      return filePath;
    }
  }

  String _resolveImgUrl(String? filename, String type, String userId) {
    return UploadUrlResolver.resolve(filename, type: type);
  }

  Future<void> _pickAndCropImage(String sectionId, ImageSource source) async {
    if (kIsWeb && source == ImageSource.camera) source = ImageSource.gallery;
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null || !context.mounted) return;

      final viewModel = context.read<CardViewModel>();
      CroppedFile? croppedFile;

      if (sectionId == 'section-profile-image') {
        croppedFile = await ImageCropperHelper.cropProfileImage(
          picked.path,
          context: context,
        );
      } else if (sectionId == 'section-company-logo') {
        croppedFile = await ImageCropperHelper.cropCompanyLogo(
          picked.path,
          context: context,
        );
      }

      if (croppedFile != null && context.mounted) {
        final bool? confirmed = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => ImageConfirmSheet(
            imagePath: picked.path,
            croppedPath: croppedFile!.path,
            title: sectionId == 'section-profile-image'
                ? 'Confirm Profile Photo'
                : 'Confirm Company Logo',
            onConfirm: (finalPath) async {
              try {
                if (sectionId == 'section-profile-image') {
                  await viewModel.handleUploadProfileImage(finalPath, null);
                } else {
                  await viewModel.handleUploadCompanyLogo(finalPath, null);
                }
                return true;
              } catch (_) {
                return false;
              }
            },
          ),
        );

        if (confirmed == true && context.mounted) {
          showGeneralDialog(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black54,
            transitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (_, _, _) => HeartbeatSuccessOverlay(
              message: sectionId == 'section-profile-image'
                  ? 'Profile photo uploaded!'
                  : 'Company logo uploaded!',
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourceSheet(String sectionId) {
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
                sectionId == 'section-profile-image'
                    ? 'Change Profile Photo'
                    : 'Change Company Logo',
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
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.primaryRed,
                  ),
                ),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndCropImage(sectionId, ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primaryRed,
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndCropImage(sectionId, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.delete_outline, color: Colors.red.shade600),
                ),
                title: Text(
                  sectionId == 'section-profile-image' ? 'Remove Photo' : 'Remove Logo',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    color: Colors.red.shade600,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final viewModel = context.read<CardViewModel>();
                  final authVm = context.read<AuthViewModel>();
                  final currentUserId = authVm.currentUser?.id.toString() ?? viewModel.userId;
                  if (sectionId == 'section-profile-image') {
                    await viewModel.handleRemoveProfileImage(currentUserId);
                    if (context.mounted && authVm.currentUser != null) {
                      authVm.updateUser(authVm.currentUser!.copyWith(profileImage: ''));
                    }
                  } else {
                    await viewModel.handleRemoveCompanyLogo(currentUserId);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, String sectionId) {
    if (sectionId == 'section-profile-image' ||
        sectionId == 'section-company-logo') {
      _showImageSourceSheet(sectionId);
      return;
    }

    final viewModel = context.read<CardViewModel>();
    viewModel.openSection(sectionId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SectionEditSheet(
          sectionId: sectionId,
          cropImageCallback: _cropImage,
          resolveImgUrlCallback: _resolveImgUrl,
        );
      },
    ).then((_) {
      viewModel.closeSection(keepChanges: false);
    });
  }

  Widget _buildSuspendButton(BuildContext context, CardViewModel viewModel) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: viewModel.isSuspended ? Colors.green : Colors.orange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: viewModel.isBusy
          ? null
          : () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(viewModel.isSuspended ? 'Unsuspend Card' : 'Suspend Card'),
                  content: Text(
                    viewModel.isSuspended
                        ? 'Are you sure you want to unsuspend this card? It will become active again.'
                        : 'Are you sure you want to suspend this card? All actions will be disabled until unsuspended.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await viewModel.handleToggleSuspension();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: viewModel.isSuspended ? Colors.green : Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(viewModel.isSuspended ? 'Unsuspend' : 'Suspend'),
                    ),
                  ],
                ),
              );
            },
      icon: Icon(
        viewModel.isSuspended ? Icons.play_circle_outline : Icons.pause_circle_outline,
        size: 18,
      ),
      label: Text(viewModel.isSuspended ? 'Unsuspend' : 'Suspend'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeViewModel = context.watch<ThemeViewModel>();
    final colors = themeViewModel.colors;
    final viewModel = context.watch<CardViewModel>();

    // Listen for error/success messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (viewModel.errorMessage != null &&
          viewModel.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.errorMessage!),
            backgroundColor: Colors.redAccent,
          ),
        );
        viewModel.clearMessages();
      }
      if (viewModel.successMessage.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.successMessage),
            backgroundColor: Colors.green,
          ),
        );
        viewModel.clearMessages();
      }
    });

    if (viewModel.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryRed),
      );
    }

    final cards = viewModel.cards;
    final currentCard = viewModel.currentCard;
    final details = viewModel.selectedCardDetails ??
        (currentCard != null
            ? CardProfileDetails(
                firstName: currentCard.name,
                companyName: currentCard.companyName,
                email: currentCard.email ?? '',
                phone: currentCard.phone,
                profileImageName: currentCard.profileImageName ?? '',
                companyLogoName: currentCard.companyLogo ?? '',
              )
            : null);
    final logoUrl = details != null
        ? _resolveImgUrl(details.companyLogoName, 'logo', viewModel.userId)
        : '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: null,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/login.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
            // Tabs Row

            // Main Editor Panel
            Expanded(
              child: details == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.primaryRed,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load card details',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32.0,
                            ),
                            child: Text(
                              'Please check your connection and ensure the backend server is running.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: colors.muted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () {
                              final authViewModel = context
                                  .read<AuthViewModel>();
                              final user = authViewModel.currentUser;
                              if (user != null) {
                                final name =
                                    '${user.firstName ?? ""} ${user.lastName ?? ""}'
                                        .trim();
                                viewModel.init(
                                  userId: user.id ?? "",
                                  fallbackName: name,
                                  fallbackPhone: user.phone ?? "",
                                  fallbackEmail: user.email,
                                );
                              } else if (viewModel.userId.isNotEmpty) {
                                viewModel.fetchCards(viewModel.userId);
                              }
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(
                              'Retry',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          IgnorePointer(
                            ignoring: viewModel.isSuspended,
                            child: Opacity(
                              opacity: viewModel.isSuspended ? 0.6 : 1.0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Card Profile Preview Header
                                  buildProfileHeader(
                            context,
                            viewModel,
                            details,
                            colors,
                            _resolveImgUrl,
                            _showEditSheet,
                          ),

                          Transform.translate(
                            offset: const Offset(0, -16),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(18),
                                ),
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                14.0,
                                18.0,
                                14.0,
                                30.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // ORG CARD - rectangular card style
                                  Column(
                                    children: [
                                      Stack(
                                        alignment: Alignment.bottomRight,
                                        children: [
                                          Container(
                                            width: 220,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: Center(
                                              child: logoUrl.isNotEmpty
                                                  ? Image.network(
                                                      logoUrl,
                                                      fit: BoxFit.contain,
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) => Center(
                                                            child: Icon(
                                                              Icons
                                                                  .broken_image,
                                                              color: Colors
                                                                  .grey
                                                                  .shade400,
                                                              size: 36,
                                                            ),
                                                          ),
                                                    )
                                                  : Text(
                                                      details
                                                              .companyName
                                                              .isNotEmpty
                                                          ? details.companyName
                                                                .substring(0, 1)
                                                                .toUpperCase()
                                                          : (details
                                                                    .firstName
                                                                    .isNotEmpty
                                                                ? details
                                                                      .firstName
                                                                      .substring(
                                                                        0,
                                                                        1,
                                                                      )
                                                                      .toUpperCase()
                                                                : 'C'),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 24,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          Transform.translate(
                                            offset: const Offset(8, 8),
                                            child: GestureDetector(
                                              onTap: () => _showEditSheet(
                                                context,
                                                'section-company-logo',
                                              ),
                                              child: Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryRed,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.camera_alt,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        details.companyName.isNotEmpty
                                            ? details.companyName
                                            : 'Add Company Details',
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: details.companyName.isNotEmpty
                                              ? const Color(0xFF1A1A1A)
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  // Professional Details Card
                                  buildSummaryCard(
                                    title: 'Professional Details',
                                    hasContent:
                                        viewModel
                                            .selectedCardDetails!
                                            .companyName
                                            .isNotEmpty ||
                                        viewModel
                                            .selectedCardDetails!
                                            .designation
                                            .isNotEmpty,
                                    onEdit: () => _showEditSheet(
                                      context,
                                      'section-company',
                                    ),
                                    colors: colors,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (details.companyName.isNotEmpty)
                                          buildFieldRow(
                                            icon: Icons.business,
                                            label: 'Organisation',
                                            value: details.companyName,
                                            iconColor: const Color(0xFFD32F2F),
                                            iconBg: const Color(0xFFFCF0F0),
                                          ),
                                        if (details.designation.isNotEmpty)
                                          buildFieldRow(
                                            icon: Icons.work_outline,
                                            label: 'Designation',
                                            value: details.designation,
                                            iconColor: const Color(0xFFD32F2F),
                                            iconBg: const Color(0xFFFCF0F0),
                                          ),
                                        if (details.companyAddress.isNotEmpty ||
                                            details
                                                .companyDistrict
                                                .isNotEmpty ||
                                            details.companyState.isNotEmpty)
                                          buildFieldRow(
                                            icon: Icons.location_on_outlined,
                                            label: 'Address',
                                            value:
                                                [
                                                      if (details
                                                          .companyAddress
                                                          .isNotEmpty)
                                                        details.companyAddress,
                                                      [
                                                            if (details
                                                                .companyDistrict
                                                                .isNotEmpty)
                                                              details
                                                                  .companyDistrict
                                                            else if (details
                                                                .companyCity
                                                                .isNotEmpty)
                                                              details
                                                                  .companyCity,
                                                            if (details
                                                                .companyState
                                                                .isNotEmpty)
                                                              details
                                                                  .companyState,
                                                          ]
                                                          .where(
                                                            (s) => s.isNotEmpty,
                                                          )
                                                          .join(', '),
                                                    ]
                                                    .where((s) => s.isNotEmpty)
                                                    .join('\n'),
                                            iconColor: const Color(0xFFD32F2F),
                                            iconBg: const Color(0xFFFCF0F0),
                                          ),
                                        if (details.companyPincode.isNotEmpty)
                                          buildFieldRow(
                                            icon: Icons.pin_drop_outlined,
                                            label: 'Pin Code',
                                            value: details.companyPincode,
                                            iconColor: const Color(0xFFD32F2F),
                                            iconBg: const Color(0xFFFCF0F0),
                                          ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // Professional Address Card
                                  buildSummaryCard(
                                    title: 'Professional Address',
                                    hasContent:
                                        details.address.isNotEmpty ||
                                        details.pincode.isNotEmpty ||
                                        details.district.isNotEmpty ||
                                        details.state.isNotEmpty,
                                    onEdit: () => _showEditSheet(
                                      context,
                                      'section-address',
                                    ),
                                    colors: colors,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (details.address.isNotEmpty ||
                                            details.district.isNotEmpty ||
                                            details.state.isNotEmpty)
                                          buildFieldRow(
                                            icon: Icons.location_on_outlined,
                                            label: 'Address',
                                            value:
                                                [
                                                      if (details
                                                          .address
                                                          .isNotEmpty)
                                                        details.address,
                                                      [
                                                            if (details
                                                                .district
                                                                .isNotEmpty)
                                                              details.district
                                                            else if (details
                                                                .city
                                                                .isNotEmpty)
                                                              details.city,
                                                            if (details
                                                                .state
                                                                .isNotEmpty)
                                                              details.state,
                                                          ]
                                                          .where(
                                                            (s) => s.isNotEmpty,
                                                          )
                                                          .join(', '),
                                                    ]
                                                    .where((s) => s.isNotEmpty)
                                                    .join('\n'),
                                            iconColor: const Color(0xFFD32F2F),
                                            iconBg: const Color(0xFFFCF0F0),
                                          ),
                                        if (details.pincode.isNotEmpty)
                                          buildFieldRow(
                                            icon: Icons.pin_drop_outlined,
                                            label: 'Pin Code',
                                            value: details.pincode,
                                            iconColor: const Color(0xFFD32F2F),
                                            iconBg: const Color(0xFFFCF0F0),
                                          ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // Professional Contact Details Card
                                  buildSummaryCard(
                                    title: 'Contact Details',
                                    hasContent:
                                        details.companyEmails.isNotEmpty ||
                                        details.contactNumbers.isNotEmpty ||
                                        details.whatsappNumbers.isNotEmpty,
                                    onEdit: () => _showEditSheet(
                                      context,
                                      'section-company-contact',
                                    ),
                                    colors: colors,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ...details.companyEmails
                                            .asMap()
                                            .entries
                                            .map(
                                              (e) => buildFieldRow(
                                                icon: Icons.mail_outline,
                                                label:
                                                    'Email${e.key > 0 ? " ${e.key + 1}" : ""}',
                                                value: e.value,
                                                iconColor: const Color(
                                                  0xFFD32F2F,
                                                ),
                                                iconBg: const Color(0xFFFCF0F0),
                                              ),
                                            ),
                                        ...details.contactNumbers
                                            .asMap()
                                            .entries
                                            .map(
                                              (e) => buildFieldRow(
                                                icon: Icons.phone_outlined,
                                                label:
                                                    'Phone${e.key > 0 ? " ${e.key + 1}" : ""}',
                                                value: e.value,
                                                iconColor: const Color(
                                                  0xFFD32F2F,
                                                ),
                                                iconBg: const Color(0xFFFCF0F0),
                                              ),
                                            ),
                                        ...details.whatsappNumbers
                                            .asMap()
                                            .entries
                                            .map(
                                              (e) => buildFieldRow(
                                                faIcon: FontAwesomeIcons.whatsapp,
                                                label:
                                                    'WhatsApp${e.key > 0 ? " ${e.key + 1}" : ""}',
                                                value: e.value,
                                                iconColor: const Color(
                                                  0xFFD32F2F,
                                                ),
                                                iconBg: const Color(0xFFFCF0F0),
                                              ),
                                            ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // Social Media Card
                                  buildSummaryCard(
                                    title: 'Social Media',
                                    hasContent:
                                        details.fbLink.isNotEmpty ||
                                        details.instaLink.isNotEmpty ||
                                        details.linkedin.isNotEmpty ||
                                        details.xLink.isNotEmpty ||
                                        details.website.isNotEmpty,
                                    onEdit: () => _showEditSheet(
                                      context,
                                      'section-social',
                                    ),
                                    colors: colors,
                                    child: GridView.count(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 2.2,
                                      children: [
                                        if (details.fbLink.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF2F2F2),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.facebook,
                                                      color: Color(0xFF4267B2),
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Facebook',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        color: const Color(
                                                          0xFF888888,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  details.fbLink
                                                      .split('/')
                                                      .last,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color: AppColors.primaryRed,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (details.instaLink.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF2F2F2),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.camera_alt,
                                                      color: Color(0xFFE1306C),
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Instagram',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        color: const Color(
                                                          0xFF888888,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  details.instaLink
                                                      .split('/')
                                                      .last,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color: AppColors.primaryRed,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (details.linkedin.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF2F2F2),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.work,
                                                      color: Color(0xFF0077B5),
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'LinkedIn',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        color: const Color(
                                                          0xFF888888,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  details.linkedin
                                                      .split('/')
                                                      .last,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color: AppColors.primaryRed,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (details.xLink.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF2F2F2),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.close,
                                                      color: Color(0xFF14171A),
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'X / Twitter',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        color: const Color(
                                                          0xFF888888,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  details.xLink.split('/').last,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color: AppColors.primaryRed,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // About Card
                                  buildSummaryCard(
                                    title: 'About',
                                    hasContent: details.aboutCompany.isNotEmpty,
                                    onEdit: () => _showEditSheet(
                                      context,
                                      'section-about',
                                    ),
                                    colors: colors,
                                    child: HtmlWidget(
                                      details.aboutCompany.isNotEmpty
                                          ? details.aboutCompany.replaceAll('\n', '<br>')
                                          : '<span style="color:#999">No about info added yet.</span>',
                                      textStyle: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: colors.text,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // YouTube Card
                                  buildSummaryCard(
                                    title: 'YouTube',
                                    hasContent:
                                        details.youtubeLinks.isNotEmpty &&
                                        details.youtubeLinks[0]
                                            .trim()
                                            .isNotEmpty,
                                    onEdit: () => _showEditSheet(
                                      context,
                                      'section-youtube',
                                    ),
                                    colors: colors,
                                    child: Builder(
                                      builder: (context) {
                                        final link = details.youtubeLinks[0]
                                            .trim();
                                        return _YoutubePreviewWidget(url: link);
                                      },
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // Gallery Card
                                  buildSummaryCard(
                                    title: 'Gallery',
                                    hasContent:
                                        details.existingPhotos.isNotEmpty,
                                    onEdit: () => _showEditSheet(
                                      context,
                                      'section-gallery',
                                    ),
                                    colors: colors,
                                    customButtonText:
                                        details.existingPhotos.isNotEmpty
                                        ? 'Edit'
                                        : '+ Add',
                                    customButtonBg:
                                        details.existingPhotos.isNotEmpty
                                        ? const Color(0xFFFCF0F0)
                                        : const Color(0xFF1A1A1A),
                                    customButtonTextCol:
                                        details.existingPhotos.isNotEmpty
                                        ? AppColors.primaryRed
                                        : Colors.white,
                                    customButtonIcon:
                                        details.existingPhotos.isNotEmpty
                                        ? Icons.edit_outlined
                                        : Icons.add,
                                    child: GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            crossAxisSpacing: 8,
                                            mainAxisSpacing: 8,
                                            childAspectRatio: 1.0,
                                          ),
                                      itemCount: details.existingPhotos.length,
                                      itemBuilder: (context, idx) {
                                        final photo =
                                            details.existingPhotos[idx];
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                              width: 0.5,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.network(
                                              _resolveImgUrl(
                                                photo,
                                                'gallery',
                                                viewModel.userId,
                                              ),
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, _, _) =>
                                                  Container(
                                                    color: colors.section,
                                                    child: Icon(
                                                      Icons.image,
                                                      color: colors.muted,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // ─── Footer Action Buttons (mirrors React UserEditFooterActions) ───
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: viewModel.isPrimaryCardSelected
                                // ── Primary card: only show Suspend/Unsuspend ──
                                ? _buildSuspendButton(context, viewModel)
                                // ── Secondary card: show Make Primary + Delete + Suspend ──
                                : Column(
                                    children: [
                                      // Row 1: Make Primary + Delete
                                      Row(
                                        children: [
                                          if (viewModel.canSetSelectedAsPrimary)
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF4F46E5), // Indigo
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                                onPressed: viewModel.isBusy
                                                    ? null
                                                    : () {
                                                        showDialog(
                                                          context: context,
                                                          builder: (ctx) => AlertDialog(
                                                            title: const Text('Set As Primary Card'),
                                                            content: const Text(
                                                              'Make this your primary card? Your primary card is the one shared by default.',
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () => Navigator.pop(ctx),
                                                                child: const Text('Cancel'),
                                                              ),
                                                              ElevatedButton(
                                                                onPressed: () async {
                                                                  Navigator.pop(ctx);
                                                                  await viewModel.handleSetPrimaryCard();
                                                                },
                                                                style: ElevatedButton.styleFrom(
                                                                  backgroundColor: const Color(0xFF4F46E5),
                                                                  foregroundColor: Colors.white,
                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                                ),
                                                                child: Text(
                                                                  viewModel.isBusy ? 'Updating...' : 'Set Primary',
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                icon: const Icon(Icons.star_outline, size: 18),
                                                label: Text(viewModel.isBusy ? 'Updating...' : 'Make Primary'),
                                              ),
                                            ),
                                          if (viewModel.canSetSelectedAsPrimary && viewModel.canDeleteSelectedCard)
                                            const SizedBox(width: 10),
                                          if (viewModel.canDeleteSelectedCard)
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.primaryRed,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                                onPressed: viewModel.isBusy
                                                    ? null
                                                    : () {
                                                        showDialog(
                                                          context: context,
                                                          builder: (ctx) => AlertDialog(
                                                            title: const Text('Delete Card'),
                                                            content: const Text(
                                                              'Are you sure you want to delete this card? This action cannot be undone.',
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () => Navigator.pop(ctx),
                                                                child: const Text('Cancel'),
                                                              ),
                                                              ElevatedButton(
                                                                onPressed: () async {
                                                                  Navigator.pop(ctx);
                                                                  await viewModel.handleDeleteCard();
                                                                  if (context.mounted) {
                                                                    try {
                                                                      context.read<DashboardViewModel>().setIndex(2);
                                                                    } catch (_) {}
                                                                  }
                                                                },
                                                                style: ElevatedButton.styleFrom(
                                                                  backgroundColor: AppColors.primaryRed,
                                                                  foregroundColor: Colors.white,
                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                                ),
                                                                child: const Text('Delete'),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                icon: const Icon(Icons.delete_outline, size: 18),
                                                label: const Text('Delete'),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      // Row 2: Suspend/Unsuspend (full width)
                                      SizedBox(
                                        width: double.infinity,
                                        child: _buildSuspendButton(context, viewModel),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _YoutubePreviewWidget extends StatefulWidget {
  final String url;
  const _YoutubePreviewWidget({required this.url});

  @override
  State<_YoutubePreviewWidget> createState() => _YoutubePreviewWidgetState();
}

class _YoutubePreviewWidgetState extends State<_YoutubePreviewWidget> {
  YoutubePlayerController? _controller;
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    _initController(widget.url);
  }

  String? _extractVideoId(String url) {
    url = url.trim();
    if (url.isEmpty) return null;

    // Custom regex that handles shorts, youtu.be, and regular URLs with query params like ?si=
    RegExp regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.|m\.)?(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/))((\w|-){11})',
      caseSensitive: false,
      multiLine: false,
    );

    Match? match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    return YoutubePlayerController.convertUrlToId(url);
  }

  void _initController(String url) {
    final videoId = _extractVideoId(url);
    if (videoId == null) {
      _isValid = false;
    } else {
      _isValid = true;
      _controller = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant _YoutubePreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      final videoId = YoutubePlayerController.convertUrlToId(widget.url);
      if (videoId == null) {
        setState(() {
          _isValid = false;
        });
      } else {
        setState(() {
          _isValid = true;
          if (_controller != null) {
            _controller!.loadVideoById(videoId: videoId);
          } else {
            _controller = YoutubePlayerController.fromVideoId(
              videoId: videoId,
              autoPlay: false,
              params: const YoutubePlayerParams(
                showControls: true,
                showFullscreenButton: true,
              ),
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isValid || _controller == null) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Invalid YouTube URL',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        key: ValueKey(widget.url),
        height: 200,
        width: double.infinity,
        child: YoutubePlayer(controller: _controller!),
      ),
    );
  }
}
