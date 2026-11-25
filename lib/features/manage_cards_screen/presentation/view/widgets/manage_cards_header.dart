import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/presentation/viewmodel/card_viewmodel.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/viewmodel/dashboard_viewmodel.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/data/models/card_model.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/core/widgets/master_app_bar.dart';

class StickyManageCardsTopBar extends ConsumerWidget {
  final CardViewModel viewModel;
  final CardProfileDetails details;
  final String Function(String?, String, String) resolveImgUrl;

  const StickyManageCardsTopBar({
    super.key,
    required this.viewModel,
    required this.details,
    required this.resolveImgUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MasterAppBar(
      titleText: 'My Card',
      style: MasterHeaderStyle.gradient,
      showBackButton: true,
      onBackTap: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          ref.read(dashboardViewModelProvider.notifier).setIndex(0);
        }
      },
    );
  }
}

Widget buildProfileHeader(
    BuildContext context,
    CardViewModel viewModel,
    CardProfileDetails details,
    AppColors colors,
    String Function(String?, String, String) resolveImgUrl,
    Function(BuildContext, String) showEditSheet, {
    bool isOrganization = false,
    bool showTopBar = true,
  }) {
    final initials =
        '${details.firstName.isNotEmpty ? details.firstName[0] : ""}${details.lastName.isNotEmpty ? details.lastName[0] : ""}'
            .toUpperCase();
    final profileImg = resolveImgUrl(
      details.profileImageName,
      'profile',
      viewModel.userId,
    );

    final topPadding = showTopBar
        ? (MediaQuery.of(context).padding.top + 8.0)
        : 16.0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryRed, AppColors.secondaryRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(top: topPadding, bottom: 44),
      child: Column(
        children: [
          if (showTopBar) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        try {
                          ProviderScope.containerOf(context).read(dashboardViewModelProvider.notifier).setIndex(0);
                        } catch (_) {}
                      }
                    },
                  ),
                  Expanded(
                    child: Text(
                      isOrganization ? 'Organization Card Details' : 'Manage Card Details',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // balances the back button
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          // Avatar Area
          const SizedBox(height: 10),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 3),
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  child: Center(
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: profileImg.isNotEmpty
                          ? Image.network(
                              profileImg,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Text(
                                  initials.isEmpty ? 'U' : initials,
                                  style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryRed,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                initials.isEmpty ? 'U' : initials,
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryRed,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                if (!isOrganization)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => showEditSheet(context, 'section-profile-image'),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryRed, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: AppColors.primaryRed,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: isOrganization ? null : () => showEditSheet(context, 'section-personal'),
              child: Column(
                children: [
                  Text(
                    '${details.firstName} ${details.lastName}'.trim().isEmpty
                        ? 'User Name'
                        : '${details.firstName} ${details.lastName}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details.designation.isEmpty
                        ? (isOrganization ? 'Official Representative' : 'Add designation')
                        : details.designation,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  }