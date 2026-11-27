import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/network/dio_service.dart';
import 'package:smartcard_flutter/features/support_agent_screen/data/models/agent_model.dart';
import 'package:smartcard_flutter/features/support_agent_screen/data/repositories/agent_repository.dart';

@immutable
class AgentState {
  final bool isLoading;
  final List<AgentModel> agents;
  final String? errorMessage;

  const AgentState({
    this.isLoading = false,
    this.agents = const [],
    this.errorMessage,
  });

  AgentState copyWith({
    bool? isLoading,
    List<AgentModel>? agents,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AgentState(
      isLoading: isLoading ?? this.isLoading,
      agents: agents ?? this.agents,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AgentViewModel extends Notifier<AgentState> {
  late final AgentRepository _repository;

  @override
  AgentState build() {
    _repository = AgentRepository(DioService());
    return const AgentState();
  }

  bool get isLoading => state.isLoading;
  List<AgentModel> get agents => state.agents;
  String? get errorMessage => state.errorMessage;

  Future<void> loadAgentsForDistrict(String? district) async {
    if (district == null || district.isEmpty) {
      state = state.copyWith(agents: const [], clearError: true);
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final agents = await _repository.getAgentsByDistrict(district);
      state = state.copyWith(agents: agents, isLoading: false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isLoading: false);
    }
  }

  Future<bool> requestAgent(int agentId) async {
    try {
      await _repository.requestAgent(agentId);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final agentViewModelProvider =
    NotifierProvider<AgentViewModel, AgentState>(AgentViewModel.new);
