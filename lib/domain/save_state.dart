// ============================================================================
//  SaveState — kalıcı ilerlemenin serialize edilebilir anlık görüntüsü (Faz H)
// ----------------------------------------------------------------------------
//  ScenarioState'in (flag/stat/resource/tamamlanan encounter) JSON karşılığı.
//  SAF Dart: Flutter/shared_preferences bağımlılığı YOK → round-trip Flame'siz
//  test edilebilir. Depolama I/O ayrı katmanda (SaveRepository + SaveStore).
//
//  `version`: ileriye dönük şema migrasyonu için; uyumsuz sürüm güvenli sıfırlanır.
//  Input/kontrol ayarları BURADA tutulmaz — onlar InputSettings'in ayrı kalıcı
//  alanıdır (sorumluluk ayrımı, §H6).
// ============================================================================

import 'scenario_state.dart';

class SaveState {
  const SaveState({
    this.version = currentVersion,
    required this.flags,
    required this.stats,
    required this.resources,
    required this.completedEncounters,
  });

  /// Mevcut şema sürümü. Şema değişince artır + (ileride) migrasyon ekle.
  static const int currentVersion = 1;

  final int version;
  final Set<String> flags;
  final Map<String, int> stats;
  final Map<String, int> resources;
  final List<String> completedEncounters;

  /// Bellekteki ScenarioState'ten anlık görüntü al (kopyalar — paylaşım yok).
  factory SaveState.fromScenario(ScenarioState s) => SaveState(
        flags: <String>{...s.flags},
        stats: <String, int>{...s.stats},
        resources: <String, int>{...s.resources},
        completedEncounters: <String>[...s.completedEncounters],
      );

  /// Bu kaydı bir ScenarioState'e uygula (önce temizler → tam yükleme).
  void applyTo(ScenarioState s) {
    s.reset();
    s.flags.addAll(flags);
    s.stats.addAll(stats);
    s.resources.addAll(resources);
    // markCompleted ile yükle → bozuk kayıttan gelen olası tekrarları ayıkla.
    for (final e in completedEncounters) {
      s.markCompleted(e);
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'version': version,
        'flags': flags.toList(),
        'stats': stats,
        'resources': resources,
        'completedEncounters': completedEncounters,
      };

  /// Savunmacı parse: eksik/yanlış-tip alanlar varsayılana düşer (çökme yok).
  factory SaveState.fromJson(Map<String, Object?> j) {
    final version = (j['version'] as num?)?.toInt() ?? currentVersion;

    Set<String> parseStrSet(Object? raw) {
      final out = <String>{};
      if (raw is List) {
        for (final e in raw) {
          if (e is String) out.add(e);
        }
      }
      return out;
    }

    List<String> parseStrList(Object? raw) {
      final out = <String>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is String) out.add(e);
        }
      }
      return out;
    }

    Map<String, int> parseIntMap(Object? raw) {
      final out = <String, int>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          if (k is String && v is num) out[k] = v.toInt();
        });
      }
      return out;
    }

    return SaveState(
      version: version,
      flags: parseStrSet(j['flags']),
      stats: parseIntMap(j['stats']),
      resources: parseIntMap(j['resources']),
      completedEncounters: parseStrList(j['completedEncounters']),
    );
  }
}
