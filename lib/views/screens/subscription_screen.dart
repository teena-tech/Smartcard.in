import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../viewmodels/card_viewmodel.dart';
import '../../core/constants/app_colors.dart';
import '../widgets/common_drawer.dart';
import '../../core/utils/responsive.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/circular_profile_avatar.dart';
import '../../core/utils/upload_url_resolver.dart';
import 'premium_payment_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final TextEditingController _couponController = TextEditingController();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _showBenefits = false;
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

    // If no payment is required or payable amount is zero, activate directly
    if (subscriptionViewModel.payableAmount == 0.0 || !subscriptionViewModel.isPaymentRequired) {
      final paymentData = {
        'razorpay_payment_id': 'free_activation_${DateTime.now().millisecondsSinceEpoch}',
        'razorpay_order_id': 'free_order_${DateTime.now().millisecondsSinceEpoch}',
        'razorpay_signature': 'free_signature',
        'coupon_code': subscriptionViewModel.appliedCouponCode.isNotEmpty
            ? subscriptionViewModel.appliedCouponCode
            : null,
        'payment_for': 'subscription',
        'payable_amount': 0.0,
      };

      final success = await subscriptionViewModel.confirmPayment(userId, paymentData);
      if (success && mounted) {
        _showSuccessDialog();
      }
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
                  Navigator.of(context).pop(); // Pop dialog
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop(); // Pop SubscriptionScreen
                  }
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

    final authVm = context.watch<AuthViewModel>();
    final profileVm = context.watch<ProfileViewModel>();
    final cardVm = context.watch<CardViewModel>();
    final user = profileVm.user ?? authVm.currentUser;
    final cardImage = cardVm.currentCard?.profileImageName;
    final profileImage = (cardImage != null && cardImage.isNotEmpty) ? cardImage : user?.profileImage;

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
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'Subscription',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/profile');
                },
                child: CircularProfileAvatar(
                  radius: 18,
                  size: 36,
                  imageUrl: profileImage != null && profileImage.isNotEmpty
                      ? UploadUrlResolver.resolve(profileImage, type: 'profile')
                      : null,
                  fallbackText: user?.initials ?? 'U',
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
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
            child: Consumer<SubscriptionViewModel>(
              builder: (context, vm, child) {
                final authVm = context.watch<AuthViewModel>();
                final profileVm = context.watch<ProfileViewModel>();
                final user = profileVm.user ?? authVm.currentUser;
                final profileImage = user?.profileImage;
                final displayName = user?.displayName ?? 'User';
                final email = user?.email ?? '';

                final profileCard = Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
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

                if (vm.subscription?.isActive == true) {
                  return Column(
                    children: [
                      profileCard,
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
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
                            const Icon(
                              Icons.verified_user_rounded,
                              color: Colors.green,
                              size: 80,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Your Premium plan is active!',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Membership Type', style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14)),
                                Text(vm.subscription?.membership ?? 'Premium', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
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
                                Text('Start Date', style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14)),
                                Text(vm.subscription?.subscriptionStart ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14)),
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
                    ],
                  );
                }

                final isExpired = vm.subscription != null && 
                    !vm.subscription!.isActive && 
                    vm.subscription!.membership.toLowerCase() != 'free';

                final List<Widget> slides = [];
                if (!isExpired) {
                  slides.add(_buildCarouselCard(
                    title: 'FREE',
                    price: '₹ 0',
                    billingInfo: '/ Year',
                    features: [
                      {'included': true, 'label': 'Create 1 smart card'},
                      {'included': true, 'label': 'Standard theme layouts'},
                      {'included': false, 'label': 'Cloud Sync & backup'},
                      {'included': false, 'label': 'Premium theme layouts'},
                    ],
                    buttonLabel: 'Current Plan',
                    onPressed: null, // Disabled
                    isCurrentPlan: true,
                  ));
                } else {
                  slides.add(_buildCarouselCard(
                    title: 'PREMIUM',
                    price: '₹ 365',
                    billingInfo: '/ Year',
                    features: [
                      {'included': true, 'label': 'Create unlimited smart cards'},
                      {'included': true, 'label': 'Premium theme layouts'},
                      {'included': true, 'label': 'Cloud Sync & backup'},
                      {'included': true, 'label': 'Priority Customer Support'},
                    ],
                    buttonLabel: 'Upgrade',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PremiumPaymentScreen(),
                        ),
                      );
                    },
                  ));
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    profileCard,
                    // Carousel Card Container
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
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Promo Code Row
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _couponController,
                                    decoration: InputDecoration(
                                      hintText: 'HAVE A PROMO CODE? APPLY HERE',
                                      hintStyle: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                    textCapitalization: TextCapitalization.characters,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ElevatedButton(
                                    onPressed: vm.isPaymentButtonDisabled
                                        ? null
                                        : () {
                                            final userId = context.read<AuthViewModel>().currentUser?.id;
                                            if (userId != null && _couponController.text.trim().isNotEmpty) {
                                              vm.applyCoupon(userId, _couponController.text.trim());
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryRed,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                    child: Text(
                                      'APPLY',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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

                          // Compare Plans Button
                          SizedBox(
                            width: 160,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _showBenefits = !_showBenefits;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryRed,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                _showBenefits ? 'Hide Details' : 'Upgrade Plan',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Conditionally Show Benefits
                    if (_showBenefits) ...[
                      const SizedBox(height: 20),
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
                                fontSize: 18,
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
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const PremiumPaymentScreen(),
                                    ),
                                  );
                                },
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
                                  'Upgrade',
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
                  ],
                );
              },
            ),
          ),
        ),
      ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 0,
        onTap: (index) {
          final dashVm = context.read<DashboardViewModel>();
          Navigator.pop(context);
          dashVm.setIndex(index == 2 ? 9 : index);
        },
      ),
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
        border: Border.all(color: Colors.grey.shade200),
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
