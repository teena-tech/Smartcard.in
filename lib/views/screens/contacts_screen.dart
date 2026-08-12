import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../main.dart';
import '../../viewmodels/contact_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../core/utils/responsive.dart';
import '../../core/services/contact_saver_service.dart';
import '../widgets/contact_list_tile.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _hasAttemptedSync = false;
  bool _isSearching = false;
  bool _permissionChecked = false;
  bool _hasPermission = false;
  bool _hasRequestedPermission = false; // Only ask once per screen lifecycle

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ContactViewModel>().setActiveFilter('Scanned');
      }
    });
    _searchController.addListener(() {
      context.read<ContactViewModel>().setSearchQuery(_searchController.text);
      if (mounted) {
        setState(() {});
      }
    });
    _searchFocus.addListener(() {
      setState(() {
        _isSearching = _searchFocus.hasFocus;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only trigger permission when the user actually navigates to the Contacts tab (index 4)
    final currentIndex = context.read<DashboardViewModel>().currentIndex;
    if (currentIndex == 4 && !_hasRequestedPermission) {
      _hasRequestedPermission = true;
      _checkPermissionStatus();
    }
  }

  Future<void> _checkPermissionStatus() async {
    final status = await Permission.contacts.status;
    final bool isGranted = status.isGranted || status.isLimited;

    if (mounted) {
      setState(() {
        _hasPermission = isGranted;
        _permissionChecked = true;
      });

      if (isGranted) {
        // Permission already granted — load contacts immediately
        context.read<ContactViewModel>().importPhoneContacts();
      } else if (status.isPermanentlyDenied) {
        // User permanently denied — show settings redirect dialog
        _showSettingsDialog();
      } else {
        // Not yet asked or denied once — ask now
        await _requestContactsPermission();
      }
    }
  }

  void _showSettingsDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contacts Permission'),
        content: const Text(
          'Contacts permission is required to show your phone contacts. Please enable it from App Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestContactsPermission() async {
    final status = await Permission.contacts.request();
    final bool saverPerm = await ContactSaverService.requestContactsPermission();
    final bool isGranted = status.isGranted || status.isLimited || saverPerm;

    if (mounted) {
      setState(() {
        _hasPermission = isGranted;
        _permissionChecked = true;
      });
      if (isGranted) {
        context.read<ContactViewModel>().importPhoneContacts(force: true);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contactViewModel = context.watch<ContactViewModel>();
    final dashboardViewModel = context.watch<DashboardViewModel>();
    final colors = context.watch<ThemeViewModel>().colors;

    final bool isPermissionGranted = _hasPermission || contactViewModel.phoneContactsCount > 0;

    // Auto-trigger sync when switching to tab if contacts are empty and permission is granted
    if (dashboardViewModel.currentIndex == 4 && isPermissionGranted && (!_hasAttemptedSync || contactViewModel.allContacts.isEmpty)) {
      _hasAttemptedSync = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          final vm = context.read<ContactViewModel>();
          vm.importPhoneContacts();
        }
      });
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      floatingActionButton: _isSearching
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                context.read<DashboardViewModel>().setIndex(1);
              },
              backgroundColor: colors.accent,
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              label: Text('Scan Card', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior.translucent,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/login.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contact Permission Warning (shown ONLY if permission is denied AND no phone contacts loaded)
                if (_permissionChecked && !isPermissionGranted)
                  _buildPermissionNotice(colors),

                _buildSearchBar(colors),
                if (!_isSearching) _buildStatistics(contactViewModel, colors),
                Expanded(
                  child: contactViewModel.isLoading
                      ? Center(child: CircularProgressIndicator(color: colors.accent))
                      : _buildFilteredList(contactViewModel, colors),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionNotice(dynamic colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.security, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Contacts permission is not granted.',
                style: GoogleFonts.inter(
                  color: colors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: _requestContactsPermission,
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Text(
                'Grant',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(dynamic colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        textCapitalization: TextCapitalization.none,
        style: GoogleFonts.inter(color: colors.text),
        decoration: InputDecoration(
          hintText: 'Search name, phone, company...',
          hintStyle: GoogleFonts.inter(color: colors.muted),
          prefixIcon: const Icon(Icons.search, color: Color(0xFFE53935)),
          filled: true,
          fillColor: colors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE53935), width: 2.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFFE53935)),
                  tooltip: 'Clear Search',
                  onPressed: () {
                    _searchController.clear();
                    context.read<ContactViewModel>().setSearchQuery('');
                    _searchFocus.unfocus();
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilteredList(ContactViewModel vm, dynamic colors) {
    final contacts = vm.contacts;

    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            globalEmptyContactsLottieComposition != null
                ? Lottie(
                    composition: globalEmptyContactsLottieComposition,
                    width: 250,
                    height: 250,
                    repeat: true,
                    animate: true,
                    fit: BoxFit.contain,
                  )
                : const SizedBox(
                    width: 250,
                    height: 250,
                    child: Center(
                        child: Icon(Icons.group_off,
                            color: Colors.grey, size: 80)),
                  ),
            const SizedBox(height: 16),
            Text(
              'No contacts found.',
              style: GoogleFonts.inter(color: colors.muted, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          vm.loadMore();
        }
        return true;
      },
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          return ContactListTile(
            contact: contact,
            onFavoriteToggle: () => vm.toggleFavorite(contact.id),
          );
        },
      ),
    );
  }

  Widget _buildStatistics(ContactViewModel vm, dynamic colors) {
    final matched = vm.matchedContactsCount;
    final phone = vm.phoneContactsCount;
    final scanned = vm.scannedContactsCount;

    Widget phoneChip = _StatChip(
      label: 'Phone Contacts',
      value: phone.toString(),
      color: colors.text,
      bgColor: colors.panel,
      isSelected: vm.activeFilter == 'Phone',
      onTap: () {
        vm.setActiveFilter(vm.activeFilter == 'Phone' ? 'All' : 'Phone');
      },
    );

    Widget matchedChip = _StatChip(
      label: 'Smart Card',
      value: matched.toString(),
      color: colors.accent,
      bgColor: colors.panel,
      isSelected: vm.activeFilter == 'Matched',
      onTap: () {
        final newFilter = vm.activeFilter == 'Matched' ? 'All' : 'Matched';
        vm.setActiveFilter(newFilter);
        if (newFilter == 'Matched') {
          vm.matchPhoneContactsWithServer(force: true);
        }
      },
    );

    Widget scannedChip = _StatChip(
      label: 'Scanned Cards',
      value: scanned.toString(),
      color: const Color(0xFF2E7D32),
      bgColor: colors.panel,
      isSelected: vm.activeFilter == 'Scanned',
      onTap: () {
        vm.setActiveFilter(vm.activeFilter == 'Scanned' ? 'All' : 'Scanned');
      },
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(child: phoneChip),
          const SizedBox(width: 8),
          Expanded(child: matchedChip),
          const SizedBox(width: 8),
          Expanded(child: scannedChip),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : bgColor.withValues(alpha: 0.6),
          border: Border.all(color: isSelected ? color : Colors.grey.withValues(alpha: 0.2), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Colors.grey[500],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isSelected ? color : color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
