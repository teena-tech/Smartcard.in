import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../viewmodels/card_viewmodel.dart';
import '../../../../core/constants/app_colors.dart';

Widget buildFooterActions(
    BuildContext context,
    CardViewModel viewModel,
    AppColors colors,
  ) {
    final List<Widget> footerActions = [];

    if (viewModel.canSetSelectedAsPrimary) {
      footerActions.add(
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: viewModel.isBusy
                  ? null
                  : () => viewModel.handleSetPrimaryCard(),
              child: Text(
                'Set As Primary',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      );
    }



    return Row(children: footerActions);
  }