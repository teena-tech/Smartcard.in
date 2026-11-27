import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/core/utils/avatar_helper.dart';
import 'package:smartcard_flutter/core/utils/contact_action_helper.dart';
import 'package:smartcard_flutter/core/utils/intent_launcher.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/app_contact.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_notifier.dart';
import 'package:smartcard_flutter/features/groups_screen/presentation/viewmodel/group_notifier.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_viewmodel.dart';
import 'package:smartcard_flutter/core/widgets/genie_hero_route.dart';
import 'package:smartcard_flutter/core/widgets/app_profile_avatar.dart';
import 'package:smartcard_flutter/core/services/contact_photo_resolver.dart';
import 'package:smartcard_flutter/core/services/contact_photo_service.dart';
import 'package:smartcard_flutter/core/utils/phone_normalizer.dart';
import 'package:smartcard_flutter/features/contact_detail_screen/presentation/view/contact_detail_screen.dart';
import 'package:smartcard_flutter/features/contact_form_screen/presentation/view/contact_form_screen.dart';

class ContactListTile extends ConsumerWidget {
  final ScannedContactModel contact;
  final VoidCallback onFavoriteToggle;
  final bool enableHero;

  const ContactListTile({
    super.key,
    required this.contact,
    required this.onFavoriteToggle,
    this.enableHero = true,
  });

  void _confirmDelete(BuildContext context, WidgetRef ref, String displayName, AppContact? appContact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: AppColors.deleteRed),
            const SizedBox(width: 10),
            Text(
              'Delete Contact?',
              style: AppFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Delete "$displayName" from your contacts?',
          style: AppFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppFonts.poppins(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deleteRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final cvm = ref.read(contactViewModelProvider.notifier);
              final cp = ref.read(contactNotifierProvider.notifier);
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
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
          final cardLink = contact.cardUrl!.startsWith('http')
              ? contact.cardUrl!
              : 'https://thesmartcards.in/c/${contact.cardUrl!}';
          buffer.writeln('Digital Smart Card: $cardLink');
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
        _showManageGroupsModal(context, ref, appContact ?? _createAppContactFallback(displayName, primaryNumber, primaryEmail, company));
        break;
      case 'delete':
        _confirmDelete(context, ref, displayName, appContact);
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

  void _showManageGroupsModal(BuildContext context, WidgetRef ref, AppContact appContact) {
    final groupNotifier = ref.read(groupNotifierProvider.notifier);
    final contactNotifier = ref.read(contactNotifierProvider.notifier);

    groupNotifier.loadGroups();

    final allGroups = groupNotifier.groups;
    final Set<String> currentSelectedGroupIds = Set.from(appContact.groupIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E3F) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add to Group',
                        style: AppFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${currentSelectedGroupIds.length} selected',
                        style: AppFonts.poppins(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: allGroups.isEmpty
                      ? Center(
                          child: Text(
                            'No groups available',
                            style: AppFonts.poppins(color: isDark ? Colors.white54 : Colors.grey[600]),
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
                              title: Text(
                                group.name,
                                style: AppFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                '${group.contactCount ?? 0} members',
                                style: AppFonts.poppins(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.grey[600],
                                ),
                              ),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.of(ctx).pop();
                          final updated = await contactNotifier.updateContact(
                            appContact,
                            newGroupIds: currentSelectedGroupIds.toList(),
                            previousGroupIds: appContact.groupIds,
                          );
                          if (updated != null) {
                            await groupNotifier.loadGroups();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Groups updated for ${appContact.displayName}'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Text('Done', style: AppFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    ref.watch(contactNotifierProvider);
    final contactNotifier = ref.read(contactNotifierProvider.notifier);

    final appContact = contactNotifier.findContactByDeviceContactIdOrDetails(
          contact.deviceContactId,
          contact.phone,
          contact.email,
          company: contact.company,
          name: contact.name,
        ) ??
        contactNotifier.findContactById(contact.id);

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
              style: AppFonts.poppins(
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
                              style: AppFonts.poppins(
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
                        style: AppFonts.poppins(
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
                                style: AppFonts.poppins(
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
                          style: AppFonts.poppins(
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
                                    .withOpacity(0.18),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: (contact.corporateGroup == 'Client'
                                          ? const Color(0xFF10B981)
                                          : contact.corporateGroup == 'Partner'
                                              ? const Color(0xFF3B82F6)
                                              : contact.corporateGroup == 'Vendor'
                                                  ? const Color(0xFFF59E0B)
                                                  : const Color(0xFF0284C7))
                                      .withOpacity(0.5),
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
                                  style: AppFonts.poppins(
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
                      ref.read(contactNotifierProvider.notifier).toggleFavorite(appContact);
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
                    ref,
                    action,
                    displayName: displayName,
                    primaryNumber: primaryNumber,
                    primaryEmail: primaryEmail,
                    company: company,
                    appContact: appContact,
                  ),
                  itemBuilder: (ctx) => [
                    if (hasPhone) ...[
                      const PopupMenuItem(
                        value: 'call',
                        child: Row(
                          children: [
                            Icon(Icons.phone_rounded, color: AppColors.callGreen, size: 20),
                            SizedBox(width: 12),
                            Text('Call'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'sms',
                        child: Row(
                          children: [
                            Icon(Icons.message_rounded, color: AppColors.smsBlue, size: 20),
                            SizedBox(width: 12),
                            Text('Message'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'whatsapp',
                        child: Row(
                          children: [
                            Icon(Icons.chat_bubble_rounded, color: AppColors.whatsappGreen, size: 20),
                            SizedBox(width: 12),
                            Text('WhatsApp'),
                          ],
                        ),
                      ),
                    ],
                    if (hasEmail)
                      const PopupMenuItem(
                        value: 'email',
                        child: Row(
                          children: [
                            Icon(Icons.email_rounded, color: AppColors.emailOrange, size: 20),
                            SizedBox(width: 12),
                            Text('Email'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_rounded, color: AppColors.secondaryRed, size: 20),
                          SizedBox(width: 12),
                          Text('Share Contact'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'group',
                      child: Row(
                        children: [
                          Icon(Icons.group_add_rounded, color: AppColors.primary, size: 20),
                          SizedBox(width: 12),
                          Text('Add to Group'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
                          SizedBox(width: 12),
                          Text('Edit Contact'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: AppColors.deleteRed, size: 20),
                          SizedBox(width: 12),
                          Text('Delete Contact', style: TextStyle(color: AppColors.deleteRed)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
