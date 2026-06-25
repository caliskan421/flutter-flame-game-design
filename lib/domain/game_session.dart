import 'package:flutter/foundation.dart';

import 'scenario_state.dart';

// ============================================================================
//  GAME SESSION  —  paylaşılan/RPG durumu için ev (Faz A iskeleti → Faz E)
// ----------------------------------------------------------------------------
//  Faz E: normal (ölümlü) maç akışının saf durumu burada tutulur — seçilen
//  boss'un id'si ve son maç sonucu. Tek-yön bağımlılık: bu sınıf saf Dart'tır;
//  Flame/Sfx/game.dart'a DOKUNMAZ (boss CharacterDef yerine id ile tutulur ki
//  combat/data katmanına bile sızmasın). game.dart bunu okur/yazar.
//  Faz G burayı senaryo durumu, envanter ve ilerleme bayraklarıyla genişletir.
//  ChangeNotifier seçildi ki ileride UI dinleyebilsin.
// ============================================================================

/// Bir normal maçın sonucu (Faz G ilerleme bayraklarına zemin).
enum MatchResult { none, won, lost }

class GameSession extends ChangeNotifier {
  /// Seçilen rakibin id'si (`kOpponentIds`'ten). Normal mod dışında null.
  String? selectedBossId;

  /// En son tamamlanan normal maçın sonucu.
  MatchResult lastResult = MatchResult.none;

  /// Faz G: senaryo/encounter durumu (flag/stat/resource/ilerleme). Combat bu
  /// flag'leri OKUR (örn. approached_silently), diyalog akışını bilmez (§8.4).
  final ScenarioState scenario = ScenarioState();

  /// Senaryo mutasyonu + dinleyicilere haber (UI/overlay bağlanabilsin).
  void setFlag(String flag) {
    scenario.setFlag(flag);
    notifyListeners();
  }

  void giveResource(String resource, int amount) {
    scenario.giveResource(resource, amount);
    notifyListeners();
  }

  void setStat(String stat, int value) {
    scenario.setStat(stat, value);
    notifyListeners();
  }

  void markEncounterCompleted(String encounterId) {
    scenario.markCompleted(encounterId);
    notifyListeners();
  }

  /// Normal maç için boss seçildi: id yazılır, önceki sonuç sıfırlanır.
  void selectBoss(String id) {
    selectedBossId = id;
    lastResult = MatchResult.none;
    notifyListeners();
  }

  /// Maç bitti: sonucu kaydet (retry/next ve Faz G bayrakları için).
  void recordResult(MatchResult result) {
    lastResult = result;
    notifyListeners();
  }
}
