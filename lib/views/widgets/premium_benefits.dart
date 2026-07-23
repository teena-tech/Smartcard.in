import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class PremiumBenefits extends StatelessWidget {
  const PremiumBenefits({super.key});

  @override
  Widget build(BuildContext context) {
    final benefits = [
      Benefit(
        icon: Icons.card_membership,
        title: 'Unlimited Cards',
        description: 'Create and manage unlimited smart cards',
      ),
      Benefit(
        icon: Icons.qr_code,
        title: 'QR Code Generation',
        description: 'Generate unlimited QR codes for your cards',
      ),
      Benefit(
        icon: Icons.share,
        title: 'Easy Sharing',
        description: 'Share your cards with anyone, anywhere',
      ),
      Benefit(
        icon: Icons.cloud_upload,
        title: 'Cloud Sync',
        description: 'Sync your cards across all devices',
      ),
      Benefit(
        icon: Icons.priority_high,
        title: 'Priority Support',
        description: 'Get 24/7 priority customer support',
      ),
      Benefit(
        icon: Icons.security,
        title: 'Advanced Security',
        description: 'Enhanced security features for your data',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium,
                color: AppColors.primaryRed,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Premium Benefits',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...benefits.map((benefit) => _buildBenefitItem(benefit)),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(Benefit benefit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              benefit.icon,
              color: AppColors.primaryRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefit.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  benefit.description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Benefit {
  final IconData icon;
  final String title;
  final String description;

  Benefit({
    required this.icon,
    required this.title,
    required this.description,
  });
}
