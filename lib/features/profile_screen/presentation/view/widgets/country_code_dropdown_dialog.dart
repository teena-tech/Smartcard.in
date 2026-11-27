import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';
import 'package:smartcard_flutter/core/utils/international_phone_helper.dart';

class CountryItem {
  final String name;
  final String code;
  final String flag;
  final bool isEnabled;

  const CountryItem({
    required this.name,
    required this.code,
    required this.flag,
    this.isEnabled = true,
  });
}

class CountryCodeDropdownDialog {
  static List<CountryItem> get countries => InternationalPhoneHelper.supportedCountries
      .map((c) => CountryItem(name: c.name, code: c.code, flag: c.flag, isEnabled: true))
      .toList();

  /// Opens a sleek, compact dropdown list with search bar right below the country code box
  static Future<void> show(
    BuildContext context, {
    GlobalKey? anchorKey,
    String selectedCode = '+91',
    bool isWhatsAppMode = false,
    ValueChanged<CountryItem>? onSelectCountry,
  }) async {
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final RenderBox? renderBox =
        anchorKey?.currentContext?.findRenderObject() as RenderBox?;

    Offset targetOffset = const Offset(36, 250);
    double anchorHeight = 44;

    if (renderBox != null && overlay != null) {
      targetOffset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
      anchorHeight = renderBox.size.height;
    } else {
      final screen = MediaQuery.of(context).size;
      targetOffset = Offset(36, screen.height * 0.38);
    }

    final selected = await showGeneralDialog<CountryItem>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CountryPicker',
      barrierColor: Colors.transparent,
      pageBuilder: (dialogContext, anim1, anim2) {
        return _CountrySearchPopup(
          targetOffset: targetOffset,
          anchorHeight: anchorHeight,
          selectedCode: selectedCode,
          isWhatsAppMode: isWhatsAppMode,
        );
      },
      transitionDuration: const Duration(milliseconds: 150),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        );
      },
    );

    if (selected != null && onSelectCountry != null) {
      onSelectCountry(selected);
    }
  }
}

class _CountrySearchPopup extends StatefulWidget {
  final Offset targetOffset;
  final double anchorHeight;
  final String selectedCode;
  final bool isWhatsAppMode;

  const _CountrySearchPopup({
    required this.targetOffset,
    required this.anchorHeight,
    required this.selectedCode,
    required this.isWhatsAppMode,
  });

  @override
  State<_CountrySearchPopup> createState() => _CountrySearchPopupState();
}

class _CountrySearchPopupState extends State<_CountrySearchPopup> {
  final TextEditingController _searchController = TextEditingController();
  List<CountryItem> _filteredCountries = CountryCodeDropdownDialog.countries;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = CountryCodeDropdownDialog.countries;
      } else {
        _filteredCountries = CountryCodeDropdownDialog.countries.where((c) {
          final nameMatch = c.name.toLowerCase().contains(query);
          final codeMatch = c.code.toLowerCase().contains(query);
          return nameMatch || codeMatch;
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double popupWidth = 175;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final keyboardInset = mediaQuery.viewInsets.bottom;

    double left = widget.targetOffset.dx;
    if (left + popupWidth > screenWidth - 16) {
      left = screenWidth - popupWidth - 16;
    }
    if (left < 16) left = 16;

    final spaceBelow =
        screenHeight - keyboardInset - (widget.targetOffset.dy + widget.anchorHeight + 4);
    double top;
    double maxHeight = 230;

    if (spaceBelow < 140 && widget.targetOffset.dy > 160) {
      // Show above anchor if keyboard covers bottom
      maxHeight = math.min(220.0, widget.targetOffset.dy - 20);
      top = widget.targetOffset.dy - maxHeight - 4;
    } else {
      top = widget.targetOffset.dy + widget.anchorHeight + 4;
      maxHeight = math.min(230.0, math.max(120.0, spaceBelow - 10));
    }

    return Stack(
      children: [
        // Barrier listener to dismiss on outside tap
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.of(context).pop(),
            child: const SizedBox.expand(),
          ),
        ),

        // Anchored Popup Card
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: popupWidth,
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Compact Search Bar Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                    child: Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: AppFonts.poppins(
                                fontSize: 11.5,
                                color: Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                hintStyle: AppFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.transparent,
                                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () => _searchController.clear(),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  Divider(height: 1, thickness: 0.8, color: Colors.grey.shade200),

                  // Country List
                  Flexible(
                    child: _filteredCountries.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Text(
                                'No country found',
                                style: AppFonts.poppins(
                                  fontSize: 10.5,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            shrinkWrap: true,
                            itemCount: _filteredCountries.length,
                            itemBuilder: (context, index) {
                              final item = _filteredCountries[index];
                              final isSelected = item.code == widget.selectedCode;

                              return InkWell(
                                onTap: () => Navigator.of(context).pop(item),
                                child: Container(
                                  height: 30,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFFFF1F2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        item.flag,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppFonts.poppins(
                                            fontSize: 10.5,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isSelected ? const Color(0xFFDC2626) : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.code,
                                        style: AppFonts.poppins(
                                          fontSize: 10.5,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected
                                              ? const Color(0xFFDC2626)
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
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
}
