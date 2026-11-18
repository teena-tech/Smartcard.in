import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/contact_provider.dart';
import '../widgets/contact_tile.dart';
import '../widgets/empty_state_widget.dart';
import 'device_contact_detail_screen.dart';
import '../../core/utils/card_expansion_route.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final contactProvider = context.watch<ContactProvider>();
    final favorites = contactProvider.favoriteContacts;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Favorite Contacts',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Refresh',
            onPressed: () => contactProvider.syncWithDevice(silent: false),
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
