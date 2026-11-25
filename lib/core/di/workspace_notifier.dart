import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class WorkspaceState {
  final bool isCorporateActive;
  final bool isOrganizationActive;
  final bool isPersonalActive;
  final String? companyId;
  final String companyName;
  final String organizationName;
  final String? companyLogo;
  final String? organizationLogo;
  final Color corporateBrandColor;
  final Color organizationBrandColor;
  final String corporateDisclaimer;
  final String organizationDisclaimer;
  final bool isCompanyAdmin;
  final bool isEmployee;

  const WorkspaceState({
    this.isCorporateActive = false,
    this.isOrganizationActive = false,
    this.isPersonalActive = true,
    this.companyId,
    this.companyName = '',
    this.organizationName = '',
    this.companyLogo,
    this.organizationLogo,
    this.corporateBrandColor = const Color(0xFF0284C7),
    this.organizationBrandColor = const Color(0xFF0284C7),
    this.corporateDisclaimer = '',
    this.organizationDisclaimer = '',
    this.isCompanyAdmin = false,
    this.isEmployee = true,
  });

  WorkspaceState copyWith({
    bool? isCorporateActive,
    bool? isOrganizationActive,
    bool? isPersonalActive,
    String? companyId,
    String? companyName,
    String? organizationName,
    String? companyLogo,
    String? organizationLogo,
    Color? corporateBrandColor,
    Color? organizationBrandColor,
    String? corporateDisclaimer,
    String? organizationDisclaimer,
    bool? isCompanyAdmin,
    bool? isEmployee,
  }) {
    return WorkspaceState(
      isCorporateActive: isCorporateActive ?? this.isCorporateActive,
      isOrganizationActive: isOrganizationActive ?? this.isOrganizationActive,
      isPersonalActive: isPersonalActive ?? this.isPersonalActive,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      organizationName: organizationName ?? this.organizationName,
      companyLogo: companyLogo ?? this.companyLogo,
      organizationLogo: organizationLogo ?? this.organizationLogo,
      corporateBrandColor: corporateBrandColor ?? this.corporateBrandColor,
      organizationBrandColor: organizationBrandColor ?? this.organizationBrandColor,
      corporateDisclaimer: corporateDisclaimer ?? this.corporateDisclaimer,
      organizationDisclaimer: organizationDisclaimer ?? this.organizationDisclaimer,
      isCompanyAdmin: isCompanyAdmin ?? this.isCompanyAdmin,
      isEmployee: isEmployee ?? this.isEmployee,
    );
  }
}

class WorkspaceNotifier extends Notifier<WorkspaceState> {
  @override
  WorkspaceState build() {
    return const WorkspaceState();
  }
}

final workspaceProvider =
    NotifierProvider<WorkspaceNotifier, WorkspaceState>(WorkspaceNotifier.new);
