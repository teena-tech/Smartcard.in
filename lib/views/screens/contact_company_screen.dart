import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/support_viewmodel.dart';
import '../../repositories/user_repository.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/common_drawer.dart';
import 'home_screen.dart';
import '../../core/utils/responsive.dart';

import '../widgets/global_bottom_nav.dart';

class ContactCompanyScreen extends StatefulWidget {
  final String? initialPrefill;
  final String? initialType;

  const ContactCompanyScreen({
    super.key,
    this.initialPrefill,
    this.initialType,
  });

  @override
  State<ContactCompanyScreen> createState() => _ContactCompanyScreenState();
}

class _ContactCompanyScreenState extends State<ContactCompanyScreen> {
  String _selectedType = 'complaint';
  final TextEditingController _textController = TextEditingController();
  final UserRepository _userRepository = UserRepository();
  
  List<Map<String, dynamic>> _reports = [];
  bool _isLoadingReports = false;
  bool _isSubmitting = false;

  final List<Map<String, String>> _reportTypes = [
    {'value': 'review', 'label': 'Review'},
    {'value': 'complaint', 'label': 'Complaint'},
    {'value': 'change_agent', 'label': 'Change Agent'},
    {'value': 'agent_request', 'label': 'Agent Request'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null && widget.initialType!.isNotEmpty) {
      _selectedType = widget.initialType!;
    }
    if (widget.initialPrefill != null && widget.initialPrefill!.isNotEmpty) {
      _textController.text = widget.initialPrefill!;
    }
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoadingReports = true);
    try {
      final reports = await _userRepository.getUserReports();
      setState(() {
        _reports = reports;
      });
    } catch (e) {
      debugPrint('Error loading reports: $e');
    } finally {
      setState(() => _isLoadingReports = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;

    return Scaffold(
      backgroundColor: colors.backgroundStart,
      bottomNavigationBar: const GlobalBottomNav(),
      drawer: const CommonDrawer(
        backTitle: 'Back to Support',
      ),
      appBar: CommonAppBar(
        titleText: 'SUPPORT REQUEST',
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
        child: RefreshIndicator(
          onRefresh: _loadReports,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildForm(context, colors),
                const SizedBox(height: 32),
                Text(
                  'MY REQUESTS (${_reports.length})',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.muted,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoadingReports && _reports.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ))
                else
                  _buildRequestsList(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, dynamic colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Request', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: colors.text)),
          const SizedBox(height: 8),
          Divider(color: colors.border),
          const SizedBox(height: 16),
          
          Text('Request Type', style: GoogleFonts.inter(fontSize: 12, color: colors.muted)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colors.panel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedType,
                isExpanded: true,
                dropdownColor: colors.card,
                items: _reportTypes.map((type) => DropdownMenuItem(
                  value: type['value'],
                  child: Text(type['label']!, style: GoogleFonts.inter(fontSize: 14, color: colors.text)),
                )).toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Text('Request Text', style: GoogleFonts.inter(fontSize: 12, color: colors.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 4,
            style: GoogleFonts.inter(fontSize: 14, color: colors.text),
            decoration: InputDecoration(
              hintText: 'Enter your request...',
              hintStyle: GoogleFonts.inter(fontSize: 14, color: colors.muted.withValues(alpha: 0.15)),
              filled: true,
              fillColor: colors.panel,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.text.withValues(alpha: 0.15))),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : () async {
                final text = _textController.text.trim();
                if (text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter your request text')),
                  );
                  return;
                }

                setState(() => _isSubmitting = true);
                final supportVm = context.read<SupportViewModel>();
                final success = await supportVm.submitReport(_selectedType, text);
                
                if (!mounted) return;
                
                if (success) {
                  _textController.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Request submitted successfully!')),
                  );
                  _loadReports();
                } else {
                  final err = supportVm.errorMessage ?? 'Failed to submit request';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err)),
                  );
                }
                setState(() => _isSubmitting = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFA0000),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFFA0000).withValues(alpha: 0.6),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _isSubmitting 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text('Submit Request', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(dynamic colors) {
    if (_reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'No support requests found.',
            style: GoogleFonts.inter(color: colors.muted, fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      children: _reports.map((req) {
        final typeRaw = req['report_type'] ?? 'request';
        final typeLabel = typeRaw.toString().toUpperCase().replaceAll('_', ' ');
        
        String dateStr = '';
        if (req['created_at'] != null) {
          try {
            final parsed = DateTime.parse(req['created_at'].toString()).toLocal();
            final day = parsed.day.toString().padLeft(2, '0');
            final month = parsed.month.toString().padLeft(2, '0');
            final year = parsed.year;
            final hour = parsed.hour.toString().padLeft(2, '0');
            final minute = parsed.minute.toString().padLeft(2, '0');
            dateStr = '$day-$month-$year $hour:$minute';
          } catch (_) {
            dateStr = req['created_at'].toString();
          }
        }
        
        final statusRaw = (req['status'] ?? 'pending').toString().toUpperCase();
        final textStr = req['report_text'] ?? '';
        final replyStr = req['admin_reply'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(typeLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: colors.muted, letterSpacing: 0.5)),
                      if (dateStr.isNotEmpty)
                        Text(dateStr, style: GoogleFonts.inter(fontSize: 11, color: colors.muted)),
                    ],
                  ),
                  _buildStatusBadge(statusRaw, colors),
                ],
              ),
              const SizedBox(height: 12),
              Text(textStr, style: GoogleFonts.inter(fontSize: 14, color: colors.text)),
              if (replyStr.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.panel,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin Reply', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: colors.muted)),
                      const SizedBox(height: 4),
                      Text(replyStr, style: GoogleFonts.inter(fontSize: 13, color: colors.text)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusBadge(String status, dynamic colors) {
    final bool isReplied = status == 'REPLIED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isReplied ? Colors.blue.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontSize: 10, 
          fontWeight: FontWeight.bold, 
          color: isReplied ? Colors.blue : Colors.orange
        ),
      ),
    );
  }
}
