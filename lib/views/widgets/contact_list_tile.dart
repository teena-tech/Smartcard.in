import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as legacy;
import '../../core/providers/app_riverpod_providers.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_config.dart';
import '../../core/utils/avatar_helper.dart';
import '../../core/utils/contact_action_helper.dart';
import '../../core/utils/intent_launcher.dart';
import '../../models/app_contact.dart';
import '../../models/scanned_contact_model.dart';
import '../../providers/contact_provider.dart';
import '../../viewmodels/contact_viewmodel.dart';
import 'contact_tile_helpers.dart';
import 'genie_hero_route.dart';
import 'app_profile_avatar.dart';
import '../../core/services/contact_photo_resolver.dart';
import '../../core/services/contact_photo_service.dart';
import '../../core/utils/phone_normalizer.dart';
import '../screens/contact_detail_screen.dart';
import '../screens/contact_form_screen.dart';

ContactProvider _getContactProvider(BuildContext context) {
  final hasScope = context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null ||
      context.findAncestorWidgetOfExactType<ProviderScope>() != null;
  if (hasScope) {
    try {
      return ProviderScope.containerOf(context, listen: false).read(contactProviderRiverpod);
    } catch (_) {}
  }
  return legacy.Provider.of<ContactProvider>(context, listen: false);
}

ContactViewModel _getContactViewModel(BuildContext context) {
  final hasScope = context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null ||
      context.findAncestorWidgetOfExactType<ProviderScope>() != null;
  if (hasScope) {
    try {
      return ProviderScope.containerOf(context, listen: false).read(contactViewModelProvider);
    } catch (_) {}
  }
  return legacy.Provider.of<ContactViewModel>(context, listen: false);
}
class ContactListTile extends StatelessWidget {
  final ScannedContactModel contact;
  final VoidCallback onFavoriteToggle;
  final bool enableHero;

  const ContactListTile({
    super.key,
    required this.contact,
    required this.onFavoriteToggle,
    this.enableHero = true,
  });

  void _confirmDelete(BuildContext context, String displayName, AppContact? appContact) {
    ContactTileHelpers.showDeleteConfirmation(
      context,
      content: 'Delete "$displayName" from your contacts?',
      onConfirm: () async {
        final messenger = ScaffoldMessenger.of(context);
        final cvm = _getContactViewModel(context);
        final cp = _getContactProvider(context);
        await cvm.deleteContact(contact.id, target: contact);
        if (appContact != null && (contact.source == 'phone' || contact.id.startsWith('phone_'))) {
          final bool usedByOtherProfile = cvm.allContacts.any(
            (c) => c.id != contact.id && (
              c.deviceContactId == appContact.id ||
              (contact.phone.isNotEmpty && PhoneNormalizer.isSame(c.phone, contact.phone))
            ),
          );
          if (!usedByOtherProfile) {
            await cp.deleteContact(appContact);
          }
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text('$displayName deleted'),
            backgroundColor: AppColors.deleteRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _handleMenuAction(
    BuildContext context,
    String action, {
    required String displayName,
    required String primaryNumber,
    required String primaryEmail,
    required String company,
    required AppContact? appContact,
  }) {
    switch (action) {
      case 'call':
        ContactActionHelper.handleCall(
          context,
          contact: contact,
          contactName: displayName,
        );
        break;
      case 'sms':
        ContactActionHelper.handleSms(
          context,
          contact: contact,
          contactName: displayName,
        );
        break;
      case 'whatsapp':
        ContactActionHelper.handleWhatsApp(
          context,
          contact: contact,
          contactName: displayName,
        );
        break;
      case 'email':
        ContactActionHelper.handleEmail(
          context,
          contact: contact,
          contactName: displayName,
        );
        break;
      case 'share':
        final buffer = StringBuffer();
        buffer.writeln('Contact: $displayName');
        if (primaryNumber.isNotEmpty) {
          buffer.writeln('Phone: $primaryNumber');
        }
        if (primaryEmail.isNotEmpty) {
          buffer.writeln('Email: $primaryEmail');
        }
        if (company.isNotEmpty) {
          buffer.writeln('Company: $company');
        }
        if (contact.cardUrl != null && contact.cardUrl!.isNotEmpty) {
          buffer.writeln(
            'Digital Smart Card: ${ApiConfig.formatSmartCardUrl(contact.cardUrl)}',
          );
        }
        IntentLauncher.shareContact(buffer.toString(), subject: displayName);
        break;
      case 'edit':
        final tag = 'profile_${contact.id}';
        Navigator.push(
          context,
          GeniePageRoute(
            page: ContactFormScreen(
              scannedContactToEdit: contact,
              contactToEdit: appContact,
              heroTag: tag,
            ),
          ),
        );
        break;
      case 'group':
        ContactTileHelpers.showManageGroupsSheet(
          context,
          appContact ?? _createAppContactFallback(displayName, primaryNumber, primaryEmail, company),
        );
        break;
      case 'delete':
        _confirmDelete(context, displayName, appContact);
        break;
    }
  }

  AppContact _createAppContactFallback(String displayName, String primaryPhone, String primaryEmail, String company) {
    return AppContact(
      id: contact.id,
      displayName: displayName,
      phones: primaryPhone.isNotEmpty ? [ContactPhone(number: primaryPhone, label: 'mobile')] : [],
      emails: primaryEmail.isNotEmpty ? [ContactEmail(address: primaryEmail, label: 'work')] : [],
      company: company,
      jobTitle: contact.designation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasScope = context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null ||
        context.findAncestorWidgetOfExactType<ProviderScope>() != null;
    if (hasScope) {
      return Consumer(
        builder: (context, ref, _) => _buildTile(context, ref.watch(contactProviderRiverpod)),
      );
    }
    return _buildTile(context, legacy.Provider.of<ContactProvider>(context));
  }

  Widget _buildTile(BuildContext context, ContactProvider contactProvider) {
    final theme = Theme.of(context);

    final appContact = contactProvider.findContactByDeviceContactIdOrDetails(
          contact.deviceContactId,
          contact.phone,
          contact.email,
          company: contact.company,
          name: contact.name,
        ) ??
        contactProvider.findContactById(contact.id);

    final displayName = contact.name.trim().isNotEmpty
        ? contact.name.trim()
        : (appContact?.displayName.trim().isNotEmpty == true
            ? appContact!.displayName.trim()
            : 'Contact');

    final primaryNumber = contact.phone.trim().isNotEmpty
        ? contact.phone.trim()
        : (appContact?.primaryPhone.trim().isNotEmpty == true
            ? appContact!.primaryPhone.trim()
            : (contact.alternativePhone?.trim() ?? ''));

    final primaryEmail = contact.email.trim().isNotEmpty
        ? contact.email.trim()
        : (appContact?.primaryEmail.trim() ?? '');

    final company = contact.company.trim().isNotEmpty
        ? contact.company.trim()
        : (appContact?.company?.trim() ?? '');

    final hasPhone = primaryNumber.isNotEmpty;
    final hasEmail = primaryEmail.isNotEmpty;
    final gradient = AvatarHelper.getGradient(displayName);

    final bool isSmartCardUser = contact.isMatched ||
        (contact.matchedUserId != null && contact.matchedUserId!.isNotEmpty) ||
        (contact.matchedCards != null && contact.matchedCards!.isNotEmpty);

    final bool isFavorite = contact.isFavorite || (appContact?.isFavorite ?? false);
    final devicePhoto = appContact?.photo;

    return Dismissible(
      key: ValueKey('swipe_call_scanned_${contact.id}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.callGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const Icon(Icons.phone_forwarded_rounded, color: Colors.white, size: 26),
            const SizedBox(width: 10),
            Text(
              hasPhone ? 'Calling $primaryNumber...' : 'No Phone Number',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        ContactActionHelper.handleCall(
          context,
          contact: contact,
          contactName: displayName,
        );
        return false;
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 0,
        color: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            final cleanContactId = contact.id.trim().isNotEmpty
                ? contact.id.trim()
                : (contact.phone.replaceAll(RegExp(r'\D'), '').isNotEmpty
                    ? contact.phone.replaceAll(RegExp(r'\D'), '')
                    : contact.name.trim().replaceAll(RegExp(r'\s+'), '_'));
            final isScanned = contact.source == 'scanned' || contact.contactType == 'scanned';
            final dynamicHeroTag = 'contact_hero_${isScanned ? 'scanned' : 'smart'}_$cleanContactId';

            var targetContact = contact;
            if (appContact != null && appContact.phones.length > 1) {
              final alts = appContact.phones.skip(1).map((p) => p.number.trim()).where((n) => n.isNotEmpty).toList();
              if (alts.isNotEmpty) {
                final existing = targetContact.alternativePhone;
                final combined = {
                  if (existing != null && existing.trim().isNotEmpty) existing.trim(),
                  ...alts,
                }.join(', ');
                targetContact = targetContact.copyWith(alternativePhone: combined);
              }
            }

            Navigator.push(
              context,
              GeniePageRoute(
                page: ContactDetailScreen(
                  contact: targetContact,
                  heroTag: dynamicHeroTag,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // 1. Avatar (ONLY Device contact photo allowed; SmartCard profile image is strictly blocked)
                Builder(
                  builder: (context) {
                    final cleanContactId = contact.id.trim().isNotEmpty
                        ? contact.id.trim()
                        : (contact.phone.replaceAll(RegExp(r'\D'), '').isNotEmpty
                            ? contact.phone.replaceAll(RegExp(r'\D'), '')
                            : contact.name.trim().replaceAll(RegExp(r'\s+'), '_'));
                    final isScanned = contact.source == 'scanned' || contact.contactType == 'scanned';
                    final dynamicHeroTag = 'contact_hero_${isScanned ? 'scanned' : 'smart'}_$cleanContactId';
                    return FutureBuilder<Uint8List?>(
                      initialData: ContactPhotoService.getCachedPhoto(
                        contactId: appContact?.id ?? contact.id,
                        phone: contact.phone.isNotEmpty ? contact.phone : appContact?.primaryPhone,
                      ) ?? devicePhoto,
                      future: (devicePhoto != null && devicePhoto.isNotEmpty)
                          ? Future.value(devicePhoto)
                          : ContactPhotoService.getBestPhoto(
                              contactId: appContact?.id ?? contact.id,
                              phone: contact.phone.isNotEmpty ? contact.phone : appContact?.primaryPhone,
                            ),
                      builder: (context, snapshot) {
                        final effectivePhotoBytes = snapshot.data ?? devicePhoto;
                        final scannedAvatarUrl =
                            ContactPhotoResolver.resolveScannedPhotoSource(contact);
                        return AppProfileAvatar(
                          id: contact.id,
                          name: contact.name,
                          avatarUrl: (effectivePhotoBytes == null || effectivePhotoBytes.isEmpty)
                              ? scannedAvatarUrl
                              : null,
                          avatarBytes: (effectivePhotoBytes != null && effectivePhotoBytes.isNotEmpty) ? effectivePhotoBytes : null,
                          size: 48,
                          heroTag: dynamicHeroTag,
                          enableHero: enableHero,
                          customKey: 'scan_profile_${contact.id}',
                          gradientColors: gradient,
                          isSmartCardUser: isSmartCardUser,
                          isBusiness: isSmartCardUser || contact.company.trim().isNotEmpty,
                          onTap: () {
                            var targetContact = contact;
                            if (appContact != null && appContact.phones.length > 1) {
                              final alts = appContact.phones.skip(1).map((p) => p.number.trim()).where((n) => n.isNotEmpty).toList();
                              if (alts.isNotEmpty) {
                                final existing = targetContact.alternativePhone;
                                final combined = {
                                  if (existing != null && existing.trim().isNotEmpty) existing.trim(),
                                  ...alts,
                                }.join(', ');
                                targetContact = targetContact.copyWith(alternativePhone: combined);
                              }
                            }
                            Navigator.push(
                              context,
                              GeniePageRoute(
                                page: ContactDetailScreen(
                                  contact: targetContact,
                                  heroTag: dynamicHeroTag,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),

                const SizedBox(width: 14),

                // 2. Full Name & Secondary Info (Exact design & typography as Contact Tab)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isSmartCardUser) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.primaryRed,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        primaryNumber.isNotEmpty ? primaryNumber : 'No phone number',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (contact.allCompanies.length > 1) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.business_center_rounded,
                              size: 13,
                              color: AppColors.primaryRed,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                contact.allCompanies.join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.primaryRed,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (company.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          company,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                      if (contact.isCorporate) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (contact.corporateGroup == 'Client'
                                        ? const Color(0xFF10B981)
                                        : contact.corporateGroup == 'Partner'
                                            ? const Color(0xFF3B82F6)
                                            : contact.corporateGroup == 'Vendor'
                                                ? const Color(0xFFF59E0B)
                                                : const Color(0xFF0284C7))
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: (contact.corporateGroup == 'Client'
                                          ? const Color(0xFF10B981)
                                          : contact.corporateGroup == 'Partner'
                                              ? const Color(0xFF3B82F6)
                                              : contact.corporateGroup == 'Vendor'
                                                  ? const Color(0xFFF59E0B)
                                                  : const Color(0xFF0284C7))
                                      .withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.business_rounded,
                                    size: 10,
                                    color: contact.corporateGroup == 'Client'
                                        ? const Color(0xFF10B981)
                                        : contact.corporateGroup == 'Partner'
                                            ? const Color(0xFF3B82F6)
                                            : contact.corporateGroup == 'Vendor'
                                                ? const Color(0xFFF59E0B)
                                                : const Color(0xFF0284C7),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    contact.corporateGroup?.isNotEmpty == true ? contact.corporateGroup! : 'Corporate',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: contact.corporateGroup == 'Client'
                                          ? const Color(0xFF10B981)
                                          : contact.corporateGroup == 'Partner'
                                              ? const Color(0xFF3B82F6)
                                              : contact.corporateGroup == 'Vendor'
                                                  ? const Color(0xFFF59E0B)
                                                  : const Color(0xFF0284C7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (contact.corporateDepartment?.isNotEmpty == true) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  contact.corporateDepartment!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 4),

                // 3. Favorite Star Icon Button
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isFavorite ? AppColors.favoriteGold : Colors.grey[400],
                    size: 22,
                  ),
                  tooltip: isFavorite ? 'Remove Favorite' : 'Mark Favorite',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    onFavoriteToggle();
                    if (appContact != null) {
                      _getContactProvider(context).toggleFavorite(appContact);
                    }
                  },
                ),

                // 4. Three-Dots Menu Dropdown Button
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tooltip: 'Contact Options',
                  onSelected: (action) => _handleMenuAction(
                    context,
                    action,
                    displayName: displayName,
                    primaryNumber: primaryNumber,
                    primaryEmail: primaryEmail,
                    company: company,
                    appContact: appContact,
                  ),
                  itemBuilder: (ctx) => ContactTileHelpers.buildContactMenuItems(
                    hasPhone: hasPhone,
                    hasEmail: hasEmail,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ContactTile extends StatelessWidget {
  final AppContact contact;
  final VoidCallback? onTap;
  final bool enableHero;

  const ContactTile({
    super.key,
    required this.contact,
    this.onTap,
    this.enableHero = true,
  });

  void _showDeleteDialog(BuildContext context) {
    ContactTileHelpers.showDeleteConfirmation(
      context,
      content: 'Delete "${contact.displayName}" from your phone contacts?',
      onConfirm: () async {
        final messenger = ScaffoldMessenger.of(context);
        final cp = _getContactProvider(context);
        final cvm = _getContactViewModel(context);
        final success = await cp.deleteContact(contact);
        await cvm.deleteContact(
          contact.id,
          target: ScannedContactModel(
            id: contact.id,
            deviceContactId: contact.id,
            name: contact.displayName,
            company: contact.company ?? '',
            designation: contact.jobTitle ?? '',
            phone: contact.primaryPhone,
            email: contact.primaryEmail,
            website: '',
            address: '',
            socialLinks: const [],
            createdAt: DateTime.now(),
          ),
        );
        if (success) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('${contact.displayName} deleted'),
              backgroundColor: AppColors.deleteRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Future<void> _handleMenuAction(BuildContext context, String action, {ScannedContactModel? matchedContact}) async {
    switch (action) {
      case 'call':
        ContactActionHelper.handleCall(
          context,
          contact: matchedContact != null && matchedContact.id.isNotEmpty ? matchedContact : contact,
          contactName: contact.displayName,
        );
        break;
      case 'sms':
        ContactActionHelper.handleSms(
          context,
          contact: matchedContact != null && matchedContact.id.isNotEmpty ? matchedContact : contact,
          contactName: contact.displayName,
        );
        break;
      case 'whatsapp':
        ContactActionHelper.handleWhatsApp(
          context,
          contact: matchedContact != null && matchedContact.id.isNotEmpty ? matchedContact : contact,
          contactName: contact.displayName,
        );
        break;
      case 'email':
        ContactActionHelper.handleEmail(
          context,
          contact: matchedContact != null && matchedContact.id.isNotEmpty ? matchedContact : contact,
          contactName: contact.displayName,
        );
        break;
      case 'share':
        final buffer = StringBuffer();
        buffer.writeln('Contact: ${contact.displayName}');
        if (contact.phones.isNotEmpty) {
          buffer.writeln('Phone: ${contact.phones.map((p) => p.number).join(', ')}');
        }
        if (contact.emails.isNotEmpty) {
          buffer.writeln('Email: ${contact.emails.map((e) => e.address).join(', ')}');
        }
        if (contact.company != null && contact.company!.isNotEmpty) {
          buffer.writeln('Company: ${contact.company}');
        }
        IntentLauncher.shareContact(buffer.toString(), subject: contact.displayName);
        break;
      case 'edit':
        final tag = 'profile_${matchedContact != null && matchedContact.id.isNotEmpty ? matchedContact.id : contact.id}';
        Navigator.push(
          context,
          GeniePageRoute(
            page: ContactFormScreen(
              contactToEdit: contact,
              scannedContactToEdit: matchedContact != null && matchedContact.id.isNotEmpty ? matchedContact : null,
              heroTag: tag,
            ),
          ),
        );
        break;
      case 'group':
        ContactTileHelpers.showManageGroupsSheet(context, contact);
        break;
      case 'toggle_smart_card':
        final cvm = _getContactViewModel(context);
        final wasMember = matchedContact != null && matchedContact.id.isNotEmpty;
        await cvm.toggleSmartCardMembership(contact);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(!wasMember ? '${contact.displayName} added to Smart Card' : '${contact.displayName} removed from Smart Card'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        break;
      case 'delete':
        _showDeleteDialog(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasScope = context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null ||
        context.findAncestorWidgetOfExactType<ProviderScope>() != null;
    if (hasScope) {
      return Consumer(
        builder: (context, ref, _) => _buildPhoneTile(context, ref.watch(contactViewModelProvider)),
      );
    }
    return _buildPhoneTile(context, legacy.Provider.of<ContactViewModel>(context));
  }

  Widget _buildPhoneTile(BuildContext context, ContactViewModel contactViewModel) {
    final theme = Theme.of(context);
    final gradient = AvatarHelper.getGradient(contact.displayName);
    final hasPhone = contact.phones.isNotEmpty;
    final primaryNumber = hasPhone ? contact.phones.first.number : '';
    final hasEmail = contact.emails.isNotEmpty;
    final allPhones = contact.phones
        .map((p) => p.number.replaceAll(RegExp(r'\D'), ''))
        .where((p) => p.isNotEmpty)
        .toList();
    if (primaryNumber.isNotEmpty) {
      final pClean = primaryNumber.replaceAll(RegExp(r'\D'), '');
      if (pClean.isNotEmpty && !allPhones.contains(pClean)) {
        allPhones.add(pClean);
      }
    }

    ScannedContactModel matchedContact = ScannedContactModel(
      id: '',
      name: '',
      company: '',
      designation: '',
      phone: '',
      email: '',
      website: '',
      address: '',
      socialLinks: const [],
      createdAt: DateTime.now(),
    );

    for (final c in contactViewModel.smartCardContacts.followedBy(contactViewModel.allContacts)) {
      if (!c.isSmartCardUser && !c.isMatched && (c.matchedUserId == null || c.matchedUserId!.isEmpty)) {
        continue;
      }
      final cp = c.phone.replaceAll(RegExp(r'\D'), '');
      final cpAlts = [
        cp,
        if (c.alternativePhone != null) c.alternativePhone!.replaceAll(RegExp(r'\D'), ''),
        ...c.additionalPhones.map((p) => p.replaceAll(RegExp(r'\D'), ''))
      ].where((p) => p.isNotEmpty).toList();

      bool matchFound = false;
      for (final pClean in allPhones) {
        final p10 = pClean.length >= 10 ? pClean.substring(pClean.length - 10) : pClean;
        for (final cand in cpAlts) {
          final cand10 = cand.length >= 10 ? cand.substring(cand.length - 10) : cand;
          if (p10.length >= 7 && cand10.length >= 7 && (p10 == cand10 || pClean.endsWith(cand10) || cand.endsWith(p10))) {
            matchFound = true;
            break;
          }
        }
        if (matchFound) break;
      }
      if (matchFound) {
        matchedContact = c;
        break;
      }
    }
    final bool isSmartCardUser = matchedContact.id.isNotEmpty;
    final cleanContactId = contact.id.trim().isNotEmpty
        ? contact.id.trim()
        : (contact.primaryPhone.replaceAll(RegExp(r'\D'), '').isNotEmpty
            ? contact.primaryPhone.replaceAll(RegExp(r'\D'), '')
            : contact.displayName.trim().replaceAll(RegExp(r'\s+'), '_'));
    final dynamicHeroTag = 'contact_hero_phone_$cleanContactId';

    return Dismissible(
      key: ValueKey('swipe_call_${contact.id}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.callGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const Icon(Icons.phone_forwarded_rounded, color: Colors.white, size: 26),
            const SizedBox(width: 10),
            Text(
              hasPhone ? 'Calling $primaryNumber...' : 'No Phone Number',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        ContactActionHelper.handleCall(
          context,
          contact: isSmartCardUser ? matchedContact : contact,
          contactName: contact.displayName,
        );
        return false;
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 0,
        color: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            ScannedContactModel targetContact;
            if (isSmartCardUser && matchedContact.id.isNotEmpty) {
              targetContact = matchedContact.copyWith(
                name: (matchedContact.name.isNotEmpty && matchedContact.name.toLowerCase() != 'smartcard user')
                    ? matchedContact.name
                    : (contact.displayName.isNotEmpty ? contact.displayName : matchedContact.name),
                deviceContactId: matchedContact.deviceContactId ?? contact.id,
                email: (matchedContact.email.isNotEmpty) ? matchedContact.email : contact.primaryEmail,
                company: matchedContact.company.isNotEmpty ? matchedContact.company : (contact.company ?? ''),
                designation: matchedContact.designation.isNotEmpty ? matchedContact.designation : (contact.jobTitle ?? ''),
                isMatched: true,
              );
            } else {
              try {
                targetContact = ScannedContactModel.fromAppContact(contact);
              } catch (_) {
                final fallbackId = contact.id.isNotEmpty
                    ? contact.id
                    : 'device_${contact.displayName}_${contact.primaryPhone}'.hashCode.abs().toString();
                targetContact = ScannedContactModel(
                  id: fallbackId,
                  name: contact.displayName.isNotEmpty ? contact.displayName : 'Contact',
                  company: contact.company ?? '',
                  designation: contact.jobTitle ?? '',
                  phone: contact.primaryPhone,
                  email: contact.primaryEmail,
                  website: contact.primaryWebsite,
                  address: contact.primaryAddress,
                  socialLinks: const [],
                  createdAt: DateTime.now(),
                );
              }
            }

            if (contact.phones.length > 1) {
              final alts = contact.phones.skip(1).map((p) => p.number.trim()).where((n) => n.isNotEmpty).toList();
              if (alts.isNotEmpty) {
                final existing = targetContact.alternativePhone;
                final combined = {
                  if (existing != null && existing.trim().isNotEmpty) existing.trim(),
                  ...alts,
                }.join(', ');
                targetContact = targetContact.copyWith(alternativePhone: combined);
              }
            }

            Navigator.push(
              context,
              GeniePageRoute(
                page: ContactDetailScreen(
                  contact: targetContact,
                  heroTag: dynamicHeroTag,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // 1. Avatar (Truecaller-style ring + micro badge + original Google/Phone photo priority)
                FutureBuilder<Uint8List?>(
                  initialData: ContactPhotoService.getCachedPhoto(
                    contactId: contact.id,
                    phone: contact.primaryPhone,
                  ) ?? contact.photo,
                  future: (contact.photo != null && contact.photo!.isNotEmpty)
                      ? Future.value(contact.photo)
                      : ContactPhotoService.getBestPhoto(
                          contactId: contact.id,
                          phone: contact.primaryPhone,
                        ),
                  builder: (context, snapshot) {
                    final effectivePhotoBytes = snapshot.data ?? contact.photo;
                    return AppProfileAvatar(
                      id: isSmartCardUser && matchedContact.id.isNotEmpty ? matchedContact.id : contact.id,
                      name: contact.displayName,
                      avatarUrl: (effectivePhotoBytes == null || effectivePhotoBytes.isEmpty)
                          ? ContactPhotoResolver.resolveScannedPhotoSource(matchedContact)
                          : null,
                      avatarBytes: effectivePhotoBytes,
                      size: 48,
                      heroTag: dynamicHeroTag,
                      enableHero: enableHero,
                      customKey: 'contact_avatar_${contact.id}',
                      gradientColors: gradient,
                      isSmartCardUser: isSmartCardUser,
                      isBusiness: isSmartCardUser || (matchedContact.company.trim().isNotEmpty) || (contact.company != null && contact.company!.trim().isNotEmpty),
                      onTap: () {
                        var targetContact = (isSmartCardUser && matchedContact.id.isNotEmpty)
                            ? matchedContact.copyWith(
                                name: (matchedContact.name.isNotEmpty && matchedContact.name.toLowerCase() != 'smartcard user')
                                    ? matchedContact.name
                                    : (contact.displayName.isNotEmpty ? contact.displayName : matchedContact.name),
                                deviceContactId: matchedContact.deviceContactId ?? contact.id,
                                email: (matchedContact.email.isNotEmpty) ? matchedContact.email : contact.primaryEmail,
                                company: matchedContact.company.isNotEmpty ? matchedContact.company : (contact.company ?? ''),
                                designation: matchedContact.designation.isNotEmpty ? matchedContact.designation : (contact.jobTitle ?? ''),
                                isMatched: true,
                              )
                            : ScannedContactModel.fromAppContact(contact);
                        if (contact.phones.length > 1) {
                          final alts = contact.phones.skip(1).map((p) => p.number.trim()).where((n) => n.isNotEmpty).toList();
                          if (alts.isNotEmpty) {
                            final existing = targetContact.alternativePhone;
                            final combined = {
                              if (existing != null && existing.trim().isNotEmpty) existing.trim(),
                              ...alts,
                            }.join(', ');
                            targetContact = targetContact.copyWith(alternativePhone: combined);
                          }
                        }
                        Navigator.push(
                          context,
                          GeniePageRoute(
                            page: ContactDetailScreen(
                              contact: targetContact,
                              heroTag: dynamicHeroTag,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(width: 14),

                // 2. Full Name & Mobile Number (Clean, spacious display)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              contact.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isSmartCardUser) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.primaryRed,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        primaryNumber.isNotEmpty ? primaryNumber : 'No phone number',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),

                // Favorite Star Icon Button
                IconButton(
                  icon: Icon(
                    contact.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: contact.isFavorite ? AppColors.favoriteGold : Colors.grey[400],
                    size: 22,
                  ),
                  tooltip: contact.isFavorite ? 'Remove Favorite' : 'Mark Favorite',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _getContactProvider(context).toggleFavorite(contact);
                    if (isSmartCardUser && matchedContact.id.isNotEmpty) {
                      _getContactViewModel(context).toggleFavorite(matchedContact.id);
                    }
                  },
                ),

                // 4. Three-Dots Menu Dropdown Button
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tooltip: 'Contact Options',
                  onSelected: (action) => _handleMenuAction(
                    context,
                    action,
                    matchedContact: isSmartCardUser ? matchedContact : null,
                  ),
                  itemBuilder: (ctx) => ContactTileHelpers.buildContactMenuItems(
                    hasPhone: hasPhone,
                    hasEmail: hasEmail,
                    showSmartCardToggle: true,
                    isSmartCardUser: isSmartCardUser,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

