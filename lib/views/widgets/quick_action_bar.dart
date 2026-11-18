import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/contact_action_helper.dart';
import '../../core/utils/intent_launcher.dart';
import '../../models/app_contact.dart';

class QuickActionBar extends StatelessWidget {
  final AppContact contact;

  const QuickActionBar({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    final hasPhone = contact.phones.isNotEmpty;
    final hasEmail = contact.emails.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF8B0000).withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. Call Button
          _ActionButton(
            icon: Icons.phone_rounded,
            label: 'Call',
            color: AppColors.callGreen,
            isEnabled: hasPhone,
            onTap: () {
              ContactActionHelper.handleCall(
                context,
                contact: contact,
                contactName: contact.displayName,
              );
            },
          ),

          // 2. SMS Button
          _ActionButton(
            icon: Icons.message_rounded,
            label: 'SMS',
            color: AppColors.smsBlue,
            isEnabled: hasPhone,
            onTap: () {
              ContactActionHelper.handleSms(
                context,
                contact: contact,
                contactName: contact.displayName,
              );
            },
          ),

          // 3. WhatsApp Button
          _ActionButton(
            icon: FontAwesomeIcons.whatsapp,
            label: 'WhatsApp',
            color: AppColors.whatsappGreen,
            isEnabled: hasPhone,
            onTap: () {
              ContactActionHelper.handleWhatsApp(
                context,
                contact: contact,
                contactName: contact.displayName,
              );
            },
          ),

          // 4. Email Button
          _ActionButton(
            icon: Icons.email_rounded,
            label: 'Email',
            color: AppColors.emailOrange,
            isEnabled: hasEmail,
            onTap: () {
              ContactActionHelper.handleEmail(
                context,
                contact: contact,
                contactName: contact.displayName,
              );
            },
          ),

          // 5. Share Button
          _ActionButton(
            icon: Icons.share_rounded,
            label: 'Share',
            color: AppColors.primary,
            isEnabled: true,
            onTap: () {
              final shareText = '''
${contact.displayName}
${contact.company != null && contact.company!.isNotEmpty ? 'Company: ${contact.company}\n' : ''}${contact.phones.map((p) => '${p.label}: ${p.number}').join('\n')}
${contact.emails.map((e) => '${e.label}: ${e.address}').join('\n')}
'''.trim();
              IntentLauncher.shareContact(
                shareText,
                subject: 'Contact: ${contact.displayName}',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final dynamic icon;
  final String label;
  final Color color;
  final bool isEnabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isEnabled ? color : Colors.grey.withAlpha(100);

    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isEnabled ? color.withAlpha(30) : Colors.grey.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: icon is IconData
                    ? Icon(icon as IconData, color: effectiveColor, size: 22)
                    : FaIcon(icon, color: effectiveColor, size: 20),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isEnabled
                    ? Theme.of(context).colorScheme.onSurface.withAlpha(220)
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
