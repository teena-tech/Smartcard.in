import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/card_viewmodel.dart';
import '../../../viewmodels/customize_viewmodel.dart';
import '../../../viewmodels/subscription_viewmodel.dart';
import '../../../viewmodels/theme_viewmodel.dart';
import '../../widgets/common_drawer.dart';
import '../../widgets/customize_flow_widgets.dart';
import '../../widgets/global_bottom_nav.dart';
import '../../../core/utils/customize_utils.dart';
import '../../../core/constants/app_colors.dart';
import '../subscription_screen.dart';

class CustomizeThemeScreen extends StatefulWidget {
  const CustomizeThemeScreen({super.key});

  @override
  State<CustomizeThemeScreen> createState() => _CustomizeThemeScreenState();
}

class _CustomizeThemeScreenState extends State<CustomizeThemeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<dynamic> _templates = [];
  bool _loading = true;
  bool _saving = false;
  String _message = '';
  String _error = '';
  String? _selectedTemplateId;
  String _selectedTemplateKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureCardContextLoaded().then((_) => _loadData());
    });
  }

  Future<void> _ensureCardContextLoaded() async {
    final authVm = context.read<AuthViewModel>();
    final cardVm = context.read<CardViewModel>();
    final user = authVm.currentUser;
    if (user == null) return;

    final userId = user.id ?? '';
    if (userId.isEmpty) return;

    if (cardVm.cards.isEmpty) {
      final name = '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim();
      cardVm.init(
        userId: userId,
        fallbackName: name.isNotEmpty ? name : 'User',
        fallbackPhone: user.phone ?? '',
        fallbackEmail: user.email,
      );
    }
  }

  Future<void> _loadData() async {
    final authVm = context.read<AuthViewModel>();
    final cardVm = context.read<CardViewModel>();
    final customizeVm = context.read<CustomizeViewModel>();
    final subVm = context.read<SubscriptionViewModel>();
    final userId = authVm.currentUser?.id ?? '';
    final workProfileId = cardVm.currentCard?.userId;

    if (userId.isEmpty) {
      if (!context.mounted) return;
      setState(() {
        _loading = false;
        _error = 'User id not found';
      });
      return;
    }

    if (!context.mounted) return;
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await Future.wait([
        customizeVm.fetchTemplates(),
        customizeVm.fetchTheme(userId, workProfileId: workProfileId),
        subVm.fetchSubscription(userId),
      ]);

      if (!context.mounted) return;
      final themeData = customizeVm.themeData ?? {};
      final templateId = themeData['template_id']?.toString();
      final templateKey = themeData['template_key']?.toString().trim() ?? '';

      setState(() {
        _templates = customizeVm.templates;
        _selectedTemplateId = templateId;
        _selectedTemplateKey = templateKey;
      });
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (context.mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool get _isDefaultSelected => _selectedTemplateKey.isEmpty || _selectedTemplateKey == 'template_0';

  String get _defaultThumb => 'assets/images/template.png';

  void _showUpgradePrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Color(0xFFEAB308), size: 28),
            const SizedBox(width: 10),
            Text(
              'Premium Template 🔒',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'This template is exclusive to Premium members. Upgrade to Premium to unlock all templates!',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Upgrade to Premium', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSelectDefault() async {
    final authVm = context.read<AuthViewModel>();
    final cardVm = context.read<CardViewModel>();
    final customizeVm = context.read<CustomizeViewModel>();
    final userId = authVm.currentUser?.id ?? '';
    final workProfileId = cardVm.currentCard?.userId;

    if (userId.isEmpty) {
      setState(() => _error = 'User id not found');
      return;
    }

    setState(() {
      _saving = true;
      _message = '';
      _error = '';
    });

    try {
      await customizeVm.saveTemplate(
        userId,
        const {'template_id': null, 'template_key': 'template_0'},
        workProfileId: workProfileId,
      );
      // Refresh global cards to reflect selection
      await cardVm.fetchCards(
        userId,
        fallbackName: authVm.currentUser?.displayName,
        fallbackPhone: authVm.currentUser?.phone ?? '',
        fallbackEmail: authVm.currentUser?.email,
      );
      if (!context.mounted) return;
      setState(() {
        _selectedTemplateId = null;
        _selectedTemplateKey = 'template_0';
        _message = 'Default template selected';
      });
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (context.mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _handleSaveTemplate(Map<String, dynamic> template) async {
    final authVm = context.read<AuthViewModel>();
    final cardVm = context.read<CardViewModel>();
    final customizeVm = context.read<CustomizeViewModel>();
    final subVm = context.read<SubscriptionViewModel>();
    final userId = authVm.currentUser?.id ?? '';
    final workProfileId = cardVm.currentCard?.userId;

    final isFree = (template['is_free'] ?? 1) == 1 || (template['is_free'] == true);
    final isPremiumUser = subVm.subscription?.isActive == true;

    if (!isFree && !isPremiumUser) {
      _showUpgradePrompt(context);
      return;
    }

    if (userId.isEmpty) {
      setState(() => _error = 'User id not found');
      return;
    }

    setState(() {
      _saving = true;
      _message = '';
      _error = '';
    });

    try {
      final payload = <String, dynamic>{
        'template_id': template['id'],
        'template_key': resolveTemplateKey(template).isNotEmpty ? resolveTemplateKey(template) : 'template_0',
      };
      await customizeVm.saveTemplate(
        userId,
        payload,
        workProfileId: workProfileId,
      );
      // Refresh global cards to reflect selection
      await cardVm.fetchCards(
        userId,
        fallbackName: authVm.currentUser?.displayName,
        fallbackPhone: authVm.currentUser?.phone ?? '',
        fallbackEmail: authVm.currentUser?.email,
      );

      if (!context.mounted) return;
      setState(() {
        _selectedTemplateId = template['id']?.toString();
        _selectedTemplateKey = payload['template_key']?.toString() ?? '';
        _message = 'Template saved successfully';
      });
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (context.mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _templateName(Map<String, dynamic> template, int index) {
    final value = firstNonEmptyString([
      template['name'],
      template['title'],
      'Theme ${index + 1}',
    ]);
    return value ?? 'Theme ${index + 1}';
  }

  bool _isTemplateSelected(Map<String, dynamic> template) {
    final templateId = template['id']?.toString() ?? '';
    final templateKey = resolveTemplateKey(template);
    return (_selectedTemplateKey.isNotEmpty && _selectedTemplateKey == templateKey) ||
        (_selectedTemplateId != null && _selectedTemplateId == templateId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    final cardVm = context.watch<CardViewModel>();

    return Scaffold(
      key: _scaffoldKey,
      drawer: const CommonDrawer(),
      backgroundColor: colors.backgroundStart,
      appBar: SmartCardsFlowAppBar(
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        initials: cardVm.selectedCardDetails == null ? 'U' : _previewInitials(cardVm),
        onProfileTap: () {},
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  'Choose Your Card Themes',
                  style: GoogleFonts.inter(
                    color: colors.text,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select a design or reset to default.',
                  style: GoogleFonts.inter(
                    color: colors.muted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: colors.section,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _isDefaultSelected ? const Color(0xFF22C55E) : colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        child: Stack(
                          children: [
                            SizedBox(
                              height: 180,
                              width: double.infinity,
                              child: Image.asset(
                                _defaultThumb,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Container(
                                  color: colors.border.withValues(alpha: 0.15),
                                  child: const Icon(Icons.image, color: Colors.white70),
                                ),
                              ),
                            ),
                            Container(
                              height: 180,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.1),
                                    Colors.black.withValues(alpha: 0.1),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'FREE',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            if (_isDefaultSelected)
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Currently Selected',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 14,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Default Card',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Reset colors, backgrounds, overlays, and template selection.',
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saving || _isDefaultSelected ? null : _handleSelectDefault,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isDefaultSelected ? const Color(0xFF16A34A) : colors.section,
                              foregroundColor: _isDefaultSelected ? Colors.white : colors.text,
                              elevation: 0,
                              side: BorderSide(color: _isDefaultSelected ? const Color(0xFF16A34A) : colors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              _isDefaultSelected ? 'Selected' : 'Use Default',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _templates.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) {
                    final template = Map<String, dynamic>.from(_templates[index] as Map);
                    final isSelected = _isTemplateSelected(template);
                    final thumb = resolveTemplateThumb(template);
                    final name = _templateName(template, index);
                    final isFree = (template['is_free'] ?? 1) == 1 || (template['is_free'] == true);

                    return Container(
                      decoration: BoxDecoration(
                        color: colors.section,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isSelected ? const Color(0xFF22C55E) : colors.border, width: isSelected ? 2 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: thumb.isNotEmpty
                                        ? Image.network(
                                            thumb,
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, stack) => _buildTemplatePlaceholder(name),
                                          )
                                        : _buildTemplatePlaceholder(name),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isFree ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (!isFree) ...[
                                            const Icon(Icons.lock, color: Colors.white, size: 10),
                                            const SizedBox(width: 3),
                                          ],
                                          Text(
                                            isFree ? 'FREE' : 'PRO',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                            child: Column(
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: colors.text,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _saving ? null : () => _handleSaveTemplate(template),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isSelected
                                          ? const Color(0xFF22C55E)
                                          : (!isFree ? const Color(0xFFD97706) : colors.section),
                                      foregroundColor: isSelected || !isFree ? Colors.white : colors.text,
                                      elevation: 0,
                                      side: BorderSide(
                                        color: isSelected
                                            ? const Color(0xFF22C55E)
                                            : (!isFree ? const Color(0xFFD97706) : colors.border),
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    child: Text(
                                      isSelected ? 'Selected' : (!isFree ? 'Unlock Pro' : 'Select'),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                if (_loading)
                  Text(
                    'Loading templates...',
                    style: GoogleFonts.inter(color: colors.muted, fontSize: 12),
                  ),
                if (_message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _message,
                    style: GoogleFonts.inter(color: Colors.green.shade700, fontSize: 12),
                  ),
                ],
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error,
                    style: GoogleFonts.inter(color: colors.danger, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _previewInitials(CardViewModel cardVm) {
    final details = cardVm.selectedCardDetails;
    final first = details?.firstName.trim() ?? '';
    final last = details?.lastName.trim() ?? '';
    final name = '$first $last'.trim();
    final fallbackUser = context.read<AuthViewModel>().currentUser;
    final displayName = name.isNotEmpty
        ? name
        : '${fallbackUser?.firstName ?? ''} ${fallbackUser?.lastName ?? ''}'.trim();
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((item) => item.trim().isNotEmpty)
        .take(2)
        .map((item) => item.trim()[0].toUpperCase())
        .toList();
    return parts.isNotEmpty ? parts.join() : 'U';
  }

  Widget _buildTemplatePlaceholder(String name) {
    final List<Color> gradientColors;
    final lowerName = name.toLowerCase();
    if (lowerName.contains('glass')) {
      gradientColors = [const Color(0xFF8B5CF6), const Color(0xFFEC4899)];
    } else if (lowerName.contains('neon') || lowerName.contains('cyber')) {
      gradientColors = [const Color(0xFF06B6D4), const Color(0xFF3B82F6)];
    } else if (lowerName.contains('gold') || lowerName.contains('luxury') || lowerName.contains('premium')) {
      gradientColors = [const Color(0xFFF59E0B), const Color(0xFFD97706)];
    } else if (lowerName.contains('dark') || lowerName.contains('minimal') || lowerName.contains('black')) {
      gradientColors = [const Color(0xFF334155), const Color(0xFF1E293B)];
    } else {
      gradientColors = [const Color(0xFFEF4444), const Color(0xFFB91C1C)];
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.style,
              color: Colors.white70,
              size: 28,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                name,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
