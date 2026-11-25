import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:google_fonts/google_fonts.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/core/utils/intent_launcher.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/app_contact.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_notifier.dart';
import 'package:smartcard_flutter/features/groups_screen/presentation/viewmodel/group_notifier.dart';
import 'package:smartcard_flutter/core/widgets/contact_tile.dart';
import 'package:smartcard_flutter/core/widgets/empty_state_widget.dart';
import 'package:smartcard_flutter/core/widgets/master_app_bar.dart';
import 'package:smartcard_flutter/core/widgets/global_bottom_nav.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final fc.Group group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  void _shareGroupContacts(BuildContext context, List<AppContact> members) {
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No contacts in "${widget.group.name}" to share.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('📋 ${widget.group.name} (${members.length} Contacts)');
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
      subject: '${widget.group.name} Contact List',
    );
  }

  void _showAddMembersModal(BuildContext context) {
    final contactNotifier = ref.read(contactNotifierProvider.notifier);
    final groupNotifier = ref.read(groupNotifierProvider.notifier);
    final groupId = widget.group.id;
    if (groupId == null) return;

    // Contacts not currently in this group
    final currentMemberIds = groupNotifier
        .getMembersForGroup(groupId, contactNotifier.contacts)
        .map((c) => c.id)
        .toSet();

    final eligibleContacts = contactNotifier.contacts
        .where((c) => !currentMemberIds.contains(c.id))
        .toList();

    final Set<String> selectedContactIds = {};
    String search = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = eligibleContacts.where((c) {
            if (search.isEmpty) return true;
            return c.displayName.toLowerCase().contains(search.toLowerCase()) ||
                c.primaryPhone.contains(search);
          }).toList();

          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
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
                        Expanded(
                          child: Text(
                            'Add to "${widget.group.name}"',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${selectedContactIds.length} selected',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search contacts to add...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  setModalState(() => search = '');
                                  FocusScope.of(context).unfocus();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.08),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) => setModalState(() => search = val),
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              eligibleContacts.isEmpty
                                  ? 'All phone contacts are already in this group!'
                                  : 'No matching contacts found',
                              style: GoogleFonts.inter(color: Colors.grey[600]),
                            ),
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is ScrollStartNotification ||
                                  notification is ScrollUpdateNotification) {
                                FocusScope.of(context).unfocus();
                              }
                              return false;
                            },
                            child: ListView.builder(
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              itemCount: filtered.length,
                              itemBuilder: (ctx, index) {
                                final contact = filtered[index];
                                final isSelected = selectedContactIds.contains(contact.id);

                                return CheckboxListTile(
                                  value: isSelected,
                                  activeColor: AppColors.primary,
                                  title: Text(
                                    contact.displayName,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                                  ),
                                  subtitle: contact.primaryPhone.isNotEmpty
                                      ? Text(contact.primaryPhone, style: GoogleFonts.inter(fontSize: 13))
                                      : null,
                                  secondary: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                    child: Text(
                                      contact.initials,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  onChanged: (val) {
                                    FocusScope.of(context).unfocus();
                                    setModalState(() {
                                      if (val == true) {
                                        selectedContactIds.add(contact.id);
                                      } else {
                                        selectedContactIds.remove(contact.id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                  ),
                  SafeArea(
                    top: false,
                    bottom: true,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: selectedContactIds.isEmpty
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  Navigator.of(ctx).pop();
                                  final success = await groupNotifier.addContactsToGroup(
                                    groupId: groupId,
                                    contactIds: selectedContactIds.toList(),
                                  );
                                  if (success) {
                                    await contactNotifier.syncWithDevice(silent: true);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Added ${selectedContactIds.length} contact(s) to "${widget.group.name}"'),
                                        backgroundColor: AppColors.success,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            'Add Selected (${selectedContactIds.length})',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
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
      ),
    );
  }

  void _confirmRemoveMember(BuildContext context, AppContact contact) {
    final groupId = widget.group.id;
    if (groupId == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove from Group?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remove "${contact.displayName}" from "${widget.group.name}"?',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This contact will NOT be deleted from your phone.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.blue[900]),
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
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();
              final groupNotifier = ref.read(groupNotifierProvider.notifier);
              final contactNotifier = ref.read(contactNotifierProvider.notifier);

              final success = await groupNotifier.removeContactsFromGroup(
                groupId: groupId,
                contactIds: [contact.id],
              );
              if (success) {
                await contactNotifier.syncWithDevice(silent: true);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Removed "${contact.displayName}" from group.'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deleteRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(contactNotifierProvider);
    ref.watch(groupNotifierProvider);
    final contactNotifier = ref.read(contactNotifierProvider.notifier);
    final groupNotifier = ref.read(groupNotifierProvider.notifier);
    final groupId = widget.group.id ?? '';

    // Members in this group via unified provider
    final members = groupNotifier.getMembersForGroup(groupId, contactNotifier.contacts);

    final filteredMembers = members.where((c) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      return c.displayName.toLowerCase().contains(q) ||
          c.primaryPhone.contains(q) ||
          c.primaryEmail.toLowerCase().contains(q);
    }).toList();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: MasterAppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.group.name,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              Text(
                '${members.length} members',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          showBackButton: true,
          extraActions: [
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              tooltip: 'Share Group Contacts',
              onPressed: () => _shareGroupContacts(context, members),
            ),
            IconButton(
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              tooltip: 'Add Members',
              onPressed: () => _showAddMembersModal(context),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search within ${widget.group.name}...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Expanded(
              child: filteredMembers.isEmpty
                  ? EmptyStateWidget(
                      type: EmptyStateType.noContacts,
                      customTitle: members.isEmpty ? 'No Members in this Group' : 'No Matching Contacts',
                      customSubtitle: members.isEmpty
                          ? 'Tap "+ Add Members" to add phone contacts into "${widget.group.name}".'
                          : 'Try searching with another name or phone number.',
                      onAction: members.isEmpty ? () => _showAddMembersModal(context) : null,
                      actionText: 'Add Members',
                    )
                  : ListView.builder(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                      itemCount: filteredMembers.length,
                      itemBuilder: (ctx, index) {
                        final contact = filteredMembers[index];
                        return Dismissible(
                          key: ValueKey('group_member_${contact.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: AppColors.deleteRed,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerRight,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Remove',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.person_remove_rounded, color: Colors.white),
                              ],
                            ),
                          ),
                          confirmDismiss: (dir) async {
                            _confirmRemoveMember(context, contact);
                            return false;
                          },
                          child: ContactTile(contact: contact),
                        );
                      },
                    ),
            ),
          ],
        ),
        bottomNavigationBar: const GlobalBottomNav(),
      ),
    );
  }
}
