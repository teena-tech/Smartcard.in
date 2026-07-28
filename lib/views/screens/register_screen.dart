import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../../core/utils/responsive.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 1;
  String _error = '';
  String _message = '';

  // Step 1: Phone
  final _phoneController = TextEditingController();
  
  // Step 2: OTP
  final _otpController = TextEditingController();
  String _sentToMask = '';

  // Step 3: Personal Details
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedGender;

  // Step 4: Address Details
  final _pincodeController = TextEditingController();
  final _districtController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
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

  @override
  void dispose() {
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
      final authViewModel = context.read<AuthViewModel>();
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

  void _handleSendOtp() async {
    _clearFeedback();
    if (_phoneController.text.length != 10) {
      setState(() => _error = 'Please enter a valid 10-digit mobile number');
      return;
    }

    final authViewModel = context.read<AuthViewModel>();

    // 1. Check if phone is available
    final available = await authViewModel.checkPhone(
      _phoneController.text.trim(),
    );
    if (!available) {
      setState(
        () => _error = authViewModel.errorMessage ?? 'Phone already registered',
      );
      return;
    }

    // 2. Send OTP
    final success = await authViewModel.sendRegistrationOtp(_phoneController.text.trim());

    if (!success) {
      setState(() => _error = authViewModel.error);
    } else {
      setState(() {
        _sentToMask = '*****${_phoneController.text.substring(6)}';
        _step = 2;
      });
    }
  }

  void _handleVerifyOtp() async {
    _clearFeedback();
    if (_otpController.text.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP');
      return;
    }

    final authViewModel = context.read<AuthViewModel>();
    final success = await authViewModel.verifyRegistrationOtp(_otpController.text.trim());

    if (success) {
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

    final authViewModel = context.read<AuthViewModel>();

    final registrationData = {
      'verification_token': authViewModel.verificationToken,
      'phone': _phoneController.text.trim(),
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
        if (context.mounted) {
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
    final colors = context.watch<ThemeViewModel>().colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Registration progress',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              width:
                  MediaQuery.of(context).size.width *
                  (_step / 4) *
                  0.7, // Approx width
              decoration: BoxDecoration(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Step $_step of 4',
          style: GoogleFonts.inter(color: colors.muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    final colors = context.watch<ThemeViewModel>().colors;
    final busy = context.watch<AuthViewModel>().isLoading;

    switch (_step) {
      case 1:
        return Column(
          children: [
            CustomTextField(
              label: 'Mobile number',
              hintText: 'Enter your phone',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: busy ? 'Sending...' : 'Send OTP',
              isLoading: busy,
              onPressed: _handleSendOtp,
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Code sent to $_sentToMask',
              style: GoogleFonts.inter(color: colors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'OTP code',
              hintText: 'Enter 6-digit OTP',
              controller: _otpController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _step = 1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryRed,
                      side: const BorderSide(color: AppColors.primaryRed),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Back',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    text: busy ? 'Verifying...' : 'Verify OTP',
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
              hintText: 'Country',
              controller: _countryController,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _step = 2),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryRed,
                      side: const BorderSide(color: AppColors.primaryRed),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Back',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                  ),
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
                  child: OutlinedButton(
                    onPressed: () => setState(() => _step = 3),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryRed,
                      side: const BorderSide(color: AppColors.primaryRed),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Back',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                  ),
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
    final colors = context.watch<ThemeViewModel>().colors;
    return Scaffold(
      backgroundColor: Colors.white, // Pure white theme canvas background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primaryRed, size: 24),
        ),
        title: Text(
          'REGISTER',
          style: GoogleFonts.inter(
            color: const Color(0xFF20263A),
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/login.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: ResponsiveCenter(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                  const SizedBox(height: 32),

                  // Form Card in Clean White styling with Red Shadow Glow
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFFA0000).withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFA0000).withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProgressBar(),
                        const SizedBox(height: 24),

                        if (_message.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              _message,
                              style: GoogleFonts.inter(
                                color: Colors.redAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (_error.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              _error,
                              style: GoogleFonts.inter(
                                color: Colors.red[600],
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _buildStepContent(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Footer Actions
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryRedHover,
                        textStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      child: const Text('Back to login'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
