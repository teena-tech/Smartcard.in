import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../viewmodels/card_viewmodel.dart';
import '../../../viewmodels/customize_viewmodel.dart';
import '../../../viewmodels/theme_viewmodel.dart';
import '../../widgets/common_drawer.dart';
import '../../widgets/customize_flow_widgets.dart';

class CardCustomizationScreen extends StatefulWidget {
  const CardCustomizationScreen({super.key});

  @override
  State<CardCustomizationScreen> createState() => _CardCustomizationScreenState();
}

class _CardCustomizationScreenState extends State<CardCustomizationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final customizeVm = context.read<CustomizeViewModel>();
    final cardVm = context.read<CardViewModel>();
    final userId = cardVm.userId;
    final workProfileId = cardVm.currentCard?.workProfileId;

    if (userId.isNotEmpty) {
      await Future.wait([
        customizeVm.fetchTemplates(),
        customizeVm.fetchTheme(userId, workProfileId: workProfileId),
      ]);
    }
  }

  void _handleSaveTemplate(Map<String, dynamic> template) async {
    final customizeVm = context.read<CustomizeViewModel>();
    final cardVm = context.read<CardViewModel>();
    final userId = cardVm.userId;
    final workProfileId = cardVm.currentCard?.workProfileId;

    if (userId.isEmpty) return;

    final payload = {
      'template_id': template['id'],
      'template_key': template['theme_key'] ?? 'template_0',
    };
    
    await customizeVm.saveTemplate(userId, payload, workProfileId: workProfileId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    final cardVm = context.watch<CardViewModel>();
    final customizeVm = context.watch<CustomizeViewModel>();
    final currentCard = cardVm.currentCard;
    final templates = customizeVm.templates;
    final themeData = customizeVm.themeData ?? {};

    return Scaffold(
      key: _scaffoldKey,
      drawer: const CommonDrawer(),
      backgroundColor: colors.backgroundStart,
      appBar: SmartCardsFlowAppBar(
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        initials: 'U',
        onProfileTap: () {},
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Live Preview Section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              color: colors.section,
              child: Column(
                children: [
                  Text(
                    'Live Preview',
                    style: GoogleFonts.inter(
                      color: colors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLivePreviewCard(context, cardVm, themeData),
                ],
              ),
            ),
            
            // Customization Options Section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Templates',
                      style: GoogleFonts.inter(
                        color: colors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (customizeVm.isLoading && templates.isEmpty)
                      const Center(child: CircularProgressIndicator())
                    else if (templates.isEmpty)
                      Text(
                        'No templates available',
                        style: GoogleFonts.inter(color: colors.muted),
                      )
                    else
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: templates.length,
                          itemBuilder: (context, index) {
                            final template = Map<String, dynamic>.from(templates[index] as Map);
                            final isSelected = themeData['template_id']?.toString() == template['id']?.toString();
                            
                            return GestureDetector(
                              onTap: () => _handleSaveTemplate(template),
                              child: Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primaryRed : colors.border,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  image: const DecorationImage(
                                    image: AssetImage('assets/images/template.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: double.infinity,
                                  color: Colors.black54,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    template['name'] ?? 'Template ${index + 1}',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 10),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                    const SizedBox(height: 24),
                    
                    // Further Customizations can be added here
                    Text(
                      'Advanced Settings',
                      style: GoogleFonts.inter(
                        color: colors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      tileColor: colors.section,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: const Icon(Icons.color_lens_outlined),
                      title: Text('Colors & Background', style: GoogleFonts.inter(color: colors.text)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // Navigate to specific background settings if needed
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePreviewCard(BuildContext context, CardViewModel cardVm, Map<String, dynamic> themeData) {
    final card = cardVm.currentCard;
    if (card == null) return const SizedBox(height: 200, child: Center(child: Text('No card selected')));

    return AspectRatio(
      aspectRatio: 1.586, // Standard credit card ratio
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  card.companyName.toUpperCase(),
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.contactless_outlined, color: Colors.white70),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.name.toUpperCase(),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (card.designation?.isNotEmpty ?? false)
                  Text(
                    card.designation!.toUpperCase(),
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
