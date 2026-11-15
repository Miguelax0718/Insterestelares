import 'dart:convert';

import 'package:hive/hive.dart';

import '../../domain/agent_contracts.dart';
import 'agent_hive_boxes.dart';

/// Hive-backed per-astronaut [MemoryStore] storing JSON-encoded [MemoryEntry]
/// records without TypeAdapters.
class HiveMemoryStore implements MemoryStore {
  HiveMemoryStore(this._box);

  final Box<dynamic> _box;

  String _keyFor(String astronautId, String id) =>
      jsonEncode(<String>[astronautId, id]);

  @override
  Future<MemoryEntry> save(MemoryEntry entry) async {
    if (entry.astronautId.trim().isEmpty) {
      throw ArgumentError.value(
        entry.astronautId,
        'astronautId',
        'MemoryEntry astronautId must not be empty.',
      );
    }
    if (entry.id.trim().isEmpty) {
      throw ArgumentError.value(
        entry.id,
        'id',
        'MemoryEntry id must not be empty.',
      );
    }
    await _box.put(
      _keyFor(entry.astronautId, entry.id),
      jsonEncode(entry.toJson()),
    );
    return entry;
  }

  @override
  Future<List<MemoryEntry>> recall(
    String astronautId, {
    String? query,
    Set<MemoryKind>? kinds,
    int limit = 10,
  }) async {
    if (limit <= 0) {
      return const [];
    }
    final filtered = <MemoryEntry>[];
    for (final raw in _box.values) {
      final entry = MemoryEntry.fromJson(decodeHiveJsonMap(raw));
      if (entry.astronautId != astronautId) {
        continue;
      }
      if (kinds != null && !kinds.contains(entry.kind)) {
        continue;
      }
      filtered.add(entry);
    }

    final normalizedQuery = query?.trim().toLowerCase() ?? '';
    if (normalizedQuery.isEmpty) {
      filtered.sort(_compareMostRecent);
      return filtered.take(limit).toList(growable: false);
    }

    final tokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);

    final scored = <(int score, MemoryEntry entry)>[];
    for (final entry in filtered) {
      final score = _scoreEntry(entry, normalizedQuery, tokens);
      if (score > 0) {
        scored.add((score, entry));
      }
    }

    scored.sort((a, b) {
      final byScore = b.$1.compareTo(a.$1);
      if (byScore != 0) {
        return byScore;
      }
      return _compareMostRecent(a.$2, b.$2);
    });

    return scored.take(limit).map((item) => item.$2).toList(growable: false);
  }

  @override
  Future<List<MemoryEntry>> recentForPrompt(
    String astronautId, {
    int limit = 8,
  }) async {
    if (limit <= 0) {
      return const [];
    }
    final allForAstronaut = <MemoryEntry>[];
    for (final raw in _box.values) {
      final entry = MemoryEntry.fromJson(decodeHiveJsonMap(raw));
      if (entry.astronautId == astronautId) {
        allForAstronaut.add(entry);
      }
    }
    allForAstronaut.sort(_compareMostRecent);

    final factBudget = limit <= 1 ? limit : limit ~/ 2;
    final facts = allForAstronaut
        .where((entry) => entry.kind == MemoryKind.fact)
        .take(factBudget)
        .toList(growable: false);

    final remaining = limit - facts.length;
    final recentEvents = allForAstronaut
        .where(
          (entry) =>
              entry.kind == MemoryKind.sessionSummary ||
              entry.kind == MemoryKind.clinicalEvent,
        )
        .take(remaining)
        .toList(growable: false);

    return <MemoryEntry>[...facts, ...recentEvents];
  }

  int _scoreEntry(MemoryEntry entry, String fullQuery, List<String> tokens) {
    final summaryLower = entry.summary.toLowerCase();
    final tagsLower = entry.tags.map((t) => t.toLowerCase()).toList();
    var score = 0;

    for (final token in tokens) {
      if (summaryLower.contains(token)) {
        score += 2;
      }
      if (tagsLower.any((tag) => tag == token)) {
        score += 3;
      } else if (tagsLower.any((tag) => tag.contains(token))) {
        score += 1;
      }
    }

    if (tokens.length > 1 && summaryLower.contains(fullQuery)) {
      score += 2;
    }

    return score;
  }

  int _compareMostRecent(MemoryEntry a, MemoryEntry b) {
    final byTime = b.createdAt.compareTo(a.createdAt);
    if (byTime != 0) {
      return byTime;
    }
    return b.id.compareTo(a.id);
  }
}
