import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../core/constants/app_colors.dart';
import '../widgets/common_drawer.dart';
import '../../core/utils/responsive.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../widgets/custom_bottom_nav.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final TextEditingController _couponController = TextEditingController();
  late Razorpay _razorpay;
  String? _lastSuccessMessage;
  String? _lastErrorMessage;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSubscription();
    });
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

  Future<void> _loadSubscription() async {
    final authViewModel = context.read<AuthViewModel>();
    final subscriptionViewModel = context.read<SubscriptionViewModel>();
    final userId = authViewModel.currentUser?.id;
    if (userId != null) {
      await subscriptionViewModel.fetchSubscription(userId);
    }
  }

  Future<void> _initiatePayment() async {
    final subscriptionViewModel = context.read<SubscriptionViewModel>();
    final authViewModel = context.read<AuthViewModel>();

    subscriptionViewModel.resetPaymentState();
    subscriptionViewModel.clearMessages();

    final userId = authViewModel.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User session not found. Please log in.')),
      );
      return;
    }

    // 1. Create Order on Backend
    final orderRes = await subscriptionViewModel.createPaymentOrder(userId);
    if (orderRes == null || orderRes['success'] != true) {
      return;
    }

    final data = orderRes['data']?['order'] as Map<String, dynamic>?;
    final razorpayKeyId = data?['razorpay_key_id']?.toString() ?? '';
    final orderId = data?['razorpay_order_id']?.toString() ?? '';
    final amountPaise = data?['amount'] as int? ?? (subscriptionViewModel.payableAmount * 100).toInt();

    // 2. Local dev mock payment fallback if order is mock or key empty
    if (orderId.startsWith('devorder_') || razorpayKeyId == 'rzp_test_mock_key' || razorpayKeyId.isEmpty) {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final rand = DateTime.now().microsecond % 9000 + 1000;
      final paymentData = {
        'razorpay_payment_id': 'devpay_${userId}_${stamp}_$rand',
        'razorpay_order_id': orderId.isNotEmpty ? orderId : 'devorder_${stamp}_$rand',
        'razorpay_signature': 'devsig_${stamp}_$rand',
        'coupon_code': subscriptionViewModel.appliedCouponCode.isNotEmpty
            ? subscriptionViewModel.appliedCouponCode
            : null,
        'base_amount': SubscriptionViewModel.baseAmount,
        'discount_amount': subscriptionViewModel.discountedAmount,
        'payable_amount': subscriptionViewModel.payableAmount,
        'gst_amount': subscriptionViewModel.gstAmount,
        'total_amount': subscriptionViewModel.totalAmount,
        'payment_for': 'subscription',
        'dev_mock_payment': 1,
      };

      final success = await subscriptionViewModel.confirmPayment(userId, paymentData);
      if (success && mounted) {
        _showSuccessDialog();
      }
      return;
    }

    // 3. Open Razorpay Checkout for actual Razorpay Key
    final options = {
      'key': razorpayKeyId,
      'amount': amountPaise,
      'name': 'SmartCard Premium',
      'description': '365 Days Premium Membership',
      'order_id': orderId,
      'prefill': {
        'contact': authViewModel.currentUser?.phone ?? '',
        'email': authViewModel.currentUser?.email ?? '',
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay checkout: $e');
      subscriptionViewModel.resetPaymentState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch Razorpay checkout: $e')),
        );
      }
    }
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
                  Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final themeViewModel = context.watch<ThemeViewModel>();
    final colors = themeViewModel.colors;

    final successMessage = context.select<SubscriptionViewModel, String?>(
      (vm) => vm.successMessage,
    );
    final errorMessage = context.select<SubscriptionViewModel, String?>(
      (vm) => vm.errorMessage,
    );

    // Check for new messages
    if (successMessage != null && successMessage != _lastSuccessMessage) {
      _lastSuccessMessage = successMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      successMessage,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 3),
            ),
          );
          context.read<SubscriptionViewModel>().clearMessages();
        }
      });
    }

    if (errorMessage != null && errorMessage != _lastErrorMessage) {
      _lastErrorMessage = errorMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: colors.backgroundStart,
      drawer: const CommonDrawer(),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryRed, AppColors.secondaryRed],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        title: Text(
          'Subscription',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: _loadSubscription,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Consumer<SubscriptionViewModel>(
              builder: (context, vm, child) {
                if (vm.subscription?.isActive == true) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.verified,
                            color: Colors.green,
                            size: 100,
                          ),
                          SizedBox(height: 24),
                          Text(
                            'You are currently enjoying Premium Benefits!',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium Benefits
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Premium Benefits',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _BenefitItem(
                            icon: Icons.card_membership,
                            title: 'Unlimited Cards',
                            subtitle: 'Create and manage unlimited smart cards',
                          ),
                          const SizedBox(height: 16),
                          const _BenefitItem(
                            icon: Icons.qr_code,
                            title: 'QR Code Generation',
                            subtitle: 'Generate unlimited QR codes for your cards',
                          ),
                          const SizedBox(height: 16),
                          const _BenefitItem(
                            icon: Icons.share,
                            title: 'Easy Sharing',
                            subtitle: 'Share your cards with anyone, anywhere',
                          ),
                          const SizedBox(height: 16),
                          const _BenefitItem(
                            icon: Icons.cloud_sync,
                            title: 'Cloud Sync',
                            subtitle: 'Sync your cards across all devices',
                          ),
                          const SizedBox(height: 16),
                          const _BenefitItem(
                            icon: Icons.priority_high,
                            title: 'Priority Support',
                            subtitle: 'Get 24/7 priority customer support',
                          ),
                          const SizedBox(height: 16),
                          const _BenefitItem(
                            icon: Icons.security,
                            title: 'Advanced Security',
                            subtitle: 'Enhanced security features for your data',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Coupon Section
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Apply Coupon',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (vm.appliedCoupon?.success == true)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Coupon applied successfully!',
                                      style: GoogleFonts.poppins(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _couponController.clear();
                                      vm.resetCoupon();
                                    },
                                    child: Text(
                                      'Remove',
                                      style: GoogleFonts.poppins(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _couponController,
                                    decoration: InputDecoration(
                                      hintText: 'Enter coupon code',
                                      hintStyle: GoogleFonts.poppins(),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                    ),
                                    textCapitalization: TextCapitalization.characters,
                                    onSubmitted: (code) {
                                      final userId = context
                                          .read<AuthViewModel>()
                                          .currentUser
                                          ?.id;
                                      if (userId != null) {
                                        vm.applyCoupon(userId, code);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: vm.isPaymentButtonDisabled
                                      ? null
                                      : () {
                                          final userId = context
                                              .read<AuthViewModel>()
                                              .currentUser
                                              ?.id;
                                          if (userId != null) {
                                            vm.applyCoupon(
                                              userId,
                                              _couponController.text,
                                            );
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Apply',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Payment Summary
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Summary',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _SummaryItem(
                            label: 'Base Plan',
                            amount: '₹${SubscriptionViewModel.baseAmount.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 12),
                          _SummaryItem(
                            label: 'GST (${SubscriptionViewModel.gstPercent}%)',
                            amount: '₹${vm.gstAmount.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 12),
                          _SummaryItem(
                            label: 'Total',
                            amount: '₹${vm.totalAmount.toStringAsFixed(2)}',
                            isBold: true,
                          ),
                          if (vm.discountedAmount > 0) ...[
                            const SizedBox(height: 12),
                            _SummaryItem(
                              label: 'Discount',
                              amount: '-₹${vm.discountedAmount.toStringAsFixed(2)}',
                              isDiscount: true,
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 12),
                            _SummaryItem(
                              label: 'Payable Amount',
                              amount: '₹${vm.payableAmount.toStringAsFixed(2)}',
                              isBold: true,
                              isTotal: true,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SafeArea(
            bottom: false,
            child: Consumer<SubscriptionViewModel>(
              builder: (context, vm, child) {
                if (vm.subscription?.isActive == true) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: vm.isPaymentButtonDisabled
                          ? null
                          : _initiatePayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: vm.paymentStatus == PaymentStatus.processing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Processing...'),
                              ],
                            )
                          : Text(
                              vm.isPaymentRequired
                                  ? 'Pay ₹${vm.payableAmount.toStringAsFixed(2)}'
                                  : 'Activate Free',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
          CustomBottomNav(
            currentIndex: 0,
            onTap: (index) {
              final dashVm = context.read<DashboardViewModel>();
              Navigator.pop(context);
              dashVm.setIndex(index == 2 ? 9 : index);
            },
          ),
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: AppColors.primaryRed,
          size: 28,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String amount;
  final bool isBold;
  final bool isDiscount;
  final bool isTotal;

  const _SummaryItem({
    required this.label,
    required this.amount,
    this.isBold = false,
    this.isDiscount = false,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? AppColors.primaryRed : null,
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isDiscount ? Colors.green : (isTotal ? AppColors.primaryRed : null),
          ),
        ),
      ],
    );
  }
}
