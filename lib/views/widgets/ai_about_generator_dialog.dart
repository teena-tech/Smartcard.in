import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:provider/provider.dart';
import 'lottie_loader.dart';

import '../../core/constants/app_colors.dart';
import '../../viewmodels/theme_viewmodel.dart';
import 'rich_text_editor.dart';

class AiAboutGeneratorDialog extends StatefulWidget {
  const AiAboutGeneratorDialog({super.key});

  @override
  State<AiAboutGeneratorDialog> createState() => _AiAboutGeneratorDialogState();
}

class _AiAboutGeneratorDialogState extends State<AiAboutGeneratorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _professionController = TextEditingController();
  final _companyController = TextEditingController();
  final _experienceController = TextEditingController();
  final _skillsController = TextEditingController();
  final _servicesController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isGenerating = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _professionController.dispose();
    _companyController.dispose();
    _experienceController.dispose();
    _skillsController.dispose();
    _servicesController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _generateContent() async {
    if (!_formKey.currentState!.validate()) return;

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      setState(() {
        _errorMessage = 'GEMINI_API_KEY is not configured in .env';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = '';
    });

    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
      
      final prompt = '''
You are an expert copywriter. Write a highly professional, engaging, and modern "About Us" or "About Me" profile for a digital business card.
Use the following details:
- Profession/Role: ${_professionController.text.trim()}
- Company Name: ${_companyController.text.trim()}
- Years of Experience: ${_experienceController.text.trim()}
- Key Skills: ${_skillsController.text.trim()}
- Services Offered: ${_servicesController.text.trim()}
- Brief Business Description: ${_descriptionController.text.trim()}

Guidelines:
- The tone should be professional, corporate, and engaging.
- Output ONLY the generated text, without any additional explanations.
- Format the output with clear paragraphs. Do NOT use markdown bolding/italics, just plain text with paragraphs.
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      if (response.text != null && response.text!.isNotEmpty) {
        if (!context.mounted) return;
        Navigator.of(context).pop(response.text!.trim());
      } else {
        setState(() {
          _errorMessage = 'Failed to generate content. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error generating content: \${e.toString()}';
      });
    } finally {
      if (context.mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Color textColor,
    required Color borderColor,
    int maxLines = 1,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.inter(color: textColor, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.inter(color: textColor.withValues(alpha: 0.15), fontSize: 13),
          hintStyle: GoogleFonts.inter(color: textColor.withValues(alpha: 0.15), fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: isRequired
            ? (value) => value == null || value.trim().isEmpty ? 'This field is required' : null
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: colors.card,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.primaryRed, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI About Generator',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: colors.text),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Provide some details to help the AI craft a professional profile for you.',
                style: GoogleFonts.inter(color: colors.muted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              if (_errorMessage.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    _errorMessage,
                    style: GoogleFonts.inter(color: Colors.red, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        RichTextEditor(
                          label: 'Profession / Role *',
                          hint: 'e.g., Software Developer',
                          controller: _professionController,
                          minLines: 1,
                          maxLines: 2,
                          colors: colors,
                        ),
                        const SizedBox(height: 16),
                        RichTextEditor(
                          label: 'Company Name *',
                          hint: 'e.g., Tech Solutions Inc.',
                          controller: _companyController,
                          minLines: 1,
                          maxLines: 2,
                          colors: colors,
                        ),
                        const SizedBox(height: 16),
                        RichTextEditor(
                          label: 'Years of Experience',
                          hint: 'e.g., 5 years',
                          controller: _experienceController,
                          minLines: 1,
                          maxLines: 2,
                          colors: colors,
                        ),
                        const SizedBox(height: 16),
                        RichTextEditor(
                          label: 'Key Skills',
                          hint: 'e.g., Flutter, Node.js, UI/UX',
                          controller: _skillsController,
                          minLines: 2,
                          maxLines: 3,
                          colors: colors,
                        ),
                        const SizedBox(height: 16),
                        RichTextEditor(
                          label: 'Services Offered',
                          hint: 'e.g., Web Development, App Creation',
                          controller: _servicesController,
                          minLines: 2,
                          maxLines: 3,
                          colors: colors,
                        ),
                        const SizedBox(height: 16),
                        RichTextEditorWithFormatting(
                          label: 'Business Description',
                          hint: 'Briefly describe what you do...',
                          controller: _descriptionController,
                          colors: colors,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _generateContent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isGenerating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: LottieLoader(size: 24),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Generate with AI',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
    );
  }
}
