import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as legacy;
import '../../core/providers/app_riverpod_providers.dart';

import '../../core/constants/app_colors.dart';
import '../../models/app_contact.dart';
import '../../providers/contact_provider.dart';
import '../../providers/group_provider.dart';

/// Shared dialogs, bottom sheets, and popup menu builders used by both
/// [ContactListTile] and [ContactTile].
class ContactTileHelpers {
  const ContactTileHelpers._();

  static void showDeleteConfirmation(
    BuildContext context, {
    required String content,
    required Future<void> Function() onConfirm,
  }) {
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
          content,
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
              await onConfirm();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  static void showManageGroupsSheet(BuildContext context, AppContact appContact) {
    final hasScope = context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null ||
        context.findAncestorWidgetOfExactType<ProviderScope>() != null;
    final groupProvider = hasScope
        ? ProviderScope.containerOf(context, listen: false).read(groupProviderRiverpod)
        : legacy.Provider.of<GroupProvider>(context, listen: false);
    final contactProvider = hasScope
        ? ProviderScope.containerOf(context, listen: false).read(contactProviderRiverpod)
        : legacy.Provider.of<ContactProvider>(context, listen: false);

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
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
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
                            style: GoogleFonts.inter(
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
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
                                child: const Icon(
                                  Icons.folder_shared_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                        child: Text(
                          'Done',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
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

  static List<PopupMenuEntry<String>> buildContactMenuItems({
    required bool hasPhone,
    required bool hasEmail,
    bool showSmartCardToggle = false,
    bool isSmartCardUser = false,
  }) {
    return [
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
      if (showSmartCardToggle)
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
    ];
  }
}

