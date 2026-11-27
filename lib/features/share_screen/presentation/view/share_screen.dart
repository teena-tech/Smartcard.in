export 'package:smartcard_flutter/features/digital_card_share_screen/presentation/view/digital_card_share_screen.dart';
import 'package:flutter/material.dart';
import 'package:smartcard_flutter/features/my_cards_screen/presentation/view/mycards.dart';

class ShareScreen extends StatelessWidget {
  const ShareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MyCardsScreen(isStandalone: true);
  }
}
