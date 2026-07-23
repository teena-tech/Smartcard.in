import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/delete_confirm_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../widgets/image_cropper_widget.dart';
import '../../widgets/rich_text_editor_widget.dart';
import '../../widgets/premium_card_widget.dart';

import '../../../viewmodels/theme_viewmodel.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/card_viewmodel.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/upload_url_resolver.dart';
import '../../../models/card_model.dart';
import '../../widgets/circular_profile_avatar.dart';
import '../../widgets/common_drawer.dart';
import '../home_screen.dart';

class ManageCardEditAllScreen extends StatefulWidget {
  final bool isTab;
  const ManageCardEditAllScreen({super.key, this.isTab = false});

  @override
  State<ManageCardEditAllScreen> createState() =>
      _ManageCardEditAllScreenState();
}

class _ManageCardEditAllScreenState extends State<ManageCardEditAllScreen> {
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  // Input Controllers
  late Map<String, dynamic> _controllers;

  List<dynamic> _personalOffices = [];
  String? _selectedPersonalOfficeIndex;
  bool _personalPincodeLoading = false;
  String _personalPincodeError = '';

  List<dynamic> _companyOffices = [];
  String? _selectedCompanyOfficeIndex;
  bool _companyPincodeLoading = false;
  String _companyPincodeError = '';

  @override
  void initState() {
    super.initState();
    _controllers = {};

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initControllers();
    });
  }

  void _initControllers() {
    final viewModel = context.read<CardViewModel>();
    final details = viewModel.selectedCardDetails;
    if (details == null) return;
    final authViewModel = context.read<AuthViewModel>();
    final currentUser = authViewModel.currentUser;

    setState(() {
      // Personal
      _controllers['firstName'] = TextEditingController(
        text: details.firstName.isNotEmpty
            ? details.firstName
            : (currentUser?.firstName ?? ''),
      );
      _controllers['lastName'] = TextEditingController(
        text: details.lastName.isNotEmpty
            ? details.lastName
            : (currentUser?.lastName ?? ''),
      );
      _controllers['email'] = TextEditingController(
        text: details.email.isNotEmpty
            ? details.email
            : (currentUser?.email ?? ''),
      );
      _controllers['phone'] = TextEditingController(
        text: details.phone.isNotEmpty
            ? details.phone
            : (currentUser?.phone ?? ''),
      );
      _controllers['gender'] = details.gender.isEmpty
          ? 'Not-Mention'
          : details.gender;

      // Personal Address
      _controllers['address'] = TextEditingController(text: details.address);
      _controllers['pincode'] = TextEditingController(text: details.pincode);
      _controllers['cityId'] = details.cityId;
      _controllers['stateId'] = details.stateId;
      _controllers['city'] = TextEditingController(text: details.city);
      _controllers['state'] = TextEditingController(text: details.state);
      _controllers['district'] = TextEditingController(text: details.district);

      if (details.pincode.length == 6) {
        _lookupPincode(details.pincode, isPersonal: true);
      }

      // Company Details
      _controllers['companyName'] = TextEditingController(
        text: details.companyName,
      );
      _controllers['designation'] = TextEditingController(
        text: details.designation,
      );
      _controllers['companyAddress'] = TextEditingController(
        text: details.companyAddress,
      );
      _controllers['companyPincode'] = TextEditingController(
        text: details.companyPincode,
      );
      _controllers['companyCityId'] = details.companyCityId;
      _controllers['companyStateId'] = details.companyStateId;
      _controllers['companyCity'] = TextEditingController(
        text: details.companyCity,
      );
      _controllers['companyState'] = TextEditingController(
        text: details.companyState,
      );
      _controllers['companyDistrict'] = TextEditingController(
        text: details.companyDistrict,
      );

      if (details.companyPincode.length == 6) {
        _lookupPincode(details.companyPincode, isPersonal: false);
      }

      // Company Contact (Multiple)
      final emails = details.companyEmails.isEmpty
          ? ['']
          : details.companyEmails;
      final phones = details.contactNumbers.isEmpty
          ? ['']
          : details.contactNumbers;
      final whatsapps = details.whatsappNumbers.isEmpty
          ? ['']
          : details.whatsappNumbers;

      _controllers['emails'] = emails
          .map((e) => TextEditingController(text: e))
          .toList();
      _controllers['phones'] = phones
          .map((p) => TextEditingController(text: p))
          .toList();
      _controllers['whatsapps'] = whatsapps
          .map((w) => TextEditingController(text: w))
          .toList();

      // Social Links
      _controllers['fbLink'] = TextEditingController(text: details.fbLink);
      _controllers['instaLink'] = TextEditingController(
        text: details.instaLink,
      );
      _controllers['linkedin'] = TextEditingController(text: details.linkedin);
      _controllers['xLink'] = TextEditingController(text: details.xLink);

      final webs = details.website.isEmpty
          ? [
              {'name': '', 'url': ''},
            ]
          : details.website;
      _controllers['websites'] = webs
          .map(
            (w) => {
              'name': TextEditingController(text: w['name'] ?? ''),
              'url': TextEditingController(text: w['url'] ?? ''),
            },
          )
          .toList();

      // About & YouTube
      _controllers['about'] = TextEditingController(text: details.aboutCompany);
      final youtubeLink = details.youtubeLinks.isEmpty ? '' : details.youtubeLinks[0];
      _controllers['youtube'] = TextEditingController(text: youtubeLink);
    });
  }

  Future<void> _lookupPincode(
    String pincode, {
    required bool isPersonal,
  }) async {
    if (pincode.length != 6) return;

    setState(() {
      if (isPersonal) {
        _personalPincodeLoading = true;
        _personalPincodeError = '';
        _personalOffices = [];
        _selectedPersonalOfficeIndex = null;
      } else {
        _companyPincodeLoading = true;
        _companyPincodeError = '';
        _companyOffices = [];
        _selectedCompanyOfficeIndex = null;
      }
    });

    final viewModel = context.read<CardViewModel>();
    try {
      final response = await viewModel.fetchPincodeDetails(pincode);
      if (response != null && response['success'] == true) {
        final data = response['data'];
        if (data != null) {
          final officesList = data['offices'] as List? ?? [];
          setState(() {
            if (isPersonal) {
              _personalOffices = officesList;
            } else {
              _companyOffices = officesList;
            }
          });

          // Autofill district and state from top-level response if present
          if (data['district'] != null) {
            if (isPersonal) {
              _controllers['district'].text = data['district'].toString();
            } else {
              _controllers['companyDistrict'].text = data['district'].toString();
            }
          }
          if (data['state'] != null) {
            if (isPersonal) {
              _controllers['state'].text = data['state'].toString();
            } else {
              _controllers['companyState'].text = data['state'].toString();
            }
          }

          final details = viewModel.selectedCardDetails!;
          final currentCityId = isPersonal
              ? details.cityId
              : details.companyCityId;
          final currentCityName =
              (isPersonal ? details.city : details.companyCity)
                  .trim()
                  .toLowerCase();

          int matchedIdx = officesList.indexWhere((o) {
            if (currentCityId.isNotEmpty &&
                o['city_id']?.toString() == currentCityId) {
              return true;
            }
            if (currentCityName.isNotEmpty &&
                o['city']?.toString().trim().toLowerCase() == currentCityName) {
              return true;
            }
            return false;
          });

          if (matchedIdx >= 0) {
            setState(() {
              if (isPersonal) {
                _selectedPersonalOfficeIndex = matchedIdx.toString();
              } else {
                _selectedCompanyOfficeIndex = matchedIdx.toString();
              }
            });
            _applyOfficeSelection(matchedIdx, isPersonal: isPersonal);
          } else if (officesList.length == 1) {
            setState(() {
              if (isPersonal) {
                _selectedPersonalOfficeIndex = '0';
              } else {
                _selectedCompanyOfficeIndex = '0';
              }
            });
            _applyOfficeSelection(0, isPersonal: isPersonal);
          } else if (officesList.isNotEmpty) {
            setState(() {
              if (isPersonal) {
                _selectedPersonalOfficeIndex = '0';
              } else {
                _selectedCompanyOfficeIndex = '0';
              }
            });
            _applyOfficeSelection(0, isPersonal: isPersonal);
          }
        }
      } else {
        setState(() {
          if (isPersonal) {
            _personalPincodeError = 'Pincode details not found.';
          } else {
            _companyPincodeError = 'Pincode details not found.';
          }
        });
      }
    } catch (_) {
      setState(() {
        if (isPersonal) {
          _personalPincodeError = 'Failed to load location details.';
        } else {
          _companyPincodeError = 'Failed to load location details.';
        }
      });
    } finally {
      setState(() {
        if (isPersonal) {
          _personalPincodeLoading = false;
        } else {
          _companyPincodeLoading = false;
        }
      });
    }
  }

  void _applyOfficeSelection(int idx, {required bool isPersonal}) {
    final offices = isPersonal ? _personalOffices : _companyOffices;
    if (idx < 0 || idx >= offices.length) return;
    final office = offices[idx];
    setState(() {
      if (isPersonal) {
        _controllers['cityId'] = office['city_id']?.toString() ?? '';
        _controllers['stateId'] = office['state_id']?.toString() ?? '';
        _controllers['city'].text = office['city']?.toString() ?? '';
        _controllers['state'].text = office['state']?.toString() ?? '';
        _controllers['district'].text = office['district']?.toString() ?? '';
      } else {
        _controllers['companyCityId'] = office['city_id']?.toString() ?? '';
        _controllers['companyStateId'] = office['state_id']?.toString() ?? '';
        _controllers['companyCity'].text = office['city']?.toString() ?? '';
        _controllers['companyState'].text = office['state']?.toString() ?? '';
        _controllers['companyDistrict'].text =
            office['district']?.toString() ?? '';
      }
    });
  }

  Future<String?> _cropImage(String filePath, bool isProfile) async {
    try {
      CroppedFile? croppedFile;
      if (isProfile) {
        croppedFile = await ImageCropperHelper.cropProfileImage(
          filePath,
          context: context,
        );
      } else {
        croppedFile = await ImageCropperHelper.cropCompanyLogo(
          filePath,
          context: context,
        );
      }
      return croppedFile?.path;
    } catch (_) {
      return filePath;
    }
  }

  void _pickAndUploadImage(bool isProfile) {
    _showImageSourceSheet(isProfile);
  }

  Future<XFile?> _pickImageFromSource(ImageSource source) async {
    if (kIsWeb && source == ImageSource.camera) {
      source = ImageSource.gallery;
    }

    try {
      return await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _handlePickAndUpload(bool isProfile, ImageSource source) async {
    final viewModel = context.read<CardViewModel>();
    final image = await _pickImageFromSource(source);
    if (image == null || !context.mounted) return;

    final croppedPath = await _cropImage(image.path, isProfile);
    if (croppedPath == null || !context.mounted) return;

    // Pop the source sheet first so it doesn't stay behind the confirm sheet
    if (context.mounted) {
      Navigator.pop(context);
    }

    // ── Show confirmation preview with OK button ──
    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ImageConfirmSheet(
        imagePath: croppedPath,
        isProfile: isProfile,
        userId: viewModel.userId,
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show heartbeat success overlay
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => _HeartbeatSuccessOverlay(
        message: isProfile ? 'Profile updated successfully!' : 'Logo updated successfully!',
      ),
    );
  }

  void _showImageSourceSheet(bool isProfile) {
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
                isProfile ? 'Upload Profile Photo' : 'Upload Company Logo',
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
                  _handlePickAndUpload(isProfile, ImageSource.camera);
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
                  _handlePickAndUpload(isProfile, ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _saveAndOpenLivePreview() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all required fields')),
      );
      return;
    }

    final viewModel = context.read<CardViewModel>();
    final details = viewModel.selectedCardDetails!;

    // Save Personal
    details.firstName = _controllers['firstName'].text.trim();
    details.lastName = _controllers['lastName'].text.trim();
    details.email = _controllers['email'].text.trim();
    details.phone = _controllers['phone'].text.trim();
    details.gender = _controllers['gender'];

    // Save Address
    details.address = _controllers['address'].text.trim();
    details.pincode = _controllers['pincode'].text.trim();
    details.cityId = _controllers['cityId'] ?? '';
    details.stateId = _controllers['stateId'] ?? '';
    details.city = _controllers['city'].text.trim();
    details.state = _controllers['state'].text.trim();
    details.district = _controllers['district'].text.trim();
    details.officeSelected =
        details.pincode.isNotEmpty && details.cityId.isNotEmpty;

    // Save Company
    details.companyName = _controllers['companyName'].text.trim();
    details.designation = _controllers['designation'].text.trim();
    details.companyAddress = _controllers['companyAddress'].text.trim();
    details.companyPincode = _controllers['companyPincode'].text.trim();
    details.companyCityId = _controllers['companyCityId'] ?? '';
    details.companyStateId = _controllers['companyStateId'] ?? '';
    details.companyCity = _controllers['companyCity'].text.trim();
    details.companyState = _controllers['companyState'].text.trim();
    details.companyDistrict = _controllers['companyDistrict'].text.trim();
    details.companyOfficeSelected =
        details.companyPincode.isNotEmpty && details.companyCityId.isNotEmpty;

    // Save Company Contact
    details.companyEmails =
        (_controllers['emails'] as List<TextEditingController>)
            .map((e) => e.text.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    details.contactNumbers =
        (_controllers['phones'] as List<TextEditingController>)
            .map((p) => p.text.trim())
            .where((p) => p.isNotEmpty)
            .toList();
    details.whatsappNumbers =
        (_controllers['whatsapps'] as List<TextEditingController>)
            .map((w) => w.text.trim())
            .where((w) => w.isNotEmpty)
            .toList();

    // Save Socials
    details.fbLink = _controllers['fbLink'].text.trim();
    details.instaLink = _controllers['instaLink'].text.trim();
    details.linkedin = _controllers['linkedin'].text.trim();
    details.xLink = _controllers['xLink'].text.trim();
    details.website = (_controllers['websites'] as List)
        .map(
          (w) => {
            'name': (w['name'] as TextEditingController).text.trim(),
            'url': (w['url'] as TextEditingController).text.trim(),
          },
        )
        .where((w) => w['url']!.isNotEmpty)
        .toList();

    // Save About & YouTube
    details.aboutCompany = _controllers['about'].text.trim();
    details.youtubeLinks = [_controllers['youtube'].text.trim()];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
    );

    final success = await viewModel.handleFormSubmit();
    if (context.mounted) {
      Navigator.pop(context); // Close loading spinner
    }

    if (success) {
      final card = viewModel.currentCard;
      final liveLink = (card?.qrCode != null && card!.qrCode!.isNotEmpty)
          ? card.qrCode!
          : 'https://thesmartcards.in/profile/${card?.userId ?? viewModel.userId}';

      try {
        final uri = Uri.parse(liveLink);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen(initialIndex: 0)),
          (route) => false,
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save details for preview.')),
        );
      }
    }
  }

  void _saveAll() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all required fields')),
      );
      return;
    }

    final viewModel = context.read<CardViewModel>();
    final details = viewModel.selectedCardDetails!;

    // Save Personal
    details.firstName = _controllers['firstName'].text.trim();
    details.lastName = _controllers['lastName'].text.trim();
    details.email = _controllers['email'].text.trim();
    details.phone = _controllers['phone'].text.trim();
    details.gender = _controllers['gender'];

    // Save Address
    details.address = _controllers['address'].text.trim();
    details.pincode = _controllers['pincode'].text.trim();
    details.cityId = _controllers['cityId'] ?? '';
    details.stateId = _controllers['stateId'] ?? '';
    details.city = _controllers['city'].text.trim();
    details.state = _controllers['state'].text.trim();
    details.district = _controllers['district'].text.trim();
    details.officeSelected =
        details.pincode.isNotEmpty && details.cityId.isNotEmpty;

    // Save Company
    details.companyName = _controllers['companyName'].text.trim();
    details.designation = _controllers['designation'].text.trim();
    details.companyAddress = _controllers['companyAddress'].text.trim();
    details.companyPincode = _controllers['companyPincode'].text.trim();
    details.companyCityId = _controllers['companyCityId'] ?? '';
    details.companyStateId = _controllers['companyStateId'] ?? '';
    details.companyCity = _controllers['companyCity'].text.trim();
    details.companyState = _controllers['companyState'].text.trim();
    details.companyDistrict = _controllers['companyDistrict'].text.trim();
    details.companyOfficeSelected =
        details.companyPincode.isNotEmpty && details.companyCityId.isNotEmpty;

    // Save Company Contact
    details.companyEmails =
        (_controllers['emails'] as List<TextEditingController>)
            .map((e) => e.text.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    details.contactNumbers =
        (_controllers['phones'] as List<TextEditingController>)
            .map((p) => p.text.trim())
            .where((p) => p.isNotEmpty)
            .toList();
    details.whatsappNumbers =
        (_controllers['whatsapps'] as List<TextEditingController>)
            .map((w) => w.text.trim())
            .where((w) => w.isNotEmpty)
            .toList();

    // Save Socials
    details.fbLink = _controllers['fbLink'].text.trim();
    details.instaLink = _controllers['instaLink'].text.trim();
    details.linkedin = _controllers['linkedin'].text.trim();
    details.xLink = _controllers['xLink'].text.trim();
    details.website = (_controllers['websites'] as List)
        .map(
          (w) => {
            'name': (w['name'] as TextEditingController).text.trim(),
            'url': (w['url'] as TextEditingController).text.trim(),
          },
        )
        .where((w) => w['url']!.isNotEmpty)
        .toList();

    // Save About & YouTube
    details.aboutCompany = _controllers['about'].text.trim();
    details.youtubeLinks = [_controllers['youtube'].text.trim()];

    final success = await viewModel.handleFormSubmit();
    if (success && context.mounted) {
      Navigator.pop(context);
    }
  }

  void _deleteCard() async {
    final confirmed = await showDeleteConfirmDialog(
      context: context,
      title: 'Delete Card',
      message: 'Are you sure you want to delete this card?',
    );

    if (confirmed == true && context.mounted) {
      final viewModel = context.read<CardViewModel>();
      await viewModel.handleDeleteCard();
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showLivePreviewModal(BuildContext context, CardModel card) {
    showDialog(
      context: context,
      builder: (context) {
        final linkToDisplay = (card.qrCode != null && card.qrCode!.isNotEmpty) 
            ? card.qrCode! 
            : 'https://www.google.com';

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.red, width: 2),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Live Card Preview',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  PremiumCardWidget(card: card),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: QrImageView(
                      data: linkToDisplay,
                      version: QrVersions.auto,
                      size: 140,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Scan or visit card link:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      try {
                        final uri = Uri.parse(linkToDisplay);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      } catch (_) {}
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        linkToDisplay,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'CLOSE',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controllers.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final themeViewModel = context.watch<ThemeViewModel>();
    final colors = themeViewModel.colors;
    final viewModel = context.watch<CardViewModel>();

    final profileUrl = UploadUrlResolver.resolve(
      viewModel.selectedCardDetails?.profileImageName,
      type: 'profile',
    );
    final logoUrl = UploadUrlResolver.resolve(
      viewModel.selectedCardDetails?.companyLogoName,
      type: 'logo',
    );

    final emails = _controllers['emails'] as List<TextEditingController>;
    final phones = _controllers['phones'] as List<TextEditingController>;
    final whatsapps = _controllers['whatsapps'] as List<TextEditingController>;
    final webs = _controllers['websites'] as List;

    return Scaffold(
      backgroundColor: widget.isTab ? Colors.transparent : colors.backgroundStart,
      drawer: widget.isTab ? null : const CommonDrawer(currentRoute: 'Manage Card'),
      // Custom gradient header replacing AppBar for premium look
      appBar: widget.isTab ? null : PreferredSize(
        preferredSize: const Size.fromHeight(200),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryRed, AppColors.secondaryRed],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Manage Card',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Spacer(),
                  if (viewModel.canDeleteSelectedCard)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white),
                      onPressed: _deleteCard,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: IgnorePointer(
          ignoring: viewModel.isSuspended,
          child: Opacity(
            opacity: viewModel.isSuspended ? 0.6 : 1.0,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [


            // Personal Section
            _buildSectionTitle('Personal Details', colors),
            _buildTextFormField(
              _controllers['firstName'],
              'First Name *',
              colors,
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            _buildTextFormField(
              _controllers['lastName'],
              'Last Name *',
              colors,
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            _buildTextFormField(
              _controllers['email'],
              'Email *',
              colors,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            _buildTextFormField(
              _controllers['phone'],
              'Phone *',
              colors,
              keyboardType: TextInputType.phone,
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            _buildInputLabel('Gender', colors),
            DropdownButtonFormField<String>(
              initialValue: _controllers['gender'],
              dropdownColor: colors.panel,
              style: GoogleFonts.inter(color: colors.text, fontSize: 14),
              decoration: _getInputDecoration('', colors),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(
                  value: 'Transgender',
                  child: Text('Transgender'),
                ),
                DropdownMenuItem(
                  value: 'Not-Mention',
                  child: Text('Not Mention'),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _controllers['gender'] = val;
                });
              },
            ),
            _buildTextFormField(
              _controllers['designation'],
              'Designation *',
              colors,
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),

            const SizedBox(height: 24),

            // Personal Address Section
            _buildSectionTitle('Personal Address', colors),
            _buildTextFormField(
              _controllers['address'],
              'Personal Address',
              colors,
              maxLines: 3,
            ),
            _buildTextFormField(
              _controllers['pincode'],
              'Pincode *',
              colors,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: (val) {
                if (val.length == 6) {
                  _lookupPincode(val, isPersonal: true);
                }
              },
              validator: (v) => v!.length != 6 ? 'Must be 6 digits' : null,
            ),
            if (_personalPincodeLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: LinearProgressIndicator(color: AppColors.primaryRed),
              ),
            if (_personalPincodeError.isNotEmpty)
              Text(
                _personalPincodeError,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            if (_personalOffices.isNotEmpty) ...[
              _buildInputLabel('Select City / Office', colors),
              DropdownButtonFormField<String>(
                initialValue: _selectedPersonalOfficeIndex,
                dropdownColor: colors.panel,
                style: GoogleFonts.inter(color: colors.text, fontSize: 14),
                decoration: _getInputDecoration('Office / City', colors),
                items: _personalOffices.asMap().entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key.toString(),
                    child: Text(e.value['city'] ?? ''),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedPersonalOfficeIndex = val;
                  });
                  if (val != null) {
                    _applyOfficeSelection(int.parse(val), isPersonal: true);
                  }
                },
              ),
            ],
            _buildTextFormField(
              _controllers['district'],
              'District',
              colors,
            ),
            _buildTextFormField(
              _controllers['state'],
              'State',
              colors,
            ),

            const SizedBox(height: 24),

            _buildSectionTitle('Company / Business Details', colors),
            _buildTextFormField(
              _controllers['companyName'],
              'Company Name',
              colors,
            ),
            _buildTextFormField(
              _controllers['companyAddress'],
              'Professional Address',
              colors,
              maxLines: 3,
            ),
            _buildTextFormField(
              _controllers['companyPincode'],
              'Company Pincode *',
              colors,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: (val) {
                if (val.length == 6) {
                  _lookupPincode(val, isPersonal: false);
                }
              },
              validator: (v) => v!.length != 6 ? 'Must be 6 digits' : null,
            ),
            if (_companyPincodeLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: LinearProgressIndicator(color: AppColors.primaryRed),
              ),
            if (_companyPincodeError.isNotEmpty)
              Text(
                _companyPincodeError,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            if (_companyOffices.isNotEmpty) ...[
              _buildInputLabel('Select Company City / Office', colors),
              DropdownButtonFormField<String>(
                initialValue: _selectedCompanyOfficeIndex,
                dropdownColor: colors.panel,
                style: GoogleFonts.inter(color: colors.text, fontSize: 14),
                decoration: _getInputDecoration('Office / City', colors),
                items: _companyOffices.asMap().entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key.toString(),
                    child: Text(e.value['city'] ?? ''),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCompanyOfficeIndex = val;
                  });
                  if (val != null) {
                    _applyOfficeSelection(int.parse(val), isPersonal: false);
                  }
                },
              ),
            ],
            _buildTextFormField(
              _controllers['companyDistrict'],
              'Company District',
              colors,
            ),
            _buildTextFormField(
              _controllers['companyState'],
              'Company State',
              colors,
            ),
            const SizedBox(height: 24),

            // Professional Contact Section
            _buildSectionTitle('Professional Contact Details', colors),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInputLabel('Professional Emails', colors),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () {
                    setState(() {
                      emails.add(TextEditingController());
                    });
                  },
                ),
              ],
            ),
            ...emails.asMap().entries.map((e) {
              return Row(
                children: [
                  Expanded(
                    child: _buildTextFormField(
                      e.value,
                      'Email address',
                      colors,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle,
                      color: Colors.redAccent,
                    ),
                    onPressed: () {
                      setState(() {
                        emails.removeAt(e.key);
                      });
                    },
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInputLabel('Contact Numbers', colors),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () {
                    setState(() {
                      phones.add(TextEditingController());
                    });
                  },
                ),
              ],
            ),
            ...phones.asMap().entries.map((e) {
              return Row(
                children: [
                  Expanded(
                    child: _buildTextFormField(
                      e.value,
                      'Phone (10 digits)',
                      colors,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      validator: (v) => v!.trim().isNotEmpty && v.trim().length != 10 ? 'Must be 10 digits' : null,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle,
                      color: Colors.redAccent,
                    ),
                    onPressed: () {
                      setState(() {
                        phones.removeAt(e.key);
                      });
                    },
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInputLabel('WhatsApp Numbers', colors),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () {
                    setState(() {
                      whatsapps.add(TextEditingController());
                    });
                  },
                ),
              ],
            ),
            ...whatsapps.asMap().entries.map((e) {
              return Row(
                children: [
                  Expanded(
                    child: _buildTextFormField(
                      e.value,
                      'WhatsApp (10 digits)',
                      colors,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      validator: (v) => v!.trim().isNotEmpty && v.trim().length != 10 ? 'Must be 10 digits' : null,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle,
                      color: Colors.redAccent,
                    ),
                    onPressed: () {
                      setState(() {
                        whatsapps.removeAt(e.key);
                      });
                    },
                  ),
                ],
              );
            }),

            const SizedBox(height: 24),

            _buildSectionTitle('Social Links', colors),
            _buildTextFormField(
              _controllers['fbLink'],
              'Facebook URL',
              colors,
              keyboardType: TextInputType.url,
            ),
            _buildTextFormField(
              _controllers['instaLink'],
              'Instagram URL',
              colors,
              keyboardType: TextInputType.url,
            ),
            _buildTextFormField(
              _controllers['linkedin'],
              'LinkedIn URL',
              colors,
              keyboardType: TextInputType.url,
            ),
            _buildTextFormField(
              _controllers['xLink'],
              'X (Twitter) URL',
              colors,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInputLabel('Websites', colors),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () {
                    setState(() {
                      webs.add({
                        'name': TextEditingController(),
                        'url': TextEditingController(),
                      });
                    });
                  },
                ),
              ],
            ),
            ...webs.asMap().entries.map((e) {
              final nameCtrl = e.value['name'] as TextEditingController;
              final urlCtrl = e.value['url'] as TextEditingController;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextFormField(
                        nameCtrl,
                        'Name (e.g. Work)',
                        colors,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: _buildTextFormField(
                        urlCtrl,
                        'URL Link',
                        colors,
                        keyboardType: TextInputType.url,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle,
                        color: Colors.redAccent,
                      ),
                      onPressed: () {
                        setState(() {
                          webs.removeAt(e.key);
                        });
                      },
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 24),

            // About Section
            RichTextEditorWidget(
              controller: _controllers['about'],
            ),

            const SizedBox(height: 24),

            _buildSectionTitle('YouTube Video', colors),
            _buildTextFormField(
              _controllers['youtube'],
              'Video Link',
              colors,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 12.0,
            bottom: 28.0, // Increased bottom padding to lift buttons higher
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryRed,
                          side: BorderSide(
                              color: viewModel.isSuspended ? Colors.grey : AppColors.primaryRed, 
                              width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(Icons.visibility, color: viewModel.isSuspended ? Colors.grey : null),
                        label: Text(
                          'Preview',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: viewModel.isSuspended ? Colors.grey : null,
                          ),
                        ),
                        onPressed: viewModel.isSuspended ? null : _saveAndOpenLivePreview,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: viewModel.isSuspended ? Colors.grey : AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: (viewModel.isSaving || viewModel.isSuspended) ? null : _saveAll,
                        child: Text(
                          viewModel.isSaving ? 'Saving...' : 'Save Details',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (viewModel.currentCard != null && !viewModel.currentCard!.isTemporary)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Delete Button
                      if (viewModel.canDeleteSelectedCard)
                        TextButton.icon(
                          onPressed: _deleteCard,
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: Text(
                            'Delete',
                            style: GoogleFonts.inter(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      
                      // Suspend/Unsuspend Button
                      TextButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(viewModel.isSuspended ? 'Unsuspend Card' : 'Suspend Card'),
                              content: Text(
                                viewModel.isSuspended 
                                  ? 'Are you sure you want to unsuspend this card and make it active again?' 
                                  : 'Are you sure you want to suspend this card? It will be hidden from the public.'
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: viewModel.isSuspended ? Colors.green : Colors.orange,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    viewModel.handleToggleSuspension();
                                  },
                                  child: Text(viewModel.isSuspended ? 'Unsuspend' : 'Suspend', style: const TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: Icon(
                          viewModel.isSuspended ? Icons.play_circle_outline : Icons.pause_circle_outline, 
                          color: viewModel.isSuspended ? Colors.green : Colors.orange
                        ),
                        label: Text(
                          viewModel.isSuspended ? 'Unsuspend' : 'Suspend',
                          style: GoogleFonts.inter(
                            color: viewModel.isSuspended ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: colors.text,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInputLabel(String text, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 6.0),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: colors.muted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _getInputDecoration(String hintText, AppColors colors) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: colors.section,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryRed),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    );
  }

  Widget _buildTextFormField(
    TextEditingController controller,
    String label,
    AppColors colors, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
    bool readOnly = false,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        style: GoogleFonts.inter(color: colors.text, fontSize: 14),
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        readOnly: readOnly,
        validator: validator,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: colors.muted, fontSize: 14),
          filled: true,
          fillColor: readOnly
              ? colors.section.withValues(alpha: 0.15)
              : colors.section,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryRed),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

// ── Image Confirm Sheet ──────────────────────────────────────
class _ImageConfirmSheet extends StatefulWidget {
  final String imagePath;
  final bool isProfile;
  final String userId;

  const _ImageConfirmSheet({
    required this.imagePath,
    required this.isProfile,
    required this.userId,
  });

  @override
  State<_ImageConfirmSheet> createState() => _ImageConfirmSheetState();
}

class _ImageConfirmSheetState extends State<_ImageConfirmSheet> with SingleTickerProviderStateMixin {
  bool _isUploading = false;
  late AnimationController _animationController;
  late Animation<double> _borderAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _borderAnimation = Tween<double>(begin: 0.1, end: 0.8).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = kIsWeb
        ? Image.network(widget.imagePath, fit: BoxFit.cover)
        : Image.file(File(widget.imagePath), fit: BoxFit.cover);

    final title = widget.isProfile ? 'Confirm Profile Photo' : 'Confirm Company Logo';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Are you sure you want to upload this photo?',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _borderAnimation,
            builder: (context, child) {
              if (widget.isProfile) {
                // Profile: circle shape
                return Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryRed.withValues(alpha: _borderAnimation.value),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryRed.withValues(alpha: _borderAnimation.value * 0.4),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipOval(child: imageWidget),
                );
              } else {
                // Logo: square shape with rounded corners
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulsing border container
                    Container(
                      width: 164,
                      height: 164,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryRed.withValues(alpha: _borderAnimation.value),
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryRed.withValues(alpha: _borderAnimation.value * 0.4),
                            blurRadius: 16,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    // Square image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 156,
                        height: 156,
                        child: imageWidget,
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isUploading ? null : () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _handleUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'OK',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _handleUpload() async {
    setState(() {
      _isUploading = true;
    });

    final cardVm = context.read<CardViewModel>();

    try {
      if (widget.isProfile) {
        await cardVm.handleUploadProfileImage(widget.imagePath, null);
      } else {
        await cardVm.handleUploadCompanyLogo(widget.imagePath, null);
      }

      // Bust image url cache immediately
      UploadUrlResolver.bustCache();

      if (context.mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: Colors.red.shade600,
        ));
      }
    }
  }
}

// ── Heartbeat Success Overlay ───────────────────────────────
class _HeartbeatSuccessOverlay extends StatefulWidget {
  final String message;
  const _HeartbeatSuccessOverlay({required this.message});

  @override
  State<_HeartbeatSuccessOverlay> createState() => _HeartbeatSuccessOverlayState();
}

class _HeartbeatSuccessOverlayState extends State<_HeartbeatSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);

    // Auto dismiss after 2 seconds
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.favorite,
                    color: Colors.redAccent,
                    size: 50,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

