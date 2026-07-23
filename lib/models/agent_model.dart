class AgentModel {
  final int id;
  final String name;
  final String? agentCode;
  final String? district;
  final String? phone;
  final String? email;

  AgentModel({
    required this.id,
    required this.name,
    this.agentCode,
    this.district,
    this.phone,
    this.email,
  });

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    return AgentModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      agentCode: json['agent_code']?.toString(),
      district: json['district']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
    );
  }
}
