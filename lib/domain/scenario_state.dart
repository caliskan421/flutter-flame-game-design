// ============================================================================
//  ScenarioState — encounter/ilerleme durumu (Faz G, architecture.md §8.4)
// ----------------------------------------------------------------------------
//  Combat'tan BAĞIMSIZ saf domain durumu: flag'ler, statlar, kaynaklar, biten
//  encounter'lar. Combat bu flag'leri OKUYABİLİR (örn. approached_silently) ama
//  diyalog node'unu/encounter akışını BİLMEZ (§8.4 sınırı). Flame bağımlılığı YOK.
//
//  Kalıcılık (save/load) Faz H'de; bu fazda bellekte yaşar.
// ============================================================================

class ScenarioState {
  ScenarioState({
    Set<String>? flags,
    Map<String, int>? stats,
    Map<String, int>? resources,
    List<String>? completedEncounters,
  })  : flags = flags ?? <String>{},
        stats = stats ?? <String, int>{},
        resources = resources ?? <String, int>{},
        completedEncounters = completedEncounters ?? <String>[];

  final Set<String> flags;
  final Map<String, int> stats;
  final Map<String, int> resources;
  final List<String> completedEncounters;

  // --- FLAG ---
  bool hasFlag(String name) => flags.contains(name);
  void setFlag(String name) => flags.add(name);
  void clearFlag(String name) => flags.remove(name);

  // --- STAT (zar bonusu vb.) ---
  int stat(String name) => stats[name] ?? 0;
  void setStat(String name, int value) => stats[name] = value;

  // --- RESOURCE (honor, gold...) ---
  int resource(String name) => resources[name] ?? 0;
  void giveResource(String name, int amount) =>
      resources[name] = (resources[name] ?? 0) + amount;

  // --- ENCOUNTER İLERLEME ---
  bool isCompleted(String encounterId) =>
      completedEncounters.contains(encounterId);
  void markCompleted(String encounterId) {
    if (!completedEncounters.contains(encounterId)) {
      completedEncounters.add(encounterId);
    }
  }

  /// Yeni oyun / sıfırlama.
  void reset() {
    flags.clear();
    stats.clear();
    resources.clear();
    completedEncounters.clear();
  }
}
