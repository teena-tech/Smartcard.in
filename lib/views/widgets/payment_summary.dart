import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../viewmodels/theme_viewmodel.dart';
import 'package:provider/provider.dart';

class PaymentSummary extends StatelessWidget {
  final double baseAmount;
  final double gstAmount;
  final double totalAmount;
  final double discountAmount;
  final double payableAmount;
  final bool hasDiscount;

  const PaymentSummary({
    super.key,
    required this.baseAmount,
    required this.gstAmount,
    required this.totalAmount,
    required this.discountAmount,
    required this.payableAmount,
    required this.hasDiscount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Summary',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Base Plan', baseAmount, colors),
          const SizedBox(height: 12),
          _buildSummaryRow('GST (18%)', gstAmount, colors),
          const Divider(height: 24, thickness: 1),
          _buildSummaryRow('Total', totalAmount, colors, isTotal: true),
          if (hasDiscount) ...[
            const SizedBox(height: 12),
            _buildSummaryRow(
              'Discount',
              -discountAmount,
              colors,
              isDiscount: true,
            ),
            const Divider(height: 24, thickness: 1),
            _buildSummaryRow(
              'Payable Amount',
              payableAmount,
              colors,
              isTotal: true,
              isFinal: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount,
    AppColors colors, {
    bool isTotal = false,
    bool isDiscount = false,
    bool isFinal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: isTotal ? 15 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
            color: isDiscount
                ? Colors.redAccent
                : (isTotal ? colors.text : colors.text),
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
            fontSize: isFinal ? 18 : (isTotal ? 16 : 14),
            fontWeight: isFinal
                ? FontWeight.bold
                : (isTotal ? FontWeight.w600 : FontWeight.w400),
            color: isDiscount
                ? Colors.redAccent
                : (isFinal ? AppColors.primaryRed : colors.text),
          ),
        ),
      ],
    );
  }
}
