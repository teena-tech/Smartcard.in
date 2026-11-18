import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'contact_detail_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/avatar_helper.dart';
import '../../core/utils/contact_action_helper.dart';
import '../../core/utils/intent_launcher.dart';
import '../../models/app_contact.dart';
import '../../models/scanned_contact_model.dart';
import '../../providers/contact_provider.dart';
import '../../providers/group_provider.dart';
import '../../viewmodels/contact_viewmodel.dart';
import '../widgets/quick_action_bar.dart';
import '../widgets/global_bottom_nav.dart';
import 'contact_form_screen.dart';

class DeviceContactDetailScreen extends StatelessWidget {
  final String contactId;

  const DeviceContactDetailScreen({super.key, required this.contactId});

  void _confirmDelete(BuildContext context, AppContact contact) {
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${contact.displayName}"?',
              style: GoogleFonts.inter(fontSize: 15),
            ),
            const SizedBox(height: 10),
            Text(
              'This will permanently remove the contact from your phone\'s Contacts Provider.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
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
              final success = await context.read<ContactProvider>().deleteContact(contact);
              await context.read<ContactViewModel>().deleteContact(
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
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${contact.displayName} deleted from phone'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.deleteRed,
                    ),
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete contact. It may be read-only.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _showFullImageDialog(BuildContext context, AppContact contact) async {
    String? imageSource;
    if (contact.photo != null && contact.photo!.isNotEmpty) {
      imageSource = 'data:image/jpeg;base64,${base64Encode(contact.photo!)}';
    }

    try {
      if (contact.id.isNotEmpty) {
        final devC = await fc.FlutterContacts.get(contact.id, properties: fc.ContactProperties.all);
        final fullBytes = devC?.photo?.fullSize ?? devC?.photo?.thumbnail;
        if (fullBytes != null && fullBytes.isNotEmpty) {
          imageSource = 'data:image/jpeg;base64,${base64Encode(fullBytes)}';
        }
      }
    } catch (_) {}

    if (context.mounted) {
      ContactDetailScreen.showFullImageDialog(
        context,
        imageSource,
        contact.displayName,
        contact.initials,
      );
    }
  }

  void _showManageGroupsModal(BuildContext context, AppContact contact) {
    final groupProvider = context.read<GroupProvider>();
    final contactProvider = context.read<ContactProvider>();

    final allGroups = groupProvider.groups;
    final Set<String> currentSelectedGroupIds = Set.from(contact.groupIds);

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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.of(ctx).pop();
                      final updated = await contactProvider.updateContact(
                        contact,
                        newGroupIds: currentSelectedGroupIds.toList(),
                        previousGroupIds: contact.groupIds,
                      );
                      if (updated != null) {
                        await groupProvider.loadGroups();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Groups updated for ${contact.displayName}'),
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
                    child: Text('Save Group Assignments', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ContactProvider>();
    final contact = provider.findContactById(contactId);

    if (contact == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contact Details')),
        body: const Center(child: Text('Contact not found')),
      );
    }

    final gradient = AvatarHelper.getGradient(contact.displayName);

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

          // Scrollable Details
          Positioned.fill(
            child: CustomScrollView(
              slivers: [
          // App Bar with Header (Curved down bottom corners)
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            stretch: true,
            backgroundColor: gradient[0],
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    contact.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: contact.isFavorite ? AppColors.favoriteGold : Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () => provider.toggleFavorite(contact),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContactFormScreen(contactToEdit: contact),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                ),
                onPressed: () => _confirmDelete(context, contact),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(36),
                    bottomRight: Radius.circular(36),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      GestureDetector(
                        onTap: () => _showFullImageDialog(context, contact),
                        child: Hero(
                          tag: 'avatar_${contact.id}',
                          placeholderBuilder: (context, heroSize, child) => child,
                          child: Material(
                            color: Colors.transparent,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.2),
                                border: Border.all(color: Colors.white, width: 3),
                                image: contact.photo != null
                                    ? DecorationImage(
                                        image: MemoryImage(contact.photo!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: contact.photo == null
                                  ? Text(
                                      contact.initials,
                                      style: GoogleFonts.outfit(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          contact.displayName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (contact.company != null && contact.company!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            contact.jobTitle != null && contact.jobTitle!.isNotEmpty
                                ? '${contact.jobTitle} • ${contact.company}'
                                : contact.company!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Body Details directly over login.png background
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Action Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: QuickActionBar(contact: contact),
                  ),

                  const SizedBox(height: 20),

                  // Slidable Groups Strip
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        ...contact.groupNames.map((gName) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showManageGroupsModal(context, contact),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.label_rounded, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        gName,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        // Add to Group chip at last
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showManageGroupsModal(context, contact),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.withValues(alpha: 0.15)
                                    : Colors.grey.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded, size: 15, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Add to Group',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Phone Numbers Section
                  _buildSectionCard(
                    context,
                    title: 'Phone Numbers',
                    icon: Icons.phone_rounded,
                    children: () {
                      if (contact.phones.isEmpty) {
                        return [
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No phone number added', style: TextStyle(color: Colors.grey)),
                          ),
                        ];
                      }

                      final bool hasExplicitPrimary = contact.phones.any((p) => p.isPrimary);
                      final primaryPhones =
                          hasExplicitPrimary ? contact.phones.where((p) => p.isPrimary).toList() : <ContactPhone>[];
                      final altPhones =
                          hasExplicitPrimary ? contact.phones.where((p) => !p.isPrimary).toList() : contact.phones;

                      if (hasExplicitPrimary) {
                        return [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Text(
                              'Primary:',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryRed,
                              ),
                            ),
                          ),
                          ...primaryPhones.asMap().entries.map((e) => _buildDevicePhoneItem(context, e.value, showDivider: e.key > 0)),
                          if (altPhones.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10.0),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: Colors.grey.withValues(alpha: 0.15),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Text(
                                'Alternative Numbers:',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            ...altPhones.asMap().entries.map((e) => _buildDevicePhoneItem(context, e.value, showDivider: e.key > 0)),
                          ],
                        ];
                      }

                      return contact.phones
                          .asMap()
                          .entries
                          .map((e) => _buildDevicePhoneItem(context, e.value, showDivider: e.key > 0))
                          .toList();
                    }(),
                  ),

                  const SizedBox(height: 16),

                  // Emails Section
                  if (contact.emails.isNotEmpty) ...[
                    _buildSectionCard(
                      context,
                      title: 'Email Addresses',
                      icon: Icons.email_rounded,
                      children: contact.emails.map((email) {
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.emailOrange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.email_outlined, color: AppColors.emailOrange, size: 20),
                            ),
                            title: Text(
                              email.address,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            subtitle: Text(
                              email.label,
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.send_rounded, color: AppColors.emailOrange, size: 20),
                              tooltip: 'Send Email',
                              onPressed: () => IntentLauncher.sendEmail(context, email.address),
                            ),
                            onTap: () => IntentLauncher.sendEmail(context, email.address),
                            onLongPress: () => _copyToClipboard(context, email.address, 'Email address'),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Websites / Links Section
                  if (contact.websites.isNotEmpty) ...[
                    _buildSectionCard(
                      context,
                      title: 'Websites & Links',
                      icon: Icons.language_rounded,
                      children: contact.websites.map((website) {
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.language_rounded, color: AppColors.primary, size: 20),
                            ),
                            title: Text(
                              website.url,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            subtitle: Text(
                              website.label,
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.open_in_browser_rounded, color: AppColors.primary, size: 20),
                              tooltip: 'Open Website',
                              onPressed: () => IntentLauncher.openWebsite(context, website.url),
                            ),
                            onTap: () => IntentLauncher.openWebsite(context, website.url),
                            onLongPress: () => _copyToClipboard(context, website.url, 'Website URL'),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Addresses Section
                  if (contact.addresses.isNotEmpty) ...[
                    Builder(
                      builder: (context) {
                        final uniqueAddrs = <ContactAddress>[];
                        final seen = <String>{};
                        for (final a in contact.addresses) {
                          final clean = ContactAddress.sanitizeAddressString(a.address);
                          if (clean.isNotEmpty && seen.add(clean.toLowerCase())) {
                            uniqueAddrs.add(ContactAddress(
                              address: clean,
                              label: a.label,
                              street: a.street,
                              city: a.city,
                              postalCode: a.postalCode,
                              country: a.country,
                            ));
                          }
                        }
                        if (uniqueAddrs.isEmpty) return const SizedBox.shrink();

                        return _buildSectionCard(
                          context,
                          title: 'Addresses',
                          icon: Icons.location_on_rounded,
                          children: uniqueAddrs.map((addr) {
                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.location_on_outlined, color: AppColors.success, size: 20),
                                ),
                                title: Text(
                                  addr.address,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                                subtitle: Text(
                                  addr.label,
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.directions_rounded, color: AppColors.success, size: 20),
                                  tooltip: 'Open in Maps',
                                  onPressed: () => IntentLauncher.openMap(context, addr.address),
                                ),
                                onTap: () => IntentLauncher.openMap(context, addr.address),
                                onLongPress: () => _copyToClipboard(context, addr.address, 'Address'),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Notes Section
                  if (contact.notes != null && contact.notes!.trim().isNotEmpty) ...[
                    _buildSectionCard(
                      context,
                      title: 'Notes',
                      icon: Icons.notes_rounded,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            contact.notes!,
                            style: GoogleFonts.inter(fontSize: 14, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
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

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    Widget? action,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const Spacer(),
              ?action,
            ],
          ),
          const SizedBox(height: 6),
          const Divider(),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDevicePhoneItem(BuildContext context, ContactPhone phone, {bool showDivider = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDivider)
          Divider(
            height: 20,
            thickness: 1,
            color: Colors.grey.withValues(alpha: 0.12),
          ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => IntentLauncher.makePhoneCall(context, phone.number),
            onLongPress: () => _copyToClipboard(context, phone.number, 'Phone number'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line 1: Phone Icon + Number in a single straight line
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.callGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.phone_outlined, color: AppColors.callGreen, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ContactActionHelper.formatDisplayPhone(phone.number),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Line 2: Left: Mobile label | Right: Action buttons (Call, SMS, WhatsApp)
                  Padding(
                    padding: const EdgeInsets.only(left: 44.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            phone.label,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMiniActionButton(
                              icon: Icons.phone_rounded,
                              color: AppColors.callGreen,
                              tooltip: 'Call',
                              onPressed: () => IntentLauncher.makePhoneCall(context, phone.number),
                            ),
                            const SizedBox(width: 8),
                            _buildMiniActionButton(
                              icon: Icons.message_rounded,
                              color: AppColors.smsBlue,
                              tooltip: 'SMS',
                              onPressed: () => IntentLauncher.sendSms(context, phone.number),
                            ),
                            const SizedBox(width: 8),
                            _buildMiniActionButton(
                              icon: FontAwesomeIcons.whatsapp,
                              color: AppColors.whatsappGreen,
                              tooltip: 'WhatsApp',
                              onPressed: () => IntentLauncher.openWhatsApp(context, phone.number),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniActionButton({
    required dynamic icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: icon is IconData
                ? Icon(icon, color: color, size: 18)
                : FaIcon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }
}
