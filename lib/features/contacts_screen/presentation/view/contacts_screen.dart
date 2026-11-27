import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/core/utils/responsive.dart';
import 'package:smartcard_flutter/core/utils/permission_helper.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/app_contact.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_notifier.dart';
import 'package:smartcard_flutter/features/groups_screen/presentation/viewmodel/group_notifier.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_viewmodel.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/viewmodel/dashboard_viewmodel.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';

import 'package:smartcard_flutter/features/contacts_screen/presentation/view/widgets/alphabet_scroll_bar.dart';
import 'package:smartcard_flutter/core/widgets/contact_tile.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/view/widgets/contact_list_tile.dart';
import 'package:smartcard_flutter/core/widgets/empty_state_widget.dart';
import 'package:smartcard_flutter/core/services/reactive_contact_sync_service.dart';
import 'package:smartcard_flutter/features/contact_form_screen/presentation/view/contact_form_screen.dart';
import 'package:smartcard_flutter/features/groups_screen/presentation/view/groups_screen.dart';
import 'package:smartcard_flutter/core/widgets/lottie_loader.dart';

abstract class ContactListItem {}

class SectionHeaderItem extends ContactListItem {
  final String letter;
  SectionHeaderItem(this.letter);
}

class ContactTileItem extends ContactListItem {
  final AppContact contact;
  ContactTileItem(this.contact);
}

class ScannedTileItem extends ContactListItem {
  final ScannedContactModel contact;
  ScannedTileItem(this.contact);
}

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _phoneScrollController = ScrollController();
  final ScrollController _smartCardScrollController = ScrollController();
  final ScrollController _scansScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  final Map<String, int> _letterItemIndices = {};
  final Map<String, double> _phoneLetterOffsets = {};
  final Map<String, double> _smartLetterOffsets = {};
  final Map<String, double> _scansLetterOffsets = {};

  // Memoized cache for Phone Contacts list construction
  Map<String, List<AppContact>>? _lastGroupedContactsRef;
  List<ContactListItem> _memoizedPhoneListItems = [];
  List<String> _memoizedPhoneAvailableLetters = [];

  // Memoized cache for Smart Cards & Scanned Cards
  List<ScannedContactModel>? _lastSmartContactsRef;
  String _lastSmartQuery = '';
  ContactFilter _lastSmartFilter = ContactFilter.all;
  String? _lastSmartGroupId;
  int _lastSmartPhoneContactsCount = -1;
  int _lastSmartDataVersion = -1;
  int _lastSmartCardCount = -1;
  int _lastSmartAllContactsLength = -1;
  List<ContactListItem> _memoizedSmartListItems = [];
  List<String> _memoizedSmartLetters = [];

  List<ScannedContactModel>? _lastScansContactsRef;
  String _lastScansQuery = '';
  ContactFilter _lastScansFilter = ContactFilter.all;
  String? _lastScansGroupId;
  int _lastScansPhoneContactsCount = -1;
  int _lastScansDataVersion = -1;
  int _lastScansCardCount = -1;
  int _lastScansAllContactsLength = -1;
  List<ContactListItem> _memoizedScansListItems = [];
  List<String> _memoizedScansLetters = [];


  String? _activeLetterBubble;
  bool _isDraggingAlphabet = false;
  bool _showScrollToTop = false;
  bool _showHeaderSection = true;
  Timer? _bubbleDismissTimer;
  bool _hasCheckedPermissionOnActive = false;
  StreamSubscription<SyncEvent>? _syncEventSub;

  // Selected tab: 0 = Phone Contacts, 1 = Smart Card, 2 = Scans
  int _selectedTabIndex = 0;

  ScrollController get _activeScrollController {
    switch (_selectedTabIndex) {
      case 0:
        return _phoneScrollController;
      case 1:
        return _smartCardScrollController;
      case 2:
        return _scansScrollController;
      default:
        return _phoneScrollController;
    }
  }

  Map<String, double> get _activeLetterOffsets {
    switch (_selectedTabIndex) {
      case 0:
        return _phoneLetterOffsets;
      case 1:
        return _smartLetterOffsets;
      case 2:
        return _scansLetterOffsets;
      default:
        return _phoneLetterOffsets;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _phoneScrollController.addListener(_onScroll);
    _smartCardScrollController.addListener(_onScroll);
    _scansScrollController.addListener(_onScroll);

    _syncEventSub = ReactiveContactSyncService().events.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestContactPermissionIfActive();
    });
  }

  /// Check permission state only when Contacts tab (index 4) is active.
  /// Uses native Android OS permission request directly (NO custom dialog popup).
  void _checkAndRequestContactPermissionIfActive() {
    if (_hasCheckedPermissionOnActive || !mounted) return;

    DashboardViewModel? dashboardVm;
    try {
      dashboardVm = ref.read(dashboardViewModelProvider.notifier);
    } catch (_) {}

    final bool isContactsActive = dashboardVm == null || dashboardVm.currentIndex == 4;
    if (!isContactsActive) return;

    _hasCheckedPermissionOnActive = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final cp = ref.read(contactNotifierProvider.notifier);
      final vm = ref.read(contactViewModelProvider.notifier);
      final gp = ref.read(groupNotifierProvider.notifier);
      final currentState = await PermissionHelper.checkContactsPermission();

      if (currentState == ContactPermissionState.granted) {
        await cp.checkPermission();
        // Trigger background sync without delaying initial render
        _refreshDataAll(silent: true);
      } else {
        // Trigger system OS native permission dialog directly
        final granted = await cp.requestPermissionAndLoad();
        if (mounted && granted) {
          await _refreshDataAll(silent: false, skipDeviceSync: false);
          await _syncDevicePhonesAndMatch(force: true);
        } else if (mounted) {
          // Even if device contacts permission is denied, still load server smart cards & groups!
          gp.loadGroups();
          vm.loadContactsFromBackend();
        }
      }
    });
  }

  /// Explicitly requests permission and immediately triggers full auto-load
  Future<void> _requestPermissionAndAutoLoad() async {
    final cp = ref.read(contactNotifierProvider.notifier);
    final granted = await cp.requestPermissionAndLoad();
    if (mounted && granted) {
      await _refreshDataAll(silent: false, skipDeviceSync: false);
      await _syncDevicePhonesAndMatch(force: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      PermissionHelper.checkContactsPermission().then((permState) {
        if (!mounted) return;
        final cp = ref.read(contactNotifierProvider.notifier);
        if (permState == ContactPermissionState.granted && cp.permissionState != ContactPermissionState.granted) {
          cp.checkPermission();
          _refreshDataAll(silent: false, skipDeviceSync: false);
          _syncDevicePhonesAndMatch(force: true);
        } else {
          _refreshDataAll(silent: true, skipDeviceSync: false);
        }
      });
    }
  }

  Future<void> _syncDevicePhonesAndMatch({bool force = false}) async {
    if (!mounted) return;
    final cp = ref.read(contactNotifierProvider.notifier);
    final vm = ref.read(contactViewModelProvider.notifier);

    final phoneToName = <String, String>{};
    final phoneToDevId = <String, String>{};
    final devicePhones = <String>[];
    for (final c in cp.contacts) {
      final p = c.primaryPhone.trim();
      if (p.isNotEmpty) {
        devicePhones.add(p);
        final cleanDigits = p.replaceAll(RegExp(r'\D'), '');
        final p10 = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;
        if (c.id.isNotEmpty) {
          phoneToDevId[cleanDigits] = c.id;
          if (p10.isNotEmpty) phoneToDevId[p10] = c.id;
          phoneToDevId[p] = c.id;
        }
        if (c.displayName.trim().isNotEmpty) {
          phoneToName[cleanDigits] = c.displayName.trim();
          if (p10.isNotEmpty) {
            phoneToName[p10] = c.displayName.trim();
          }
          phoneToName[p] = c.displayName.trim();
        }
      }
    }
    if (devicePhones.isNotEmpty || vm.smartCardContactsCount == 0) {
      await vm.matchPhoneContactsWithServer(
        force: force,
        devicePhones: devicePhones.isNotEmpty ? devicePhones : null,
        phoneToNameMap: phoneToName.isNotEmpty ? phoneToName : null,
        phoneToDevIdMap: phoneToDevId.isNotEmpty ? phoneToDevId : null,
      );
    }
  }

  Future<void> _refreshDataAll({bool silent = true, bool skipDeviceSync = false}) async {
    if (!mounted) return;
    final cp = ref.read(contactNotifierProvider.notifier);
    final gp = ref.read(groupNotifierProvider.notifier);
    final vm = ref.read(contactViewModelProvider.notifier);
    final dashboardVm = ref.read(dashboardViewModelProvider.notifier);

    final future = () async {
      try {
        final List<Future<dynamic>> syncTasks = [
          gp.loadGroups(),
          vm.loadContactsFromBackend(),
        ];
        if (!skipDeviceSync) {
          syncTasks.insert(
            0,
            ReactiveContactSyncService().handleDatabaseChange(
              contactNotifier: cp,
              contactViewModel: vm,
              dashboardViewModel: dashboardVm,
              silent: silent,
            ),
          );
        }
        await Future.wait(syncTasks);

        if (!mounted) return;
        await _syncDevicePhonesAndMatch(force: !silent || vm.smartCardContactsCount == 0);
      } catch (e) {
        debugPrint('Error in _refreshDataAll: $e');
      }
    }();

    if (!silent) {
      await future;
    }
  }

  void _onScroll() {
    final ctrl = _activeScrollController;
    if (!ctrl.hasClients) return;
    final offset = ctrl.offset;
    final show = offset > 200;
    if (show != _showScrollToTop) {
      setState(() {
        _showScrollToTop = show;
      });
    }

    final direction = ctrl.position.userScrollDirection;
    if (offset <= 10) {
      if (!_showHeaderSection) {
        setState(() => _showHeaderSection = true);
      }
    } else if (direction == ScrollDirection.reverse) {
      if (_showHeaderSection) {
        setState(() => _showHeaderSection = false);
      }
    } else if (direction == ScrollDirection.forward) {
      if (!_showHeaderSection) {
        setState(() => _showHeaderSection = true);
      }
    }
  }

  void _scrollToTop() {
    final ctrl = _activeScrollController;
    if (ctrl.hasClients) {
      ctrl.animateTo(
        0.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phoneScrollController.removeListener(_onScroll);
    _smartCardScrollController.removeListener(_onScroll);
    _scansScrollController.removeListener(_onScroll);
    _phoneScrollController.dispose();
    _smartCardScrollController.dispose();
    _scansScrollController.dispose();
    _bubbleDismissTimer?.cancel();
    _syncEventSub?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _scrollToLetter(String letter) {
    FocusScope.of(context).unfocus();

    if (letter == '↑') {
      _scrollToTop();
      return;
    }

    setState(() {
      _activeLetterBubble = letter;
      _isDraggingAlphabet = true;
    });

    _bubbleDismissTimer?.cancel();
    _bubbleDismissTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _isDraggingAlphabet = false;
          _activeLetterBubble = null;
        });
      }
    });

    final offsets = _activeLetterOffsets;
    final ctrl = _activeScrollController;

    double? targetOffset = offsets[letter];
    if (targetOffset == null && offsets.isNotEmpty) {
      final sortedAvailable = offsets.keys.toList()..sort();
      for (final l in sortedAvailable) {
        if (l.compareTo(letter) >= 0) {
          targetOffset = offsets[l];
          break;
        }
      }
      targetOffset ??= ctrl.hasClients ? ctrl.position.maxScrollExtent : 0.0;
    }

    if (targetOffset != null && ctrl.hasClients) {
      final double clampedOffset = targetOffset.clamp(
        0.0,
        ctrl.position.maxScrollExtent,
      );

      ctrl.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    ref.watch(contactNotifierProvider);
    ref.watch(groupNotifierProvider);
    ref.watch(contactViewModelProvider);
    final contactNotifier = ref.read(contactNotifierProvider.notifier);
    final groupNotifier = ref.read(groupNotifierProvider.notifier);
    final contactViewModel = ref.read(contactViewModelProvider.notifier);
    final colors = ref.watch(themeViewModelProvider).colors;

    final dashboardViewModel = ref.watch(dashboardViewModelProvider);
    if (dashboardViewModel != null && dashboardViewModel.currentIndex == 4 && !_hasCheckedPermissionOnActive) {
      _checkAndRequestContactPermissionIfActive();
    }

    final grouped = contactNotifier.groupedContacts;

    // Calculate item offsets for phone contacts virtualized list (memoized)
    if (!identical(grouped, _lastGroupedContactsRef)) {
      _lastGroupedContactsRef = grouped;
      _memoizedPhoneAvailableLetters = grouped.keys.toList();
      _memoizedPhoneListItems = [];
      _letterItemIndices.clear();
      _phoneLetterOffsets.clear();

      const double headerHeight = 44.0;
      const double tileHeight = 76.0;

      double runningOffset = 0.0;

      for (final entry in grouped.entries) {
        _letterItemIndices[entry.key] = _memoizedPhoneListItems.length;
        _phoneLetterOffsets[entry.key] = runningOffset;

        _memoizedPhoneListItems.add(SectionHeaderItem(entry.key));
        runningOffset += headerHeight;

        for (final contact in entry.value) {
          _memoizedPhoneListItems.add(ContactTileItem(contact));
          runningOffset += tileHeight;
        }
      }
    }

    final availableLetters = _memoizedPhoneAvailableLetters;
    final listItems = _memoizedPhoneListItems;

    final bool showAlphabetBar = _selectedTabIndex == 0 &&
        availableLetters.isNotEmpty &&
        contactNotifier.filteredContacts.isNotEmpty &&
        !(contactNotifier.isLoading && contactNotifier.contacts.isEmpty);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        floatingActionButton: _showScrollToTop
            ? FloatingActionButton.small(
                onPressed: _scrollToTop,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
              )
            : null,
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
            child: SafeArea(
              child: Column(
                children: [
                  // 1. Search Bar at TOP (Always Visible)
                  const SizedBox(height: 6),
                  _buildTopSearchBar(context, contactNotifier, contactViewModel, theme),
                  const SizedBox(height: 6),

                  // 2. Collapsible Top Summary Cards Row & Filter Chips
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: (_showHeaderSection &&
                            _searchController.text.trim().isEmpty &&
                            contactNotifier.searchQuery.isEmpty &&
                            contactViewModel.searchQuery.isEmpty)
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Top Summary Cards Row: Contacts | Groups | Smart Card | Scans
                              _buildTopTabs(contactNotifier, groupNotifier, contactViewModel),
                              const SizedBox(height: 6),
                              // Filter Chips Row: Favorites | Groups
                              _buildFilterChipsRow(contactNotifier, groupNotifier, contactViewModel),
                              const SizedBox(height: 6),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

                  // 3. Tab Content in IndexedStack to preserve state & scroll across all tabs
                  Expanded(
                    child: NotificationListener<UserScrollNotification>(
                      onNotification: (notification) {
                        if (notification.direction == ScrollDirection.reverse) {
                          if (_showHeaderSection) {
                            setState(() => _showHeaderSection = false);
                          }
                        } else if (notification.direction == ScrollDirection.forward) {
                          if (!_showHeaderSection) {
                            setState(() => _showHeaderSection = true);
                          }
                        }
                        return false;
                      },
                      child: IndexedStack(
                        index: _selectedTabIndex,
                        children: [
                          _buildPhoneContactsView(
                            context,
                            contactNotifier,
                            groupNotifier,
                            listItems,
                            availableLetters,
                            showAlphabetBar,
                            theme,
                          ),
                          _buildSmartOrScannedCardsView(
                            context,
                            contactViewModel,
                            contactNotifier,
                            groupNotifier,
                            colors,
                            isSmartCard: true,
                            controller: _smartCardScrollController,
                            offsetsMap: _smartLetterOffsets,
                          ),
                          _buildSmartOrScannedCardsView(
                            context,
                            contactViewModel,
                            contactNotifier,
                            groupNotifier,
                            colors,
                            isSmartCard: false,
                            controller: _scansScrollController,
                            offsetsMap: _scansLetterOffsets,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopTabs(
    ContactNotifier contactNotifier,
    GroupNotifier groupNotifier,
    ContactViewModel contactViewModel,
  ) {
    final phoneCount = contactNotifier.totalCount;
    final smartCardCount = contactViewModel.smartCardContactsCount > 0
        ? contactViewModel.smartCardContactsCount
        : (contactViewModel.matchedContactsCount > 0
            ? contactViewModel.matchedContactsCount
            : contactViewModel.allContacts.where((c) => c.isSmartCardUser).length);
    final scannedCount = contactViewModel.scannedContactsCount > 0
        ? contactViewModel.scannedContactsCount
        : contactViewModel.allContacts.where((c) {
            final src = (c.source ?? '').toLowerCase();
            return c.id.startsWith('scan_') ||
                src.contains('ocr') ||
                src.contains('business_card') ||
                src.contains('scan') ||
                src == 'scanned' ||
                src == 'card_scan' ||
                (c.imagePath != null && c.imagePath!.trim().isNotEmpty && c.imagePath!.trim().toLowerCase() != 'null');
          }).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: Row(
        children: [
          Expanded(
            child: _buildTabChip(
              title: 'Contacts',
              count: phoneCount,
              isSelected: _selectedTabIndex == 0,
              icon: Icons.phone_android_rounded,
              onTap: () {
                setState(() => _selectedTabIndex = 0);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildTabChip(
              title: 'Smart Card',
              count: smartCardCount,
              isSelected: _selectedTabIndex == 1,
              icon: Icons.verified_rounded,
              onTap: () {
                setState(() => _selectedTabIndex = 1);
                contactViewModel.setActiveFilter('Matched');
                _syncDevicePhonesAndMatch(force: contactViewModel.smartCardContactsCount == 0);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildTabChip(
              title: 'Scans',
              count: scannedCount,
              isSelected: _selectedTabIndex == 2,
              icon: Icons.credit_card_rounded,
              onTap: () {
                setState(() => _selectedTabIndex = 2);
                contactViewModel.setActiveFilter('Scanned');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip({
    required String title,
    required int count,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFDE8E8) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryRed : Colors.grey.shade200,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primaryRed : const Color(0xFF4A4A4A),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? AppColors.primaryRed : const Color(0xFF555555),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$count',
                      style: AppFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? AppColors.primaryRed : const Color(0xFF222222),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChipsRow(
    ContactNotifier contactNotifier,
    GroupNotifier groupNotifier,
    ContactViewModel contactViewModel,
  ) {

    final bool isFavoritesSelected = contactNotifier.currentFilter == ContactFilter.favorites ||
        contactViewModel.activeFilter == 'Favorites';

    final int favoritesCount = _selectedTabIndex == 0
        ? contactNotifier.favoritesCount
        : (_selectedTabIndex == 1
            ? contactViewModel.allContacts.where((c) => (c.isMatched || (c.matchedCards != null && c.matchedCards!.isNotEmpty)) && c.isFavorite).length
            : contactViewModel.allContacts.where((c) => c.isFavorite).length);

    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildFilterChip(
            label: 'Favorites ($favoritesCount)',
            leadingIcon: const Icon(
              Icons.star_rounded,
              size: 15,
              color: AppColors.favoriteGold,
            ),
            isSelected: isFavoritesSelected,
            onTap: () {
              if (isFavoritesSelected) {
                contactNotifier.setFilter(ContactFilter.all);
                if (_selectedTabIndex == 1) {
                  contactViewModel.setActiveFilter('Matched');
                } else if (_selectedTabIndex == 2) {
                  contactViewModel.setActiveFilter('Scanned');
                } else {
                  contactViewModel.setActiveFilter('All');
                }
              } else {
                contactNotifier.setFilter(ContactFilter.favorites);
                contactViewModel.setActiveFilter('Favorites');
              }
            },
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: '👥 Groups (${groupNotifier.groups.length})',
            isSelected: false,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GroupsScreen()),
              );
              if (mounted) {
                groupNotifier.loadGroups();
              }
            },
          ),
          if (groupNotifier.groups.isNotEmpty) ...[
            const SizedBox(width: 8),
            ...groupNotifier.groups.map((g) {
              final isSelected = contactNotifier.currentFilter == ContactFilter.group &&
                  contactNotifier.selectedGroupId == g.id;
              final memberCount = groupNotifier.getMemberCount(g.id ?? '', contactNotifier.contacts);
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _buildFilterChip(
                  label: '🏷️ ${g.name} ($memberCount)',
                  isSelected: isSelected,
                  onTap: () {
                    final defaultTabFilter = _selectedTabIndex == 1
                        ? 'Matched'
                        : (_selectedTabIndex == 2 ? 'Scanned' : 'All');
                    if (isSelected) {
                      contactNotifier.setFilter(ContactFilter.all);
                      contactViewModel.setActiveFilter(defaultTabFilter);
                    } else if (g.id != null) {
                      contactViewModel.setActiveFilter(defaultTabFilter);
                      contactNotifier.setGroupFilter(g.id!, g.name);
                    }
                  },
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildTopSearchBar(
    BuildContext context,
    ContactNotifier contactNotifier,
    ContactViewModel contactViewModel,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    String hint = 'Search contacts...';
    String currentQuery = '';

    if (_selectedTabIndex == 0) {
      final count = contactNotifier.currentFilter != ContactFilter.all
          ? contactNotifier.filteredContacts.length
          : contactNotifier.totalCount;
      if (contactNotifier.currentFilter == ContactFilter.favorites) {
        hint = 'Search $count favorite contacts...';
      } else if (contactNotifier.currentFilter == ContactFilter.group && contactNotifier.selectedGroupName != null) {
        hint = 'Search $count ${contactNotifier.selectedGroupName} contacts...';
      } else {
        hint = 'Search ${count > 0 ? "$count " : ""}contacts...';
      }
      currentQuery = contactNotifier.searchQuery;
    } else if (_selectedTabIndex == 1) {
      final count = contactViewModel.smartCardContactsCount;
      hint = 'Search ${count > 0 ? "$count " : ""}digital smart cards...';
      currentQuery = contactViewModel.searchQuery;
    } else if (_selectedTabIndex == 2) {
      final count = contactViewModel.scannedContactsCount;
      hint = 'Search ${count > 0 ? "$count " : ""}scanned cards...';
      currentQuery = contactViewModel.searchQuery;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                style: AppFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: AppFonts.poppins(
                    fontSize: 13.5,
                    color: Colors.grey[500],
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty || currentQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            if (_selectedTabIndex == 0) {
                              contactNotifier.setSearchQuery('');
                            } else {
                              contactViewModel.setSearchQuery('');
                            }
                          },
                        )
                      : null,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  fillColor: isDark
                      ? Colors.grey.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                ),
                onChanged: (val) {
                  if (_selectedTabIndex == 0) {
                    contactNotifier.setSearchQuery(val);
                  } else {
                    contactViewModel.setSearchQuery(val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            borderRadius: BorderRadius.circular(14),
            elevation: 1,
            shadowColor: AppColors.primary.withValues(alpha: 0.3),
            child: InkWell(
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ContactFormScreen(),
                  ),
                );
                if (result != null && mounted) {
                  _refreshDataAll(silent: true);
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_add_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Add',
                      style: AppFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneContactsView(
    BuildContext context,
    ContactNotifier contactNotifier,
    GroupNotifier groupNotifier,
    List<ContactListItem> listItems,
    List<String> availableLetters,
    bool showAlphabetBar,
    ThemeData theme,
  ) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _refreshDataAll(silent: false, skipDeviceSync: false),
          color: AppColors.primary,
          child: contactNotifier.isLoading && contactNotifier.contacts.isEmpty
              ? const Center(child: LottieLoader(size: 80))
              : contactNotifier.permissionState == ContactPermissionState.denied && !PermissionHelper.isDesktop && contactNotifier.contacts.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.5,
                        alignment: Alignment.center,
                        child: EmptyStateWidget(
                          type: EmptyStateType.permissionDenied,
                          actionText: 'Grant Permission',
                          onAction: _requestPermissionAndAutoLoad,
                        ),
                      ),
                    )
                  : contactNotifier.filteredContacts.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.5,
                            alignment: Alignment.center,
                            child: EmptyStateWidget(
                              type: contactNotifier.searchQuery.isNotEmpty ||
                                      contactNotifier.currentFilter != ContactFilter.all
                                  ? EmptyStateType.noSearchResults
                                  : EmptyStateType.noContacts,
                              onAction: () {
                                if (contactNotifier.searchQuery.isNotEmpty ||
                                    contactNotifier.currentFilter != ContactFilter.all) {
                                  _searchController.clear();
                                  contactNotifier.setSearchQuery('');
                                  contactNotifier.setFilter(ContactFilter.all);
                                } else {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const ContactFormScreen()),
                                  );
                                }
                              },
                            ),
                          ),
                        )
                  : ListView.builder(
                      controller: _phoneScrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: listItems.length,
                      itemBuilder: (context, index) {
                        final item = listItems[index];

                        if (item is SectionHeaderItem) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item.letter,
                                    style: AppFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Divider(color: Colors.grey.withValues(alpha: 0.2)),
                                ),
                              ],
                            ),
                          );
                        } else if (item is ContactTileItem) {
                          final contact = item.contact;
                          return Padding(
                            padding: EdgeInsets.only(right: showAlphabetBar ? 26.0 : 8.0),
                            child: ContactTile(
                              contact: contact,
                              enableHero: _selectedTabIndex == 0,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
        ),

        // Right-side Fast Scroller
        if (showAlphabetBar)
          Positioned(
            right: 2,
            top: 10,
            bottom: 10,
            child: Center(
              child: AlphabetScrollBar(
                availableAlphabets: availableLetters,
                onLetterSelected: _scrollToLetter,
                onDragStateChanged: (isDragging) {
                  setState(() => _isDraggingAlphabet = isDragging);
                },
              ),
            ),
          ),

        // Floating Letter Bubble Preview
        if (_isDraggingAlphabet && _activeLetterBubble != null)
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _activeLetterBubble!,
                style: AppFonts.poppins(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Map<String, List<ScannedContactModel>> _groupScannedContacts(List<ScannedContactModel> list) {
    final List<ScannedContactModel> sortedList = List.from(list)
      ..sort((a, b) {
        final nameA = a.name.trim();
        final nameB = b.name.trim();
        if (nameA.isEmpty && nameB.isEmpty) return 0;
        if (nameA.isEmpty) return 1;
        if (nameB.isEmpty) return -1;
        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      });

    final Map<String, List<ScannedContactModel>> grouped = {};
    for (final c in sortedList) {
      final trimmedName = c.name.trim();
      String firstChar = '#';
      if (trimmedName.isNotEmpty) {
        final char = trimmedName[0].toUpperCase();
        if (RegExp(r'[A-Z]').hasMatch(char)) {
          firstChar = char;
        }
      }
      grouped.putIfAbsent(firstChar, () => []).add(c);
    }

    final keys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });

    final Map<String, List<ScannedContactModel>> sortedMap = {};
    for (final k in keys) {
      sortedMap[k] = grouped[k]!;
    }
    return sortedMap;
  }

  Widget _buildSmartOrScannedCardsView(
    BuildContext context,
    ContactViewModel vm,
    ContactNotifier contactNotifier,
    GroupNotifier groupNotifier,
    dynamic colors, {
    required bool isSmartCard,
    required ScrollController controller,
    required Map<String, double> offsetsMap,
  }) {
    final q = vm.searchQuery.trim().toLowerCase();
    final filter = contactNotifier.currentFilter;
    final groupId = contactNotifier.selectedGroupId;
    final phoneCount = contactNotifier.contacts.length;

    final List<ScannedContactModel> baseList = isSmartCard
        ? (vm.smartCardContacts.isNotEmpty
            ? vm.smartCardContacts
            : vm.allContacts.where((c) => c.isSmartCardUser).toList())
        : (vm.scannedContacts.isNotEmpty
            ? vm.scannedContacts
            : vm.allContacts.where((c) {
                final src = (c.source ?? '').toLowerCase();
                return c.id.startsWith('scan_') ||
                    src.contains('ocr') ||
                    src.contains('business_card') ||
                    src.contains('scan') ||
                    src == 'scanned' ||
                    src == 'card_scan' ||
                    (c.imagePath != null &&
                        c.imagePath!.trim().isNotEmpty &&
                        c.imagePath!.trim().toLowerCase() != 'null');
              }).toList());

    final bool isCacheEmptyWithData = filter == ContactFilter.all &&
        q.isEmpty &&
        (isSmartCard
            ? (_memoizedSmartListItems.isEmpty && baseList.isNotEmpty)
            : (_memoizedScansListItems.isEmpty && baseList.isNotEmpty));

    final bool needsRecompute = isCacheEmptyWithData || (isSmartCard
        ? (vm.dataVersion != _lastSmartDataVersion ||
            (_memoizedSmartListItems.isEmpty && filter == ContactFilter.all && q.isEmpty && baseList.isNotEmpty) ||
            vm.smartCardContacts.length != _lastSmartCardCount ||
            vm.allContacts.length != _lastSmartAllContactsLength ||
            !identical(vm.allContacts, _lastSmartContactsRef) ||
            q != _lastSmartQuery ||
            filter != _lastSmartFilter ||
            groupId != _lastSmartGroupId ||
            phoneCount != _lastSmartPhoneContactsCount)
        : (vm.dataVersion != _lastScansDataVersion ||
            (_memoizedScansListItems.isEmpty && filter == ContactFilter.all && q.isEmpty && baseList.isNotEmpty) ||
            vm.scannedContacts.length != _lastScansCardCount ||
            vm.allContacts.length != _lastScansAllContactsLength ||
            !identical(vm.allContacts, _lastScansContactsRef) ||
            q != _lastScansQuery ||
            filter != _lastScansFilter ||
            groupId != _lastScansGroupId ||
            phoneCount != _lastScansPhoneContactsCount));

    List<ContactListItem> scannedListItems;
    List<String> availableLetters;

    if (needsRecompute) {
      List<ScannedContactModel> list = baseList;

      // 1. Filter by Search Query
      if (q.isNotEmpty) {
        list = list.where((c) {
          return c.name.toLowerCase().contains(q) ||
              c.phone.contains(q) ||
              (c.alternativePhone?.contains(q) ?? false) ||
              c.email.toLowerCase().contains(q) ||
              c.company.toLowerCase().contains(q) ||
              c.designation.toLowerCase().contains(q);
        }).toList();
      }

      // 2. Filter by Current Filter Chip (Favorites, Groups) - ONLY when actively on that filter
      if (filter == ContactFilter.favorites) {
        list = list.where((c) {
          final devC = contactNotifier.findContactByPhoneOrEmail(c.phone, c.email) ?? contactNotifier.findContactById(c.id);
          return c.isFavorite || (devC?.isFavorite ?? false);
        }).toList();
      } else if (filter == ContactFilter.group && groupId != null) {
        list = list.where((c) {
          final devC = contactNotifier.findContactByPhoneOrEmail(c.phone, c.email) ?? contactNotifier.findContactById(c.id);
          return devC != null && devC.groupIds.contains(groupId);
        }).toList();
      }



      final groupedScanned = _groupScannedContacts(list);
      availableLetters = groupedScanned.keys.toList();

      scannedListItems = [];
      offsetsMap.clear();

      const double headerHeight = 44.0;
      const double tileHeight = 76.0;

      double runningOffset = 0.0;

      for (final entry in groupedScanned.entries) {
        offsetsMap[entry.key] = runningOffset;

        scannedListItems.add(SectionHeaderItem(entry.key));
        runningOffset += headerHeight;

        for (final contact in entry.value) {
          scannedListItems.add(ScannedTileItem(contact));
          runningOffset += tileHeight;
        }
      }

      if (isSmartCard) {
        _lastSmartDataVersion = vm.dataVersion;
        _lastSmartCardCount = vm.smartCardContacts.length;
        _lastSmartAllContactsLength = vm.allContacts.length;
        _lastSmartContactsRef = vm.allContacts;
        _lastSmartQuery = q;
        _lastSmartFilter = filter;
        _lastSmartGroupId = groupId;
        _lastSmartPhoneContactsCount = phoneCount;
        _memoizedSmartListItems = scannedListItems;
        _memoizedSmartLetters = availableLetters;
      } else {
        _lastScansDataVersion = vm.dataVersion;
        _lastScansCardCount = vm.scannedContacts.length;
        _lastScansAllContactsLength = vm.allContacts.length;
        _lastScansContactsRef = vm.allContacts;
        _lastScansQuery = q;
        _lastScansFilter = filter;
        _lastScansGroupId = groupId;
        _lastScansPhoneContactsCount = phoneCount;
        _memoizedScansListItems = scannedListItems;
        _memoizedScansLetters = availableLetters;
      }
    } else {
      scannedListItems = isSmartCard ? _memoizedSmartListItems : _memoizedScansListItems;
      availableLetters = isSmartCard ? _memoizedSmartLetters : _memoizedScansLetters;

      // Safety guard: if cached list became empty but baseList has items, build immediately!
      if (scannedListItems.isEmpty && baseList.isNotEmpty && q.isEmpty && filter == ContactFilter.all) {
        final groupedScanned = _groupScannedContacts(baseList);
        availableLetters = groupedScanned.keys.toList();
        scannedListItems = [];
        for (final entry in groupedScanned.entries) {
          scannedListItems.add(SectionHeaderItem(entry.key));
          for (final contact in entry.value) {
            scannedListItems.add(ScannedTileItem(contact));
          }
        }
        if (isSmartCard) {
          _memoizedSmartListItems = scannedListItems;
          _memoizedSmartLetters = availableLetters;
        } else {
          _memoizedScansListItems = scannedListItems;
          _memoizedScansLetters = availableLetters;
        }
      }
    }

    final bool showAlphabetBar = availableLetters.isNotEmpty && scannedListItems.isNotEmpty;

    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _refreshDataAll(silent: false),
          child: scannedListItems.isEmpty
              ? (isSmartCard && vm.isLoading && baseList.isEmpty)
                  ? const Center(child: LottieLoader(size: 80))
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.45,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(24.0),
                        child: EmptyStateWidget(
                          type: q.isNotEmpty ? EmptyStateType.noSearchResults : EmptyStateType.noContacts,
                          customTitle: q.isNotEmpty ? null : (isSmartCard ? 'No Smart Card Contacts' : 'No Scanned Business Cards'),
                          customSubtitle: q.isNotEmpty ? null : (isSmartCard
                              ? 'Contacts matched with TheSmartCards digital cards will appear here.'
                              : 'Scan business cards or QR codes to save them in this tab.'),
                          onAction: q.isNotEmpty
                              ? () {
                                  _searchController.clear();
                                  vm.setSearchQuery('');
                                }
                              : null,
                        ),
                      ),
                    )
              : ListView.builder(
                  controller: controller,
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: scannedListItems.length,
                  itemBuilder: (context, index) {
                    final item = scannedListItems[index];

                    if (item is SectionHeaderItem) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.letter,
                                style: AppFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Divider(color: Colors.grey.withValues(alpha: 0.2)),
                            ),
                          ],
                        ),
                      );
                    } else if (item is ScannedTileItem) {
                      final contact = item.contact;
                      return Padding(
                        padding: EdgeInsets.only(right: showAlphabetBar ? 26.0 : 8.0),
                        child: ContactListTile(
                          contact: contact,
                          enableHero: isSmartCard ? _selectedTabIndex == 1 : _selectedTabIndex == 2,
                          onFavoriteToggle: () => vm.toggleFavorite(contact.id),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
        ),

        // Right-side Fast Scroller
        if (showAlphabetBar)
          Positioned(
            right: 2,
            top: 10,
            bottom: 10,
            child: Center(
              child: AlphabetScrollBar(
                availableAlphabets: availableLetters,
                onLetterSelected: _scrollToLetter,
                onDragStateChanged: (isDragging) {
                  setState(() => _isDraggingAlphabet = isDragging);
                },
              ),
            ),
          ),

        // Floating Letter Bubble Preview
        if (_isDraggingAlphabet && _activeLetterBubble != null)
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _activeLetterBubble!,
                style: AppFonts.poppins(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    Widget? leadingIcon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            leadingIcon,
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppFonts.poppins(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : null,
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}
