import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_riverpod_providers.dart';
import '../../models/scanned_contact_model.dart';
import '../screens/contact_detail_screen.dart';
import '../../core/utils/card_expansion_route.dart';
import 'genie_hero_route.dart';

class RecentActivityList extends ConsumerWidget {
  final List<ScannedContactModel> activities;

  const RecentActivityList({
    super.key,
    required this.activities,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeViewModelProvider).colors;

    if (activities.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.symmetric(horizontal: 24.0),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.history, size: 48, color: colors.muted.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text('No recent activity to show', style: GoogleFonts.inter(color: colors.muted, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activities.length > 5 ? 5 : activities.length,
      separatorBuilder: (context, index) => Divider(color: colors.border, height: 1),
      itemBuilder: (context, index) {
        final activity = activities[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryRed.withValues(alpha: 0.15),
            child: Text(
              activity.name.isNotEmpty ? activity.name[0].toUpperCase() : '?',
              style: GoogleFonts.inter(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            activity.name,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          subtitle: Text(
            'Scanned on ${_formatDate(activity.createdAt)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: colors.muted,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: colors.muted.withValues(alpha: 0.15),
          ),
          onTap: () {
            Navigator.push(
              context,
              CardExpansionPageRoute(
                page: ContactDetailScreen(
                  contact: activity,
                  heroTag: contactHeroTag(
                    id: activity.id,
                    phone: activity.phone,
                    name: activity.name,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
