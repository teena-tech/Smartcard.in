import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/view/home_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
import 'package:smartcard_flutter/core/widgets/custom_text_field.dart';
import 'package:smartcard_flutter/core/widgets/primary_button.dart';
import 'package:smartcard_flutter/core/utils/responsive.dart';
import 'package:smartcard_flutter/features/register_screen/presentation/view/widgets/otp_channel_banner.dart';
import 'package:smartcard_flutter/core/widgets/otp_input_field.dart';
import 'package:smartcard_flutter/features/register_screen/presentation/view/widgets/international_phone_input.dart';
import 'package:smartcard_flutter/core/utils/international_phone_helper.dart';
import 'package:smartcard_flutter/core/services/otp_autofill_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  int _step = 1;
  String _error = '';
  String _message = '';

  // Step 1: Phone & WhatsApp Mode
  final _phoneController = TextEditingController();
  bool _isWhatsAppMode = false;
  String _selectedCountryCode = '+91';
  String _selectedCountryFlag = '🇮🇳';
  
  // Step 2: OTP
  final _otpController = TextEditingController();
  String _sentToMask = '';
  Timer? _resendTimer;
  int _resendSecondsLeft = 0;
  static const int _resendCooldown = 30;

  // Step 3: Personal Details
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedGender;

  // Step 4: Address Details
  final _pincodeController = TextEditingController();
  final _districtController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');
  final _addressController = TextEditingController();

  String? _selectedCity;
  int? _selectedCityId;
  int? _selectedStateId;
  List<Map<String, dynamic>> _availableOffices = [];

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Transgender',
    'Not-Mention',
  ];
  final List<String> _dummyCities = ['Chennai', 'Coimbatore', 'Madurai'];

  @override
  void initState() {
    super.initState();
    _pincodeController.addListener(_onPincodeChanged);
  }
  String capitalizeWords(String text) {
    return text
        .split(' ')
        .map((word) => word.isEmpty
        ? ''
        : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  void _startOtpListener() {
    OtpAutofillService().startListening(
      onCodeReceived: (receivedCode) {
        if (!mounted) return;
        final cleanCode = receivedCode.replaceAll(RegExp(r'\D'), '');
        if (cleanCode.length >= 6) {
          final otp6 = cleanCode.substring(0, 6);
          setState(() {
            _otpController.text = otp6;
          });
          OtpAutofillService().markAutofillInitialized();
          _handleVerifyOtp();
        }
      },
      onTimeout: () {
        debugPrint('⏰ [RegisterScreen] OTP autofill listening timed out');
      },
    );
  }

  void _stopOtpListener() {
    OtpAutofillService().stopListening();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _stopOtpListener();
    _pincodeController.removeListener(_onPincodeChanged);
    _phoneController.dispose();
    _otpController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _pincodeController.dispose();
    _districtController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _onPincodeChanged() async {
    final pincode = _pincodeController.text.trim();
    if (pincode.length == 6) {
      final authViewModel = ref.read(authViewModelProvider.notifier);
      final response = await authViewModel.fetchPincodeDetails(pincode);

      if (response != null && response['success'] == true) {
        final data = response['data'];
        setState(() {
          if (data != null) {
            if (data['city'] != null) {
              _selectedCity = data['city'];
            }
            if (data['district'] != null) {
              _districtController.text = data['district'];
            }
            if (data['state'] != null) {
              _stateController.text = data['state'];
            }
            if (data['city_id'] != null) {
              _selectedCityId = data['city_id'];
            }
            if (data['state_id'] != null) {
              _selectedStateId = data['state_id'];
            }
            if (data['offices'] != null && data['offices'] is List) {
              _availableOffices = List<Map<String, dynamic>>.from(
                data['offices'],
              );
            }
          }
        });
      }
    }
  }

  void _clearFeedback() {
    setState(() {
      _error = '';
      _message = '';
    });
  }

  void _goBackToPhoneStep() {
    _stopOtpListener();
    _resendTimer?.cancel();
    _otpController.clear();
    setState(() {
      _step = 1;
      _error = '';
      _message = '';
      _resendSecondsLeft = 0;
    });
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendSecondsLeft = _resendCooldown;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {
        _resendSecondsLeft = _resendSecondsLeft - 1;
        if (_resendSecondsLeft <= 0) {
          _resendTimer?.cancel();
          _resendSecondsLeft = 0;
        }
      });
    });
  }

  Future<void> _sendRegOtp({
    required bool useWhatsApp,
    required bool checkAvailability,
    bool showSnack = false,
  }) async {
    _clearFeedback();
    final phone = _phoneController.text.trim();

    final validationError = InternationalPhoneHelper.validatePhoneNumber(
      phone: phone,
      countryCode: _selectedCountryCode,
      isWhatsApp: useWhatsApp,
    );
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    final authViewModel = ref.read(authViewModelProvider.notifier);
    final previousWhatsApp = _isWhatsAppMode;

    if (checkAvailability) {
      final available = await authViewModel.checkPhone(
        phone,
        countryCode: _selectedCountryCode,
      );
      if (!mounted) return;
      if (!available) {
        setState(
          () => _error = authViewModel.errorMessage ?? 'Phone already registered',
        );
        return;
      }
    }

    if (_isWhatsAppMode != useWhatsApp) {
      setState(() => _isWhatsAppMode = useWhatsApp);
    }

    final success = await authViewModel.sendRegistrationOtp(
      phone,
      channel: useWhatsApp ? 'whatsapp' : 'phone',
      countryCode: _selectedCountryCode,
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        _isWhatsAppMode = previousWhatsApp;
        _error = authViewModel.error;
      });
    } else {
      _otpController.clear();
      setState(() {
        _sentToMask = '$_selectedCountryFlag $_selectedCountryCode $phone';
        _message = useWhatsApp
            ? 'OTP sent successfully. Check your WhatsApp.'
            : 'OTP sent successfully. Check your SMS.';
        _step = 2;
      });
      _startResendTimer();
      _startOtpListener();

      if (showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              useWhatsApp ? 'OTP sent via WhatsApp' : 'OTP sent via SMS',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: const Color(0xFF15803D),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _handleSendOtp() async {
    await _sendRegOtp(
      useWhatsApp: _isWhatsAppMode,
      checkAvailability: true,
    );
  }

  void _handleResendOtp() async {
    if (_resendSecondsLeft > 0) return;
    await _sendRegOtp(
      useWhatsApp: _isWhatsAppMode,
      checkAvailability: false,
      showSnack: true,
    );
  }

  void _handleVerifyOtp() async {
    _clearFeedback();
    if (_otpController.text.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP');
      return;
    }

    final authViewModel = ref.read(authViewModelProvider.notifier);
    final success = await authViewModel.verifyRegistrationOtp(_otpController.text.trim());

    if (success) {
      _stopOtpListener();
      OtpAutofillService().markAutofillInitialized();
      setState(() {
        _step = 3;
      });
    } else {
      setState(() => _error = authViewModel.error);
    }
  }

  void _handlePersonalDetails() {
    _clearFeedback();
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty) {
      setState(() => _error = 'Please fill all required fields');
      return;
    }

    setState(() => _step = 4);
  }

  void _handleRegister() async {
    _clearFeedback();
    if (_pincodeController.text.length != 6) {
      setState(() => _error = 'Pincode must be 6 digits');
      return;
    }

    final authViewModel = ref.read(authViewModelProvider.notifier);

    final registrationData = {
      'verification_token': authViewModel.verificationToken,
      'phone': InternationalPhoneHelper.formatForBackend(
        phone: _phoneController.text.trim(),
        countryCode: _selectedCountryCode,
      ),
      'country_code': _selectedCountryCode,
      'full_phone': InternationalPhoneHelper.toE164(
        phone: _phoneController.text.trim(),
        countryCode: _selectedCountryCode,
      ),
      'preferred_otp_method': _isWhatsAppMode ? 'whatsapp' : 'phone',
      'delivery_method': _isWhatsAppMode ? 'whatsapp' : 'phone',
      'first_name': capitalizeWords(_firstNameController.text.trim()),
      'last_name': capitalizeWords(_lastNameController.text.trim()),
      'email': _emailController.text.trim(),
      'gender': _selectedGender,
      'pincode': _pincodeController.text.trim(),
      'city_id': _selectedCityId,
      'state_id': _selectedStateId,
      'address': capitalizeWords(_addressController.text.trim()),
      'district': capitalizeWords(_districtController.text.trim()),
      'state': capitalizeWords(_stateController.text.trim()),
      'country': capitalizeWords(_countryController.text.trim()),
    };

    final success = await authViewModel.register(registrationData);

    if (success) {
      setState(() {
        _message = '${_firstNameController.text} registered successfully';
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 0)),
            (route) => false,
          );
        }
      });
    } else {
      setState(() => _error = authViewModel.error);
    }
  }

  Widget _buildProgressBar() {
    final colors = ref.watch(themeViewModelProvider).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REGISTRATION PROGRESS',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 5,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 5,
                  width: constraints.maxWidth * (_step / 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFDC2626),
                        Color(0xFF9E1C24),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Step $_step of 4',
          style: GoogleFonts.inter(
            color: colors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBackPillButton(VoidCallback onPressed) {
    const crimson = Color(0xFF9E1C24);
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: crimson,
          side: const BorderSide(color: crimson, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Text(
          'Back',
          style: GoogleFonts.inter(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    final colors = ref.watch(themeViewModelProvider).colors;
    final busy = ref.watch(authViewModelProvider).isLoading;

    switch (_step) {
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InternationalPhoneInput(
              phoneController: _phoneController,
              isWhatsAppMode: false,
              selectedCountryCode: '+91',
              allowSeparateWhatsApp: false,
              showModeSelector: false,
              disableCountryPicker: true,
              showChannelStatusBanner: false,
              enabled: !busy,
              onWhatsAppModeChanged: (val) {
                setState(() {
                  _isWhatsAppMode = val;
                  if (!val) {
                    _selectedCountryCode = '+91';
                    _selectedCountryFlag = '🇮🇳';
                  }
                  _clearFeedback();
                });
              },
              onCountryCodeChanged: (cData) {
                setState(() {
                  _selectedCountryCode = cData.code;
                  _selectedCountryFlag = cData.flag;
                  _clearFeedback();
                });
              },
              onChanged: (_) => _clearFeedback(),
            ),

            const SizedBox(height: 14),
            Text(
              'Enter your mobile number to create your SmartCards account.',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              text: busy ? 'Sending...' : 'SEND OTP',
              isLoading: busy,
              onPressed: _handleSendOtp,
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OtpChannelBanner(
              isWhatsAppMode: _isWhatsAppMode,
              phoneDisplay: _sentToMask,
              onChangePressed: _goBackToPhoneStep,
            ),
            const SizedBox(height: 18),
            OTPInputField(
              controller: _otpController,
              length: 6,
              accentColor: const Color(0xFFA81C24),
              onChanged: (code) {
                if (_error.isNotEmpty) {
                  setState(() => _error = '');
                }
              },
              onCompleted: (code) {
                if (code.length == 6) {
                  _handleVerifyOtp();
                }
              },
            ),
            const SizedBox(height: 16),
            OtpStatusNotice(
              statusMessage: _message,
              errorMessage: _error,
              isWhatsAppMode: false,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildBackPillButton(_goBackToPhoneStep)),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    text: busy ? 'Verifying...' : 'VERIFY OTP',
                    isLoading: busy,
                    onPressed: _handleVerifyOtp,
                  ),
                ),
              ],
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'First name',
                    hintText: 'First name',
                    controller: _firstNameController,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    label: 'Last name',
                    hintText: 'Last name',
                    controller: _lastNameController,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Email',
              hintText: 'Email (required)',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            // Gender Dropdown
            Text(
              'GENDER',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedGender,
                  hint: Text(
                    'Gender (optional)',
                    style: GoogleFonts.inter(color: colors.muted),
                  ),
                  items: _genderOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedGender = val),
                ),
              ),
            ),

            const SizedBox(height: 16),

            CustomTextField(
              label: 'Country',
              hintText: 'India',
              controller: _countryController,
              readOnly: true,
              enabled: false,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildBackPillButton(() => setState(() => _step = 2)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    text: 'Next',
                    onPressed: _handlePersonalDetails,
                  ),
                ),
              ],
            ),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(
              label: 'Pincode',
              hintText: 'Pincode (required)',
              controller: _pincodeController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            // Offices Dropdown (if multiple offices available)
            if (_availableOffices.length > 1) ...[
              Text(
                'SELECT LOCATION',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    isExpanded: true,
                    value: _availableOffices.firstWhere(
                      (office) => office['city_id'] == _selectedCityId,
                      orElse: () => _availableOffices[0],
                    ),
                    hint: Text(
                      'Select your location',
                      style: GoogleFonts.inter(color: colors.muted),
                    ),
                    items: _availableOffices
                        .map((office) => DropdownMenuItem(
                              value: office,
                              child: Text(office['city'] ?? 'Unknown'),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() {
                      if (val != null) {
                        _selectedCity = val['city'];
                        _selectedCityId = val['city_id'];
                        _selectedStateId = val['state_id'];
                        if (val['district'] != null) {
                          _districtController.text = val['district'];
                        }
                        if (val['state'] != null) {
                          _stateController.text = val['state'];
                        }
                      }
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // City Dropdown (fallback if no offices)
            if (_availableOffices.length <= 1) ...[
              Text(
                'CITY',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedCity,
                    hint: Text(
                      'City',
                      style: GoogleFonts.inter(color: colors.muted),
                    ),
                    items: _dummyCities
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCity = val),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            CustomTextField(
              label: 'District',
              hintText: 'District',
              controller: _districtController,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'State',
              hintText: 'State',
              controller: _stateController,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Address',
              hintText: 'Address (optional)',
              controller: _addressController,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildBackPillButton(() => setState(() => _step = 3)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    text: busy ? 'Registering...' : 'Register',
                    isLoading: busy,
                    onPressed: _handleRegister,
                  ),
                ),
              ],
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeViewModelProvider).colors;
    final busy = ref.watch(authViewModelProvider).isLoading;
    const crimson = Color(0xFF9E1C24);

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
        child: SafeArea(
          child: Stack(
            children: [
              ResponsiveCenter(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/images/smartlogo.png',
                            height: 90,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 44),

                        Text(
                          'USER ACCESS',
                          style: GoogleFonts.inter(
                            color: AppColors.primaryRedHover,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Register',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.w300,
                                color: colors.text,
                              ),
                        ),
                        const SizedBox(height: 15),

                        // Luxury elevated white card matching Login aesthetics
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.05),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_step > 1) ...[
                                _buildProgressBar(),
                                const SizedBox(height: 18),
                              ],
                              if (_step != 2) ...[
                                if (_message.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14.0),
                                    child: Text(
                                      _message,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF15803D),
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (_error.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14.0),
                                    child: Text(
                                      _error,
                                      style: GoogleFonts.inter(
                                        color: Colors.red[600],
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                child: _buildStepContent(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Footer Actions
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: crimson,
                              textStyle: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                                letterSpacing: 0.2,
                                decoration: TextDecoration.underline,
                                decorationColor: crimson,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            ),
                            child: const Text('Back to login'),
                          ),
                        ),
                        if (_step == 2)
                          Center(
                            child: TextButton(
                              onPressed: (busy || _resendSecondsLeft > 0)
                                  ? null
                                  : _handleResendOtp,
                              style: TextButton.styleFrom(
                                foregroundColor: crimson,
                                disabledForegroundColor: const Color(0xFF1F2937),
                                textStyle: GoogleFonts.inter(
                                  fontWeight: _resendSecondsLeft > 0
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              child: Text(
                                _resendSecondsLeft > 0
                                    ? 'Resend OTP in ${_resendSecondsLeft}s'
                                    : 'Resend OTP',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Color(0xFF1F2937),
                  ),
                  onPressed: () {
                    if (_step == 2) {
                      _goBackToPhoneStep();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
