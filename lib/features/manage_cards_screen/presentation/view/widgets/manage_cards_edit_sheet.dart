import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:smartcard_flutter/core/utils/international_phone_helper.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/view/widgets/country_code_dropdown_dialog.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/presentation/viewmodel/card_viewmodel.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/data/models/card_model.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/features/manage_card_edit_all_screen/presentation/view/widgets/rich_text_editor_widget.dart';
import 'package:smartcard_flutter/features/manage_cards_screen/presentation/view/widgets/manage_cards_video_widget.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/data/models/video_item.dart';
class SectionEditSheet extends ConsumerStatefulWidget {
  final String sectionId;
  final Future<String?> Function(String, bool) cropImageCallback;
  final String Function(String?, String, String) resolveImgUrlCallback;

  const SectionEditSheet({
    super.key,
    required this.sectionId,
    required this.cropImageCallback,
    required this.resolveImgUrlCallback,
  });

  @override
  ConsumerState<SectionEditSheet> createState() => _SectionEditSheetState();
}

class _SectionEditSheetState extends ConsumerState<SectionEditSheet> {
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  late Map<String, dynamic> _controllers;
  List<TextEditingController> _videoControllers = [];
  List<TextEditingController> _videoTitleControllers = [];

  // Pincode lookup variables
  List<dynamic> _offices = [];
  String? _selectedOfficeIndex;
  bool _pincodeLoading = false;
  String _pincodeError = '';
  String _phoneCountryCode = '+91';
  String _waCountryCode = '+91';

  @override
  void initState() {
    super.initState();
    _controllers = {};
    final viewModel = ref.read(cardViewModelProvider.notifier);
    final details = viewModel.selectedCardDetails;
    if (details != null) {
      _initControllers(details);
    }
  }

  void _initControllers(CardProfileDetails details) {
    // Personal Details
    _controllers['firstName'] = TextEditingController(text: details.firstName);
    _controllers['lastName'] = TextEditingController(text: details.lastName);
    _controllers['email'] = TextEditingController(text: details.email);
    _controllers['phone'] = TextEditingController(text: details.phone);
    _controllers['gender'] = details.gender.isEmpty ? 'Not-Mention' : details.gender;

    // Professional Details
    _controllers['companyName'] = TextEditingController(text: details.companyName);
    _controllers['designation'] = TextEditingController(text: details.designation);
    _controllers['companyAddress'] = TextEditingController(text: details.companyAddress);
    _controllers['companyPincode'] = TextEditingController(text: details.companyPincode);
    _controllers['companyCityId'] = details.companyCityId;
    _controllers['companyStateId'] = details.companyStateId;
    _controllers['companyCity'] = TextEditingController(text: details.companyCity);
    _controllers['companyState'] = TextEditingController(text: details.companyState);
    _controllers['companyDistrict'] = TextEditingController(text: details.companyDistrict);

    // Personal / Professional Address
    final effectiveAddress = details.address.isNotEmpty ? details.address : details.companyAddress;
    final effectivePincode = details.pincode.isNotEmpty ? details.pincode : details.companyPincode;
    final effectiveCityId = details.cityId.isNotEmpty ? details.cityId : details.companyCityId;
    final effectiveStateId = details.stateId.isNotEmpty ? details.stateId : details.companyStateId;
    final effectiveCity = details.city.isNotEmpty ? details.city : details.companyCity;
    final effectiveState = details.state.isNotEmpty ? details.state : details.companyState;
    final effectiveDistrict = details.district.isNotEmpty ? details.district : details.companyDistrict;

    _controllers['address'] = TextEditingController(text: effectiveAddress);
    _controllers['pincode'] = TextEditingController(text: effectivePincode);
    _controllers['cityId'] = effectiveCityId;
    _controllers['stateId'] = effectiveStateId;
    _controllers['city'] = TextEditingController(text: effectiveCity);
    _controllers['state'] = TextEditingController(text: effectiveState);
    _controllers['district'] = TextEditingController(text: effectiveDistrict);

    // Dynamic lists
    final emails = details.companyEmails.isEmpty ? [''] : details.companyEmails;
    final phones = details.contactNumbers.isEmpty ? [''] : details.contactNumbers.map((p) {
      var raw = p.trim();
      if (raw.startsWith('+91')) raw = raw.substring(3).trim();
      else if (raw.startsWith('91') && raw.length > 10) raw = raw.substring(2).trim();
      return raw;
    }).toList();
    final whatsapps = details.whatsappNumbers.isEmpty ? [''] : details.whatsappNumbers.map((w) {
      var raw = w.trim();
      if (raw.startsWith('+91')) raw = raw.substring(3).trim();
      else if (raw.startsWith('91') && raw.length > 10) raw = raw.substring(2).trim();
      return raw;
    }).toList();

    _controllers['emails'] = emails.map((e) => TextEditingController(text: e)).toList();
    _controllers['phones'] = phones.map((p) => TextEditingController(text: p)).toList();
    _controllers['whatsapps'] = whatsapps.map((w) => TextEditingController(text: w)).toList();

    // Socials
    _controllers['fbLink'] = TextEditingController(text: details.fbLink);
    _controllers['instaLink'] = TextEditingController(text: details.instaLink);
    _controllers['linkedin'] = TextEditingController(text: details.linkedin);
    _controllers['xLink'] = TextEditingController(text: details.xLink);

    final webs = details.website.isEmpty ? [{'name': '', 'url': ''}] : details.website;
    _controllers['websites'] = webs.map((w) => {
      'name': TextEditingController(text: w['name'] ?? ''),
      'url': TextEditingController(text: w['url'] ?? ''),
    }).toList();

    // About & Videos
    _controllers['about'] = TextEditingController(text: details.aboutCompany);
    final validVideos = details.videos;
    if (validVideos.isEmpty) {
      _videoControllers = [TextEditingController()];
      _videoTitleControllers = [TextEditingController()];
    } else {
      _videoControllers = validVideos.map((v) => TextEditingController(text: v.url)).toList();
      _videoTitleControllers = validVideos.map((v) => TextEditingController(text: v.title)).toList();
    }
    final youtubeLink = _videoControllers.isEmpty ? '' : _videoControllers[0].text;
    _controllers['youtube'] = TextEditingController(text: youtubeLink);

    // Auto Pincode Lookups
    if (widget.sectionId == 'section-company' && details.companyPincode.length == 6) {
      _lookupPincode(details.companyPincode, isPersonal: false);
    } else if (widget.sectionId == 'section-address' && details.pincode.length == 6) {
      _lookupPincode(details.pincode, isPersonal: true);
    }
  }

  Future<void> _lookupPincode(String pincode, {required bool isPersonal}) async {
    if (pincode.length != 6) return;

    setState(() {
      _pincodeLoading = true;
      _pincodeError = '';
      _offices = [];
      _selectedOfficeIndex = null;
    });

    final viewModel = ref.read(cardViewModelProvider.notifier);
    try {
      final response = await viewModel.fetchPincodeDetails(pincode);
      if (response != null && response['success'] == true) {
        final data = response['data'];
        if (data != null) {
          final officesList = data['offices'] as List? ?? [];
          setState(() {
            _offices = officesList;
          });

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
          final currentCityId = isPersonal ? details.cityId : details.companyCityId;
          final currentCityName = (isPersonal ? details.city : details.companyCity).trim().toLowerCase();

          int matchedIdx = officesList.indexWhere((o) {
            if (currentCityId.isNotEmpty && o['city_id']?.toString() == currentCityId) return true;
            if (currentCityName.isNotEmpty && o['city']?.toString().trim().toLowerCase() == currentCityName) return true;
            return false;
          });

          if (matchedIdx >= 0) {
            setState(() => _selectedOfficeIndex = matchedIdx.toString());
            _applyOfficeSelection(matchedIdx, isPersonal: isPersonal);
          } else if (officesList.isNotEmpty) {
            setState(() => _selectedOfficeIndex = '0');
            _applyOfficeSelection(0, isPersonal: isPersonal);
          }
        }
      } else {
        setState(() => _pincodeError = 'Pincode details not found.');
      }
    } catch (_) {
      setState(() => _pincodeError = 'Failed to load location details.');
    } finally {
      setState(() => _pincodeLoading = false);
    }
  }

  void _applyOfficeSelection(int idx, {required bool isPersonal}) {
    if (idx < 0 || idx >= _offices.length) return;
    final office = _offices[idx];
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
        _controllers['companyDistrict'].text = office['district']?.toString() ?? '';
      }
    });
  }

  String _getSectionTitle() {
    switch (widget.sectionId) {
      case 'section-personal': return 'Personal Details';
      case 'section-company': return 'Professional Details';
      case 'section-address': return 'Professional Address';
      case 'section-company-contact': return 'Contact Details';
      case 'section-social': return 'Social Media';
      case 'section-about': return 'About';
      case 'section-youtube': return 'My Videos';
      case 'section-gallery': return 'Gallery';
      default: return 'Edit Details';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controllers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
      );
    }

    final themeViewModel = ref.watch(themeViewModelProvider);
    final colors = themeViewModel.colors;
    final viewModel = ref.watch(cardViewModelProvider.notifier);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: MediaQuery.of(context).viewInsets,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.80,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Top indicator and close bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getSectionTitle(),
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.sectionId == 'section-company-contact'
                              ? 'Add your email, phone, and WhatsApp for quick connections'
                              : 'Provide your information below to keep your card updated.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: _buildFormFields(colors, viewModel),
                ),
              ),
            ),
            if (widget.sectionId != 'section-gallery')
              _buildSaveButton(viewModel),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildFormFields(AppColors colors, CardViewModel viewModel) {
    switch (widget.sectionId) {
      case 'section-personal':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextFormField(_controllers['firstName'], 'First Name *', colors, textCapitalization: TextCapitalization.words, validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            _buildTextFormField(_controllers['lastName'], 'Last Name *', colors, textCapitalization: TextCapitalization.words, validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            _buildTextFormField(_controllers['email'], 'Email *', colors, keyboardType: TextInputType.emailAddress, validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            _buildTextFormField(_controllers['phone'], 'Phone *', colors, keyboardType: TextInputType.phone, validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            _buildInputLabel('Gender', colors),
            DropdownButtonFormField<String>(
              initialValue: _controllers['gender'],
              dropdownColor: Colors.white,
              style: GoogleFonts.inter(color: colors.text, fontSize: 14),
              decoration: _getInputDecoration('', colors),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(value: 'Transgender', child: Text('Transgender')),
                DropdownMenuItem(value: 'Not-Mention', child: Text('Not Mention')),
              ],
              onChanged: (val) => setState(() => _controllers['gender'] = val),
            ),
          ],
        );

      case 'section-company':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextFormField(_controllers['companyName'], 'Company Name', colors, textCapitalization: TextCapitalization.words),
            _buildTextFormField(_controllers['designation'], 'Designation *', colors, textCapitalization: TextCapitalization.words, validator: (v) => v!.trim().isEmpty ? 'Required' : null),
          ],
        );

      case 'section-address':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextFormField(_controllers['address'], 'Professional Address', colors, maxLines: 3, textCapitalization: TextCapitalization.words),
            _buildTextFormField(
              _controllers['pincode'],
              'Pincode *',
              colors,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: (val) => _lookupPincode(val, isPersonal: true),
              validator: (v) => v!.length != 6 ? 'Must be 6 digits' : null,
            ),
            if (_pincodeLoading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: LinearProgressIndicator(color: AppColors.primaryRed)),
            if (_pincodeError.isNotEmpty)
              Text(_pincodeError, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            if (_offices.isNotEmpty) ...[
              _buildInputLabel('Select City / PO Location *', colors),
              DropdownButtonFormField<String>(
                initialValue: _selectedOfficeIndex,
                dropdownColor: Colors.white,
                style: GoogleFonts.inter(color: colors.text, fontSize: 14),
                decoration: _getInputDecoration('Location', colors),
                items: _offices.asMap().entries.map((e) {
                  return DropdownMenuItem(value: e.key.toString(), child: Text(e.value['city'] ?? ''));
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedOfficeIndex = val);
                  if (val != null) _applyOfficeSelection(int.parse(val), isPersonal: true);
                },
              ),
            ],
            _buildTextFormField(_controllers['district'], 'District', colors, textCapitalization: TextCapitalization.words),
            _buildTextFormField(_controllers['state'], 'State', colors, textCapitalization: TextCapitalization.words),
          ],
        );

      case 'section-company-contact':
        final emails = _controllers['emails'] as List<TextEditingController>;
        final phones = _controllers['phones'] as List<TextEditingController>;
        final whatsapps = _controllers['whatsapps'] as List<TextEditingController>;
        
        if (emails.isEmpty) emails.add(TextEditingController());
        if (phones.isEmpty) phones.add(TextEditingController());
        if (whatsapps.isEmpty) whatsapps.add(TextEditingController());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Emails List (Redundant titles removed per NOV 2026 specifications)
            ...emails.asMap().entries.map((e) {
              final idx = e.key;
              final ctrl = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: ctrl,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.inter(color: const Color(0xFF1A1A1A), fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Email address',
                          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13.5),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.only(left: 0, right: 10, top: 15, bottom: 15),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.6)),
                          prefixIconConstraints: const BoxConstraints(minWidth: 32, maxWidth: 34, minHeight: 24),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 10, right: 4),
                            child: Icon(Icons.email_outlined, size: 17, color: AppColors.primaryRed),
                          ),
                        ),
                      ),
                    ),
                    if (emails.length > 1)
                      IconButton(icon: const Icon(Icons.remove_circle, color: Colors.redAccent), onPressed: () => setState(() => emails.removeAt(idx))),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryRed, size: 18),
                label: Text('Add another email', style: GoogleFonts.inter(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => setState(() => emails.add(TextEditingController())),
              ),
            ),
            const SizedBox(height: 12),

            // Phone Numbers with Country Code (+91 India default, no 10-digit lock)
            ...phones.asMap().entries.map((e) {
              final idx = e.key;
              final ctrl = e.value;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildPhoneFieldWithCountryCode(
                      controller: ctrl,
                      hint: 'Contact number',
                      countryCode: _phoneCountryCode,
                      onCountryCodeChanged: (code) => setState(() => _phoneCountryCode = code),
                      colors: colors,
                      isWhatsApp: false,
                    ),
                  ),
                  if (phones.length > 1)
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 36),
                      padding: const EdgeInsets.only(left: 4),
                      icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 20),
                      onPressed: () => setState(() => phones.removeAt(idx)),
                    ),
                ],
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryRed, size: 18),
                label: Text('Add another phone number', style: GoogleFonts.inter(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => setState(() => phones.add(TextEditingController())),
              ),
            ),
            _buildDottedDivider(),

            // WhatsApp Numbers with Country Code (+91 India default, no 10-digit lock)
            ...whatsapps.asMap().entries.map((e) {
              final idx = e.key;
              final ctrl = e.value;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildPhoneFieldWithCountryCode(
                      controller: ctrl,
                      hint: 'WhatsApp number',
                      countryCode: _waCountryCode,
                      onCountryCodeChanged: (code) => setState(() => _waCountryCode = code),
                      colors: colors,
                      isWhatsApp: true,
                    ),
                  ),
                  if (whatsapps.length > 1)
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 36),
                      padding: const EdgeInsets.only(left: 4),
                      icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 20),
                      onPressed: () => setState(() => whatsapps.removeAt(idx)),
                    ),
                ],
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryRed, size: 18),
                label: Text('Add another WhatsApp number', style: GoogleFonts.inter(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => setState(() => whatsapps.add(TextEditingController())),
              ),
            ),
          ],
        );


      case 'section-social':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextFormField(_controllers['fbLink'], 'Facebook URL', colors, keyboardType: TextInputType.url),
            _buildTextFormField(_controllers['instaLink'], 'Instagram URL', colors, keyboardType: TextInputType.url),
            _buildTextFormField(_controllers['linkedin'], 'LinkedIn URL', colors, keyboardType: TextInputType.url),
            _buildTextFormField(_controllers['xLink'], 'X (Twitter) URL', colors, keyboardType: TextInputType.url),
          ],
        );

      case 'section-about':
        return RichTextEditorWidget(controller: _controllers['about']);

      case 'section-youtube':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Paste video links from YouTube, Instagram Reels, Facebook, TikTok, Vimeo, or direct video URLs.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.blueGrey.shade800,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ..._videoControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              final detectedInfo = controller.text.trim().isNotEmpty
                  ? VideoPlatformHelper.detect(controller.text)
                  : null;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: detectedInfo != null
                        ? detectedInfo.brandColor.withValues(alpha: 0.35)
                        : Colors.grey.shade300,
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Video ${index + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const Spacer(),
                        if (_videoControllers.length > 1)
                          InkWell(
                            onTap: () {
                              setState(() {
                                final removed = _videoControllers.removeAt(index);
                                removed.dispose();
                                if (index < _videoTitleControllers.length) {
                                  final removedTitle = _videoTitleControllers.removeAt(index);
                                  removedTitle.dispose();
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.delete_outline, size: 15, color: Colors.redAccent),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Remove',
                                    style: GoogleFonts.inter(
                                      color: Colors.redAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: controller,
                      keyboardType: TextInputType.url,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.inter(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'https://youtube.com/watch?v=... or reel link',
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12.5),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        prefixIcon: const Icon(Icons.link, size: 18, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: index < _videoTitleControllers.length
                          ? _videoTitleControllers[index]
                          : TextEditingController(),
                      style: GoogleFonts.inter(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Video Title (e.g. Flutter Tutorial, My Portfolio)',
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12.5),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        prefixIcon: const Icon(Icons.title, size: 18, color: Colors.grey),
                      ),
                    ),
                    if (detectedInfo != null) ...[
                      const SizedBox(height: 8),
                      VideoPlatformBadge(info: detectedInfo),
                    ],
                  ],
                ),
              );
            }),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryRed,
                side: const BorderSide(color: AppColors.primaryRed, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                setState(() {
                  _videoControllers.add(TextEditingController());
                  _videoTitleControllers.add(TextEditingController());
                });
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'Add Another Video',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        );

      case 'section-gallery':
        final existingPhotos = viewModel.selectedCardDetails?.existingPhotos ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final List<XFile> images = await _picker.pickMultiImage();
                if (images.isNotEmpty) {
                  await viewModel.handleUploadGalleryImages(images);
                  setState(() {});
                }
              },
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Select from Gallery'),
            ),
            const SizedBox(height: 16),
            if (existingPhotos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(child: Text('No gallery images uploaded yet.', style: GoogleFonts.inter(color: Colors.grey))),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemCount: existingPhotos.length,
                itemBuilder: (context, idx) {
                  final photo = existingPhotos[idx];
                  final url = widget.resolveImgUrlCallback(photo, 'gallery', viewModel.userId);
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(color: Colors.grey.shade100, child: const Icon(Icons.broken_image, color: Colors.grey)),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () async {
                            await viewModel.handleRemoveGalleryImage(photo);
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 24),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSaveButton(CardViewModel viewModel) {
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final extraBottomPadding = viewInsetsBottom > 0 
        ? 12.0 
        : 18.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 18.0,
        right: 18.0,
        top: 12.0,
        bottom: extraBottomPadding, 
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54, // slightly taller for better touch target
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          onPressed: viewModel.isSaving ? null : _saveSectionData,
          child: viewModel.isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  'Save Changes',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  void _saveSectionData() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = ref.read(cardViewModelProvider.notifier);
    final details = viewModel.selectedCardDetails!;

    if (widget.sectionId == 'section-personal') {
      details.firstName = _controllers['firstName'].text.trim();
      details.lastName = _controllers['lastName'].text.trim();
      details.email = _controllers['email'].text.trim();
      details.phone = _controllers['phone'].text.trim();
      details.gender = _controllers['gender'];
    } else if (widget.sectionId == 'section-company') {
      details.companyName = _controllers['companyName'].text.trim();
      details.designation = _controllers['designation'].text.trim();
      details.companyAddress = _controllers['companyAddress'].text.trim();
      details.companyPincode = _controllers['companyPincode'].text.trim();
      details.companyCityId = _controllers['companyCityId'] ?? '';
      details.companyStateId = _controllers['companyStateId'] ?? '';
      details.companyCity = _controllers['companyCity'].text.trim();
      details.companyState = _controllers['companyState'].text.trim();
      details.companyDistrict = _controllers['companyDistrict'].text.trim();
      details.companyOfficeSelected = details.companyPincode.isNotEmpty && details.companyCityId.isNotEmpty;
    } else if (widget.sectionId == 'section-address') {
      final savedAddress = _controllers['address'].text.trim();
      final savedPincode = _controllers['pincode'].text.trim();
      final savedCityId = _controllers['cityId'] ?? '';
      final savedStateId = _controllers['stateId'] ?? '';
      final savedCity = _controllers['city'].text.trim();
      final savedState = _controllers['state'].text.trim();
      final savedDistrict = _controllers['district'].text.trim();
      final isOfficeSelected = savedPincode.isNotEmpty && savedCityId.isNotEmpty;

      // Update personal address
      details.address = savedAddress;
      details.pincode = savedPincode;
      details.cityId = savedCityId;
      details.stateId = savedStateId;
      details.city = savedCity;
      details.state = savedState;
      details.district = savedDistrict;
      details.officeSelected = isOfficeSelected;

      // Synchronize professional / company address so work card profile stays identical
      details.companyAddress = savedAddress;
      details.companyPincode = savedPincode;
      details.companyCityId = savedCityId;
      details.companyStateId = savedStateId;
      details.companyCity = savedCity;
      details.companyState = savedState;
      details.companyDistrict = savedDistrict;
      details.companyOfficeSelected = isOfficeSelected;
    } else if (widget.sectionId == 'section-company-contact') {
      details.companyEmails = (_controllers['emails'] as List<TextEditingController>)
          .map((e) => e.text.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      details.contactNumbers = (_controllers['phones'] as List<TextEditingController>)
          .map((p) => p.text.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      details.whatsappNumbers = (_controllers['whatsapps'] as List<TextEditingController>)
          .map((w) => w.text.trim())
          .where((w) => w.isNotEmpty)
          .toList();
    } else if (widget.sectionId == 'section-social') {
      details.fbLink = _controllers['fbLink'].text.trim();
      details.instaLink = _controllers['instaLink'].text.trim();
      details.linkedin = _controllers['linkedin'].text.trim();
      details.xLink = _controllers['xLink'].text.trim();
    } else if (widget.sectionId == 'section-about') {
      details.aboutCompany = _controllers['about'].text.trim();
    } else if (widget.sectionId == 'section-youtube') {
      final List<VideoItem> newVideos = [];
      for (int i = 0; i < _videoControllers.length; i++) {
        final url = _videoControllers[i].text.trim();
        if (url.isNotEmpty) {
          final title = i < _videoTitleControllers.length ? _videoTitleControllers[i].text.trim() : '';
          newVideos.add(VideoItem.fromUrl(url, title: title.isNotEmpty ? title : null));
        }
      }
      details.videos = newVideos;
      if (details.youtubeLinks.isNotEmpty && _controllers['youtube'] != null) {
        _controllers['youtube'].text = details.youtubeLinks[0];
      }
    }

    final success = await viewModel.handleFormSubmit();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_getSectionTitle()} saved successfully!'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      final err = viewModel.errorMessage ?? 'Update failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: AppColors.deleteRed,
      ));
    }
  }

  InputDecoration _getInputDecoration(String hintText, AppColors colors) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildTextFormField(
    TextEditingController controller,
    String label,
    AppColors colors, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputLabel(label, colors),
          TextFormField(
            controller: controller,
            style: GoogleFonts.inter(color: const Color(0xFF1A1A1A), fontSize: 15),
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            maxLines: maxLines,
            maxLength: maxLength,
            validator: validator,
            onChanged: onChanged,
            decoration: InputDecoration(
              counterText: '', // Hide max length counter text if any
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
              ),
              errorStyle: const TextStyle(height: 0.8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String text, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 2.0),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: const Color(0xFF4A4E5C),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDottedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dotSize = 3.5;
          const gap = 5.0;
          final count = (constraints.maxWidth / (dotSize + gap)).floor().clamp(1, 100);
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              count,
              (_) => Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhoneFieldWithCountryCode({
    required TextEditingController controller,
    required String hint,
    required String countryCode,
    required ValueChanged<String> onCountryCodeChanged,
    required AppColors colors,
    bool isWhatsApp = false,
  }) {
    final flag = InternationalPhoneHelper.findByCode(countryCode).flag;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Country Code Dropdown Button defaulting to +91 India
          InkWell(
            onTap: () {
              CountryCodeDropdownDialog.show(
                context,
                selectedCode: countryCode,
                isWhatsAppMode: isWhatsApp,
                onSelectCountry: (item) {
                  onCountryCodeChanged(item.code);
                },
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: isWhatsApp ? const Color(0xFFE8F5E9) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isWhatsApp ? const Color(0xFF25D366).withValues(alpha: 0.6) : Colors.grey.shade300,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(flag, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 3),
                  Text(
                    countryCode,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isWhatsApp ? const Color(0xFF2E7D32) : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(width: 1),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: isWhatsApp ? const Color(0xFF2E7D32) : Colors.grey.shade700,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Phone / WhatsApp Number Input Field with tight icon spacing and full number visibility
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.inter(
                color: isWhatsApp ? const Color(0xFF2E7D32) : const Color(0xFF1A1A1A),
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.only(left: 0, right: 8, top: 14, bottom: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isWhatsApp ? const Color(0xFF25D366) : AppColors.primaryRed,
                    width: 1.6,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 28, maxWidth: 32, minHeight: 24),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 9, right: 4),
                  child: isWhatsApp
                      ? const FaIcon(FontAwesomeIcons.whatsapp, size: 17, color: Color(0xFF25D366))
                      : const Icon(Icons.phone_rounded, size: 17, color: AppColors.primaryRed),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// WhatsApp-branded field with real WhatsApp logo icon
  Widget _buildWhatsAppField({
    required TextEditingController controller,
    required AppColors colors,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 2.0),
            child: Text(
              'WhatsApp Number',
              style: GoogleFonts.inter(
                color: const Color(0xFF4A4E5C),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Input field
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            validator: (v) => v!.trim().isNotEmpty && v.trim().length != 10
                ? 'Must be 10 digits'
                : null,
            style: GoogleFonts.inter(
              color: const Color(0xFF1A1A1A),
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: 'Enter 10-digit number',
              hintStyle:
                  GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppColors.primaryRed.withValues(alpha: 0.3),
                    width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primaryRed, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }


  /// Branded contact input field with coloured icon prefix

  Widget _buildContactField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required TextInputType keyboardType,
    required AppColors colors,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 2.0),
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF4A4E5C),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Input
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            validator: validator,
            style: GoogleFonts.inter(
              color: const Color(0xFF1A1A1A),
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: iconBg.withValues(alpha: 0.3), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: iconBg, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

