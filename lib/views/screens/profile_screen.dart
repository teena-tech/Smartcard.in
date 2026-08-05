import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io' show File;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/card_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/message_viewmodel.dart';
import '../../models/user_model.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/upload_url_resolver.dart';
import '../widgets/common_drawer.dart';
import '../widgets/image_cropper_widget.dart';
import '../widgets/info_card.dart';
import '../widgets/otp_input_field.dart';
import '../widgets/delete_confirm_dialog.dart';
import 'login_screen.dart';

// ═══════════════════════════════════════════════════════════════
// Root Screen
// ═══════════════════════════════════════════════════════════════
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CommonDrawer(currentRoute: 'Dashboard'),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/login.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: const ResponsiveCenter(child: _ProfileBody()),
      ),
    );
  }
}

// Public alias — home_screen.dart references ProfileBody by name
class ProfileBody extends StatelessWidget {
  const ProfileBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/login.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: const ResponsiveCenter(child: _ProfileBody()),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody();

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  bool    _isInit              = false;
  String? _lastPopulatedUserId;

  // ── Form controllers (personal) ─────────────────────────────
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _professionCtrl;
  String _gender = 'Male';

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
    final profileVm = context.read<ProfileViewModel>();
    final authVm    = context.read<AuthViewModel>();
    final currentUserId = authVm.currentUser?.id;

    if (!_isInit) {
      if (profileVm.user == null &&
          !profileVm.isLoading &&
          currentUserId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          profileVm.loadProfile(currentUserId).then((_) {
            if (!context.mounted) return;
            _populate(context.read<ProfileViewModel>().user);
            _lastPopulatedUserId = currentUserId;
          });
        });
      } else {
        _populate(profileVm.user);
        _lastPopulatedUserId = currentUserId;
      }
      _isInit = true;
      return;
    }

    if (profileVm.user != null &&
        profileVm.user!.id != _lastPopulatedUserId) {
      _populate(profileVm.user);
      _lastPopulatedUserId = profileVm.user!.id;
    }
  }

  void _populate(UserModel? u) {
    if (u == null) return;
    _set(_firstNameCtrl,  u.firstName);
    _set(_lastNameCtrl,   u.lastName);
    _set(_emailCtrl,      u.email);
    _set(_phoneCtrl,      u.phone);
    _set(_dobCtrl,        u.dateOfBirth);
    _set(_professionCtrl, u.profession);
    _set(_addressCtrl,    u.address);
    _set(_pincodeCtrl,    u.pincode);
    _set(_districtCtrl,   u.district);
    _set(_stateCtrl,      u.state);
    if (u.gender != null && u.gender!.isNotEmpty) {
      _gender = _normaliseGender(u.gender!);
    }
    if (context.mounted) setState(() {});
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

      final userId = context.read<AuthViewModel>().currentUser?.id;
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: error ? Colors.red.shade600 : Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
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
              Text('Change Profile Photo',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_outlined,
                      color: AppColors.primaryRed),
                ),
                title: Text('Take Photo',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_outlined,
                      color: AppColors.primaryRed),
                ),
                title: Text('Choose from Gallery',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
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
                  final authVm = context.read<AuthViewModel>();
                  final userId = authVm.currentUser?.id;
                  if (userId == null) return;

                  final success = await context
                      .read<ProfileViewModel>()
                      .removeProfileImage(userId);

                  if (success && authVm.currentUser != null) {
                    authVm.updateUser(authVm.currentUser!.copyWith(profileImage: ''));
                    context.read<CardViewModel>().clearProfileImage();
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
    final profileVm = context.watch<ProfileViewModel>();
    final cardImage = context.select<CardViewModel, String?>((vm) => vm.currentCard?.profileImageName);
    context.watch<ThemeViewModel>(); // keep dependency without unused variable

    final profile   = profileVm.user;
    final userImage = profile?.profileImage;
    final imagePath =
        (cardImage != null && cardImage.isNotEmpty) ? cardImage : userImage;

    final fullName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : '${_firstNameCtrl.text} ${_lastNameCtrl.text}'.trim();

    IconData getGenderIcon(String gender) {
      final g = gender.toLowerCase().trim();
      if (g == 'female') return Icons.female_outlined;
      if (g == 'male') return Icons.male_outlined;
      return Icons.transgender;
    }

    return Column(
      children: [
        _StickyTopBar(
          initials: profile?.initials ?? '?',
          imagePath: imagePath,
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primaryRed,
            onRefresh: () async {
              final uid = context.read<AuthViewModel>().currentUser?.id;
              final pVm = context.read<ProfileViewModel>();
              if (uid != null) {
                await pVm.loadProfile(uid);
                if (context.mounted) {
                  _populate(pVm.user);
                }
              }
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // ── Red header ──────────────────────────────────────
                  _Header(
                    fullName:        fullName.isEmpty ? 'Your Name' : fullName,
                    initials:        profile?.initials ?? '?',
                    imagePath:       imagePath,
                    isUploading:     profileVm.isUploadingImage,
                    onCameraTap:     _showImageSourceSheet,
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
                          offset: const Offset(0, -16),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                            child: Column(
                              children: [
                                InfoCard(
                                  title: 'PERSONAL DETAILS',
                                  icon: Icons.person_outline,
                                  onEdit: _showPersonalDetailsDialog,
                                  rows: [
                                    RowData(Icons.person_outline,       'Full Name',    fullName.isEmpty ? '—' : fullName),
                                    RowData(getGenderIcon(_gender),      'Gender',       _gender),
                                    RowData(Icons.mail_outline,          'Email Address', _emailCtrl.text.isEmpty ? '—' : _emailCtrl.text),
                                    RowData(Icons.phone_outlined,        'Phone Number',  _phoneCtrl.text.isEmpty ? '—' : _phoneCtrl.text),
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
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════
  // PERSONAL DETAILS DIALOG — direct save, no OTP gate
  // ═════════════════════════════════════════════════════════════
  void _showPersonalDetailsDialog() {
    // Temporary copies so dialog changes don't affect main state until saved
    final fn  = TextEditingController(text: _firstNameCtrl.text);
    final ln  = TextEditingController(text: _lastNameCtrl.text);
    final em  = TextEditingController(text: _emailCtrl.text);
    final ph  = TextEditingController(text: _phoneCtrl.text);
    final otpCtrl = TextEditingController();
    String dialogGender = _gender;
    bool showOtpField = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        bool saving  = false;
        String? errMsg;

        return StatefulBuilder(builder: (ctx, setS) {
          final profileVm = ctx.read<ProfileViewModel>();
          final authVm    = ctx.read<AuthViewModel>();
          final userId    = authVm.currentUser?.id ?? '';

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogHeader(
                  title: 'Personal Details',
                  icon: Icons.person_outline,
                  onClose: () => Navigator.pop(ctx),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (errMsg != null) _ErrorBanner(errMsg!),
                        _DField('First Name', fn,
                            icon: Icons.person_outline),
                        _DField('Last Name', ln,
                            icon: Icons.person_outline),
                        _DField('Email Address', em,
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress),
                        _DField('Phone Number', ph,
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone),
                        const SizedBox(height: 4),
                        Text('Gender',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700])),
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
                              value: dialogGender,
                              isExpanded: true,
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
                          Text(
                            'Enter the 6-digit OTP sent to your phone to verify changes',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 12),
                          OTPInputField(
                            controller: otpCtrl,
                            length: 6,
                            onCompleted: (code) async {
                              setS(() { saving = true; errMsg = null; });
                              final verified = await profileVm.verifyProfileOtp(userId, code);
                              if (!ctx.mounted) return;
                              if (verified) {
                                final updated = await profileVm.updateProfile(userId, {
                                  'first_name':    fn.text.trim(),
                                  'last_name':     ln.text.trim(),
                                  'email':         em.text.trim(),
                                  'phone':         ph.text.trim(),
                                  'gender':        dialogGender,
                                });
                                if (!ctx.mounted) return;
                                setS(() => saving = false);
                                if (updated) {
                                  if (context.mounted) {
                                    setState(() {
                                      _firstNameCtrl.text  = fn.text;
                                      _lastNameCtrl.text   = ln.text;
                                      _emailCtrl.text      = em.text;
                                      _phoneCtrl.text      = ph.text;
                                      _gender              = dialogGender;
                                    });
                                  }
                                  profileVm.loadProfile(userId).then((_) {
                                    if (context.mounted) _populate(profileVm.user);
                                  });
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) _showSnack('Personal details updated!');
                                } else {
                                  setS(() {
                                    errMsg = profileVm.errorMessage ?? 'Update failed. Please try again.';
                                  });
                                }
                              } else {
                                setS(() {
                                  saving = false;
                                  errMsg = profileVm.errorMessage ?? 'OTP verification failed. Please try again.';
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
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
                                    icon: const Icon(Icons.save_outlined, size: 18),
                                    label: Text('Save Changes',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                    onPressed: () async {
                                      setS(() { saving = true; errMsg = null; });
                                      final nameOrPhoneChanged =
                                          fn.text.trim() != (_firstNameCtrl.text) ||
                                          ln.text.trim() != (_lastNameCtrl.text) ||
                                          ph.text.trim() != (_phoneCtrl.text);

                                      if (nameOrPhoneChanged) {
                                        final requested = await profileVm.sendProfileOtp(userId, ph.text.trim());
                                        if (!ctx.mounted) return;
                                        setS(() => saving = false);
                                        if (requested) {
                                          setS(() {
                                            showOtpField = true;
                                            otpCtrl.clear();
                                          });
                                        } else {
                                          setS(() {
                                            errMsg = profileVm.errorMessage ?? 'Failed to send OTP. Try again.';
                                          });
                                        }
                                      } else {
                                        final updated = await profileVm.updateProfile(userId, {
                                          'first_name':    fn.text.trim(),
                                          'last_name':     ln.text.trim(),
                                          'email':         em.text.trim(),
                                          'phone':         ph.text.trim(),
                                          'gender':        dialogGender,
                                        });
                                        if (!ctx.mounted) return;
                                        setS(() => saving = false);
                                        if (updated) {
                                          if (context.mounted) {
                                            setState(() {
                                              _firstNameCtrl.text  = fn.text;
                                              _lastNameCtrl.text   = ln.text;
                                              _emailCtrl.text      = em.text;
                                              _phoneCtrl.text      = ph.text;
                                              _gender              = dialogGender;
                                            });
                                          }
                                          profileVm.loadProfile(userId).then((_) {
                                            if (context.mounted) _populate(profileVm.user);
                                          });
                                          if (ctx.mounted) Navigator.pop(ctx);
                                          if (context.mounted) _showSnack('Personal details updated!');
                                        } else {
                                          setS(() {
                                            errMsg = profileVm.errorMessage ?? 'Update failed. Please try again.';
                                          });
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
    );
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
          final authViewModel = context.read<AuthViewModel>();
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
                          icon: Icons.home_outlined, maxLines: 3),
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
                                final authViewModel = ctx.read<AuthViewModel>();
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
                          icon: Icons.map_outlined),
                      _DField('State', st,
                          icon: Icons.flag_outlined),
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
                                  final uid = ctx.read<AuthViewModel>().currentUser?.id;
                                  final addrVm = ctx.read<ProfileViewModel>();
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

                                  final ok = await addrVm.updateProfile(uid, {
                                    'address':  finalAddress,
                                    'pincode':  pin.text.trim(),
                                    'district': dist.text.trim(),
                                    'state':    st.text.trim(),
                                  });
                                  if (!ctx.mounted) return;
                                  setS(() => saving = false);
                                  if (ok) {
                                    if (context.mounted) {
                                      setState(() {
                                        _addressCtrl.text =
                                            finalAddress;
                                        _pincodeCtrl.text =
                                            pin.text;
                                        _districtCtrl.text =
                                            dist.text;
                                        _stateCtrl.text =
                                            st.text;
                                      });
                                    }
                                     if (ctx.mounted) {
                                       Navigator.pop(ctx);
                                     }
                                   } else {
                                     setS(() => errMsg = ctx
                                            .read<ProfileViewModel>()
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
      final authVm = context.read<AuthViewModel>();
      final profileVm = context.read<ProfileViewModel>();
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

      final success = await authVm.deleteAccount(userId);
      if (success) {
        if (context.mounted) {
          context.read<MessageViewModel>().stopPolling();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
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



class _StickyTopBar extends StatelessWidget {
  final String initials;
  final String? imagePath;

  const _StickyTopBar({
    required this.initials,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primaryRed,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white, size: 18),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              Text(
                'My Profile',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: (imagePath != null && imagePath!.isNotEmpty)
                    ? Image.network(
                        UploadUrlResolver.resolve(imagePath!, type: 'profile'),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(
                          child: Text(
                            initials.isEmpty ? 'U' : initials,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initials.isEmpty ? 'U' : initials,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
}

class _Header extends StatelessWidget {
  final String fullName;
  final String initials;
  final String? imagePath;
  final bool isUploading;
  final VoidCallback onCameraTap;

  const _Header({
    required this.fullName,
    required this.initials,
    required this.imagePath,
    required this.isUploading,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryRed, AppColors.secondaryRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.only(top: 16, bottom: 40),
      child: Column(
        children: [
          const SizedBox(height: 8),

            // Circular Avatar
            GestureDetector(
              onTap: onCameraTap,
              child: Stack(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: isUploading
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primaryRed,
                                    strokeWidth: 2.5))
                            : (imagePath != null && imagePath!.isNotEmpty)
                                ? Image.network(
                                    UploadUrlResolver.resolve(imagePath!, type: 'profile'),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        _Initials(initials: initials),
                                  )
                                : _Initials(initials: initials),
                      ),
                    ),
                  ),
                  // Camera badge
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryRed,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: AppColors.primaryRed,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Name
            Text(fullName,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),

            // Free user badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline, color: Colors.white70, size: 13),
                  const SizedBox(width: 4),
                  Text('Free User',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
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
class _DialogHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onClose;
  const _DialogHeader(
      {required this.title,
      required this.icon,
      required this.onClose});

  @override
  Widget build(BuildContext context) {
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
class _DField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData? icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? hint;
  final ValueChanged<String>? onChanged;

  const _DField(this.label, this.ctrl,
      {this.icon,
      this.maxLines = 1,
      this.keyboardType,
      this.hint,
      this.onChanged});

  @override
  Widget build(BuildContext context) {
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
            onChanged: onChanged,
            style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: hint,
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
class _ErrorBanner extends StatelessWidget {
  final String msg;
  const _ErrorBanner(this.msg);

  @override
  Widget build(BuildContext context) {
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
class _LoadingBtn extends StatelessWidget {
  final bool green;
  const _LoadingBtn({this.green = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: green ? Colors.green : AppColors.primaryRed,
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


// ── Initials avatar ───────────────────────────────────────────
class _Initials extends StatelessWidget {
  final String initials;
  const _Initials({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFECEC),
      alignment: Alignment.center,
      child: Text(initials,
          style: GoogleFonts.inter(
              color: AppColors.primaryRed,
              fontSize: 28,
              fontWeight: FontWeight.bold)),
    );
  }
}

// ── Image Confirm Sheet ──────────────────────────────────────
class _ImageConfirmSheet extends StatefulWidget {
  final String imagePath;
  final String? croppedPath;
  final String userId;

  const _ImageConfirmSheet({
    required this.imagePath,
    required this.croppedPath,
    required this.userId,
  });

  @override
  State<_ImageConfirmSheet> createState() => _ImageConfirmSheetState();
}

class _ImageConfirmSheetState extends State<_ImageConfirmSheet> {
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
      final ok = await context
          .read<ProfileViewModel>()
          .uploadProfileImageSafe(widget.userId, widget.imagePath);

      if (!context.mounted) return;

      if (ok) {
        // Also sync card profile image
        try {
          final cardVm = context.read<CardViewModel>();
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
        final errorMsg = context.read<ProfileViewModel>().errorMessage ??
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
class _HeartbeatSuccessOverlay extends StatefulWidget {
  const _HeartbeatSuccessOverlay();

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



