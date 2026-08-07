import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../main.dart';
import '../../viewmodels/contact_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../core/utils/responsive.dart';
import '../widgets/contact_list_tile.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _activeFilter = 'SmartCard'; // 'All', 'Phone', 'SmartCard'
  bool _hasAttemptedSync = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      context.read<ContactViewModel>().setSearchQuery(_searchController.text);
    });
    _searchFocus.addListener(() {
      setState(() {
        _isSearching = _searchFocus.hasFocus;
      });
    });
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
    
    // Automatically prompt for permission when the user switches to this tab for the first time
    if (dashboardViewModel.currentIndex == 4 && !_hasAttemptedSync) {
      _hasAttemptedSync = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.read<ContactViewModel>().importPhoneContacts();
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
      body: Container(
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
          prefixIcon: Icon(Icons.search, color: colors.muted),
          filled: true,
          fillColor: colors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colors.accent, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          suffixIcon: IconButton(
            icon: Icon(Icons.sync, color: colors.accentSoft),
            tooltip: 'Sync Phone Contacts',
            onPressed: () {
              context.read<ContactViewModel>().importPhoneContacts();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing contacts...')),
              );
            },
          ),
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
        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          vm.loadMore();
        }
        return true;
      },
      child: ListView.builder(
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
    final smartcard = vm.smartCardContactsCount;
    final phone = vm.phoneContactsCount;

    Widget phoneChip = _StatChip(
      label: 'Phone Contacts',
      value: phone.toString(),
      color: colors.text,
      bgColor: colors.panel,
      isSelected: vm.activeFilter == 'Phone',
      onTap: () {
        vm.setActiveFilter('Phone');
      },
    );

    Widget smartcardChip = _StatChip(
      label: 'SmartCard Scans',
      value: smartcard.toString(),
      color: colors.accent,
      bgColor: colors.panel,
      isSelected: vm.activeFilter == 'SmartCard',
      onTap: () {
        vm.setActiveFilter('SmartCard');
      },
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(child: phoneChip),
          const SizedBox(width: 12),
          Expanded(child: smartcardChip),
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
    super.key,
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
