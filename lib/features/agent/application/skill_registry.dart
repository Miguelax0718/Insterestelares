import '../domain/agent_contracts.dart';
import '../domain/agent_models.dart';

class SkillRegistry {
  SkillRegistry([List<AgentSkill> skills = const []])
      : _skills = List<AgentSkill>.from(skills);

  final List<AgentSkill> _skills;

  List<AgentSkill> get skills => List<AgentSkill>.unmodifiable(_skills);

  void register(AgentSkill skill) {
    final index = _skills.indexWhere((s) => s.id == skill.id);
    if (index >= 0) {
      _skills[index] = skill;
    } else {
      _skills.add(skill);
    }
  }

  AgentSkill? byId(String id) {
    for (final skill in _skills) {
      if (skill.id == id) {
        return skill;
      }
    }
    return null;
  }

  List<AgentSkill> select({
    required String query,
    String? forcedSkillId,
    int maxSkills = 4,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final cap = maxSkills < 0 ? 0 : maxSkills;

    final alwaysOnSkills = <AgentSkill>[];
    final candidates = <({AgentSkill skill, int score, int order})>[];

    for (var i = 0; i < _skills.length; i++) {
      final skill = _skills[i];
      if (skill.alwaysOn) {
        alwaysOnSkills.add(skill);
        continue;
      }

      final isForced = forcedSkillId != null && skill.id == forcedSkillId;
      final triggerScore = _matchScore(skill, normalizedQuery);
      if (isForced || triggerScore > 0) {
        final score = isForced ? 1000000 + triggerScore : triggerScore;
        candidates.add((skill: skill, score: score, order: i));
      }
    }

    candidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.order.compareTo(b.order);
    });

    final selectedRaw = <AgentSkill>[
      ...alwaysOnSkills,
      ...candidates.take(cap).map((c) => c.skill),
    ];

    final seenTools = <String>{};
    final result = <AgentSkill>[];
    for (final skill in selectedRaw) {
      final uniqueTools = <AgentTool>[];
      var changed = false;
      for (final tool in skill.tools) {
        if (seenTools.add(tool.name)) {
          uniqueTools.add(tool);
        } else {
          changed = true;
        }
      }
      if (!changed) {
        result.add(skill);
      } else {
        result.add(
          AgentSkill(
            id: skill.id,
            instructions: skill.instructions,
            tools: uniqueTools,
            componentIds: skill.componentIds,
            triggers: skill.triggers,
            alwaysOn: skill.alwaysOn,
            offlineFlow: skill.offlineFlow,
          ),
        );
      }
    }
    return result;
  }

  List<AgentTool> toolsFor(List<AgentSkill> selected) {
    final seen = <String>{};
    final tools = <AgentTool>[];
    for (final skill in selected) {
      for (final tool in skill.tools) {
        if (seen.add(tool.name)) {
          tools.add(tool);
        }
      }
    }
    return tools;
  }

  List<ToolSpec> toolSpecsFor(List<AgentSkill> selected) {
    return toolsFor(selected).map((t) => t.toSpec()).toList(growable: false);
  }

  DeterministicFlow? findOfflineFlow(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return null;
    }

    DeterministicFlow? bestFlow;
    var bestScore = 0;

    for (final skill in _skills) {
      final flow = skill.offlineFlow;
      if (flow == null) {
        continue;
      }
      final score = _matchScore(skill, normalizedQuery);
      if (score > bestScore) {
        bestScore = score;
        bestFlow = flow;
      }
    }
    return bestFlow;
  }

  int _matchScore(AgentSkill skill, String normalizedQuery) {
    if (normalizedQuery.isEmpty) {
      return 0;
    }
    var score = 0;
    for (final trigger in skill.triggers) {
      final normalizedTrigger = trigger.trim().toLowerCase();
      if (normalizedTrigger.isEmpty) {
        continue;
      }
      if (normalizedQuery.contains(normalizedTrigger)) {
        score += 100 + normalizedTrigger.length;
      }
    }
    return score;
  }
}
