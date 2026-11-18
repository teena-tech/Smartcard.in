import 'package:flutter/material.dart';

/// WorkspaceProvider — simplified after removing Corporate/Personal mode.
/// Kept as a stub so existing `context.watch<WorkspaceProvider>()` calls
/// throughout the app don't break.  Always returns "personal / non-corporate".
class WorkspaceProvider extends ChangeNotifier {
  // Always personal mode
  bool get isCorporateActive => false;
  bool get isOrganizationActive => false;
  bool get isPersonalActive => true;

  String? get companyId => null;
  String get companyName => '';
  String get organizationName => '';
  String? get companyLogo => null;
  String? get organizationLogo => null;
  Color get corporateBrandColor => const Color(0xFF0284C7);
  Color get organizationBrandColor => const Color(0xFF0284C7);
  String get corporateDisclaimer => '';
  String get organizationDisclaimer => '';

  bool get isCompanyAdmin => false;
  bool get isEmployee => true;
}
