import 'package:flutter/foundation.dart';

import 'save_repository.dart';
import 'save_state.dart';
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

  // --- KALICILIK (Faz H) ----------------------------------------------------
  // GameSession kalıcılığın TEK otoritesidir: tüm kaydetme buradan geçer
  // (persist). Depolama opsiyonel katmandır; repository yoksa oyun bellekte
  // çalışmaya devam eder. Input ayarları AYRI (InputSettings) — burada tutulmaz.
  SaveRepository? _repo;

  // Tüm disk yazımları (save/clear) bu zincire kuyruklanır → SIRALI çalışır.
  // Böylece hızlı ardışık kayıtlar birbirinin üstüne binmez ve reset'in clear'ı
  // bekleyen eski bir save tarafından geri getirilmez (Faz H sağlamlık).
  Future<void> _ioChain = Future<void>.value();

  /// Kalıcılığı bağla ve varsa kaydı yükle (açılışta main'de bir kez çağrılır).
  Future<void> attachPersistence(SaveRepository repo) async {
    _repo = repo;
    final loaded = await repo.load();
    if (loaded != null) {
      loaded.applyTo(scenario);
      notifyListeners();
    }
  }

  /// Kaydedilecek anlamlı ilerleme var mı? ("Devam et"/"Yeni oyun" görünürlüğü.)
  bool get hasProgress =>
      scenario.flags.isNotEmpty ||
      scenario.stats.isNotEmpty ||
      scenario.resources.isNotEmpty ||
      scenario.completedEncounters.isNotEmpty;

  /// Senaryo durumunu diske yaz. TEK kayıt yolu. Anlık görüntü ŞİMDİ alınır,
  /// yazım sıralı kuyruğa eklenir (fire-and-forget; akışı bloklamaz).
  void persist() {
    final repo = _repo;
    if (repo == null) return;
    final snapshot = SaveState.fromScenario(scenario); // çağrı anındaki durum
    _ioChain = _ioChain.then((_) => repo.save(snapshot)).catchError((_) {});
  }

  /// Yeni oyun: belleği temizle, ardından (bekleyen save'lerden SONRA) diski sil.
  Future<void> resetProgress() async {
    scenario.reset();
    notifyListeners();
    final repo = _repo;
    if (repo == null) return;
    _ioChain = _ioChain.then((_) => repo.clear()).catchError((_) {});
    await _ioChain;
  }

  /// Senaryo değişti → dinleyicilere haber + kalıcı kayıt (merkezi).
  void _scenarioChanged() {
    notifyListeners();
    persist();
  }

  void setFlag(String flag) {
    scenario.setFlag(flag);
    _scenarioChanged();
  }

  void giveResource(String resource, int amount) {
    scenario.giveResource(resource, amount);
    _scenarioChanged();
  }

  void setStat(String stat, int value) {
    scenario.setStat(stat, value);
    _scenarioChanged();
  }

  void markEncounterCompleted(String encounterId) {
    scenario.markCompleted(encounterId);
    _scenarioChanged();
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
