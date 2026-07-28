import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/upload_url_resolver.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/subscription_viewmodel.dart';

class PremiumPaymentScreen extends StatefulWidget {
  const PremiumPaymentScreen({super.key});

  @override
  State<PremiumPaymentScreen> createState() => _PremiumPaymentScreenState();
}

class _PremiumPaymentScreenState extends State<PremiumPaymentScreen> {
  final TextEditingController _couponController = TextEditingController();
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _couponController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final subscriptionViewModel = context.read<SubscriptionViewModel>();
    final authViewModel = context.read<AuthViewModel>();
    final userId = authViewModel.currentUser?.id ?? '1';

    final paymentData = {
      'razorpay_payment_id': response.paymentId,
      'razorpay_order_id': response.orderId,
      'razorpay_signature': response.signature,
      'coupon_code': subscriptionViewModel.appliedCouponCode.isNotEmpty
          ? subscriptionViewModel.appliedCouponCode
          : null,
      'payment_for': 'subscription',
    };

    final success = await subscriptionViewModel.confirmPayment(userId, paymentData);
    if (success && mounted) {
      _showSuccessDialog();
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    final subscriptionViewModel = context.read<SubscriptionViewModel>();
    subscriptionViewModel.resetPaymentState();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment cancelled or failed: ${response.message ?? "Try again"}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External wallet selected: ${response.walletName}');
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: AppColors.primaryRed,
              size: 80,
            ),
            const SizedBox(height: 20),
            Text(
              'Payment Successful!',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your premium subscription has been activated!',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Pop dialog
                  Navigator.of(context).pop(); // Pop PremiumPaymentScreen
                  context.read<SubscriptionViewModel>().resetPaymentState();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Great!',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _initiatePayment() async {
    final subscriptionViewModel = context.read<SubscriptionViewModel>();
    final authViewModel = context.read<AuthViewModel>();
    final user = authViewModel.currentUser;
    final userId = user?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User details not found. Please log in again.')),
      );
      return;
    }

    // Call API to create order / initiate payment
    final orderResponse = await subscriptionViewModel.createPaymentOrder(userId);

    if (orderResponse != null) {
      if (!subscriptionViewModel.isPaymentRequired) {
        // If payable amount is 0 (due to 100% discount coupon), bypass payment Gateway
        final confirmPayload = {
          'razorpay_payment_id': 'free_bypass_${DateTime.now().millisecondsSinceEpoch}',
          'razorpay_order_id': orderResponse['id'],
          'razorpay_signature': 'free_signature',
          'coupon_code': subscriptionViewModel.appliedCouponCode,
          'payment_for': 'subscription',
        };
        final success = await subscriptionViewModel.confirmPayment(userId, confirmPayload);
        if (success && mounted) {
          _showSuccessDialog();
        }
        return;
      }

      // Launch Razorpay checkout
      final options = {
        'key': orderResponse['razorpay_key_id'],
        'amount': orderResponse['amount'],
        'name': 'SmartCard Premium',
        'description': 'Premium Subscription',
        'order_id': orderResponse['id'],
        'prefill': {
          'contact': user?.phone ?? '',
          'email': user?.email ?? '',
        },
        'external': {
          'wallets': ['paytm']
        }
      };

      try {
        _razorpay.open(options);
      } catch (e) {
        debugPrint('Error launching Razorpay: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryRed, AppColors.secondaryRed],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Premium Checkout',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/login.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Consumer<SubscriptionViewModel>(
            builder: (context, vm, child) {
              return Column(
                children: [
                  // Main Payment Card (matching the 3rd image layout)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Premium Subscription',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF1E293B),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '365 + 18% GST',
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '₹ ${vm.payableAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFEF4444),
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Features List
                        const _FeatureCheckItem(text: 'Professional Profile Update'),
                        const SizedBox(height: 12),
                        const _FeatureCheckItem(text: 'Theme Customization'),
                        const SizedBox(height: 12),
                        const _FeatureCheckItem(text: 'Social Media Links'),
                        const SizedBox(height: 12),
                        const _FeatureCheckItem(text: 'Thumbnail in Social Media'),

                        const SizedBox(height: 28),

                        // Coupon input block
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _couponController,
                                  decoration: InputDecoration(
                                    hintText: 'DISCOUNT COUPON CODE',
                                    hintStyle: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  textCapitalization: TextCapitalization.characters,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: vm.isPaymentButtonDisabled
                                    ? null
                                    : () {
                                        final userId = context.read<AuthViewModel>().currentUser?.id;
                                        if (userId != null && _couponController.text.trim().isNotEmpty) {
                                          vm.applyCoupon(userId, _couponController.text.trim());
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC0564C),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                child: Text(
                                  'APPLY',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Pay Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: vm.isPaymentButtonDisabled ? null : _initiatePayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              vm.isPaymentRequired ? 'Pay Now' : 'Activate Free',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FeatureCheckItem extends StatelessWidget {
  final String text;

  const _FeatureCheckItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF4CAF50),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(3),
          child: const Icon(Icons.check, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
