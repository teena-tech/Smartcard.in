import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/agent_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/support_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/common_drawer.dart';
import 'home_screen.dart';
import '../../core/utils/responsive.dart';
import 'support_chat_screen.dart';
import 'contact_company_screen.dart';
import '../widgets/global_bottom_nav.dart';

class SupportAgentScreen extends StatefulWidget {
  const SupportAgentScreen({super.key});

  @override
  State<SupportAgentScreen> createState() => _SupportAgentScreenState();
}

class _SupportAgentScreenState extends State<SupportAgentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = context.read<AuthViewModel>();
      final userId = authViewModel.currentUser?.id;
      if (userId != null) {
        context.read<SupportViewModel>().fetchSupportContext(userId);
      }
      final district = context.read<ProfileViewModel>().user?.district;
      context.read<AgentViewModel>().loadAgentsForDistrict(district);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    final supportVm = context.watch<SupportViewModel>();
    final agentVm = context.watch<AgentViewModel>();
    
    final contextData = supportVm.supportContext;
    final isLoading = supportVm.isLoading;
    final hasAssignedAgent = contextData?['has_assigned_agent'] == true;
    final assignedAgent = contextData?['assigned_agent'];

    // Combine district_agents from supportContext and AgentViewModel agents
    List<dynamic> districtAgentsList = [];
    if (contextData != null && contextData['district_agents'] is List && (contextData['district_agents'] as List).isNotEmpty) {
      districtAgentsList = List<dynamic>.from(contextData['district_agents']);
    }
    
    // Add agents from AgentViewModel if not already in the list
    final existingIds = districtAgentsList.map((e) => e['id']).toSet();
    for (final a in agentVm.agents) {
      if (!existingIds.contains(a.id)) {
        districtAgentsList.add({
          'id': a.id,
          'name': a.name,
          'code': a.agentCode ?? '-',
          'phone': a.phone ?? '-',
          'email': a.email ?? '-',
          'district': a.district ?? '-',
          'status': 'active',
        });
      }
    }

    return Scaffold(
      backgroundColor: colors.backgroundStart,
      bottomNavigationBar: const GlobalBottomNav(),
      drawer: const CommonDrawer(
        backTitle: 'Back to Support',
      ),
      appBar: CommonAppBar(
        titleText: 'SUPPORT AGENT',
        showProfile: true,
        onProfileTap: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 3)),
            (route) => false,
          );
        },
      ),
      body: ResponsiveCenter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading && contextData == null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Center(
                    child: Text('Loading support details...', style: GoogleFonts.inter(color: colors.muted)),
                  ),
                )
              else if (hasAssignedAgent && assignedAgent != null) ...[
                _buildAgentCard(context, colors, assignedAgent),
                const SizedBox(height: 24),
                
                // Change Agent Primary Action Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final agentName = assignedAgent['name']?.toString() ?? 'Not available';
                      final agentCode = assignedAgent['code']?.toString() ?? '-';
                      final userObj = contextData?['user'] ?? {};
                      final districtStr = userObj['district']?.toString() ?? '';
                      final stateStr = userObj['state_name']?.toString() ?? '';
                      final pincodeStr = userObj['pincode']?.toString() ?? '';
                      final locationParts = [districtStr, stateStr, pincodeStr].where((s) => s.isNotEmpty).join(', ');
                      
                      final prefillLines = [
                        'I would like to request a change of my assigned agent.',
                        '',
                        'Current agent: $agentName ($agentCode)',
                        'My location: ${locationParts.isNotEmpty ? locationParts : '-'}',
                        '',
                        'Reason:'
                      ];

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ContactCompanyScreen(
                            initialPrefill: prefillLines.join('\n'),
                            initialType: 'change_agent'
                          )
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFA0000),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_add_alt_1_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text('Change Agent', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.support_agent, size: 48, color: colors.muted),
                      const SizedBox(height: 16),
                      Text(
                        'No Agent Assigned',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: colors.text),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please select an agent from your district below to assist you.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 14, color: colors.muted, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'AVAILABLE AGENTS',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.muted,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDistrictAgentsList(context, colors, districtAgentsList, contextData),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentCard(BuildContext context, dynamic colors, Map<String, dynamic> agent) {
    final nameFromMap = agent['name']?.toString() ?? '';
    final firstName = agent['first_name']?.toString() ?? '';
    final lastName = agent['last_name']?.toString() ?? '';
    final constructedName = '$firstName $lastName'.trim();
    final name = nameFromMap.isNotEmpty
        ? nameFromMap
        : (constructedName.isNotEmpty ? constructedName : 'Assigned Agent');

    final code = agent['code']?.toString() ?? '-';
    final phone = agent['phone']?.toString() ?? '-';
    final email = agent['email']?.toString() ?? '-';
    final district = agent['district']?.toString() ?? '-';
    final pincode = agent['pincode']?.toString() ?? agent['pin_code']?.toString() ?? '-';
    final profileImage = agent['profile_image']?.toString() ?? agent['image']?.toString() ?? agent['avatar']?.toString() ?? agent['profile_picture']?.toString();
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assigned Agent', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: colors.text)),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.panel,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.border, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: (profileImage != null && profileImage.isNotEmpty)
                    ? Image.network(
                        profileImage,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Text(initials, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: colors.text)),
                      )
                    : Text(initials, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: colors.text)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: colors.text)),
                    Text(code, style: GoogleFonts.inter(fontSize: 12, color: colors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildActionButton(
                Icons.chat_bubble_outline, 
                'Chat', 
                colors, 
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SupportChatScreen()),
                  );
                }
              ),
              const SizedBox(width: 12),
              _buildActionButton(Icons.call_outlined, 'Call', colors, onTap: () async {
                 final cleanPhone = phone.replaceAll(RegExp(r'[^\+\d]'), '');
                 if (cleanPhone.isNotEmpty) {
                    final Uri url = Uri(scheme: 'tel', path: cleanPhone);
                    if (await canLaunchUrl(url)) {
                       await launchUrl(url);
                    }
                 }
              }),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Phone', phone, colors),
          _buildInfoRow('Email', email, colors),
          _buildInfoRow('District', district, colors),
          if (pincode != '-') _buildInfoRow('Pincode', pincode, colors),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, dynamic colors, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: label.toLowerCase() == 'chat' ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 10),
              Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, dynamic colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 14, color: colors.muted)),
          Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text)),
        ],
      ),
    );
  }

  Widget _buildDistrictAgentsList(BuildContext context, dynamic colors, List<dynamic> agents, Map<String, dynamic>? contextData) {
    if (agents.isEmpty) {
      return Center(
        child: Text('No agents available right now.',
            style: GoogleFonts.inter(color: colors.muted)),
      );
    }

    return Column(
      children: agents.map((agentItem) {
        final agent = agentItem is Map ? agentItem : {};
        final rawName = agent['name']?.toString() ?? '';
        final firstName = agent['first_name']?.toString() ?? '';
        final lastName = agent['last_name']?.toString() ?? '';
        final constructedName = '$firstName $lastName'.trim();
        final agentName = rawName.isNotEmpty
            ? rawName
            : (constructedName.isNotEmpty ? constructedName : 'Agent');
        final agentCode = agent['code']?.toString() ?? '-';
        final agentPhone = agent['phone']?.toString() ?? '-';
        final agentEmail = agent['email']?.toString() ?? '-';
        final agentDistrict = agent['district']?.toString() ?? '-';
        final agentStatus = agent['status']?.toString() ?? 'active';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(agentName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: colors.text)),
                  Text(agentCode, style: GoogleFonts.inter(fontSize: 12, color: colors.muted)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Phone: $agentPhone', style: GoogleFonts.inter(fontSize: 12, color: colors.muted)),
              Text('Email: $agentEmail', style: GoogleFonts.inter(fontSize: 12, color: colors.muted)),
              Text('District: $agentDistrict', style: GoogleFonts.inter(fontSize: 12, color: colors.muted)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: ElevatedButton(
                  onPressed: () {
                    final userObj = contextData?['user'] ?? {};
                    final districtStr = userObj['district']?.toString() ?? '';
                    final stateStr = userObj['state_name']?.toString() ?? '';
                    final pincodeStr = userObj['pincode']?.toString() ?? '';
                    final locationParts = [districtStr, stateStr, pincodeStr].where((s) => s.isNotEmpty).join(', ');
                    
                    final prefillLines = [
                      'I would like to request this agent assignment.',
                      '',
                      'Requested agent: $agentName ($agentCode)',
                      'Phone: $agentPhone',
                      'Email: $agentEmail',
                      'District: $agentDistrict',
                      'Status: ${agentStatus.toUpperCase()}',
                      '',
                      'My location: ${locationParts.isNotEmpty ? locationParts : '-'}',
                      '',
                      'Details:'
                    ];

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContactCompanyScreen(
                          initialPrefill: prefillLines.join('\n'),
                          initialType: 'agent_request'
                        )
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent ?? const Color(0xFFFA0000),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Request Agent', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
