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

  static int _parseInt(dynamic val, [int fallback = 0]) {
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val != null) return int.tryParse(val.toString()) ?? fallback;
    return fallback;
  }

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    return AgentModel(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      agentCode: json['agent_code']?.toString(),
      district: json['district']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
    );
  }
}
