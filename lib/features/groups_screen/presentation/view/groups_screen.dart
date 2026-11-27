import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:google_fonts/google_fonts.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/core/utils/intent_launcher.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/app_contact.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_notifier.dart';
import 'package:smartcard_flutter/features/groups_screen/presentation/viewmodel/group_notifier.dart';
import 'package:smartcard_flutter/core/widgets/empty_state_widget.dart';
import 'package:smartcard_flutter/core/widgets/master_app_bar.dart';
import 'package:smartcard_flutter/core/widgets/global_bottom_nav.dart';
import 'package:smartcard_flutter/features/group_detail_screen/presentation/view/group_detail_screen.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/viewmodel/dashboard_viewmodel.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(groupNotifierProvider.notifier).loadGroups();
    });
  }

  void _showCreateGroupDialog(BuildContext context) {
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.group_add_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Text(
              'Create New Group',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Group Name',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Family, Office, Friends, Work',
                  prefixIcon: const Icon(Icons.label_rounded, color: AppColors.primary),
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a group name';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final name = textController.text.trim();
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(ctx).pop();

                final groupNotifier = ref.read(groupNotifierProvider.notifier);
                final created = await groupNotifier.createGroup(name);
                if (created != null) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Group "$name" created successfully!'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Create', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showRenameGroupDialog(BuildContext context, fc.Group group) {
    final textController = TextEditingController(text: group.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Rename Group',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: textController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Group Name',
              prefixIcon: const Icon(Icons.edit_rounded, color: AppColors.primary),
              filled: true,
              fillColor: Colors.grey.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter a group name';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate() && group.id != null) {
                final newName = textController.text.trim();
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(ctx).pop();

                final groupNotifier = ref.read(groupNotifierProvider.notifier);
                final success = await groupNotifier.renameGroup(group.id!, newName);
                if (success) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Group renamed to "$newName"'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showDeleteGroupDialog(BuildContext context, fc.Group group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: AppColors.deleteRed, size: 28),
            const SizedBox(width: 10),
            Text(
              'Delete Group?',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${group.name}"?',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Contacts will NOT be deleted from your phone.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.blueGrey[800], fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              if (group.id != null) {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(ctx).pop();
                final groupNotifier = ref.read(groupNotifierProvider.notifier);
                final success = await groupNotifier.deleteGroup(group.id!);
                if (success) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Group "${group.name}" deleted.'),
                      backgroundColor: AppColors.deleteRed,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deleteRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete Group', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  IconData _getGroupIcon(String groupName) {
    final lower = groupName.toLowerCase();
    if (lower.contains('family')) return Icons.family_restroom_rounded;
    if (lower.contains('work') || lower.contains('office') || lower.contains('job')) return Icons.business_center_rounded;
    if (lower.contains('friend')) return Icons.people_alt_rounded;
    if (lower.contains('customer') || lower.contains('client')) return Icons.handshake_rounded;
    if (lower.contains('school') || lower.contains('college')) return Icons.school_rounded;
    if (lower.contains('emergency')) return Icons.emergency_rounded;
    return Icons.folder_shared_rounded;
  }

  Color _getGroupColor(int index) {
    final colors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF10B981), // Green
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFF97316), // Orange
    ];
    return colors[index % colors.length];
  }

  void _shareGroupContacts(BuildContext context, fc.Group group, List<AppContact> allContacts) {
    final groupNotifier = ref.read(groupNotifierProvider.notifier);
    final members = groupNotifier.getMembersForGroup(group.id ?? '', allContacts);

    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No contacts in "${group.name}" to share.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('📋 ${group.name} (${members.length} Contacts)');
    buffer.writeln('--------------------------------');
    for (int i = 0; i < members.length; i++) {
      final m = members[i];
      buffer.writeln('${i + 1}. ${m.displayName}');
      if (m.phones.isNotEmpty) {
        buffer.writeln('   📞 ${m.phones.map((p) => p.number).join(', ')}');
      }
      if (m.emails.isNotEmpty) {
        buffer.writeln('   ✉️ ${m.emails.map((e) => e.address).join(', ')}');
      }
      buffer.writeln('');
    }

    IntentLauncher.shareContact(
      buffer.toString().trim(),
      subject: '${group.name} Contact List',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(groupNotifierProvider);
    ref.watch(contactNotifierProvider);
    final groupNotifier = ref.read(groupNotifierProvider.notifier);
    final contactNotifier = ref.read(contactNotifierProvider.notifier);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: MasterAppBar(
          titleText: 'Contact Groups',
          showBackButton: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            tooltip: 'Back to Contacts',
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                ref.read(dashboardViewModelProvider.notifier).setIndex(4);
              }
            },
          ),
          extraActions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Refresh Groups',
              onPressed: () => groupNotifier.loadGroups(),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: groupNotifier.isLoading
            ? const Center(child: CircularProgressIndicator())
            : groupNotifier.groups.isEmpty
                ? EmptyStateWidget(
                    type: EmptyStateType.noContacts,
                    customTitle: 'No Contact Groups',
                    customSubtitle: 'Create custom groups like Family, Office, Friends to organize your contacts.',
                    onAction: () => _showCreateGroupDialog(context),
                    actionText: 'Create First Group',
                  )
                : RefreshIndicator(
                    onRefresh: () => groupNotifier.loadGroups(),
                    child: ListView.builder(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: groupNotifier.groups.length,
                      itemBuilder: (context, index) {
                        final group = groupNotifier.groups[index];
                        final memberCount = groupNotifier.getMemberCount(group.id ?? '', contactNotifier.contacts);
                        final groupColor = _getGroupColor(index);
                        final icon = _getGroupIcon(group.name);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: theme.brightness == Brightness.dark
                                   ? Colors.grey.withValues(alpha: 0.2)
                                  : Colors.grey.withValues(alpha: 0.15),
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GroupDetailScreen(group: group),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: groupColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(icon, color: groupColor, size: 26),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          group.name,
                                          style: GoogleFonts.outfit(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '$memberCount contacts',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: groupColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$memberCount',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: groupColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    onSelected: (val) {
                                      if (val == 'share') {
                                        _shareGroupContacts(context, group, contactNotifier.contacts);
                                      } else if (val == 'rename') {
                                        _showRenameGroupDialog(context, group);
                                      } else if (val == 'delete') {
                                        _showDeleteGroupDialog(context, group);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'share',
                                        child: Row(
                                          children: [
                                            Icon(Icons.share_rounded, size: 18, color: AppColors.secondaryRed),
                                            SizedBox(width: 10),
                                            Text('Share Group'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'rename',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                                            SizedBox(width: 10),
                                            Text('Rename Group'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_forever_rounded, size: 18, color: AppColors.deleteRed),
                                            SizedBox(width: 10),
                                            Text('Delete Group', style: TextStyle(color: AppColors.deleteRed)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: (index * 40).ms).slideY(begin: 0.05, end: 0);
                      },
                    ),
                  ),
            ),
            if (!groupNotifier.isLoading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Center(
                  child: Material(
                    color: Colors.white,
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => _showCreateGroupDialog(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Add Group',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: const GlobalBottomNav(),
      ),
    );
  }
}
