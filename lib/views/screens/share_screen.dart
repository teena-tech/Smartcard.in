export 'digital_card_share_screen.dart';
import 'package:flutter/material.dart';
import 'mycards.dart';

class ShareScreen extends StatelessWidget {
  const ShareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MyCardsScreen(isStandalone: true);
  }
}
