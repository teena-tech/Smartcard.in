import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/avatar_helper.dart';
import '../../core/utils/contact_action_helper.dart';
import '../../core/utils/intent_launcher.dart';
import '../../models/app_contact.dart';
import '../../models/scanned_contact_model.dart';
import '../../providers/contact_provider.dart';
import '../../providers/group_provider.dart';
import '../../viewmodels/contact_viewmodel.dart';
import 'genie_hero_route.dart';
import 'app_profile_avatar.dart';
import '../../core/services/contact_photo_resolver.dart';
import '../../core/services/contact_photo_service.dart';
import '../screens/contact_detail_screen.dart';
import '../screens/contact_form_screen.dart';

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
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Delete "${contact.displayName}" from your phone contacts?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey[600])),
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
              final cp = context.read<ContactProvider>();
              final cvm = context.read<ContactViewModel>();
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
            child: const Text('Delete'),
          ),
        ],
      ),
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
        _showManageGroupsModal(context, contact);
        break;
      case 'toggle_smart_card':
        final cvm = context.read<ContactViewModel>();
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

  void _showManageGroupsModal(BuildContext context, AppContact appContact) {
    final groupProvider = context.read<GroupProvider>();
    final contactProvider = context.read<ContactProvider>();

    groupProvider.loadGroups();

    final allGroups = groupProvider.groups;
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
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${currentSelectedGroupIds.length} selected',
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
                            'No groups available',
                            style: GoogleFonts.inter(color: isDark ? Colors.white54 : Colors.grey[600]),
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
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                '${group.contactCount ?? 0} members',
                                style: GoogleFonts.inter(
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
                        child: Text('Done', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = AvatarHelper.getGradient(contact.displayName);
    final hasPhone = contact.phones.isNotEmpty;
    final primaryNumber = hasPhone ? contact.phones.first.number : '';
    final hasEmail = contact.emails.isNotEmpty;

    final contactViewModel = context.watch<ContactViewModel>();
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
                    context.read<ContactProvider>().toggleFavorite(contact);
                    if (isSmartCardUser && matchedContact.id.isNotEmpty) {
                      context.read<ContactViewModel>().toggleFavorite(matchedContact.id);
                    }
                  },
                ),

                // 4. Three-Dots Menu Dropdown Button
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tooltip: 'Contact Options',
                  onSelected: (action) => _handleMenuAction(context, action, matchedContact: isSmartCardUser ? matchedContact : null),
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
                    PopupMenuItem(
                      value: 'toggle_smart_card',
                      child: Row(
                        children: [
                          Icon(
                            isSmartCardUser ? Icons.person_remove_rounded : Icons.verified_user_rounded,
                            color: isSmartCardUser ? AppColors.deleteRed : AppColors.primaryRed,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(isSmartCardUser ? 'Remove from Smart Card' : 'Add to Smart Card'),
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
