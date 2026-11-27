import 'package:smartcard_flutter/core/network/dio_service.dart';
import 'package:smartcard_flutter/features/support_agent_screen/data/models/agent_model.dart';

class AgentRepository {
  final DioService dioService;

  AgentRepository(this.dioService);

  Future<List<AgentModel>> getAgentsByDistrict(String district) async {
    try {
      final response = await dioService.client.get('/agents', queryParameters: {'district': district});
      final List<dynamic> data = response.data is List ? response.data : (response.data['data'] ?? response.data['agents'] ?? []);
      return data.map((e) => AgentModel.fromJson(e)).toList();
    } catch (e) {
      // Fallback dummy data if API fails to prevent white screen
      return [
        AgentModel(id: 1, name: 'Agent A', district: district, agentCode: 'AG-101', phone: '+91 9876543210'),
        AgentModel(id: 2, name: 'Agent B', district: district, agentCode: 'AG-102'),
        AgentModel(id: 3, name: 'Agent C', district: district, agentCode: 'AG-103'),
      ];
    }
  }

  Future<void> requestAgent(int agentId) async {
    try {
      await dioService.client.post('/agents/$agentId/request');
    } catch (e) {
      // Silent catch for dummy implementation
    }
  }
}
