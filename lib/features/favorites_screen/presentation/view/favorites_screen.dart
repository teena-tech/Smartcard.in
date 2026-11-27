import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_notifier.dart';
import 'package:smartcard_flutter/core/widgets/contact_tile.dart';
import 'package:smartcard_flutter/core/widgets/empty_state_widget.dart';
import 'package:smartcard_flutter/features/device_contact_detail_screen/presentation/view/device_contact_detail_screen.dart';
import 'package:smartcard_flutter/core/widgets/master_app_bar.dart';
import 'package:smartcard_flutter/core/utils/card_expansion_route.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(contactNotifierProvider);
    final contactNotifier = ref.read(contactNotifierProvider.notifier);
    final favorites = contactNotifier.favoriteContacts;

    return Scaffold(
      appBar: MasterAppBar(
        titleText: 'Favorite Contacts',
        showBackButton: true,
        extraActions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () => contactNotifier.syncWithDevice(silent: false),
          ),
        ],
      ),
      body: favorites.isEmpty
          ? const EmptyStateWidget(
              type: EmptyStateType.noFavorites,
              customTitle: 'No Favorite Contacts',
              customSubtitle: 'Star your frequent contacts to have one-tap access to call, text, and email them here.',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final contact = favorites[index];

                return ContactTile(
                  contact: contact,
                  onTap: () {
                    Navigator.of(context).push(
                      CardExpansionPageRoute(
                        page: DeviceContactDetailScreen(contactId: contact.id),
                      ),
                    );
                  },
                ).animate().fadeIn(delay: (index * 40).ms).slideY(begin: 0.05, end: 0);
              },
            ),
    );
  }
}
