import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_riverpod_providers.dart';
import '../../core/utils/responsive.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const List<Map<String, dynamic>> _aboutSections = [
    {
      'title': 'A Trusted Partner for Digital Transformation',
      'paragraphs': [
        'In an era where digital presence defines business success, Antz Media Digital Solutions has emerged as a key partner for businesses that want stronger online visibility, better customer engagement, and scalable digital systems.',
        'Recognized for practical strategy and client-focused execution, the company supports brands that want to simplify web, marketing, and digital communication under one reliable team.'
      ]
    },
    {
      'title': 'A Leader in Digital Innovation',
      'paragraphs': [
        'Antz Media combines creativity, technology and measurable planning to deliver useful digital outcomes. Whether a business is launching, expanding, or modernizing, the team builds solutions aligned with real growth goals instead of generic templates.'
      ]
    },
    {
      'title': 'What Sets Antz Media Apart?',
      'paragraphs': [
        'Its strength lies in a connected service model that brings App development, web development, digital marketing, branding and multimedia production into one workflow.'
      ],
      'bullets': [
        'Strategic Expertise: Campaigns designed for business growth and not just visibility.',
        'Creative Excellence: Strong visuals, engaging media, and polished digital experiences.',
        'Adaptability: Support for fast-changing trends including AI-driven marketing and immersive content.'
      ]
    }
  ];

  static const Map<String, dynamic> _termsContent = {
    'title': 'Terms & Conditions',
    'subtitle': 'Terms & Conditions',
    'updatedAt': '23-07-2026',
    'sections': [
      {
        'heading': '1. Introduction',
        'paragraphs': [
          'By accessing or using TheSmartCards.in or its related mobile application, you agree to be bound by these Terms and Conditions. If you disagree, do not use the services. We may revise these terms at any time, and continued use constitutes acceptance of changes.'
        ]
      },
      {
        'heading': '2. User Accounts',
        'bullets': [
          'Registration: Users must provide accurate, current information to access certain features.',
          'Security: You are responsible for maintaining account confidentiality and all activities under your account.',
          'Age Restriction: Users must be at least 15 years old.'
        ]
      },
      {
        'heading': '3. Services and Products',
        'bullets': [
          'Scope: We provide products and services related to smart cards, subscriptions, and supporting digital tools.',
          'Modifications: We may modify, suspend, or discontinue services at any time without notice.',
          'Payment: Fees for products and services are non-refundable unless stated otherwise. Subscription services may auto-renew unless cancelled.'
        ]
      },
      {
        'heading': '4. Return and Refund Policy',
        'bullets': [
          'Physical NFC Cards: Returns are accepted within 15 days of delivery. Card cost may be refunded or a new card may be reissued on request. Refunds are processed to the original payment method within 14 business days.',
          'Digital Card Service: Subscription payments are non-refundable. Contact support within 7 days for issue resolution.'
        ]
      },
      {
        'heading': '5. User Data and Privacy',
        'bullets': [
          'Data Collection: We may collect personal information, payment details, usage data, device information, cookies, and user-generated content uploaded through the service.',
          'Use of Data: Data is used to deliver services, process payments, improve user experience, and support optional marketing communication settings.',
          'Information Sharing: We do not sell user data. We may share it with trusted service providers, legal authorities when required, or affiliated entities during business transitions.'
        ]
      },
      {
        'heading': '6. Data Security',
        'bullets': [
          'We use encryption, access controls, and regular audits to protect user data.',
          'No internet transmission or storage system can be guaranteed 100% secure.'
        ]
      },
      {
        'heading': '7. Service Agreement',
        'bullets': [
          'User Obligations: Do not misuse the app or website for illegal activities, spam, or infringement of intellectual property.',
          'Termination: We may suspend or terminate accounts that violate these terms.'
        ]
      },
      {
        'heading': '8. Disclaimers and Liability',
        'bullets': [
          'As Is Basis: Services are provided without warranties unless explicitly stated.',
          'Limitation of Liability: We are not liable for indirect, incidental, or consequential damages arising from service use.'
        ]
      },
      {
        'heading': '9. Governing Law',
        'paragraphs': [
          'These terms are governed by the laws of India. Disputes will be resolved through applicable legal process in Kochi.'
        ]
      },
      {
        'heading': '10. Contact',
        'paragraphs': [
          'For questions, contact support@thesmartcards.in or Antzmedia Digital Solutions Pvt Ltd, Shine Road, Vyttila 682019.'
        ]
      }
    ]
  };

  static const Map<String, dynamic> _privacyContent = {
    'title': 'Privacy Policy',
    'subtitle': 'Privacy Policy for TheSmartCards.in and Related Mobile Application',
    'updatedAt': '23-07-2026',
    'sections': [
      {
        'heading': '1. Introduction',
        'paragraphs': [
          'This Privacy Policy explains how TheSmartCards.in and its related mobile application collect, use, store, and protect personal information in line with applicable Indian legal requirements.'
        ]
      },
      {
        'heading': '2. Information We Collect',
        'bullets': [
          'Personal Information: name, email address, postal address, professional address, phone number, date of birth, gender, and other optional profile information.',
          'Payment Information: card details, UPI identifiers, or payment-related data processed through secure third-party gateways.',
          'Usage Data: IP address, browser type, device identifiers, app or site activity, and interaction history.'
        ]
      },
      {
        'heading': '3. Purpose of Data Collection',
        'paragraphs': ['Your information may be used to:'],
        'bullets': [
          'Create and manage your account.',
          'Deliver services, process payments, and fulfill orders.',
          'Provide customer support and respond to enquiries.',
          'Personalize content, recommendations, and relevant communication.',
          'Improve app functionality, user experience, and fraud prevention controls.'
        ]
      },
      {
        'heading': '4. Data Sharing and Disclosure',
        'paragraphs': ['We may share information with:'],
        'bullets': [
          'Third-party service providers such as payment gateways, hosting providers, analytics tools, and marketing partners under confidentiality obligations.',
          'Legal or regulatory authorities when disclosure is required by law.',
          'Business successors or affiliates during restructuring, merger, or acquisition activity.'
        ]
      },
      {
        'heading': '5. Data Storage and Security',
        'bullets': [
          'Data is stored on secure servers in India, with transfers handled in line with Indian law and equivalent protection standards.',
          'Security controls include access management, process restrictions, and protective technical measures.'
        ]
      },
      {
        'heading': '6. Your Rights Under Indian Law',
        'paragraphs': ['You have the right to:'],
        'bullets': [
          'Access, review, or request a copy of your personal data.',
          'Correct inaccuracies or update information.',
          'Withdraw consent for specific processing activities when legally permitted.',
          'Request deletion of data, subject to statutory and operational obligations.',
          'Raise grievances with the designated support or grievance contact.'
        ]
      },
      {
        'heading': '7. Cookies and Tracking Technologies',
        'paragraphs': [
          'We may use cookies, web beacons, and similar technologies to improve functionality, measure usage, and support relevant communication and experience optimization.'
        ]
      }
    ]
  };

  void _showLegalDialog(BuildContext context, Map<String, dynamic> content, AppColors colors) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: colors.backgroundStart,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: colors.border),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360, maxHeight: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content['title'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          content['subtitle'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: colors.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Last Updated: ${content['updatedAt']}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: colors.muted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ...((content['sections'] as List<dynamic>).map((secData) {
                          final sec = secData as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sec['heading'] ?? '',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: colors.text,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (sec['paragraphs'] != null)
                                  ...((sec['paragraphs'] as List<dynamic>).map((paraData) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        paraData as String,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          height: 1.6,
                                          color: colors.muted,
                                        ),
                                      ),
                                    );
                                  })),
                                if (sec['bullets'] != null)
                                  ...((sec['bullets'] as List<dynamic>).map((bulletData) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('- ', style: GoogleFonts.inter(fontSize: 13, color: colors.muted)),
                                          Expanded(
                                            child: Text(
                                              bulletData as String,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                height: 1.6,
                                                color: colors.muted,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  })),
                              ],
                            ),
                          );
                        })),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Close',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeViewModel = ref.watch(themeViewModelProvider);
    final colors = themeViewModel.colors;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/login.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: ResponsiveCenter(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Brand Logo (Transparent)
            Image.asset(
              'assets/images/smartlogo.png',
              height: 54,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),

            const SizedBox(height: 24),
            // About Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.6), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Antz Media',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...(_aboutSections.map((sec) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sec['title'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (sec['paragraphs'] != null)
                            ...((sec['paragraphs'] as List<String>).map((para) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  para,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    height: 1.6,
                                    color: colors.muted,
                                  ),
                                ),
                              );
                            })),
                          if (sec['bullets'] != null)
                            ...((sec['bullets'] as List<String>).map((bullet) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('- ', style: GoogleFonts.inter(fontSize: 13, color: colors.muted)),
                                    Expanded(
                                      child: Text(
                                        bullet,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          height: 1.6,
                                          color: colors.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            })),
                        ],
                      ),
                    );
                  })),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 12),
                  // Terms and Privacy Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _showLegalDialog(context, _termsContent, colors),
                        child: Text(
                          'Terms & Conditions',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '|',
                          style: TextStyle(color: colors.border),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showLegalDialog(context, _privacyContent, colors),
                        child: Text(
                          'Privacy Policy',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '© 2026 SmartCard Inc. All rights reserved.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: colors.muted,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      ),
    );
  }
}
