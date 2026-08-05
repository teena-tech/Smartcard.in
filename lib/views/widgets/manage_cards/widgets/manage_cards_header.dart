import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../viewmodels/card_viewmodel.dart';
import '../../../../models/card_model.dart';
import '../../../../core/constants/app_colors.dart';

class StickyManageCardsTopBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final initials =
        '${details.firstName.isNotEmpty ? details.firstName[0] : ""}${details.lastName.isNotEmpty ? details.lastName[0] : ""}'
            .toUpperCase();
    final profileImg = resolveImgUrl(
      details.profileImageName,
      'profile',
      viewModel.userId,
    );

    return Container(
      width: double.infinity,
      color: AppColors.primaryRed,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white, size: 18),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              Text(
                'My Card',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
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
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initials.isEmpty ? 'U' : initials,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget buildProfileHeader(
    BuildContext context,
    CardViewModel viewModel,
    CardProfileDetails details,
    AppColors colors,
    String Function(String?, String, String) resolveImgUrl,
    Function(BuildContext, String) showEditSheet,
  ) {
    final initials =
        '${details.firstName.isNotEmpty ? details.firstName[0] : ""}${details.lastName.isNotEmpty ? details.lastName[0] : ""}'
            .toUpperCase();
    final profileImg = resolveImgUrl(
      details.profileImageName,
      'profile',
      viewModel.userId,
    );

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryRed, AppColors.secondaryRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.only(top: 16, bottom: 40),
      child: Column(
        children: [
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
              onTap: () => showEditSheet(context, 'section-personal'),
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
                    details.designation.isEmpty ? 'Add designation' : details.designation,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.9),
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