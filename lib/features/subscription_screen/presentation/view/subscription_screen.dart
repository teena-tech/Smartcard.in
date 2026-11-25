import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/viewmodel/profile_viewmodel.dart';
import 'package:smartcard_flutter/features/subscription_screen/presentation/viewmodel/subscription_viewmodel.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/presentation/viewmodel/card_viewmodel.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/core/utils/responsive.dart';
import 'package:smartcard_flutter/core/widgets/global_bottom_nav.dart';
import 'package:smartcard_flutter/core/widgets/circular_profile_avatar.dart';
import 'package:smartcard_flutter/core/widgets/master_app_bar.dart';
import 'package:smartcard_flutter/core/utils/upload_url_resolver.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  final TextEditingController _couponController = TextEditingController();
  final PageController _pageController = PageController();
  int _currentPage = 0;
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
    _pageController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final subscriptionViewModel = ref.read(subscriptionViewModelProvider.notifier);
    final authViewModel = ref.read(authViewModelProvider.notifier);
    final userId = authViewModel.currentUser?.id ?? '1';

    final paymentData = {
      'razorpay_payment_id': response.paymentId ?? '',
      'razorpay_order_id': response.orderId ?? '',
      'razorpay_signature': response.signature ?? '',
      'coupon_code': subscriptionViewModel.appliedCouponCode.isNotEmpty
          ? subscriptionViewModel.appliedCouponCode
          : null,
      'base_amount': SubscriptionViewModel.baseAmount,
      'discount_amount': subscriptionViewModel.discountedAmount,
      'payable_amount': subscriptionViewModel.payableAmount,
      'gst_amount': subscriptionViewModel.gstAmount,
      'total_amount': subscriptionViewModel.totalAmount,
      'payment_for': 'subscription',
    };

    final success = await subscriptionViewModel.confirmPayment(userId, paymentData);
    if (success && mounted) {
      _showSuccessDialog();
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    final subscriptionViewModel = ref.read(subscriptionViewModelProvider.notifier);
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
    final authViewModel = ref.read(authViewModelProvider.notifier);
    final profileViewModel = ref.read(profileViewModelProvider.notifier);
    final subscriptionViewModel = ref.read(subscriptionViewModelProvider.notifier);
    final userId = authViewModel.currentUser?.id;
    if (userId != null) {
      await Future.wait<void>([
        profileViewModel.loadProfile(userId),
        subscriptionViewModel.fetchSubscription(userId),
      ]);
    }
  }

  void _openCheckoutModal({bool preserveCoupon = false}) {
    final vm = ref.read(subscriptionViewModelProvider.notifier);
    vm.clearMessages();
    if (!preserveCoupon) {
      vm.resetCoupon();
      _couponController.clear();
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPremiumCheckoutSheet(),
    );
  }

  Future<bool> _initiatePayment() async {
    final subscriptionViewModel = ref.read(subscriptionViewModelProvider.notifier);
    final authViewModel = ref.read(authViewModelProvider.notifier);

    subscriptionViewModel.resetPaymentState();
    subscriptionViewModel.clearMessages();

    final userId = authViewModel.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User session not found. Please log in.')),
        );
      }
      return false;
    }

    // If no payment is required or payable amount is zero, activate directly
    if (subscriptionViewModel.payableAmount == 0.0 || !subscriptionViewModel.isPaymentRequired) {
      final paymentData = {
        'razorpay_payment_id': 'free_activation_${DateTime.now().millisecondsSinceEpoch}',
        'razorpay_order_id': 'free_order_${DateTime.now().millisecondsSinceEpoch}',
        'razorpay_signature': 'free_signature',
        'coupon_code': subscriptionViewModel.appliedCouponCode.isNotEmpty
            ? subscriptionViewModel.appliedCouponCode
            : null,
        'base_amount': SubscriptionViewModel.baseAmount,
        'discount_amount': subscriptionViewModel.discountedAmount,
        'payable_amount': 0.0,
        'gst_amount': 0.0,
        'total_amount': 0.0,
        'payment_for': 'subscription',
      };

      final success = await subscriptionViewModel.confirmPayment(userId, paymentData);
      if (success && mounted) {
        _showSuccessDialog();
      }
      return success;
    }

    // 1. Create Order on Backend
    final orderRes = await subscriptionViewModel.createPaymentOrder(userId);
    if (orderRes == null || orderRes['success'] != true) {
      return false;
    }

    final data = orderRes['data']?['order'] as Map<String, dynamic>?;
    final razorpayKeyId = data?['razorpay_key_id']?.toString() ?? '';
    final orderId = data?['razorpay_order_id']?.toString() ?? '';
    final amountPaise = data?['amount'] as int? ?? (subscriptionViewModel.payableAmount * 100).round();

    // 2. Open Razorpay Checkout for real payment
    final options = <String, dynamic>{
      'key': razorpayKeyId,
      'amount': amountPaise,
      'name': 'SmartCard Premium',
      'description': '365 Days Premium Membership',
      'order_id': orderId,
      'prefill': {
        'contact': authViewModel.currentUser?.phone ?? '',
        'email': authViewModel.currentUser?.email ?? '',
      },
    };

    try {
      debugPrint('🚀 Opening Razorpay with key=$razorpayKeyId, orderId=$orderId, amount=$amountPaise');
      _razorpay.open(options);
      subscriptionViewModel.resetPaymentState();
      return true;
    } catch (e) {
      debugPrint('Error opening Razorpay checkout: $e');
      subscriptionViewModel.resetPaymentState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch Razorpay checkout: $e')),
        );
      }
      return false;
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
                  Navigator.of(context).pop(); // Pop dialog
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop(); // Pop SubscriptionScreen
                  }
                  ref.read(subscriptionViewModelProvider.notifier).resetPaymentState();
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

  String _formatAmount(double amount) {
    if (amount % 1 == 0) {
      return amount.toInt().toString();
    }
    final str = amount.toStringAsFixed(2);
    if (str.endsWith('.00')) {
      return str.substring(0, str.length - 3);
    }
    return str;
  }

  Widget _buildPremiumCheckoutSheet() {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter modalSetState) {
        final vm = ref.watch(subscriptionViewModelProvider);

        final String displayAmount = _formatAmount(vm.payableAmount);

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAF5F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryRed,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Premium Checkout',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Balance back icon
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Card Container
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Premium Subscription',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E233A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '365 + 18% GST',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Price Display
                      Column(
                        children: [
                          if (vm.appliedCoupon != null && vm.appliedCoupon!.success && vm.discountedAmount > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                '₹ ${_formatAmount(vm.totalAmount)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade500,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                vm.isPaymentRequired ? '₹ $displayAmount' : 'FREE',
                                style: GoogleFonts.poppins(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: vm.isPaymentRequired ? AppColors.primaryRed : Colors.green,
                                ),
                              ),
                            ],
                          ),
                          if (vm.appliedCoupon != null && vm.appliedCoupon!.success)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                vm.appliedCoupon!.message ?? 'Coupon Applied Successfully!',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Features Bullet List
                      ...[
                        'Professional Profile Update',
                        'Theme Customization',
                        'Social Media Links',
                        'Thumbnail in Social Media',
                      ].map((feature) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF22C55E),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              feature,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 20),

                      // Discount Coupon Code Field
                      if (vm.appliedCoupon != null && vm.appliedCoupon!.success)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vm.appliedCouponCode.toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                    if (vm.appliedCoupon?.message != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          vm.appliedCoupon!.message!,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  ref.read(subscriptionViewModelProvider.notifier).resetCoupon();
                                  _couponController.clear();
                                },
                                child: Icon(Icons.close, color: Colors.green.shade600, size: 20),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primaryRed, width: 1.2),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: TextField(
                                    controller: _couponController,
                                    decoration: InputDecoration(
                                      hintText: 'DISCOUNT COUPON CODE (OPTIONAL)',
                                      hintStyle: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade500,
                                      ),
                                      border: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textCapitalization: TextCapitalization.characters,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: (vm.isPaymentButtonDisabled || vm.status == SubscriptionStatus.loading)
                                      ? null
                                      : () async {
                                          final userId = ref.read(authViewModelProvider.notifier).currentUser?.id;
                                          if (userId != null && _couponController.text.trim().isNotEmpty) {
                                            await ref.read(subscriptionViewModelProvider.notifier).applyCoupon(userId, _couponController.text.trim());
                                            final updatedVm = ref.read(subscriptionViewModelProvider);
                                            if (mounted) {
                                              if (updatedVm.appliedCoupon != null && updatedVm.appliedCoupon!.success) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(updatedVm.successMessage ?? 'Coupon applied successfully!'),
                                                    backgroundColor: Colors.green,
                                                  ),
                                                );
                                                if (!updatedVm.isSubscriptionDurationCoupon) {
                                                  await ref.read(subscriptionViewModelProvider.notifier).createPaymentOrder(userId);
                                                }
                                              } else if (updatedVm.errorMessage != null) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(updatedVm.errorMessage!),
                                                    backgroundColor: AppColors.deleteRed,
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryRed,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 18),
                                  ),
                                  child: vm.status == SubscriptionStatus.loading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'APPLY',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                            // Inline error message
                            if (vm.errorMessage != null && vm.errorMessage!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6, left: 4),
                                child: Text(
                                  vm.errorMessage!,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 20),

                      // Pay Now Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (vm.paymentStatus == PaymentStatus.processing || vm.status == SubscriptionStatus.loading)
                              ? null
                              : () async {
                                  final nav = Navigator.of(context);
                                  final success = await _initiatePayment();
                                  if (success) {
                                    nav.pop(); // Close checkout sheet ONLY on successful launch/upgrade
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: vm.paymentStatus == PaymentStatus.processing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  vm.isPaymentRequired ? 'Pay Now' : 'Apply & Upgrade',
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
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeViewModel = ref.watch(themeViewModelProvider);
    final colors = themeViewModel.colors;

    final authVm = ref.watch(authViewModelProvider);
    final profileVm = ref.watch(profileViewModelProvider);
    final cardVm = ref.watch(cardViewModelProvider);
    final user = profileVm.user ?? authVm.currentUser;
    final cardImage = cardVm.currentCard?.profileImageName;
    final profileImage = (cardImage != null && cardImage.isNotEmpty) ? cardImage : user?.profileImage;

    final successMessage = ref.watch(subscriptionViewModelProvider.select((vm) => vm.successMessage,
    ));
    final errorMessage = ref.watch(subscriptionViewModelProvider.select((vm) => vm.errorMessage,
    ));

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
          ref.read(subscriptionViewModelProvider.notifier).clearMessages();
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
      appBar: MasterAppBar(
        titleText: 'Subscription',
        style: MasterHeaderStyle.gradient,
        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
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
        child: ResponsiveCenter(
          child: RefreshIndicator(
            onRefresh: _loadSubscription,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
            child: Consumer(builder: (context, ref, child) {
  final vm = ref.watch(subscriptionViewModelProvider);
                final displayName = user?.displayName ?? 'User';
                final email = user?.email ?? '';

                final profileCard = Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.6), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircularProfileAvatar(
                        radius: 30,
                        size: 60,
                        imageUrl: profileImage != null && profileImage.isNotEmpty
                            ? UploadUrlResolver.resolve(profileImage, type: 'profile')
                            : null,
                        fallbackText: user?.initials ?? 'U',
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E233A),
                              ),
                            ),
                            Text(
                              email,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: vm.subscription?.isActive == true ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                vm.subscription?.isActive == true ? 'PREMIUM MEMBER' : 'FREE ACCOUNT',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: vm.subscription?.isActive == true ? Colors.green : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );

                final isPremiumUser = vm.subscription?.isActive == true;
                final planButtonText = isPremiumUser ? 'Extend Plan' : 'Upgrade Plan';

                final List<Widget> slides = [];
                slides.add(_buildCarouselCard(
                  title: 'PREMIUM',
                  price: '₹ 365',
                  billingInfo: '/ Year',
                  features: [
                    {'included': true, 'label': 'Unlimited Cards/Professional profiles'},
                    {'included': true, 'label': 'Unlimited card scans & contact save'},
                    {'included': true, 'label': 'All premium card themes available'},
                    {'included': true, 'label': 'Ad-free experience'},
                  ],
                  buttonLabel: planButtonText,
                  onPressed: _openCheckoutModal,
                ));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    profileCard,
                    if (vm.subscription?.isActive == true)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.6), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Membership Type', style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14)),
                                Text('PREMIUM', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Days Remaining', style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14)),
                                Text('${vm.subscription?.daysRemaining ?? 0} Days', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryRed)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('End Date', style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14)),
                                Text(vm.subscription?.subscriptionEnd ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    // Carousel Card Container
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.6), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Promo Code Row (Independent Input Box & APPLY Button with 5px spacing)
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primaryRed, width: 1.2),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: TextField(
                                    controller: _couponController,
                                    decoration: InputDecoration(
                                      hintText: 'HAVE A PROMO CODE? APPLY HERE',
                                      hintStyle: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade500,
                                      ),
                                      border: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textCapitalization: TextCapitalization.characters,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5), // 5px spacing
                              SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: (vm.isPaymentButtonDisabled || vm.status == SubscriptionStatus.loading)
                                      ? null
                                      : () async {
                                          final userId = ref.read(authViewModelProvider.notifier).currentUser?.id;
                                          if (userId != null && _couponController.text.trim().isNotEmpty) {
                                            await ref.read(subscriptionViewModelProvider.notifier).applyCoupon(userId, _couponController.text.trim());
                                            final updatedVm = ref.read(subscriptionViewModelProvider);
                                            if (mounted) {
                                              if (updatedVm.appliedCoupon != null && updatedVm.appliedCoupon!.success) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(updatedVm.successMessage ?? 'Coupon applied successfully!'),
                                                    backgroundColor: Colors.green,
                                                  ),
                                                );
                                                if (!updatedVm.isSubscriptionDurationCoupon) {
                                                  _openCheckoutModal(preserveCoupon: true);
                                                  await ref.read(subscriptionViewModelProvider.notifier).createPaymentOrder(userId);
                                                }
                                              } else if (updatedVm.errorMessage != null) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(updatedVm.errorMessage!),
                                                    backgroundColor: AppColors.deleteRed,
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryRed,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 18),
                                  ),
                                  child: Text(
                                    'APPLY',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Plan Carousel PageView
                          SizedBox(
                            height: 280,
                            child: PageView(
                              controller: _pageController,
                              onPageChanged: (idx) {
                                setState(() {
                                  _currentPage = idx;
                                });
                              },
                              children: slides,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Page Indicator Dots
                          if (slides.length > 1)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(slides.length, (index) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: _currentPage == index ? 10 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _currentPage == index ? AppColors.primaryRed : Colors.grey.shade400,
                                    shape: BoxShape.circle,
                                  ),
                                );
                              }),
                            ),
                          if (slides.length > 1) const SizedBox(height: 16),

                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.6), width: 1.2),
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
                              'Free User Privileges',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E233A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const _BenefitItem(
                              icon: Icons.badge,
                              title: 'Lifetime digital business card',
                              subtitle: 'Single card theme with customization',
                            ),
                            const SizedBox(height: 12),
                            const _BenefitItem(
                              icon: Icons.person,
                              title: 'Professional profile management',
                              subtitle: '1 profile management included',
                            ),
                            const SizedBox(height: 12),
                            const _BenefitItem(
                              icon: Icons.qr_code_scanner,
                              title: '25 scans & contact saves',
                              subtitle: 'Business card scanning and storage limit',
                            ),
                            const SizedBox(height: 12),
                            const _BenefitItem(
                              icon: Icons.share,
                              title: 'Multi-channel sharing',
                              subtitle: 'Share via App, QR code, NFC & link',
                            ),
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              'Premium Features',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryRed,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Everything in the Free plan, plus:',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const _BenefitItem(
                              icon: Icons.style,
                              title: 'Unlimited Cards & Profiles',
                              subtitle: 'Create and manage unlimited cards and professional profiles',
                            ),
                            const SizedBox(height: 12),
                            const _BenefitItem(
                              icon: Icons.center_focus_strong,
                              title: 'Unlimited Card Scans',
                              subtitle: 'Scan and save unlimited business contacts',
                            ),
                            const SizedBox(height: 12),
                            const _BenefitItem(
                              icon: Icons.palette,
                              title: 'All Premium Card Themes',
                              subtitle: 'Full access to all current and upcoming premium themes',
                            ),
                            const SizedBox(height: 12),
                            const _BenefitItem(
                              icon: Icons.block,
                              title: 'Ad-free Experience',
                              subtitle: 'Zero advertisements displayed across the app',
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _openCheckoutModal,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryRed,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  planButtonText,
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
      ),
      ),
      bottomNavigationBar: const GlobalBottomNav(),
    );
  }

  Widget _buildCarouselCard({
    required String title,
    required String price,
    required String billingInfo,
    required List<Map<String, dynamic>> features,
    required String buttonLabel,
    required VoidCallback? onPressed,
    bool isCurrentPlan = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with Red Gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryRed, AppColors.secondaryRed],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      billingInfo,
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Features List
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: features.map((feature) {
                  final bool included = feature['included'] as bool;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          included ? Icons.check_circle : Icons.cancel,
                          color: included ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature['label'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: included ? const Color(0xFF1E293B) : Colors.grey.shade500,
                              fontWeight: included ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Action Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 38,
              child: isCurrentPlan
                  ? Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300, width: 1.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        buttonLabel,
                        style: GoogleFonts.inter(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: onPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        buttonLabel,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitItem extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
