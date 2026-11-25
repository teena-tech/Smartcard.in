import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io' show File;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/viewmodel/profile_viewmodel.dart';
import 'package:smartcard_flutter/features/subscription_screen/presentation/viewmodel/subscription_viewmodel.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/presentation/viewmodel/card_viewmodel.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/features/messages_screen/presentation/viewmodel/message_viewmodel.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/viewmodel/dashboard_viewmodel.dart';
import 'package:smartcard_flutter/features/profile_screen/data/models/user_model.dart';
import 'package:smartcard_flutter/core/utils/responsive.dart';
import 'package:smartcard_flutter/core/utils/upload_url_resolver.dart';
import 'package:smartcard_flutter/core/widgets/profile_menu_bottom_sheet.dart';
import 'package:smartcard_flutter/core/widgets/master_app_bar.dart';
import 'package:smartcard_flutter/core/widgets/image_cropper_widget.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/view/widgets/info_card.dart';
import 'package:smartcard_flutter/core/widgets/otp_input_field.dart';
import 'package:smartcard_flutter/core/widgets/delete_confirm_dialog.dart';
import 'package:smartcard_flutter/core/services/otp_autofill_service.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/view/login_screen.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/view/widgets/profile_hero_rect_dialog.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:smartcard_flutter/core/utils/international_phone_helper.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/view/widgets/country_code_dropdown_dialog.dart';



// ═══════════════════════════════════════════════════════════════
// Root Screen
// ═══════════════════════════════════════════════════════════════
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/login.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: const ResponsiveCenter(child: _ProfileBody(showTopBar: true)),
      ),
    );
  }
}

// Public alias — home_screen.dart references ProfileBody by name
class ProfileBody extends ConsumerWidget {
  const ProfileBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/login.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: const ResponsiveCenter(child: _ProfileBody(showTopBar: false)),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  final bool showTopBar;
  const _ProfileBody({this.showTopBar = true});

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  bool get _isWhatsAppFrozen => false;
  bool    _isInit              = false;
  String? _lastPopulatedUserId;

  // ── Form controllers (personal) ─────────────────────────────
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _professionCtrl;
  String _gender = 'Male';
  String _countryCode = '+91';
  String _whatsappCountryCode = '+91';
  String _preferredOtpMethod = 'phone';

  // ── Form controllers (address) ──────────────────────────────
  late final TextEditingController _addressCtrl;
  late final TextEditingController _pincodeCtrl;
  late final TextEditingController _districtCtrl;
  late final TextEditingController _stateCtrl;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController();
    _lastNameCtrl  = TextEditingController();
    _emailCtrl     = TextEditingController();
    _phoneCtrl     = TextEditingController();
    _whatsappCtrl  = TextEditingController();
    _dobCtrl       = TextEditingController();
    _professionCtrl= TextEditingController();
    _addressCtrl   = TextEditingController();
    _pincodeCtrl   = TextEditingController();
    _districtCtrl  = TextEditingController();
    _stateCtrl     = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _dobCtrl.dispose();
    _professionCtrl.dispose();
    _addressCtrl.dispose();
    _pincodeCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profileVm = ref.read(profileViewModelProvider.notifier);
    final authVm    = ref.read(authViewModelProvider.notifier);
    final currentUserId = authVm.currentUser?.id;

    if (!_isInit) {
      if (currentUserId != null) {
        final subVm = ref.read(subscriptionViewModelProvider.notifier);
        if (subVm.subscription == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              subVm.fetchSubscription(currentUserId);
            }
          });
        }
      }
      if (profileVm.user == null &&
          !profileVm.isLoading &&
          currentUserId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          profileVm.loadProfile(currentUserId).then((_) {
            if (!context.mounted) return;
            _populate(ref.read(profileViewModelProvider.notifier).user, notify: true);
            _lastPopulatedUserId = currentUserId;
          });
        });
      } else {
        _populate(profileVm.user, notify: false);
        _lastPopulatedUserId = currentUserId;
      }
      _isInit = true;
      return;
    }

    if (profileVm.user != null &&
        profileVm.user!.id != _lastPopulatedUserId) {
      _populate(profileVm.user, notify: false);
      _lastPopulatedUserId = profileVm.user!.id;
    }
  }

  void _populate(UserModel? u, {bool notify = false}) {
    if (u == null) return;
    _set(_firstNameCtrl,  u.firstName);
    _set(_lastNameCtrl,   u.lastName);
    _set(_emailCtrl,      u.email);
    _set(_dobCtrl,        u.dateOfBirth);
    _set(_professionCtrl, u.profession);
    _set(_addressCtrl,    u.address);
    _set(_pincodeCtrl,    u.pincode);
    _set(_districtCtrl,   u.district);
    _set(_stateCtrl,      u.state);
    if (u.gender != null && u.gender!.isNotEmpty) {
      _gender = _normaliseGender(u.gender!);
    }

    if (u.countryCode != null && u.countryCode!.isNotEmpty) {
      _countryCode = u.countryCode!;
      _set(_phoneCtrl, u.phone);
    } else if (u.phone != null && u.phone!.isNotEmpty) {
      final parsed = InternationalPhoneHelper.parseRaw(u.phone!);
      _countryCode = parsed.countryCode;
      _phoneCtrl.text = parsed.nationalNumber;
    }

    if (u.whatsappNumber != null && u.whatsappNumber!.isNotEmpty) {
      final parsed = InternationalPhoneHelper.parseRaw(u.whatsappNumber!);
      _whatsappCountryCode = parsed.countryCode;
      _whatsappCtrl.text = parsed.nationalNumber;
    } else {
      _whatsappCtrl.text = '';
      _whatsappCountryCode = _countryCode;
    }

    if (u.preferredOtpMethod != null && u.preferredOtpMethod!.isNotEmpty) {
      _preferredOtpMethod = u.preferredOtpMethod!;
    }

    if (notify && mounted) setState(() {});
  }

  void _set(TextEditingController ctrl, String? val) {
    if (val != null && val.isNotEmpty) ctrl.text = val;
  }

  String _normaliseGender(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('female')) return 'Female';
    if (lower.contains('other') || lower.contains('trans')) return 'Other';
    return 'Male';
  }

  // ── Image picker (crash-safe) ────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    // Web does not support camera source — fall back to gallery
    if (kIsWeb && source == ImageSource.camera) {
      source = ImageSource.gallery;
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 75,   // Reduced from 80 to guard against OOM on large photos
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null || !context.mounted) return;

      String imagePath = picked.path;
      String? croppedPath;
      try {
        final cropped = await ImageCropperHelper.cropProfileImage(
          picked.path,
          context: context,
        );
        if (cropped != null) {
          imagePath = cropped.path;
          croppedPath = cropped.path;
        }
      } catch (_) {
        // If cropping fails or is canceled, continue with the selected image.
      }

      if (!context.mounted) return;

      final userId = ref.read(authViewModelProvider.notifier).currentUser?.id;
      if (userId == null) {
        _showSnack('Not logged in.', error: true);
        return;
      }

      // ── Show confirmation preview with OK button ──
      final bool? confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ImageConfirmSheet(
          imagePath: imagePath,
          croppedPath: croppedPath,
          userId: userId,
        ),
      );

      if (confirmed != true || !context.mounted) return;

      // Show heartbeat animation success dialog
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => const _HeartbeatSuccessOverlay(),
      );
    } on Exception catch (e) {
      if (!context.mounted) return;
      _showSnack('Could not pick image: ${e.toString()}', error: true);
    } catch (e) {
      // Catches Error subclasses (e.g. OOM, PlatformException-as-Error)
      if (!context.mounted) return;
      _showSnack('Image selection failed. Please try a smaller photo.', error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!context.mounted) return;
    try {
      final sm = ScaffoldMessenger.maybeOf(context);
      if (sm == null) return;
      sm.hideCurrentSnackBar();
      sm.showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: error ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    } catch (_) {}
  }

  // ── Image source bottom sheet ────────────────────────────────
  void _showImageSourceSheet() {
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
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
                  Text('Profile Photo',
                      style: GoogleFonts.outfit(
                          fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
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
                  child: const Icon(Icons.camera_alt_outlined,
                      color: Color(0xFF4285F4)),
                ),
                title: Text('Take Photo',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
                  child: const Icon(Icons.photo_library_outlined,
                      color: Color(0xFF9B72CF)),
                ),
                title: Text('Choose from Gallery',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
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
                title: Text('Remove Photo',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: Colors.red.shade600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final authVm = ref.read(authViewModelProvider.notifier);
                  final userId = authVm.currentUser?.id;
                  if (userId == null) return;

                  final success = await ref.read(profileViewModelProvider.notifier)
                      .removeProfileImage(userId);

                  if (success && authVm.currentUser != null) {
                    authVm.updateUser(authVm.currentUser!.copyWith(profileImage: ''));
                    ref.read(cardViewModelProvider.notifier).clearProfileImage();
                  }


                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Profile photo removed successfully.',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Colors.green.shade700,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
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

  // ═════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final profileVm = ref.watch(profileViewModelProvider);
    final authUser = ref.watch(authViewModelProvider).currentUser;
    final cardImage = ref.watch(cardViewModelProvider.select((vm) => vm.currentCard?.profileImageName));
    ref.watch(themeViewModelProvider); // keep dependency without unused variable

    final profile   = profileVm.user ?? authUser;
    final userImage = profile?.profileImage;
    final imagePath =
        (cardImage != null && cardImage.isNotEmpty) ? cardImage : userImage;

    final fullName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : '${_firstNameCtrl.text} ${_lastNameCtrl.text}'.trim();
    final isIndian = _isUserIndian(profile ?? authUser);

    IconData getGenderIcon(String gender) {
      final g = gender.toLowerCase().trim();
      if (g == 'female') return Icons.female_outlined;
      if (g == 'male') return Icons.male_outlined;
      return Icons.transgender;
    }

    return RefreshIndicator(
      color: AppColors.primaryRed,
      onRefresh: () async {
        final uid = ref.read(authViewModelProvider.notifier).currentUser?.id;
        final pVm = ref.read(profileViewModelProvider.notifier);
        if (uid != null) {
          await pVm.loadProfile(uid);
          if (context.mounted) {
            _populate(pVm.user ?? ref.read(authViewModelProvider.notifier).currentUser);
          }
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // ── Red header ──────────────────────────────────────
            _Header(
              userId: ref.read(authViewModelProvider.notifier).currentUser?.id,
              fullName: fullName.isEmpty ? 'Your Name' : fullName,
              initials: profile?.initials ?? '?',
              imagePath: imagePath,
              isUploading: profileVm.isUploadingImage,
              onCameraTap: _showImageSourceSheet,
              showTopBar: widget.showTopBar,
            ),

                  // ── Content below header ─────────────────────────────
                  profileVm.isLoading && profile == null
                      ? const Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryRed,
                            ),
                          ),
                        )
                      : Transform.translate(
                          offset: const Offset(0, -24),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(32),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, -4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                            child: Column(
                              children: [
                                

                                InfoCard(
                                  title: 'PERSONAL DETAILS',
                                  icon: Icons.person_outline,
                                  onEdit: () => _showPersonalDetailsDialog(),
                                  rows: [
                                    RowData(Icons.person_outline,       'Full Name',    fullName.isEmpty ? '—' : fullName),
                                    RowData(getGenderIcon(_gender),      'Gender',       _gender),
                                    RowData(Icons.mail_outline,          'Email Address', _emailCtrl.text.isEmpty ? '—' : _emailCtrl.text),
                                    RowData(
                                      Icons.phone_outlined,
                                      'Phone Number',
                                      _phoneCtrl.text.isEmpty
                                          ? (isIndian ? '—' : 'Not provided (Disabled)')
                                          : '${_countryCode.isNotEmpty ? '$_countryCode ' : ''}${_phoneCtrl.text}',
                                      trailing: !isIndian
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.lock_outline_rounded, size: 12, color: Colors.grey[600]),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Read-only',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      color: Colors.grey[700],
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : null,
                                      onTap: !isIndian
                                          ? () => _showInternationalPhoneUnavailableDialog(context)
                                          : null,
                                    ),
                                    RowData(
                                        FontAwesomeIcons.whatsapp,
                                        'WhatsApp Number',
                                        _whatsappCtrl.text.isNotEmpty
                                            ? '${_whatsappCountryCode.isNotEmpty ? '$_whatsappCountryCode ' : ''}${_whatsappCtrl.text}'
                                            : (isIndian && _phoneCtrl.text.isNotEmpty
                                                ? '${_countryCode.isNotEmpty ? '$_countryCode ' : ''}${_phoneCtrl.text}'
                                                : '—'),
                                        iconColor: const Color(0xFF25D366),
                                        iconBg: const Color(0xFFE8F5E9),
                                        trailing: _whatsappCtrl.text.isNotEmpty
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE8F5E9),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: const Color(0xFF25D366).withValues(alpha: 0.4),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.verified_rounded, size: 13, color: Color(0xFF25D366)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Verified',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10.5,
                                                        color: const Color(0xFF2E7D32),
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                // ── Address card ────────────────────
                                InfoCard(
                                  title: 'ADDRESS DETAILS',
                                  icon: Icons.location_on_outlined,
                                  onEdit: _showAddressDialog,
                                  rows: [
                                    if (_addressCtrl.text.isNotEmpty)
                                      RowData(Icons.location_on_outlined, 'Address',  _addressCtrl.text),
                                    if (_pincodeCtrl.text.isNotEmpty)
                                      RowData(Icons.pin_drop_outlined,    'Pin Code',  _pincodeCtrl.text),
                                    if (_districtCtrl.text.isNotEmpty)
                                      RowData(Icons.map_outlined,         'District',  _districtCtrl.text),
                                    if (_stateCtrl.text.isNotEmpty)
                                      RowData(Icons.map_outlined,         'State',     _stateCtrl.text),
                                    // Show placeholder if all empty
                                    if (_addressCtrl.text.isEmpty && _pincodeCtrl.text.isEmpty &&
                                        _districtCtrl.text.isEmpty && _stateCtrl.text.isEmpty)
                                      const RowData(Icons.location_on_outlined, 'Address', '—'),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // ── Delete Account Button ────────────
                                Center(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showDeleteAccountDialog(context),
                                    icon: const Icon(Icons.delete_forever, size: 18),
                                    label: Text('Delete Account', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            ),
          );
  }

  // ═════════════════════════════════════════════════════════════
  // COUNTRY DETECTION HELPER
  // ═════════════════════════════════════════════════════════════
  bool _isUserIndian(UserModel? u) {
    if (u?.countryCode != null && u!.countryCode!.trim().isNotEmpty) {
      final clean = u.countryCode!.trim().replaceAll(RegExp(r'\D'), '');
      return clean == '91';
    }
    if (u?.phone != null && u!.phone!.trim().isNotEmpty) {
      final parsed = InternationalPhoneHelper.parseRaw(u.phone!.trim());
      final clean = parsed.countryCode.replaceAll(RegExp(r'\D'), '');
      return clean == '91';
    }
    if (u?.whatsappNumber != null && u!.whatsappNumber!.trim().isNotEmpty) {
      final parsed = InternationalPhoneHelper.parseRaw(u.whatsappNumber!.trim());
      final clean = parsed.countryCode.replaceAll(RegExp(r'\D'), '');
      return clean == '91';
    }
    final clean = _countryCode.replaceAll(RegExp(r'\D'), '');
    return clean == '91' || _countryCode == '+91';
  }

  // ═════════════════════════════════════════════════════════════
  // ALERT DIALOG FOR INTERNATIONAL USERS (Main Profile Screen tap)
  // ═════════════════════════════════════════════════════════════
  void _showInternationalPhoneUnavailableDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (alertCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Icon(Icons.phone_disabled_rounded, color: Colors.amber.shade800, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Phone/SMS Service Unavailable',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Phone/SMS profile updates are currently available only for Indian users. Please update your WhatsApp number instead.',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: Colors.grey[700],
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // When Cancel is selected, close the alert without changing any profile data.
              Navigator.pop(alertCtx);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(alertCtx);
              _showPersonalDetailsDialog(initialEnableWhatsApp: true);
            },
            icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16, color: Colors.white),
            label: Text(
              'Update WhatsApp Number',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // ALERT DIALOG FOR INTERNATIONAL USERS (Inside Edit Dialog tap)
  // ═════════════════════════════════════════════════════════════
  void _showInternationalPhoneAlert({
    required BuildContext context,
    required StateSetter setDialogState,
    required ScrollController scrollController,
    required FocusNode waFocusNode,
    VoidCallback? onWhatsAppSectionEnabled,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (alertCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Icon(Icons.phone_disabled_rounded, color: Colors.amber.shade800, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Phone/SMS Service Unavailable',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Phone/SMS profile updates are currently available only for Indian users. Please update your WhatsApp number instead.',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: Colors.grey[700],
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // When Cancel is selected, close the alert without changing any profile data.
              Navigator.pop(alertCtx);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // 1. Close the alert dialog.
              Navigator.pop(alertCtx);

              // 2. Enable the WhatsApp section or toggle it ON.
              setDialogState(() {
                if (onWhatsAppSectionEnabled != null) {
                  onWhatsAppSectionEnabled();
                }
              });

              // 3. Scroll to the WhatsApp number field.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (scrollController.hasClients) {
                  scrollController.animateTo(
                    scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                  );
                }
                // 4. Allow user to enter or update WhatsApp number.
                waFocusNode.requestFocus();
              });
            },
            icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16, color: Colors.white),
            label: Text(
              'Update WhatsApp Number',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // PERSONAL DETAILS DIALOG — with OTP verification
  // ═════════════════════════════════════════════════════════════
  void _showPersonalDetailsDialog({bool initialEnableWhatsApp = false}) {
    final profileVm = ref.read(profileViewModelProvider.notifier);
    final authVm    = ref.read(authViewModelProvider.notifier);
    final user      = profileVm.user ?? authVm.currentUser;
    final isIndian  = _isUserIndian(user);

    // Temporary copies so dialog changes don't affect main state until saved
    final fn  = TextEditingController(text: _firstNameCtrl.text);
    final ln  = TextEditingController(text: _lastNameCtrl.text);
    final em  = TextEditingController(text: _emailCtrl.text);
    String dialogCountryCode = _countryCode;
    String dialogWhatsappCountryCode = _whatsappCountryCode;

    String initialPh = _phoneCtrl.text.trim();
    if (initialPh.startsWith('+91')) {
      initialPh = initialPh.substring(3).trim();
    } else if (dialogCountryCode.isNotEmpty && initialPh.startsWith(dialogCountryCode)) {
      initialPh = initialPh.substring(dialogCountryCode.length).trim();
    }
    final ph  = TextEditingController(text: initialPh);

    String initialWa = _whatsappCtrl.text.trim();
    if (initialWa.startsWith('+91')) {
      initialWa = initialWa.substring(3).trim();
    } else if (dialogWhatsappCountryCode.isNotEmpty && initialWa.startsWith(dialogWhatsappCountryCode)) {
      initialWa = initialWa.substring(dialogWhatsappCountryCode.length).trim();
    }
    if (initialWa.isEmpty && isIndian && initialPh.isNotEmpty) {
      initialWa = initialPh;
    }
    final waCtrl = TextEditingController(text: initialWa);
    final otpCtrl = TextEditingController();
    final scrollController = ScrollController();
    final waFocusNode = FocusNode();
    final GlobalKey waCountryKey = GlobalKey();
    final GlobalKey waSectionKey = GlobalKey();

    String dialogGender = _gender;
    bool showOtpField = false;
    bool dialogIsWhatsApp = _preferredOtpMethod == 'whatsapp' || initialEnableWhatsApp || (!isIndian && _whatsappCtrl.text.isNotEmpty);
    bool isWhatsAppSectionEnabled = true;

    // Track verification of WhatsApp number in dialog
    bool isWhatsAppVerified = _whatsappCtrl.text.trim().isNotEmpty &&
        (waCtrl.text.trim() == initialWa || waCtrl.text.trim() == _whatsappCtrl.text.trim()) &&
        dialogWhatsappCountryCode == _whatsappCountryCode;

    if (initialEnableWhatsApp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
        waFocusNode.requestFocus();
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        bool saving  = false;
        String? errMsg;

        return StatefulBuilder(builder: (ctx, setS) {
          final pVm = ref.read(profileViewModelProvider.notifier);
          final aVm = ref.read(authViewModelProvider.notifier);
          final userId = aVm.currentUser?.id ?? '';

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.all(16),
            backgroundColor: const Color(0xFFFFF7F7),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogHeader(
                  title: 'Personal Details',
                  icon: Icons.person_outline,
                  onClose: () {
                    OtpAutofillService().stopListening();
                    Navigator.pop(ctx);
                  },
                ),
                Flexible(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (errMsg != null) _ErrorBanner(errMsg!),
                        _DField('First Name', fn,
                            icon: Icons.person_outline,
                            textCapitalization: TextCapitalization.words),
                        _DField('Last Name', ln,
                            icon: Icons.person_outline,
                            textCapitalization: TextCapitalization.words),
                        _DField('Email Address', em,
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 12),

                        // ── Phone Number Section ───────────────────────
                        if (isIndian) ...[
                          // Indian Users: Keep existing phone editable, locked to +91, with optional WhatsApp toggle
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Phone Number',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Country code locked to +91
                              InkWell(
                                onTap: () {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Indian phone numbers are locked to +91.',
                                        style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white),
                                      ),
                                      backgroundColor: const Color(0xFF1E293B),
                                      duration: const Duration(seconds: 3),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 50,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(ctx).cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.35),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🇮🇳', style: TextStyle(fontSize: 16)),
                                      const SizedBox(width: 5),
                                      Text(
                                        '+91',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(ctx).colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.lock_outline_rounded,
                                        size: 14,
                                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: TextFormField(
                                    controller: ph,
                                    enabled: !saving && !showOtpField,
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFDC2626),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter 10-digit mobile number',
                                      hintStyle: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFFDC2626).withValues(alpha: 0.6),
                                      ),
                                      counterText: '',
                                      filled: true,
                                      fillColor: Theme.of(ctx).cardColor,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.35),
                                          width: 1.2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.35),
                                          width: 1.2,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFDC2626),
                                          width: 1.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),



                          // WhatsApp Number Field (Nov 2026 unified styling)
                          const SizedBox(height: 14),
                          Text(
                            'WhatsApp Number',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              InkWell(
                                key: waCountryKey,
                                onTap: (!saving && !showOtpField)
                                    ? () {
                                        CountryCodeDropdownDialog.show(
                                          context,
                                          anchorKey: waCountryKey,
                                          selectedCode: dialogWhatsappCountryCode,
                                          isWhatsAppMode: true,
                                          onSelectCountry: (item) {
                                            setS(() {
                                              dialogWhatsappCountryCode = item.code;
                                              isWhatsAppVerified = (_whatsappCtrl.text.trim().isNotEmpty &&
                                                  dialogWhatsappCountryCode == _whatsappCountryCode &&
                                                  waCtrl.text.trim() == _whatsappCtrl.text.trim());
                                            });
                                          },
                                        );
                                      }
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 50,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(ctx).cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.35),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        InternationalPhoneHelper.findByCode(dialogWhatsappCountryCode).flag,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        dialogWhatsappCountryCode,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(ctx).colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: TextFormField(
                                    controller: waCtrl,
                                    focusNode: waFocusNode,
                                    enabled: !saving && !showOtpField,
                                    keyboardType: TextInputType.phone,
                                    maxLength: 15,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(15),
                                    ],
                                    onChanged: (val) {
                                      setS(() {
                                        isWhatsAppVerified = (_whatsappCtrl.text.trim().isNotEmpty &&
                                            dialogWhatsappCountryCode == _whatsappCountryCode &&
                                            val.trim() == _whatsappCtrl.text.trim());
                                      });
                                    },
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFDC2626),
                                    ),
                                    decoration: InputDecoration(
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF25D366),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const FaIcon(
                                            FontAwesomeIcons.whatsapp,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      hintText: 'Enter WhatsApp number',
                                      hintStyle: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFFDC2626).withValues(alpha: 0.6),
                                      ),
                                      counterText: '',
                                      filled: true,
                                      fillColor: Theme.of(ctx).cardColor,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.35),
                                          width: 1.2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.35),
                                          width: 1.2,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF25D366),
                                          width: 1.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // ── International Users Section ───────────────────
                          // Phone field is strictly read-only/disabled.
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Phone Number',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.lock_outline_rounded, size: 11, color: Colors.grey[600]),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Read-only',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () {
                                  _showInternationalPhoneAlert(
                                    context: context,
                                    setDialogState: setS,
                                    scrollController: scrollController,
                                    waFocusNode: waFocusNode,
                                    onWhatsAppSectionEnabled: () {
                                      isWhatsAppSectionEnabled = true;
                                      dialogIsWhatsApp = true;
                                    },
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 50,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[300]!, width: 1.2),
                                  ),
                                  child: ph.text.trim().isNotEmpty
                                      ? Row(
                                          children: [
                                            Text(
                                              InternationalPhoneHelper.findByCode(dialogCountryCode).flag,
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              dialogCountryCode,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                ph.text.trim(),
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ),
                                            Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey[500]),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Icon(Icons.phone_disabled_outlined, size: 18, color: Colors.grey[500]),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'No phone number added (Disabled)',
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  color: Colors.grey[500],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                            Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey[500]),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  _showInternationalPhoneAlert(
                                    context: context,
                                    setDialogState: setS,
                                    scrollController: scrollController,
                                    waFocusNode: waFocusNode,
                                    onWhatsAppSectionEnabled: () {
                                      isWhatsAppSectionEnabled = true;
                                      dialogIsWhatsApp = true;
                                    },
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 12, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Phone/SMS updates available for Indian users only. Tap to update WhatsApp.',
                                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // International Users: WhatsApp Update Card
                          const SizedBox(height: 16),
                          Container(
                            key: waSectionKey,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isWhatsAppVerified
                                    ? const Color(0xFF25D366).withValues(alpha: 0.6)
                                    : const Color(0xFFDC2626).withValues(alpha: 0.6),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const FaIcon(FontAwesomeIcons.whatsapp, size: 16, color: Color(0xFF25D366)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'WhatsApp Number',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF1B5E20),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isWhatsAppVerified)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F5E9),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF25D366)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.verified_rounded, size: 13, color: Color(0xFF25D366)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Verified',
                                              style: GoogleFonts.inter(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF2E7D32),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.red.shade300),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.error_outline, size: 13, color: Colors.red.shade700),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Unverified',
                                              style: GoogleFonts.inter(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    // Country code selector for WhatsApp
                                    InkWell(
                                      key: waCountryKey,
                                      onTap: (!saving && !showOtpField)
                                          ? () {
                                              CountryCodeDropdownDialog.show(
                                                context,
                                                anchorKey: waCountryKey,
                                                selectedCode: dialogWhatsappCountryCode,
                                                isWhatsAppMode: true,
                                                onSelectCountry: (item) {
                                                  setS(() {
                                                    dialogWhatsappCountryCode = item.code;
                                                    isWhatsAppVerified = (_whatsappCtrl.text.trim().isNotEmpty &&
                                                        dialogWhatsappCountryCode == _whatsappCountryCode &&
                                                        waCtrl.text.trim() == _whatsappCtrl.text.trim());
                                                  });
                                                },
                                              );
                                            }
                                          : null,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 50,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFF25D366).withValues(alpha: 0.6),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              InternationalPhoneHelper.findByCode(dialogWhatsappCountryCode).flag,
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              dialogWhatsappCountryCode,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF2E7D32),
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            const Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              size: 16,
                                              color: Color(0xFF2E7D32),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SizedBox(
                                        height: 50,
                                        child: TextFormField(
                                          controller: waCtrl,
                                          focusNode: waFocusNode,
                                          enabled: !saving && !showOtpField,
                                          keyboardType: TextInputType.phone,
                                          maxLength: 15,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(15),
                                          ],
                                          onChanged: (val) {
                                            setS(() {
                                              isWhatsAppVerified = (_whatsappCtrl.text.trim().isNotEmpty &&
                                                  dialogWhatsappCountryCode == _whatsappCountryCode &&
                                                  val.trim() == _whatsappCtrl.text.trim());
                                            });
                                          },
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF2E7D32),
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Enter WhatsApp number',
                                            hintStyle: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF2E7D32).withValues(alpha: 0.6),
                                            ),
                                            counterText: '',
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: isWhatsAppVerified
                                                    ? const Color(0xFF25D366)
                                                    : const Color(0xFFDC2626),
                                                width: 1.2,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: isWhatsAppVerified
                                                    ? const Color(0xFF25D366)
                                                    : const Color(0xFFDC2626),
                                                width: 1.2,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: isWhatsAppVerified
                                                    ? const Color(0xFF25D366)
                                                    : const Color(0xFFDC2626),
                                                width: 1.6,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (!isWhatsAppVerified) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 12, color: Colors.red.shade700),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          waCtrl.text.trim().isEmpty
                                              ? 'Please enter your WhatsApp number.'
                                              : 'Unverified: WhatsApp OTP verification required before saving.',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF25D366)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Verified WhatsApp number for notifications & OTP',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: const Color(0xFF2E7D32),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                        Text('Gender',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700])),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: dialogGender,
                              isExpanded: true,
                              dropdownColor: Theme.of(ctx).cardColor,
                              onChanged: (v) {
                                if (v != null) setS(() => dialogGender = v);
                              },
                              items: ['Male', 'Female', 'Other']
                                  .map((v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v, style: GoogleFonts.inter(fontSize: 14))))
                                  .toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Save Changes / OTP verification UI ─────────────────
                        if (showOtpField) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              'Enter the 6-digit verification code sent to your ${dialogIsWhatsApp ? "WhatsApp" : "phone"}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OTPInputField(
                            controller: otpCtrl,
                            length: 6,
                            onCompleted: (code) async {
                              if (saving) return;
                              setS(() { saving = true; errMsg = null; });
                              final verified = await pVm.verifyProfileOtp(userId, code);
                              if (!ctx.mounted) return;
                              if (verified) {
                                OtpAutofillService().stopListening();
                                OtpAutofillService().markAutofillInitialized();

                                if (isIndian) {
                                  final effectiveWa = isWhatsAppSectionEnabled
                                      ? (waCtrl.text.trim().isNotEmpty
                                          ? InternationalPhoneHelper.formatForBackend(
                                              phone: waCtrl.text.trim(),
                                              countryCode: dialogWhatsappCountryCode,
                                            )
                                          : InternationalPhoneHelper.formatForBackend(
                                              phone: ph.text.trim(),
                                              countryCode: dialogCountryCode,
                                            ))
                                      : (waCtrl.text.trim().isNotEmpty
                                          ? waCtrl.text.trim()
                                          : null);

                                  final updated = await pVm.updateProfile(userId, {
                                    'first_name': fn.text.trim(),
                                    'last_name': ln.text.trim(),
                                    'email': em.text.trim(),
                                    'phone': InternationalPhoneHelper.formatForBackend(
                                      phone: ph.text.trim(),
                                      countryCode: dialogCountryCode,
                                    ),
                                    'full_phone': InternationalPhoneHelper.toE164(
                                      phone: ph.text.trim(),
                                      countryCode: dialogCountryCode,
                                    ),
                                    'country_code': dialogCountryCode,
                                    'whatsapp_number': effectiveWa,
                                    'preferred_otp_method': dialogIsWhatsApp ? 'whatsapp' : 'phone',
                                    'delivery_method': dialogIsWhatsApp ? 'whatsapp' : 'phone',
                                    'gender': dialogGender,
                                  });
                                  if (!ctx.mounted) return;
                                  setS(() => saving = false);
                                  if (updated) {
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      setState(() {
                                        _firstNameCtrl.text = fn.text;
                                        _lastNameCtrl.text = ln.text;
                                        _emailCtrl.text = em.text;
                                        _phoneCtrl.text = ph.text;
                                        _whatsappCtrl.text = waCtrl.text;
                                        _countryCode = dialogCountryCode;
                                        _whatsappCountryCode = dialogWhatsappCountryCode;
                                        _preferredOtpMethod = dialogIsWhatsApp ? 'whatsapp' : 'phone';
                                        _gender = dialogGender;
                                        _lastPopulatedUserId = userId;
                                      });
                                      _showSnack('Personal details updated!');
                                    }
                                  } else {
                                    setS(() {
                                      errMsg = pVm.errorMessage ?? 'Update failed. Please try again.';
                                    });
                                  }
                                } else {
                                  // International User: Preserve existing phone number data. Do not submit phone-number update requests.
                                  final updateData = <String, dynamic>{
                                    'first_name': fn.text.trim(),
                                    'last_name': ln.text.trim(),
                                    'email': em.text.trim(),
                                    'whatsapp_number': InternationalPhoneHelper.formatForBackend(
                                      phone: waCtrl.text.trim(),
                                      countryCode: dialogWhatsappCountryCode,
                                    ),
                                    'preferred_otp_method': 'whatsapp',
                                    'delivery_method': 'whatsapp',
                                    'gender': dialogGender,
                                  };
                                  if (pVm.user?.phone != null && pVm.user!.phone!.isNotEmpty) {
                                    updateData['phone'] = pVm.user!.phone!;
                                  }
                                  if (pVm.user?.countryCode != null && pVm.user!.countryCode!.isNotEmpty) {
                                    updateData['country_code'] = pVm.user!.countryCode!;
                                  }

                                  final updated = await pVm.updateProfile(userId, updateData);
                                  if (!ctx.mounted) return;
                                  setS(() => saving = false);
                                  if (updated) {
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      setState(() {
                                        _firstNameCtrl.text = fn.text;
                                        _lastNameCtrl.text = ln.text;
                                        _emailCtrl.text = em.text;
                                        _whatsappCtrl.text = waCtrl.text;
                                        _whatsappCountryCode = dialogWhatsappCountryCode;
                                        _preferredOtpMethod = 'whatsapp';
                                        _gender = dialogGender;
                                        _lastPopulatedUserId = userId;
                                      });
                                      _showSnack('WhatsApp number verified and profile updated successfully!');
                                    }
                                  } else {
                                    setS(() {
                                      errMsg = pVm.errorMessage ?? 'Update failed. Please try again.';
                                    });
                                  }
                                }
                              } else {
                                setS(() {
                                  saving = false;
                                  errMsg = pVm.errorMessage ?? 'OTP verification failed. Please try again.';
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Didn't receive the code? ",
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                              ),
                              TextButton(
                                onPressed: saving
                                    ? null
                                    : () async {
                                        setS(() { saving = true; errMsg = null; });
                                        final channel = isIndian ? (dialogIsWhatsApp ? 'whatsapp' : 'phone') : 'whatsapp';
                                        final targetPhone = isIndian ? ph.text.trim() : waCtrl.text.trim();
                                        final targetWa = isIndian
                                            ? ((dialogIsWhatsApp && waCtrl.text.trim().isNotEmpty) ? waCtrl.text.trim() : null)
                                            : waCtrl.text.trim();
                                        final targetCountry = isIndian ? dialogCountryCode : dialogWhatsappCountryCode;

                                        final resendOk = await pVm.sendProfileOtp(
                                          userId,
                                          targetPhone,
                                          channel: channel,
                                          countryCode: targetCountry,
                                          whatsappNumber: targetWa,
                                        );
                                        if (!ctx.mounted) return;
                                        setS(() => saving = false);
                                        if (resendOk) {
                                          if (context.mounted) {
                                            _showSnack('OTP resent via ${channel == "whatsapp" ? "WhatsApp" : "SMS"}!');
                                          }
                                        } else {
                                          setS(() {
                                            errMsg = pVm.errorMessage ?? 'Failed to resend OTP.';
                                          });
                                        }
                                      },
                                child: Text(
                                  'Resend OTP',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: (isIndian && !dialogIsWhatsApp)
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF25D366),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              OtpAutofillService().stopListening();
                              setS(() {
                                showOtpField = false;
                                otpCtrl.clear();
                              });
                            },
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                color: Colors.red[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            child: saving
                                ? const _LoadingBtn()
                                : ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryRed,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.save_outlined, size: 18, color: Colors.white),
                                    label: Text('Save Changes',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                                    onPressed: () async {
                                      setS(() { saving = true; errMsg = null; });

                                      if (isIndian) {
                                        // 1. Validate Indian phone number
                                        final phoneErr = InternationalPhoneHelper.validatePhoneNumber(
                                          phone: ph.text.trim(),
                                          countryCode: dialogCountryCode,
                                          isWhatsApp: false,
                                          fieldName: 'Phone number',
                                        );
                                        if (phoneErr != null) {
                                          setS(() {
                                            saving = false;
                                            errMsg = phoneErr;
                                          });
                                          return;
                                        }

                                        // 2. Validate WhatsApp number if separate entered
                                        if (isWhatsAppSectionEnabled && waCtrl.text.trim().isNotEmpty) {
                                          final waErr = InternationalPhoneHelper.validatePhoneNumber(
                                            phone: waCtrl.text.trim(),
                                            countryCode: dialogWhatsappCountryCode,
                                            isWhatsApp: true,
                                            fieldName: 'WhatsApp number',
                                          );
                                          if (waErr != null) {
                                            setS(() {
                                              saving = false;
                                              errMsg = waErr;
                                            });
                                            return;
                                          }
                                        }

                                        final phoneChanged =
                                            ph.text.trim() != _phoneCtrl.text.trim() ||
                                            dialogCountryCode != _countryCode;
                                        final waChanged = isWhatsAppSectionEnabled &&
                                            (waCtrl.text.trim() != _whatsappCtrl.text.trim() ||
                                             dialogWhatsappCountryCode != _whatsappCountryCode);
                                        final methodChanged =
                                            (dialogIsWhatsApp ? 'whatsapp' : 'phone') != _preferredOtpMethod;

                                        final requiresOtp = phoneChanged || waChanged || methodChanged;

                                        if (requiresOtp) {
                                          final channel = dialogIsWhatsApp ? 'whatsapp' : 'phone';
                                          final targetWa = (dialogIsWhatsApp && waCtrl.text.trim().isNotEmpty)
                                              ? waCtrl.text.trim()
                                              : null;

                                          final requested = await pVm.sendProfileOtp(
                                            userId,
                                            ph.text.trim(),
                                            channel: channel,
                                            countryCode: dialogCountryCode,
                                            whatsappNumber: targetWa,
                                          );
                                          if (!ctx.mounted) return;
                                          setS(() => saving = false);
                                          if (requested) {
                                            setS(() {
                                              showOtpField = true;
                                              otpCtrl.clear();
                                            });
                                            OtpAutofillService().startListening(
                                              onCodeReceived: (code) {
                                                if (!ctx.mounted) return;
                                                otpCtrl.text = code;
                                                OtpAutofillService().markAutofillInitialized();
                                              },
                                            );
                                          } else {
                                            setS(() {
                                              errMsg = pVm.errorMessage ?? 'Failed to send OTP. Try again.';
                                            });
                                          }
                                        } else {
                                          final effectiveWa = isWhatsAppSectionEnabled
                                              ? (waCtrl.text.trim().isNotEmpty
                                                  ? InternationalPhoneHelper.formatForBackend(
                                                      phone: waCtrl.text.trim(),
                                                      countryCode: dialogWhatsappCountryCode,
                                                    )
                                                  : InternationalPhoneHelper.formatForBackend(
                                                      phone: ph.text.trim(),
                                                      countryCode: dialogCountryCode,
                                                    ))
                                              : (waCtrl.text.trim().isNotEmpty
                                                  ? waCtrl.text.trim()
                                                  : null);

                                          final updated = await pVm.updateProfile(userId, {
                                            'first_name': fn.text.trim(),
                                            'last_name': ln.text.trim(),
                                            'email': em.text.trim(),
                                            'phone': InternationalPhoneHelper.formatForBackend(
                                              phone: ph.text.trim(),
                                              countryCode: dialogCountryCode,
                                            ),
                                            'full_phone': InternationalPhoneHelper.toE164(
                                              phone: ph.text.trim(),
                                              countryCode: dialogCountryCode,
                                            ),
                                            'country_code': dialogCountryCode,
                                            'whatsapp_number': effectiveWa,
                                            'preferred_otp_method': dialogIsWhatsApp ? 'whatsapp' : 'phone',
                                            'delivery_method': dialogIsWhatsApp ? 'whatsapp' : 'phone',
                                            'gender': dialogGender,
                                          });
                                          if (!ctx.mounted) return;
                                          setS(() => saving = false);
                                          if (updated) {
                                            if (ctx.mounted) Navigator.pop(ctx);
                                            if (mounted) {
                                              setState(() {
                                                _firstNameCtrl.text = fn.text;
                                                _lastNameCtrl.text = ln.text;
                                                _emailCtrl.text = em.text;
                                                _phoneCtrl.text = ph.text;
                                                _whatsappCtrl.text = waCtrl.text;
                                                _countryCode = dialogCountryCode;
                                                _whatsappCountryCode = dialogWhatsappCountryCode;
                                                _preferredOtpMethod = dialogIsWhatsApp ? 'whatsapp' : 'phone';
                                                _gender = dialogGender;
                                                _lastPopulatedUserId = userId;
                                              });
                                              _showSnack('Personal details updated!');
                                            }
                                          } else {
                                            setS(() {
                                              errMsg = pVm.errorMessage ?? 'Update failed. Please try again.';
                                            });
                                          }
                                        }
                                      } else {
                                        // ── International User Save ─────────────────────
                                        // Validate WhatsApp format if entered
                                        if (waCtrl.text.trim().isNotEmpty) {
                                          final waErr = InternationalPhoneHelper.validatePhoneNumber(
                                            phone: waCtrl.text.trim(),
                                            countryCode: dialogWhatsappCountryCode,
                                            isWhatsApp: true,
                                            fieldName: 'WhatsApp number',
                                          );
                                          if (waErr != null) {
                                            setS(() {
                                              saving = false;
                                              errMsg = waErr;
                                            });
                                            return;
                                          }
                                        }

                                        final waChanged =
                                            waCtrl.text.trim() != _whatsappCtrl.text.trim() ||
                                            dialogWhatsappCountryCode != _whatsappCountryCode;
                                        final nameChanged =
                                            fn.text.trim() != _firstNameCtrl.text.trim() ||
                                            ln.text.trim() != _lastNameCtrl.text.trim();

                                        // Require successful OTP verification before marking a changed WhatsApp number as verified
                                        if (waChanged && waCtrl.text.trim().isNotEmpty) {
                                          final requested = await pVm.sendProfileOtp(
                                            userId,
                                            waCtrl.text.trim(),
                                            channel: 'whatsapp',
                                            countryCode: dialogWhatsappCountryCode,
                                            whatsappNumber: waCtrl.text.trim(),
                                          );
                                          if (!ctx.mounted) return;
                                          setS(() => saving = false);
                                          if (requested) {
                                            setS(() {
                                              showOtpField = true;
                                              otpCtrl.clear();
                                            });
                                            OtpAutofillService().startListening(
                                              onCodeReceived: (code) {
                                                if (!ctx.mounted) return;
                                                otpCtrl.text = code;
                                                OtpAutofillService().markAutofillInitialized();
                                              },
                                            );
                                          } else {
                                            setS(() {
                                              errMsg = pVm.errorMessage ?? 'Failed to send WhatsApp verification code. Try again.';
                                            });
                                          }
                                          return;
                                        } else {
                                          // Direct update: Do not submit phone-number update requests. Preserve existing phone-number data.
                                          final updateData = <String, dynamic>{
                                            'first_name': fn.text.trim(),
                                            'last_name': ln.text.trim(),
                                            'email': em.text.trim(),
                                            'gender': dialogGender,
                                          };
                                          if (waCtrl.text.trim().isNotEmpty) {
                                            updateData['whatsapp_number'] = InternationalPhoneHelper.formatForBackend(
                                              phone: waCtrl.text.trim(),
                                              countryCode: dialogWhatsappCountryCode,
                                            );
                                            updateData['preferred_otp_method'] = 'whatsapp';
                                            updateData['delivery_method'] = 'whatsapp';
                                          }
                                          if (pVm.user?.phone != null && pVm.user!.phone!.isNotEmpty) {
                                            updateData['phone'] = pVm.user!.phone!;
                                          }
                                          if (pVm.user?.countryCode != null && pVm.user!.countryCode!.isNotEmpty) {
                                            updateData['country_code'] = pVm.user!.countryCode!;
                                          }

                                          final updated = await pVm.updateProfile(userId, updateData);
                                          if (!ctx.mounted) return;
                                          setS(() => saving = false);
                                          if (updated) {
                                            if (ctx.mounted) Navigator.pop(ctx);
                                            if (mounted) {
                                              setState(() {
                                                _firstNameCtrl.text = fn.text;
                                                _lastNameCtrl.text = ln.text;
                                                _emailCtrl.text = em.text;
                                                _whatsappCtrl.text = waCtrl.text;
                                                _whatsappCountryCode = dialogWhatsappCountryCode;
                                                _preferredOtpMethod = 'whatsapp';
                                                _gender = dialogGender;
                                                _lastPopulatedUserId = userId;
                                              });
                                              _showSnack('Personal details updated!');
                                            }
                                          } else {
                                            setS(() {
                                              errMsg = pVm.errorMessage ?? 'Update failed. Please try again.';
                                            });
                                          }
                                        }
                                      }
                                    },
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    ).whenComplete(() {
      OtpAutofillService().stopListening();
      Future.delayed(const Duration(milliseconds: 600), () {
        try { scrollController.dispose(); } catch (_) {}
        try { waFocusNode.dispose(); } catch (_) {}
        try { fn.dispose(); } catch (_) {}
        try { ln.dispose(); } catch (_) {}
        try { em.dispose(); } catch (_) {}
        try { ph.dispose(); } catch (_) {}
        try { waCtrl.dispose(); } catch (_) {}
        try { otpCtrl.dispose(); } catch (_) {}
      });
    });
  }

  void _showAddressDialog() {
    final addr = TextEditingController(text: _addressCtrl.text);
    final pin  = TextEditingController(text: _pincodeCtrl.text);
    final dist = TextEditingController(text: _districtCtrl.text);
    final st   = TextEditingController(text: _stateCtrl.text);

    bool saving   = false;
    String? errMsg;
    bool pincodeLoading = false;
    String pincodeError = '';
    List<Map<String, dynamic>> offices = [];
    String? selectedOffice;
    VoidCallback? rebuildDialog;

    // Pre-trigger lookup if pincode is already present
    if (pin.text.trim().length == 6) {
      Future.delayed(const Duration(milliseconds: 300), () async {
        try {
          final authViewModel = ref.read(authViewModelProvider.notifier);
          final response = await authViewModel.fetchPincodeDetails(pin.text.trim());
          if (response != null && response['success'] == true) {
            final data = response['data'];
            if (data != null) {
              final officesList = data['offices'] as List? ?? [];
              offices = List<Map<String, dynamic>>.from(officesList);
              if (offices.isNotEmpty) {
                final addrLower = addr.text.toLowerCase();
                final matchIdx = offices.indexWhere((o) =>
                    o['city'] != null &&
                    addrLower.contains(o['city'].toString().toLowerCase()));
                if (matchIdx >= 0) {
                  selectedOffice = offices[matchIdx]['city']?.toString();
                } else {
                  selectedOffice = offices[0]['city']?.toString();
                }
              }
              rebuildDialog?.call();
            }
          }
        } catch (_) {}
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(builder: (ctx, setS) {
        rebuildDialog = () {
          if (ctx.mounted) setS(() {});
        };

        return Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogHeader(
                title: 'Address Details',
                icon: Icons.location_on_outlined,
                onClose: () => Navigator.pop(ctx),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (errMsg != null) _ErrorBanner(errMsg!),
                      _DField('Full Address', addr,
                          icon: Icons.home_outlined,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.words),
                      _DField('Pin Code', pin,
                          icon: Icons.pin_drop_outlined,
                          keyboardType: TextInputType.number,
                          onChanged: (val) async {
                            if (val.length == 6) {
                              setS(() {
                                pincodeLoading = true;
                                pincodeError = '';
                                offices = [];
                                selectedOffice = null;
                              });
                              try {
                                final authViewModel = ref.read(authViewModelProvider.notifier);
                                final response = await authViewModel.fetchPincodeDetails(val);
                                if (!ctx.mounted) return;
                                if (response != null && response['success'] == true) {
                                  final data = response['data'];
                                  if (data != null) {
                                    final officesList = data['offices'] as List? ?? [];
                                    setS(() {
                                      offices = List<Map<String, dynamic>>.from(officesList);
                                      if (data['district'] != null) {
                                        dist.text = data['district'];
                                      }
                                      if (data['state'] != null) {
                                        st.text = data['state'];
                                      }
                                      if (offices.isNotEmpty) {
                                        selectedOffice = offices[0]['city']?.toString();
                                      }
                                    });
                                  } else {
                                    setS(() {
                                      pincodeError = 'Pincode details not found.';
                                    });
                                  }
                                } else {
                                  setS(() {
                                    pincodeError = 'Pincode details not found.';
                                  });
                                }
                              } catch (e) {
                                if (!ctx.mounted) return;
                                setS(() {
                                  pincodeError = 'Failed to load location details.';
                                });
                              } finally {
                                setS(() {
                                  pincodeLoading = false;
                                });
                              }
                            }
                          }),
                      if (pincodeLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: LinearProgressIndicator(color: AppColors.primaryRed),
                        ),
                      if (pincodeError.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            pincodeError,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                        ),
                      if (offices.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Location / PO Location',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: selectedOffice,
                                  items: offices
                                      .map((o) => DropdownMenuItem<String>(
                                            value: o['city']?.toString(),
                                            child: Text(
                                              o['city']?.toString() ?? '',
                                              style: GoogleFonts.inter(fontSize: 14),
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    setS(() {
                                      selectedOffice = val;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      _DField('District', dist,
                          icon: Icons.map_outlined,
                          textCapitalization: TextCapitalization.words),
                      _DField('State', st,
                          icon: Icons.flag_outlined,
                          textCapitalization: TextCapitalization.words),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: saving
                            ? const _LoadingBtn()
                            : ElevatedButton.icon(
                                icon: const Icon(
                                    Icons.save_outlined,
                                    size: 18),
                                label: Text('Save Address',
                                    style: GoogleFonts.inter(
                                        fontWeight:
                                            FontWeight.bold)),
                                onPressed: () async {
                                  final uid = ref.read(authViewModelProvider.notifier).currentUser?.id;
                                  final addrVm = ref.read(profileViewModelProvider.notifier);
                                  if (uid == null) return;
                                  setS(() {
                                    saving = true;
                                    errMsg = null;
                                  });

                                  String finalAddress = addr.text.trim();
                                  if (selectedOffice != null && selectedOffice!.isNotEmpty) {
                                    if (!finalAddress.toLowerCase().contains(selectedOffice!.toLowerCase())) {
                                      if (finalAddress.isNotEmpty) {
                                        finalAddress = "$finalAddress, $selectedOffice";
                                      } else {
                                        finalAddress = selectedOffice!;
                                      }
                                    }
                                  }

                                  final cardVm = ref.read(cardViewModelProvider.notifier);
                                  final workProfileId = cardVm.currentCard?.workProfileId;
                                  final payload = <String, dynamic>{
                                    'address':  finalAddress,
                                    'pincode':  pin.text.trim(),
                                    'district': dist.text.trim(),
                                    'state':    st.text.trim(),
                                  };
                                  if (workProfileId != null && workProfileId > 0) {
                                    payload['work_profile_id'] = workProfileId;
                                  }

                                  final ok = await addrVm.updateProfile(uid, payload, workProfileId: workProfileId);
                                  if (!ctx.mounted) return;
                                  setS(() => saving = false);
                                  if (ok) {
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }
                                    if (mounted) {
                                      setState(() {
                                        _addressCtrl.text = finalAddress;
                                        _pincodeCtrl.text = pin.text;
                                        _districtCtrl.text = dist.text;
                                        _stateCtrl.text = st.text;
                                      });
                                      _showSnack('Address updated successfully!');
                                    }
                                  } else {
                                     setS(() => errMsg = ref.read(profileViewModelProvider.notifier)
                                            .errorMessage ??
                                        'Save failed. Try again.');
                                   }
                                },
                                style: _redBtnStyle(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    ).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 500), () {
        addr.dispose(); pin.dispose();
        dist.dispose(); st.dispose();
      });
    });
  }

  // ── Button styles ──────────────────────────────────────────
  ButtonStyle _redBtnStyle({bool disabled = false}) =>
      ElevatedButton.styleFrom(
        backgroundColor: disabled
            ? Colors.green.shade400
            : AppColors.primaryRed,
        disabledBackgroundColor: Colors.green.shade400,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        padding:
            const EdgeInsets.symmetric(vertical: 14),
      );


  void _showDeleteAccountDialog(BuildContext context) async {
    final confirmed = await showDeleteConfirmDialog(
      context: context,
      title: 'Delete Account',
      message: 'Are you sure you want to delete your account? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      requireTextInput: true,
      confirmInputText: 'yes',
    );

    if (confirmed == true && context.mounted) {
      final authVm = ref.read(authViewModelProvider.notifier);
      final profileVm = ref.read(profileViewModelProvider.notifier);
      final userId = (authVm.currentUser?.id?.isNotEmpty == true)
          ? authVm.currentUser!.id!
          : (profileVm.user?.id?.isNotEmpty == true ? profileVm.user!.id! : '');

      if (userId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('User session or ID not found.', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: Colors.red.shade600,
        ));
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Deleting account...', style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: Colors.blue.shade600,
        duration: const Duration(seconds: 2),
      ));

      final success = await authVm.deleteAccount(userId);
      if (success) {
        if (context.mounted) {
          try {
            ref.read(messageViewModelProvider.notifier).stopPolling();
          } catch (_) {}

          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );

          try {
            profileVm.clearUser();
          } catch (_) {}

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Account deleted successfully.', style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: Colors.green.shade600,
          ));
        }
      } else {
        if (context.mounted) {
          final errStr = authVm.error.isNotEmpty ? authVm.error : 'Failed to delete account.';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(errStr, style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: Colors.red.shade600,
          ));
        }
      }
    }
  }
}





class _Header extends ConsumerWidget {
  final String? userId;
  final String fullName;
  final String initials;
  final String? imagePath;
  final bool isUploading;
  final VoidCallback onCameraTap;
  final bool showTopBar;
  final VoidCallback? onBackTap;

  const _Header({
    this.userId,
    required this.fullName,
    required this.initials,
    required this.imagePath,
    required this.isUploading,
    required this.onCameraTap,
    this.showTopBar = true,
    this.onBackTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = showTopBar
        ? (MediaQuery.of(context).padding.top + 8.0)
        : 16.0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryRed, AppColors.secondaryRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(top: topPadding, bottom: 44),
      child: Column(
        children: [
          if (showTopBar) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    onPressed: () {
                      if (onBackTap != null) {
                        onBackTap!();
                      } else if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        try {
                          ref.read(dashboardViewModelProvider.notifier).setIndex(0);
                        } catch (_) {}
                      }
                    },
                  ),
                  Expanded(
                    child: Text(
                      'My Profile',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // balances back button
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),

            // Rectangular Profile Avatar with Hero Animation matching bottom sheet
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (imagePath != null && imagePath!.isNotEmpty) {
                      ProfileHeroRectDialog.show(
                        context,
                        imageUrl: imagePath!,
                        heroTag: 'profile_hero_avatar_${userId ?? 'current'}',
                        fullName: fullName,
                        initials: initials,
                      );
                    } else {
                      onCameraTap();
                    }
                  },
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Hero(
                      tag: 'profile_hero_avatar_${userId ?? 'current'}',
                      createRectTween: (begin, end) => ProfileHeroArcTween(begin: begin, end: end),
                      flightShuttleBuilder: profileHeroFlightShuttleBuilder,
                      child: ClipOval(
                        child: isUploading
                            ? Container(
                                color: Colors.white,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primaryRed,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              )
                            : (imagePath != null && imagePath!.isNotEmpty)
                                ? CachedNetworkImage(
                                    imageUrl: UploadUrlResolver.resolve(imagePath!, type: 'profile'),
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.high,
                                    placeholder: (ctx, url) => Container(
                                      color: Colors.white,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: AppColors.primaryRed,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, _, _) => Container(
                                      color: Colors.white,
                                      alignment: Alignment.center,
                                      child: Text(
                                        initials,
                                        style: GoogleFonts.outfit(
                                          color: AppColors.primaryRed,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Colors.white,
                                    alignment: Alignment.center,
                                    child: Text(
                                      initials,
                                      style: GoogleFonts.outfit(
                                        color: AppColors.primaryRed,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                      ),
                    ),
                  ),
                ),
                // Camera badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: onCameraTap,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryRed,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: AppColors.primaryRed,
                        size: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  fullName,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Dynamic Membership Badge (Premium vs Free User)
            Consumer(builder: (context, ref, child) {
  final subVm = ref.watch(subscriptionViewModelProvider);
                final isPremium = subVm.isPremium;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: isPremium
                        ? const Color(0xFFFFD700).withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPremium
                          ? const Color(0xFFFFD700).withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPremium ? Icons.workspace_premium_rounded : Icons.person_outline,
                        color: isPremium ? const Color(0xFFFFD700) : Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPremium ? 'Premium Member' : 'Free User',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
          ],
        ),
      );
  }
  }

// ═══════════════════════════════════════════════════════════════
// _InfoCard
// ═══════════════════════════════════════════════════════════════




// ═══════════════════════════════════════════════════════════════
// Dialog sub-widgets
// ═══════════════════════════════════════════════════════════════
class _DialogHeader extends ConsumerWidget {
  final String title;
  final IconData icon;
  final VoidCallback onClose;
  const _DialogHeader(
      {required this.title,
      required this.icon,
      required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryRed, AppColors.secondaryRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close,
                  color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dialog text field ────────────────────────────────────────
class _DField extends ConsumerWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData? icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;

  const _DField(this.label, this.ctrl,
      {super.key,
      this.icon,
      this.maxLines = 1,
      this.keyboardType,
      this.onChanged,
      this.textCapitalization = TextCapitalization.none});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            onChanged: onChanged,
            style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF1E293B)),
            decoration: InputDecoration(
              prefixIcon: icon != null
                  ? Icon(icon,
                      color: AppColors.primaryRed
                          .withValues(alpha: 0.15),
                      size: 18)
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: Colors.grey[300]!)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.primaryRed,
                      width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error banner ─────────────────────────────────────────────
class _ErrorBanner extends ConsumerWidget {
  final String msg;
  const _ErrorBanner(this.msg);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: Colors.red.shade600, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: GoogleFonts.inter(
                    color: Colors.red.shade600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Loading button ────────────────────────────────────────────
class _LoadingBtn extends ConsumerWidget {
  const _LoadingBtn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryRed,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
            color: Colors.white, strokeWidth: 2.5),
      ),
    );
  }
}



// ── Image Confirm Sheet ──────────────────────────────────────
class _ImageConfirmSheet extends ConsumerStatefulWidget {
  final String imagePath;
  final String? croppedPath;
  final String userId;

  const _ImageConfirmSheet({
    required this.imagePath,
    required this.croppedPath,
    required this.userId,
  });

  @override
  ConsumerState<_ImageConfirmSheet> createState() => _ImageConfirmSheetState();
}

class _ImageConfirmSheetState extends ConsumerState<_ImageConfirmSheet> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final imageWidget = kIsWeb
        ? Image.network(widget.imagePath, fit: BoxFit.cover)
        : Image.file(File(widget.imagePath), fit: BoxFit.cover);

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
            'Confirm Image Change',
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
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.15), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: imageWidget,
            ),
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

    try {
      final ok = await ref.read(profileViewModelProvider.notifier)
          .uploadProfileImageSafe(widget.userId, widget.imagePath);

      if (!context.mounted) return;

      if (ok) {
        // Also sync card profile image
        try {
          final cardVm = ref.read(cardViewModelProvider.notifier);
          if (cardVm.currentCard != null) {
            await cardVm.handleUploadProfileImage(
              widget.croppedPath ?? widget.imagePath,
              null,
            );
          }
          await cardVm.fetchCards(widget.userId);
        } catch (_) {}

        // Bust cache so the new image renders instantly
        UploadUrlResolver.bustCache();

        if (context.mounted) {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _isUploading = false;
        });
        final errorMsg = ref.read(profileViewModelProvider.notifier).errorMessage ??
            'Upload failed. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMsg, style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: Colors.red.shade600,
        ));
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
class _HeartbeatSuccessOverlay extends ConsumerStatefulWidget {
  const _HeartbeatSuccessOverlay();

  @override
  ConsumerState<_HeartbeatSuccessOverlay> createState() => _HeartbeatSuccessOverlayState();
}

class _HeartbeatSuccessOverlayState extends ConsumerState<_HeartbeatSuccessOverlay>
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
                'Profile upload successfully!',
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



