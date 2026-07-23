import 'package:flutter/foundation.dart';
import '../models/agent_model.dart';
import '../repositories/agent_repository.dart';
import '../models/user_model.dart';

class AgentViewModel extends ChangeNotifier {
  final AgentRepository _repository;

  bool _isLoading = false;
  List<AgentModel> _agents = [];
  String? _errorMessage;

  AgentViewModel(this._repository);

  bool get isLoading => _isLoading;
  List<AgentModel> get agents => _agents;
  String? get errorMessage => _errorMessage;

  Future<void> loadAgentsForDistrict(String? district) async {
    if (district == null || district.isEmpty) {
      _agents = [];
      notifyListeners();
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _agents = await _repository.getAgentsByDistrict(district);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> requestAgent(int agentId) async {
    try {
      await _repository.requestAgent(agentId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
