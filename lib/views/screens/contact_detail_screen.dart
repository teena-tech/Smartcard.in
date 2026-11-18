import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../models/scanned_contact_model.dart';
import '../../models/app_contact.dart';
import '../../providers/contact_provider.dart';
import '../../providers/group_provider.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/contact_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/contact_action_helper.dart';
import '../../core/utils/intent_launcher.dart';
import '../../core/utils/upload_url_resolver.dart';
import '../../core/utils/avatar_helper.dart';
import '../../core/utils/safe_base64.dart';
import '../widgets/genie_hero_route.dart';
import '../widgets/global_bottom_nav.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/quick_action_bar.dart';
import '../../core/services/contact_photo_resolver.dart';
import '../../core/services/contact_photo_service.dart';
import '../../core/utils/phone_normalizer.dart';
import 'contacts_screen.dart';
import 'contact_form_screen.dart';

class ContactDetailScreen extends StatefulWidget {
  final ScannedContactModel contact;
  final String? heroTag;

  const ContactDetailScreen({super.key, required this.contact, this.heroTag});

  static void showFullImageDialog(BuildContext context, String? imageSource, String contactName, String initial, {String? heroTag}) {
    if (imageSource == null || imageSource.trim().isEmpty) return;

    final String resolvedSource = (!kIsWeb && File(imageSource).existsSync()) ||
            imageSource.startsWith('data:') ||
            imageSource.startsWith('http://') ||
            imageSource.startsWith('https://')
        ? imageSource
        : UploadUrlResolver.resolve(imageSource, type: 'profile');

    Widget imageWidget;
    if (resolvedSource.startsWith('data:image') || resolvedSource.startsWith('data:')) {
      final base64Bytes = safeBase64Decode(imageSource);
      if (base64Bytes != null) {
        imageWidget = Image.memory(
          base64Bytes,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          gaplessPlayback: true,
        );
      } else {
        imageWidget = _buildFallbackInitial(initial);
      }
    } else if (resolvedSource.startsWith('http://') || resolvedSource.startsWith('https://')) {
      imageWidget = CachedNetworkImage(
        imageUrl: resolvedSource,
        cacheKey: resolvedSource.split('?').first,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (ctx, url) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryRed),
        ),
        errorWidget: (c, url, err) => _buildFallbackInitial(initial),
      );
    } else if (!kIsWeb) {
      try {
        final file = File(resolvedSource);
        if (file.existsSync()) {
          imageWidget = Image.file(
            file,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
            gaplessPlayback: true,
          );
        } else {
          imageWidget = _buildFallbackInitial(initial);
        }
      } catch (_) {
        imageWidget = _buildFallbackInitial(initial);
      }
    } else {
      imageWidget = _buildFallbackInitial(initial);
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pinch-to-zoom full image
                  InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.8,
                    maxScale: 5.0,
                    child: Center(child: imageWidget),
                  ),
                  // Close button top-right
                  Positioned(
                    top: 48,
                    right: 20,
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  // Contact name at bottom
                  Positioned(
                    bottom: 48,
                    left: 20,
                    right: 20,
                    child: Text(
                      contactName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        shadows: [const Shadow(color: Colors.black87, blurRadius: 8)],
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

  static Widget buildFullImageWidget(String? avatarSource, String initial) {
    if (avatarSource == null || avatarSource.trim().isEmpty) {
      return _buildFallbackInitial(initial);
    }

    final String resolvedSource = (!kIsWeb && File(avatarSource).existsSync()) ||
            avatarSource.startsWith('data:') ||
            avatarSource.startsWith('http://') ||
            avatarSource.startsWith('https://')
        ? avatarSource
        : UploadUrlResolver.resolve(avatarSource, type: 'profile');

    if (resolvedSource.startsWith('data:image') || resolvedSource.startsWith('data:')) {
      final base64Bytes = safeBase64Decode(avatarSource);
      if (base64Bytes != null) {
        return Image.memory(
          base64Bytes,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          gaplessPlayback: true,
          errorBuilder: (c, e, s) => _buildFallbackInitial(initial),
        );
      }
      return _buildFallbackInitial(initial);
    } else if (resolvedSource.startsWith('http://') || resolvedSource.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: resolvedSource,
        cacheKey: resolvedSource.split('?').first,
        useOldImageOnUrlChange: true,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryRed),
        ),
        errorWidget: (c, url, err) => _buildFallbackInitial(initial),
      );
    } else if (!kIsWeb) {
      try {
        final file = File(resolvedSource);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
            gaplessPlayback: true,
            errorBuilder: (c, e, s) => _buildFallbackInitial(initial),
          );
        } else {
          return _buildFallbackInitial(initial);
        }
      } catch (_) {
        return _buildFallbackInitial(initial);
      }
    } else {
      return _buildFallbackInitial(initial);
    }
  }

  static Widget _buildFallbackInitial(String initial) {
    return Container(
      width: 320,
      height: 320,
      color: const Color(0xFFFEE2E2),
      alignment: Alignment.center,
      child: Text(
        initial.isNotEmpty ? initial[0].toUpperCase() : '?',
        style: GoogleFonts.outfit(
          color: const Color(0xFFE53935),
          fontSize: 72,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  static final Map<String, String> _devicePhotoCache = {};
  late ScannedContactModel _contact;
  String? _liveDevicePhoto;
  bool _hasRecordedView = false;

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
    _liveDevicePhoto = _devicePhotoCache[_contact.id];
    _fetchLiveDevicePhoto();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasRecordedView) return;
      final isSmartCard = _contact.isMatched ||
          (_contact.matchedUserId != null &&
              _contact.matchedUserId!.trim().isNotEmpty &&
              _contact.matchedUserId!.toLowerCase() != 'null') ||
          (_contact.matchedCards != null && _contact.matchedCards!.isNotEmpty);
      final ownerId = _contact.matchedUserId ?? _contact.id;
      if (isSmartCard && ownerId.isNotEmpty) {
        _hasRecordedView = true;
        try {
          context.read<ProfileViewModel>().incrementCardViews(ownerId);
        } catch (_) {}
      }
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final phoneDigits = _contact.phone.replaceAll(RegExp(r'\D'), '');
        if (phoneDigits.isNotEmpty) {
          context.read<ContactViewModel>().matchPhoneContactsWithServer(
            force: true,
            devicePhones: [phoneDigits, _contact.phone],
          );
        }
      }
    });
  }

  Future<void> _fetchLiveDevicePhoto() async {
    final cacheKey = _contact.id;
    if (_devicePhotoCache.containsKey(cacheKey)) {
      final cached = _devicePhotoCache[cacheKey];
      if (cached != null && cached.isNotEmpty && mounted && _liveDevicePhoto != cached) {
        setState(() {
          _liveDevicePhoto = cached;
        });
      }
      return;
    }

    try {
      final bestBytes = await ContactPhotoService.getBestPhoto(
        contactId: _contact.id,
        phone: _contact.phone,
      );
      if (bestBytes != null && bestBytes.isNotEmpty) {
        final base64Str = 'data:image/jpeg;base64,${base64Encode(bestBytes)}';
        _devicePhotoCache[cacheKey] = base64Str;
        if (mounted) {
          setState(() {
            _liveDevicePhoto = base64Str;
          });
        }
        return;
      }
    } catch (_) {}

    try {
      final status = await Permission.contacts.status;
      if (status.isGranted || status.isLimited) {
        Contact? devContact;
        final rawId = _contact.id.replaceFirst('phone_', '').replaceFirst('matched_', '');
        if (rawId.isNotEmpty && RegExp(r'^\d+$').hasMatch(rawId)) {
          devContact = await FlutterContacts.get(
            rawId,
            properties: ContactProperties.all,
          );
        }

        if (devContact == null && _contact.phone.isNotEmpty) {
          final cleanPhone = _contact.phone.replaceAll(RegExp(r'\D'), '');
          final p10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
          if (p10.length >= 7) {
            final matches = await FlutterContacts.getAll(
              properties: {
                ContactProperty.name,
                ContactProperty.phone,
              },
            );
            for (final c in matches) {
              final matchFound = c.phones.any((p) {
                final pClean = p.number.replaceAll(RegExp(r'\D'), '');
                final cp10 = pClean.length >= 10 ? pClean.substring(pClean.length - 10) : pClean;
                return cp10.length >= 7 && (cp10 == p10 || pClean.endsWith(p10) || cleanPhone.endsWith(cp10));
              });
              if (matchFound && c.id != null) {
                devContact = await FlutterContacts.get(
                  c.id!,
                  properties: ContactProperties.all,
                );
                break;
              }
            }
          }
        }

        if (devContact != null) {
          final bytes = devContact.photo?.fullSize ?? devContact.photo?.thumbnail;
          if (bytes != null && bytes.isNotEmpty) {
            final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
            _devicePhotoCache[cacheKey] = base64Str;
            if (mounted) {
              setState(() {
                _liveDevicePhoto = base64Str;
              });
            }
            return;
          }
        }
      }
    } catch (_) {}

    // Fallback to ContactProvider cached photo only if full HD fetch fails
    try {
      final contactProvider = context.read<ContactProvider>();
      final cleanPhone = _contact.phone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.isNotEmpty) {
        final p10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
        if (p10.length >= 7) {
          for (final appC in contactProvider.contacts) {
            if (appC.photo != null && appC.photo!.isNotEmpty) {
              final matchFound = appC.phones.any((p) {
                final pClean = p.number.replaceAll(RegExp(r'\D'), '');
                final cp10 = pClean.length >= 10 ? pClean.substring(pClean.length - 10) : pClean;
                return cp10.length >= 7 && (cp10 == p10 || pClean.endsWith(p10) || cleanPhone.endsWith(cp10));
              });
              if (matchFound) {
                final base64Str = 'data:image/jpeg;base64,${base64Encode(appC.photo!)}';
                _devicePhotoCache[cacheKey] = base64Str;
                if (mounted) {
                  setState(() {
                    _liveDevicePhoto = base64Str;
                  });
                }
                return;
              }
            }
          }
        }
      }
    } catch (_) {}
  }



  String _formatFullSmartCardUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return 'https://thesmartcards.com';
    final trimmed = rawUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('?sc=') || trimmed.startsWith('sc=')) {
      final q = trimmed.startsWith('?') ? trimmed : '?$trimmed';
      return 'https://thesmartcards.com$q';
    }
    if (trimmed.startsWith('/c/') || trimmed.startsWith('/')) {
      return 'https://thesmartcards.com$trimmed';
    }
    return 'https://thesmartcards.com/c/$trimmed';
  }

  List<Map<String, dynamic>> _getContactCards(ScannedContactModel contact) {
    if (contact.matchedCards != null && contact.matchedCards!.isNotEmpty) {
      return contact.matchedCards!;
    }
    final bool isActualSmartCardUser = contact.isSmartCardUser ||
        contact.isMatched ||
        contact.source == 'smart_card' ||
        (contact.cardUrl != null && contact.cardUrl!.trim().isNotEmpty && contact.cardUrl!.trim().toLowerCase() != 'null') ||
        (contact.matchedUserId != null &&
            contact.matchedUserId!.trim().isNotEmpty &&
            contact.matchedUserId!.trim().toLowerCase() != 'null');

    if (isActualSmartCardUser) {
      final count = contact.totalCardsCount ?? 1;
      final List<Map<String, dynamic>> list = [];
      for (int i = 0; i < count; i++) {
        list.add({
          'company': i == 0 ? contact.company : '',
          'designation': i == 0
              ? (contact.primaryDesignation?.isNotEmpty == true ? contact.primaryDesignation! : contact.designation)
              : '',
          'cardUrl': contact.cardUrl,
          'profileImage': contact.matchedProfileImage ?? contact.profileImage ?? contact.imagePath,
        });
      }
      if (list.isNotEmpty) return list;
    }

    // Regular phone contacts without SmartCard MUST NOT show SmartCards section or View Card!
    return const [];
  }

  Widget _buildCardFallbackAvatar(ScannedContactModel displayContact, dynamic colors) {
    return Center(
      child: Text(
        displayContact.name.isNotEmpty ? displayContact.name[0].toUpperCase() : 'S',
        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: colors.accent, fontSize: 16),
      ),
    );
  }

  Widget _buildSmartCardSection(ScannedContactModel displayContact, dynamic colors) {
    final cards = _getContactCards(displayContact);
    if (cards.isEmpty) return const SizedBox.shrink();

    final totalCount = displayContact.totalCardsCount ?? cards.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F2).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: AppColors.primaryRed, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SmartCards',
                  style: GoogleFonts.inter(
                    color: colors.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  totalCount > 1 ? '$totalCount Cards Held' : '1 Card Held',
                  style: GoogleFonts.inter(
                    color: colors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...cards.asMap().entries.map((entry) {
            final idx = entry.key;
            final cardData = entry.value;
            final companyName = cardData['company']?.toString().isNotEmpty == true
                ? cardData['company'].toString()
                : (idx == 0 && displayContact.company.isNotEmpty ? displayContact.company : '');
            final designationName = cardData['designation']?.toString().isNotEmpty == true
                ? cardData['designation'].toString()
                : (idx == 0
                    ? (displayContact.primaryDesignation?.isNotEmpty == true
                        ? displayContact.primaryDesignation!
                        : displayContact.designation)
                    : '');
            final rawUrl = cardData['cardUrl']?.toString() ?? displayContact.cardUrl;
            final fullUrl = _formatFullSmartCardUrl(rawUrl);

            String? imgCandidate;
            String imgCandidateType = 'profile';

            final pImg = cardData['profileImageName']?.toString() ??
                cardData['profile_image_name']?.toString() ??
                cardData['profileImage']?.toString() ??
                cardData['profile_image']?.toString() ??
                cardData['user_image']?.toString() ??
                cardData['userImage']?.toString() ??
                cardData['avatar']?.toString();
            if (pImg != null && pImg.trim().isNotEmpty && pImg.trim().toLowerCase() != 'null') {
              imgCandidate = pImg.trim();
              imgCandidateType = (imgCandidate.contains('/logo/') || imgCandidate.contains('logo')) ? 'logo' : 'profile';
            } else {
              final lImg = cardData['companyLogo']?.toString() ??
                  cardData['company_logo']?.toString() ??
                  cardData['logo']?.toString();
              if (lImg != null && lImg.trim().isNotEmpty && lImg.trim().toLowerCase() != 'null') {
                imgCandidate = lImg.trim();
                imgCandidateType = 'logo';
              } else {
                imgCandidate = displayContact.matchedProfileImage ??
                    displayContact.profileImage ??
                    displayContact.imagePath ??
                    _liveDevicePhoto ??
                    displayContact.companyLogo;
                if (imgCandidate != null && (imgCandidate.contains('/logo/') || imgCandidate.contains('logo') || (displayContact.matchedProfileImage == null && displayContact.companyLogo != null))) {
                  imgCandidateType = 'logo';
                }
              }
            }

            final String cleanImg = (imgCandidate != null && imgCandidate.trim().isNotEmpty && imgCandidate.trim().toLowerCase() != 'null')
                ? imgCandidate.trim()
                : '';
            final String resolvedImgUrl = cleanImg.isNotEmpty
                ? UploadUrlResolver.resolve(cleanImg, type: imgCandidateType)
                : '';

            return Container(
              margin: EdgeInsets.only(bottom: idx == cards.length - 1 ? 0 : 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.panel.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          try {
                            ContactDetailScreen.showFullImageDialog(
                              context,
                              resolvedImgUrl.isNotEmpty ? resolvedImgUrl : displayContact.profileImage,
                              displayContact.name,
                              displayContact.name.isNotEmpty ? displayContact.name[0].toUpperCase() : '?',
                            );
                          } catch (e) {
                            debugPrint('Card avatar tap error: $e');
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.accent.withValues(alpha: 0.15),
                            border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: resolvedImgUrl.isNotEmpty
                              ? (resolvedImgUrl.startsWith('data:image') || resolvedImgUrl.startsWith('data:')
                                  ? () {
                                      final base64Bytes = safeBase64Decode(resolvedImgUrl);
                                      if (base64Bytes != null) {
                                        return Image.memory(
                                          base64Bytes,
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                          errorBuilder: (c, e, s) => _buildCardFallbackAvatar(displayContact, colors),
                                        );
                                      }
                                      return _buildCardFallbackAvatar(displayContact, colors);
                                    }()
                                  : CachedNetworkImage(
                                      imageUrl: resolvedImgUrl,
                                      cacheKey: resolvedImgUrl.split('?').first,
                                      useOldImageOnUrlChange: true,
                                      fit: BoxFit.cover,
                                      fadeInDuration: Duration.zero,
                                      fadeOutDuration: Duration.zero,
                                      placeholder: (c, url) => _buildCardFallbackAvatar(displayContact, colors),
                                      errorWidget: (c, url, err) => _buildCardFallbackAvatar(displayContact, colors),
                                    ))
                              : _buildCardFallbackAvatar(displayContact, colors),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (companyName.isNotEmpty)
                              Text(
                                companyName,
                                style: GoogleFonts.inter(
                                  color: colors.text,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (designationName.isNotEmpty)
                              Text(
                                designationName,
                                style: GoogleFonts.inter(
                                  color: colors.accent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (companyName.isEmpty && designationName.isEmpty)
                              Text(
                                'Smart Card #${idx + 1}',
                                style: GoogleFonts.inter(
                                  color: colors.text,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (fullUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_browser, size: 18),
                        label: Text(
                          'View Card',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          final uri = Uri.parse(fullUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildScannedCardImageSection(ScannedContactModel displayContact, dynamic colors) {
    return const SizedBox.shrink();
  }

  void _toggleFavorite() {
    context.read<ContactViewModel>().toggleFavorite(_contact.id);
    setState(() {
      _contact = _contact.copyWith(isFavorite: !_contact.isFavorite);
    });
  }

  void _showManageGroupsModal(BuildContext context, AppContact appContact) {
    final groupProvider = context.read<GroupProvider>();
    final contactProvider = context.read<ContactProvider>();

    final allGroups = groupProvider.groups;
    final Set<String> currentSelectedGroupIds = Set.from(appContact.groupIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Manage Contact Groups',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${currentSelectedGroupIds.length} groups',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: allGroups.isEmpty
                    ? Center(
                        child: Text(
                          'No contact groups created yet.',
                          style: GoogleFonts.inter(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: allGroups.length,
                        itemBuilder: (ctx, index) {
                          final group = allGroups[index];
                          final isAssigned = currentSelectedGroupIds.contains(group.id);

                          return CheckboxListTile(
                            value: isAssigned,
                            activeColor: AppColors.primary,
                            title: Text(group.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            subtitle: Text('${group.contactCount ?? 0} members', style: GoogleFonts.inter(fontSize: 12)),
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.folder_shared_rounded, color: AppColors.primary, size: 20),
                            ),
                            onChanged: (val) {
                              if (group.id != null) {
                                setModalState(() {
                                  if (val == true) {
                                    currentSelectedGroupIds.add(group.id!);
                                  } else {
                                    currentSelectedGroupIds.remove(group.id!);
                                  }
                                });
                              }
                            },
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.of(ctx).pop();
                        final updated = await contactProvider.updateContact(
                          appContact,
                          newGroupIds: currentSelectedGroupIds.toList(),
                          previousGroupIds: appContact.groupIds,
                        );
                        if (updated != null) {
                          await groupProvider.loadGroups();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Groups updated for ${appContact.displayName}'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Done', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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

  Widget _buildPhoneNumbersCard(BuildContext context, ScannedContactModel contact, dynamic colors) {
    AppContact? linkedAppContact;
    try {
      final cp = context.read<ContactProvider>();
      linkedAppContact = cp.findContactByDeviceContactIdOrDetails(
            contact.deviceContactId,
            contact.phone,
            contact.email,
            company: contact.company,
            name: contact.name,
          ) ??
          cp.findContactById(contact.id);
    } catch (_) {}

    final phoneItems = ContactActionHelper.extractPhoneItems(contact, appContact: linkedAppContact);
    if (phoneItems.isEmpty) return const SizedBox.shrink();

    final Color cardBg = colors.card ?? Colors.white;
    final Color textColor = colors.text ?? Colors.black87;
    final Color mutedColor = colors.muted ?? Colors.grey[600]!;
    final Color borderColor = colors.border ?? const Color(0xFF8B0000).withValues(alpha: 0.45);

    final bool hasExplicitPrimary = phoneItems.any((item) => item.isPrimary);
    final List<ContactActionItem> primaryItems =
        hasExplicitPrimary ? phoneItems.where((item) => item.isPrimary).toList() : [];
    final List<ContactActionItem> altItems =
        hasExplicitPrimary ? phoneItems.where((item) => !item.isPrimary).toList() : phoneItems;

    Widget buildPhoneItem(ContactActionItem item, {bool showPrimaryBadge = false}) {
      final number = item.value;
      final formattedNumber = ContactActionHelper.formatDisplayPhone(number);
      final label = item.label.isNotEmpty ? item.label : 'Mobile';

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: number));
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied $number to clipboard'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.callGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.phone_outlined, color: AppColors.callGreen, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formattedNumber,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            letterSpacing: 0.3,
                            color: textColor,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.copy_rounded, size: 15, color: mutedColor.withValues(alpha: 0.7)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 44.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: mutedColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: mutedColor,
                            ),
                          ),
                        ),
                        if (showPrimaryBadge) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.3), width: 1),
                            ),
                            child: Text(
                              'Primary',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryRed,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMiniActionButton(
                        icon: Icons.phone_rounded,
                        color: AppColors.callGreen,
                        tooltip: 'Call',
                        onPressed: () => IntentLauncher.makePhoneCall(context, number),
                      ),
                      const SizedBox(width: 8),
                      _buildMiniActionButton(
                        icon: Icons.message_rounded,
                        color: AppColors.smsBlue,
                        tooltip: 'SMS',
                        onPressed: () => IntentLauncher.sendSms(context, number),
                      ),
                      const SizedBox(width: 8),
                      _buildMiniActionButton(
                        icon: FontAwesomeIcons.whatsapp,
                        color: AppColors.whatsappGreen,
                        tooltip: 'WhatsApp',
                        onPressed: () => IntentLauncher.openWhatsApp(context, number),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_rounded, color: AppColors.primaryRed, size: 20),
              const SizedBox(width: 10),
              Text(
                'Phone Numbers',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: borderColor.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          if (hasExplicitPrimary) ...[
            Text(
              'Primary:',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryRed,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            ...primaryItems.map((item) => buildPhoneItem(item, showPrimaryBadge: false)),
            if (altItems.isNotEmpty) ...[
              const SizedBox(height: 4),
              Divider(height: 1, color: borderColor.withValues(alpha: 0.2)),
              const SizedBox(height: 10),
              Text(
                'Alternative Numbers:',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: mutedColor,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              ...altItems.map((item) => buildPhoneItem(item, showPrimaryBadge: false)),
            ],
          ] else ...[
            // No explicit primary — display all numbers using their actual device labels
            ...phoneItems.map((item) => buildPhoneItem(item, showPrimaryBadge: false)),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniActionButton({
    required dynamic icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: icon is IconData
                ? Icon(icon, color: color, size: 18)
                : FaIcon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }

  AppContact _toAppContact(ScannedContactModel model) {
    final phoneItems = ContactActionHelper.extractPhoneItems(model);
    final emailItems = ContactActionHelper.extractEmailItems(model);
    final websiteItems = ContactActionHelper.extractWebsiteItems(model);

    final List<ContactPhone> phones = phoneItems.map((item) => ContactPhone(number: item.value, label: item.label)).toList();
    final List<ContactEmail> emails = emailItems.map((item) => ContactEmail(address: item.value, label: item.label)).toList();
    final List<ContactWebsite> websites = websiteItems.map((item) => ContactWebsite(url: item.value, label: item.label)).toList();
    final List<ContactAddress> addresses = [];
    if (model.address.trim().isNotEmpty) {
      addresses.add(ContactAddress(address: model.address.trim(), label: 'Work'));
    }

    return AppContact(
      id: model.id,
      displayName: model.name,
      phones: phones,
      emails: emails,
      websites: websites,
      addresses: addresses,
      company: model.company,
      jobTitle: model.designation,
      notes: model.address,
      isFavorite: model.isFavorite,
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactViewModel = context.watch<ContactViewModel>();
    final all = contactViewModel.allContacts;



    // Check if there is an enriched matched contact in smartCardContacts or allContacts
    ScannedContactModel displayContact = _contact;
    if (!displayContact.isMatched || displayContact.matchedCards == null || displayContact.matchedCards!.isEmpty) {
      final phoneDigits = [
        _contact.phone,
        _contact.alternativePhone,
        _contact.whatsApp,
        _contact.landline,
      ].where((p) => p != null && p.trim().isNotEmpty).map((p) => p!.replaceAll(RegExp(r'\D'), '')).toList();

      for (final c in contactViewModel.smartCardContacts.followedBy(all)) {
        if (c.id == _contact.id && (c.isSmartCardUser || c.isMatched || (c.matchedCards != null && c.matchedCards!.isNotEmpty))) {
          displayContact = c;
          break;
        }
        final cp = c.phone.replaceAll(RegExp(r'\D'), '');
        final cp10 = cp.length >= 10 ? cp.substring(cp.length - 10) : cp;
        if (cp10.isNotEmpty) {
          for (final pd in phoneDigits) {
            final pd10 = pd.length >= 10 ? pd.substring(pd.length - 10) : pd;
            if (pd10.isNotEmpty && pd10 == cp10 && (c.isSmartCardUser || c.isMatched || (c.matchedCards != null && c.matchedCards!.isNotEmpty))) {
              displayContact = c;
              break;
            }
          }
        }
        if (displayContact != _contact) break;
      }
    }

    // Preserve alternativePhone from _contact if displayContact doesn't have it
    if (displayContact != _contact) {
      if ((displayContact.alternativePhone == null || displayContact.alternativePhone!.trim().isEmpty) &&
          (_contact.alternativePhone != null && _contact.alternativePhone!.trim().isNotEmpty)) {
        displayContact = displayContact.copyWith(alternativePhone: _contact.alternativePhone);
      }
    }

    // Also look up device contact in ContactProvider to ensure any second/alternative numbers on device are attached
    try {
      final cp = context.read<ContactProvider>();
      final devContact = cp.findContactByDeviceContactIdOrDetails(
            displayContact.deviceContactId,
            displayContact.phone,
            displayContact.email,
            company: displayContact.company,
            name: displayContact.name,
          ) ??
          cp.findContactById(displayContact.id);
      if (devContact != null && devContact.phones.length > 1) {
        final alts = devContact.phones.skip(1).map((p) => p.number.trim()).where((n) => n.isNotEmpty).toList();
        if (alts.isNotEmpty) {
          final existing = displayContact.alternativePhone;
          final combined = {
            if (existing != null && existing.trim().isNotEmpty) existing.trim(),
            ...alts,
          }.join(', ');
          displayContact = displayContact.copyWith(alternativePhone: combined);
        }
      }
    } catch (_) {}

    final appContact = _toAppContact(displayContact);
    final colors = context.watch<ThemeViewModel>().colors;

    final bool isSmartCardUser = displayContact.isSmartCardUser ||
        displayContact.isMatched ||
        (displayContact.matchedCards != null && displayContact.matchedCards!.isNotEmpty) ||
        _contact.isSmartCardUser ||
        _contact.isMatched ||
        (_contact.matchedCards != null && _contact.matchedCards!.isNotEmpty);

    String? resolvedAvatar;
    String resolvedAvatarType = 'profile';

    if (_liveDevicePhoto != null && _liveDevicePhoto!.trim().isNotEmpty) {
      resolvedAvatar = _liveDevicePhoto!.trim();
    } else if (appContact.photo != null && appContact.photo!.isNotEmpty) {
      resolvedAvatar = 'data:image/jpeg;base64,${base64Encode(appContact.photo!)}';
    } else {
      resolvedAvatar = ContactPhotoResolver.resolveScannedPhotoSource(displayContact);
      if (resolvedAvatar != null &&
          (resolvedAvatar.contains('/logo/') || resolvedAvatar.contains('logo'))) {
        resolvedAvatarType = 'logo';
      }
    }

    final String? rawAvatar = (resolvedAvatar != null && resolvedAvatar.trim().isNotEmpty && resolvedAvatar.trim().toLowerCase() != 'null')
        ? resolvedAvatar.trim()
        : null;

    final String? avatarSource = rawAvatar != null
      ? ((!kIsWeb && File(rawAvatar).existsSync()) ||
          rawAvatar.startsWith('data:') ||
          rawAvatar.startsWith('http://') ||
          rawAvatar.startsWith('https://')
        ? rawAvatar
        : UploadUrlResolver.resolve(rawAvatar, type: resolvedAvatarType))
      : null;

    final String profileInitial = displayContact.name.isNotEmpty
        ? displayContact.name[0].toUpperCase()
        : '?';

    final String effectiveHeroTag = widget.heroTag ??
        contactHeroTag(
          id: widget.contact.id,
          phone: widget.contact.phone,
          name: widget.contact.name,
        );

    final bool isBusinessContact = displayContact.company.trim().isNotEmpty || isSmartCardUser;

    final contactGradient = AvatarHelper.getGradient(displayContact.name);
    final headerGradient = LinearGradient(
      colors: contactGradient.length >= 2
          ? contactGradient
          : const [Color(0xFF005CE6), Color(0xFF003CB5)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Full Screen login.png Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/login.png',
              fit: BoxFit.cover,
            ),
          ),

          // Scrollable Content
          Positioned.fill(
            child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // 1. Top Vibrant Dynamic Colour Banner
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: headerGradient,
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            // Top Navigation Bar (Back, Favorite, Edit, Delete/More)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: Icon(
                                      _contact.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      color: _contact.isFavorite ? Colors.redAccent : Colors.white,
                                      size: 24,
                                    ),
                                    onPressed: _toggleFavorite,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                                    onPressed: () => _showEditDialog(context),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 24),
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                        ),
                                        builder: (ctx) => SafeArea(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                leading: Icon(
                                                  isSmartCardUser ? Icons.person_remove_rounded : Icons.verified_user_rounded,
                                                  color: isSmartCardUser ? AppColors.deleteRed : AppColors.primaryRed,
                                                ),
                                                title: Text(isSmartCardUser ? 'Remove from Smart Card' : 'Add to Smart Card'),
                                                onTap: () async {
                                                  Navigator.pop(ctx);
                                                  final cvm = context.read<ContactViewModel>();
                                                  final appC = appContact ?? AppContact(
                                                    id: displayContact.deviceContactId ?? displayContact.id,
                                                    displayName: displayContact.name,
                                                    phones: [if (displayContact.phone.isNotEmpty) ContactPhone(number: displayContact.phone)],
                                                    emails: [if (displayContact.email.isNotEmpty) ContactEmail(address: displayContact.email)],
                                                    company: displayContact.company.isNotEmpty ? displayContact.company : null,
                                                    jobTitle: displayContact.designation.isNotEmpty ? displayContact.designation : null,
                                                  );
                                                  await cvm.toggleSmartCardMembership(appC);
                                                  if (mounted) {
                                                    setState(() {
                                                      _contact = _contact.copyWith(
                                                        isMatched: !isSmartCardUser,
                                                        source: !isSmartCardUser ? 'smart_card' : 'device',
                                                      );
                                                    });
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text(!isSmartCardUser ? 'Added to Smart Card' : 'Removed from Smart Card'),
                                                        duration: const Duration(seconds: 2),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.edit_rounded, color: AppColors.primaryRed),
                                                title: const Text('Edit Contact'),
                                                onTap: () {
                                                  Navigator.pop(ctx);
                                                  _showEditDialog(context);
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.deleteRed),
                                                title: const Text('Delete Contact', style: TextStyle(color: AppColors.deleteRed)),
                                                onTap: () {
                                                  Navigator.pop(ctx);
                                                  _confirmDelete(context);
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Centered Profile Avatar with Silver metallic border ring and silver micro business badge
                            GestureDetector(
                              onTap: () => _showFullImagePreview(
                                context,
                                displayContact,
                                appContact,
                                avatarSource,
                                effectiveHeroTag,
                                isBusinessContact,
                              ),
                              child: Hero(
                                tag: effectiveHeroTag,
                                createRectTween: (begin, end) => GenieRectTween(begin: begin, end: end),
                                flightShuttleBuilder: genieFlightShuttleBuilder,
                                child: Material(
                                  color: Colors.transparent,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.center,
                                    children: [
                                      // Truecaller-inspired Bloody Red Ring with crisp separation gap
                                      Container(
                                        padding: const EdgeInsets.all(3.5),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF8B0000), // Bloody red ring
                                            width: 3.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF8B0000).withValues(alpha: 0.4),
                                              blurRadius: 14,
                                              spreadRadius: 1,
                                              offset: const Offset(0, 3),
                                            ),
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.25),
                                              blurRadius: 10,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(2.5),
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white, // Truecaller signature white gap
                                          ),
                                          child: ClipOval(
                                            child: SizedBox(
                                              width: 100,
                                              height: 100,
                                              child: (appContact.photo != null && appContact.photo!.isNotEmpty)
                                                  ? Image.memory(
                                                      appContact.photo!,
                                                      fit: BoxFit.cover,
                                                      filterQuality: FilterQuality.high,
                                                    )
                                                  : (avatarSource != null && avatarSource.isNotEmpty)
                                                      ? ((avatarSource.startsWith('data:image') || avatarSource.startsWith('data:'))
                                                          ? () {
                                                              final base64Bytes = safeBase64Decode(avatarSource);
                                                              if (base64Bytes != null) {
                                                                return Image.memory(
                                                                  base64Bytes,
                                                                  fit: BoxFit.cover,
                                                                  filterQuality: FilterQuality.high,
                                                                  errorBuilder: (_, _, _) => _buildAvatarInitial(profileInitial),
                                                                );
                                                              }
                                                              return _buildAvatarInitial(profileInitial);
                                                            }()
                                                          : CachedNetworkImage(
                                                              imageUrl: avatarSource,
                                                              cacheKey: avatarSource.split('?').first,
                                                              fit: BoxFit.cover,
                                                              filterQuality: FilterQuality.high,
                                                              fadeInDuration: Duration.zero,
                                                              fadeOutDuration: Duration.zero,
                                                              placeholder: (_, _) => _buildAvatarInitial(profileInitial),
                                                              errorWidget: (_, _, _) => _buildAvatarInitial(profileInitial),
                                                            ))
                                                      : _buildAvatarInitial(profileInitial),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Silver Micro Business / Verified Badge
                                      if (isBusinessContact || isSmartCardUser)
                                        Positioned(
                                          right: 2,
                                          bottom: 2,
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFF9FAFB),
                                                  Color(0xFF9CA3AF),
                                                  Color(0xFFD1D5DB),
                                                  Color(0xFF4B5563),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2.2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.35),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Icon(
                                                isBusinessContact ? Icons.business_center_rounded : Icons.verified_rounded,
                                                size: 17,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Line 1: Contact Name in Large Bold White Text
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                displayContact.name.isNotEmpty ? displayContact.name : 'Unknown Contact',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 27,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),

                            // Line 2: Designation (Second Line)
                            if (displayContact.designation.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6, left: 24, right: 24),
                                child: Text(
                                  displayContact.designation.trim(),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.95),
                                  ),
                                ),
                              ),

                            // Line 3: Company (Third Line)
                            if (displayContact.company.trim().isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: displayContact.designation.trim().isNotEmpty ? 3 : 6,
                                  left: 24,
                                  right: 24,
                                ),
                                child: Text(
                                  displayContact.company.trim(),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.88),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 8),

                            // In your contacts / SmartCard User badge text
                            Text(
                              isSmartCardUser ? 'SmartCard User' : 'In your contacts',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),



                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),

                    // 2. White Bottom Sheet with Curved Top Corners (Screenshot 2 exact style)
                    Transform.translate(
                      offset: const Offset(0, -32),
                      child: Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height * 0.65,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF161B22)
                              : Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(36),
                            topRight: Radius.circular(36),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 24,
                              spreadRadius: 2,
                              offset: const Offset(0, -6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Quick Action Bar inside the white sheet
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: QuickActionBar(contact: appContact),
                              ),

                              // ── Digital Corporate Business Card Layout (Section 2.3 BRD) ──
                              if (displayContact.isCorporate) ...[
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF0F2038), Color(0xFF1E3A5F)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0284C7),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(Icons.business_rounded, color: Colors.white, size: 16),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'OFFICIAL CORPORATE LEAD',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.1,
                                                  color: const Color(0xFF7DD3FC),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: (displayContact.corporateGroup == 'Client'
                                                      ? const Color(0xFF10B981)
                                                      : displayContact.corporateGroup == 'Partner'
                                                          ? const Color(0xFF3B82F6)
                                                          : displayContact.corporateGroup == 'Vendor'
                                                              ? const Color(0xFFF59E0B)
                                                              : const Color(0xFF0284C7))
                                                  .withValues(alpha: 0.25),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: (displayContact.corporateGroup == 'Client'
                                                        ? const Color(0xFF10B981)
                                                        : displayContact.corporateGroup == 'Partner'
                                                            ? const Color(0xFF3B82F6)
                                                            : displayContact.corporateGroup == 'Vendor'
                                                                ? const Color(0xFFF59E0B)
                                                                : const Color(0xFF0284C7))
                                                    .withValues(alpha: 0.8),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              displayContact.corporateGroup?.isNotEmpty == true
                                                  ? displayContact.corporateGroup!
                                                  : 'Corporate',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: displayContact.corporateGroup == 'Client'
                                                    ? const Color(0xFF10B981)
                                                    : displayContact.corporateGroup == 'Partner'
                                                        ? const Color(0xFF3B82F6)
                                                        : displayContact.corporateGroup == 'Vendor'
                                                            ? const Color(0xFFF59E0B)
                                                            : const Color(0xFF7DD3FC),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        displayContact.company.isNotEmpty ? displayContact.company : 'Company Corporate',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (displayContact.designation.isNotEmpty)
                                        Text(
                                          displayContact.designation,
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      if (displayContact.corporateDepartment?.isNotEmpty == true) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.domain_rounded, size: 13, color: Color(0xFF38BDF8)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Department: ${displayContact.corporateDepartment!}',
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                color: const Color(0xFFBAE6FD),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (displayContact.address.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF38BDF8)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                displayContact.address,
                                                style: GoogleFonts.inter(
                                                  fontSize: 11.5,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (displayContact.website.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        InkWell(
                                          onTap: () => IntentLauncher.openWebsite(context, displayContact.website),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.language_rounded, size: 14, color: Color(0xFF38BDF8)),
                                              const SizedBox(width: 4),
                                              Text(
                                                displayContact.website,
                                                style: GoogleFonts.inter(
                                                  fontSize: 11.5,
                                                  color: const Color(0xFF38BDF8),
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (displayContact.corporateTags.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 6,
                                          children: displayContact.corporateTags.map((t) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '#$t',
                                                style: GoogleFonts.inter(fontSize: 10, color: Colors.white),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],

                              // Visiting Card (If scanned)
                              if ((displayContact.source == 'ocr' ||
                                   displayContact.source == 'business_card' ||
                                   displayContact.source == 'scanned' ||
                                   displayContact.contactType == 'scanned' ||
                                   displayContact.contactType == 'ocr' ||
                                   displayContact.contactType == 'business_card') &&
                                  (displayContact.imagePath != null && displayContact.imagePath!.trim().isNotEmpty && displayContact.imagePath!.trim().toLowerCase() != 'null')) ...[
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GestureDetector(
                            onTap: () => _showFullImagePreview(
                              context,
                              displayContact,
                              appContact,
                              displayContact.imagePath ?? avatarSource,
                              'card_${displayContact.id}',
                              isBusinessContact,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.credit_card_rounded, size: 16, color: AppColors.primaryRed),
                                    const SizedBox(width: 6),
                                    Text(
                                      'VISITING CARD',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                        color: AppColors.primaryRed,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Tap to zoom',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.grey),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  height: ((MediaQuery.of(context).size.width - 40) / 1.72).clamp(180.0, 280.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.primaryRed.withValues(alpha: 0.5),
                                      width: 1.8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryRed.withValues(alpha: 0.12),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: SizedBox(
                                      width: MediaQuery.of(context).size.width - 40,
                                      height: ((MediaQuery.of(context).size.width - 40) / 1.72),
                                      child: _buildRectanglePhotoContent(
                                        displayContact,
                                        appContact,
                                        avatarSource,
                                        MediaQuery.of(context).size.width - 40,
                                        ((MediaQuery.of(context).size.width - 40) / 1.72),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                    const SizedBox(height: 20),

                    // Add to Group Pill & Slidable Group tags
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showManageGroupsModal(context, appContact),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded, size: 16, color: AppColors.primaryRed),
                              const SizedBox(width: 4),
                              Text(
                                'Add to Group',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // SmartCard Verified Profile Section (if matched)
                    _buildSmartCardSection(displayContact, colors),

                    // Scanned Visiting Card Image Section (if physical card image exists)
                    _buildScannedCardImageSection(displayContact, colors),

                    // Phone Numbers Card with inline Call, SMS, WhatsApp buttons
                    _buildPhoneNumbersCard(context, displayContact, colors),

                    // Email Addresses Section
                    if (displayContact.email.trim().isNotEmpty)
                      _buildDetailCard(
                        colors: colors,
                        icon: Icons.email_rounded,
                        label: 'Email',
                        value: displayContact.email.trim(),
                        onTap: () => IntentLauncher.sendEmail(context, displayContact.email.trim()),
                      ),

                    // Websites & Links Section
                    if (displayContact.website.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildDetailCard(
                        colors: colors,
                        icon: Icons.language_rounded,
                        label: 'Website',
                        value: displayContact.website.trim(),
                        onTap: () => IntentLauncher.openWebsite(context, displayContact.website.trim()),
                      ),
                    ],

                    // Addresses Section
                    if (displayContact.address.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildDetailCard(
                        colors: colors,
                        icon: Icons.location_on_rounded,
                        label: 'Address',
                        value: displayContact.address.trim(),
                        onTap: () => IntentLauncher.openMap(context, displayContact.address.trim()),
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
          // 4-side bloody red border ONLY on contact detail screen
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF8B0000), // Bloody red 4-side border
                    width: 3.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const GlobalBottomNav(),
    );
  }

  void _showEditDialog(BuildContext context) async {
    final effectiveHeroTag = widget.heroTag ?? 'profile_${_contact.id}';
    final result = await Navigator.push(
      context,
      GeniePageRoute(
        page: ContactFormScreen(
          scannedContactToEdit: _contact,
          heroTag: effectiveHeroTag,
        ),
      ),
    );
    if (result != null && mounted) {
      if (result is ScannedContactModel) {
        setState(() {
          _contact = result;
        });
      } else if (result is AppContact) {
        setState(() {
          _contact = _contact.copyWith(
            name: result.displayName,
            phone: result.primaryPhone,
            email: result.primaryEmail,
            company: result.company,
            designation: result.jobTitle,
            address: result.addresses.isNotEmpty ? result.addresses.first.address : '',
            website: result.websites.isNotEmpty ? result.websites.first.url : '',
            isFavorite: result.isFavorite,
          );
        });
      }
    }
  }

  void _confirmDelete(BuildContext context) async {
    final confirmed = await showDeleteConfirmDialog(
      context: context,
      title: 'Delete Contact',
      message: 'Are you sure you want to delete this contact? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );

    if (confirmed != true || !context.mounted) return;

    // Show loading indicator while deleting
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Deleting contact...'),
          ],
        ),
        duration: Duration(seconds: 15),
      ),
    );

    try {
      final contactVm = context.read<ContactViewModel>();
      final provider = context.read<ContactProvider>();

      await contactVm.deleteContact(_contact.id, target: _contact);

      try {
        final bool isExplicitPhoneContact = _contact.source == 'phone' || _contact.id.startsWith('phone_');
        if (isExplicitPhoneContact && _contact.deviceContactId != null && _contact.deviceContactId!.isNotEmpty) {
          final devMatch = provider.findContactById(_contact.deviceContactId!);
          if (devMatch != null) {
            final bool usedByOtherProfile = contactVm.allContacts.any(
              (c) => c.id != _contact.id && (
                c.deviceContactId == devMatch.id ||
                (_contact.phone.isNotEmpty && PhoneNormalizer.isSame(c.phone, _contact.phone))
              ),
            );
            if (!usedByOtherProfile) {
              await provider.deleteContact(devMatch);
            }
          }
        }
      } catch (e) {
        debugPrint('Device contact deletion warning: $e');
      }

      scaffoldMessenger.hideCurrentSnackBar();

      // Pop the screen FIRST, then show the success message on the contacts list
      if (navigator.canPop()) {
        navigator.pop({'deleted': true, 'name': _contact.name});
      } else {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ContactsScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error deleting contact: $e'),
          backgroundColor: AppColors.deleteRed,
        ),
      );
    }
  }

  void _showFullImagePreview(
    BuildContext context,
    ScannedContactModel displayContact,
    AppContact? appContact,
    String? avatarSource,
    String heroTag,
    bool isBusiness,
  ) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.85),
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) {
          final screenWidth = MediaQuery.of(context).size.width;
          final bool isCard = heroTag.startsWith('card_');
          final rectWidth = isCard
              ? (screenWidth * 0.92).clamp(300.0, 520.0)
              : (screenWidth * 0.82).clamp(260.0, 380.0);
          final rectHeight = isCard ? (rectWidth / 1.70) : rectWidth;

          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                isCard ? 'Visiting Card' : (displayContact.name.isNotEmpty ? displayContact.name : 'Profile Photo'),
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              centerTitle: true,
            ),
            body: SafeArea(
              child: Stack(
                children: [
                  // Tap outside to close
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: const SizedBox.expand(),
                  ),

                  // Center Expanded Visiting Card / Profile Photo with Pinch-to-Zoom & Genie transition
                  Center(
                    child: Hero(
                      tag: heroTag,
                      createRectTween: (begin, end) => GenieRectTween(begin: begin, end: end),
                      flightShuttleBuilder: genieFlightShuttleBuilder,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          width: rectWidth,
                          height: rectHeight,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(isCard ? 16 : 24),
                            border: Border.all(
                              color: Colors.white,
                              width: 3.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 30,
                                spreadRadius: 4,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(isCard ? 13 : 21),
                            child: InteractiveViewer(
                              minScale: 1.0,
                              maxScale: 4.0,
                              child: SizedBox(
                                width: rectWidth,
                                height: rectHeight,
                                child: _buildRectanglePhotoContent(
                                  displayContact,
                                  appContact,
                                  avatarSource,
                                  rectWidth,
                                  rectHeight,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildRectanglePhotoContent(
    ScannedContactModel displayContact,
    AppContact? appContact,
    String? avatarSource,
    double width,
    double height,
  ) {
    // 1. Device contact photo bytes
    if (appContact?.photo != null && appContact!.photo!.isNotEmpty) {
      return Image.memory(
        appContact.photo!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
      );
    }

    if (_liveDevicePhoto != null && _liveDevicePhoto!.trim().isNotEmpty) {
      final bytes = safeBase64Decode(_liveDevicePhoto);
      if (bytes != null) {
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
        );
      }
    }

    // 2. Resolve candidate image path/URL: for scanned cards, prioritize physical scanned imagePath
    final bool isScannedCard = (displayContact.source == 'ocr' ||
        displayContact.source == 'business_card' ||
        displayContact.source == 'scanned' ||
        displayContact.contactType == 'scanned' ||
        displayContact.contactType == 'ocr' ||
        displayContact.contactType == 'business_card');

    String? rawCandidate;
    if (isScannedCard && displayContact.imagePath?.trim().isNotEmpty == true && displayContact.imagePath!.trim().toLowerCase() != 'null') {
      rawCandidate = displayContact.imagePath!.trim();
    } else if (avatarSource != null && avatarSource.trim().isNotEmpty && avatarSource.trim().toLowerCase() != 'null') {
      rawCandidate = avatarSource.trim();
    }

    if (rawCandidate == null) {
      if (displayContact.matchedProfileImage?.trim().isNotEmpty == true && displayContact.matchedProfileImage!.trim().toLowerCase() != 'null') {
        rawCandidate = displayContact.matchedProfileImage!.trim();
      } else if (displayContact.cardUrl?.trim().isNotEmpty == true && displayContact.cardUrl!.trim().toLowerCase() != 'null') {
        rawCandidate = displayContact.cardUrl!.trim();
      } else if (displayContact.profileImage?.trim().isNotEmpty == true && displayContact.profileImage!.trim().toLowerCase() != 'null') {
        rawCandidate = displayContact.profileImage!.trim();
      } else if (displayContact.companyLogo?.trim().isNotEmpty == true && displayContact.companyLogo!.trim().toLowerCase() != 'null') {
        rawCandidate = displayContact.companyLogo!.trim();
      } else if (displayContact.imagePath?.trim().isNotEmpty == true && displayContact.imagePath!.trim().toLowerCase() != 'null') {
        rawCandidate = displayContact.imagePath!.trim();
      } else if (displayContact.matchedCards != null && displayContact.matchedCards!.isNotEmpty) {
        for (final card in displayContact.matchedCards!) {
          final pImg = card['profileImageName']?.toString() ??
              card['profile_image_name']?.toString() ??
              card['profileImage']?.toString() ??
              card['profile_image']?.toString() ??
              card['user_image']?.toString() ??
              card['userImage']?.toString() ??
              card['user_photo']?.toString() ??
              card['userPhoto']?.toString() ??
              card['avatar']?.toString() ??
              card['cardUrl']?.toString() ??
              card['card_url']?.toString();
          if (pImg != null && pImg.trim().isNotEmpty && pImg.trim().toLowerCase() != 'null') {
            rawCandidate = pImg.trim();
            break;
          }
          final lImg = card['companyLogo']?.toString() ??
              card['company_logo']?.toString() ??
              card['logo']?.toString();
          if (lImg != null && lImg.trim().isNotEmpty && lImg.trim().toLowerCase() != 'null') {
            rawCandidate = lImg.trim();
            break;
          }
        }
      }
    }

    final effectiveFit = isScannedCard ? BoxFit.contain : BoxFit.cover;

    if (rawCandidate != null && rawCandidate.isNotEmpty) {
      // Base64 Data URI
      if (rawCandidate.startsWith('data:image') || rawCandidate.startsWith('data:')) {
        final bytes = safeBase64Decode(rawCandidate);
        if (bytes != null) {
          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: effectiveFit,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
          );
        }
      }

      // Local filesystem path
      if (!kIsWeb && File(rawCandidate).existsSync()) {
        return Image.file(
          File(rawCandidate),
          width: width,
          height: height,
          fit: effectiveFit,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
        );
      }

      // Server Network Image URL
      final resolvedUrl = (rawCandidate.startsWith('http://') || rawCandidate.startsWith('https://'))
          ? rawCandidate
          : UploadUrlResolver.resolve(rawCandidate, type: (rawCandidate.contains('/logo/') || rawCandidate.contains('logo')) ? 'logo' : 'profile');

      return CachedNetworkImage(
        imageUrl: resolvedUrl,
        width: width,
        height: height,
        fit: effectiveFit,
        filterQuality: FilterQuality.high,
        useOldImageOnUrlChange: true,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (_, _) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade100,
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primaryRed),
          ),
        ),
        errorWidget: (_, _, _) => _buildFallbackInitialRect(displayContact.name, width, height),
      );
    }

    return _buildFallbackInitialRect(displayContact.name, width, height);
  }

  Widget _buildFallbackInitialRect(String name, double width, double height) {
    final initial = AvatarHelper.getFirstLetter(name);
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryRed, Color(0xFFB71C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: height * 0.42,
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required dynamic colors,
    required dynamic icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    Widget iconWidget = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: icon is IconData
          ? Icon(icon, color: AppColors.primary, size: 20)
          : const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
    );

    final bool isPhoneCard = label.toLowerCase().contains('phone') ||
        label.toLowerCase().contains('landline') ||
        label.toLowerCase().contains('whatsapp');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF8B0000).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        color: colors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        color: colors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPhoneCard) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => IntentLauncher.makePhoneCall(context, value),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.callGreen.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone_rounded, color: AppColors.callGreen, size: 18),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => IntentLauncher.sendSms(context, value),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.smsBlue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.message_rounded, color: AppColors.smsBlue, size: 18),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => IntentLauncher.openWhatsApp(context, value),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.whatsappGreen.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const FaIcon(FontAwesomeIcons.whatsapp, color: AppColors.whatsappGreen, size: 18),
                      ),
                    ),
                  ],
                ),
              ] else if (onTap != null) ...[
                const Icon(Icons.chevron_right, color: Color(0xFFE53935), size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarInitial(String initial) {
    return Container(
      width: 104,
      height: 104,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFFEBEE),
      ),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: GoogleFonts.inter(
            color: const Color(0xFFE53935),
            fontSize: 38,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

