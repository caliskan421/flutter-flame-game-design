// ============================================================================
//  EncounterRunner — encounter akışının TEK otoritesi (Faz G, architecture.md §8.1)
// ----------------------------------------------------------------------------
//  Adımları sırayla yürütür; her geçişte ne gösterileceğini `EncounterHost`'a
//  KOMUT olarak söyler (overlay aç / combat başlat). Host'u soyut tutarak runner
//  Flame/oyun motorundan bağımsız ve test edilebilir kalır (FakeHost ile). Akış
//  orkestratöre (game.dart) GÖMÜLMEZ → D6 borcu burada çözülür.
//
//  Zar SADECE hikaye sonucunu etkiler (ilke 8): DiceCheckStep'in onSuccess/
//  onFailure efektleri ScenarioState'e uygulanır; combat math'ine dokunulmaz.
// ============================================================================

import '../../core/rng.dart';
import '../../domain/dice_service.dart';
import '../../domain/encounter.dart';
import '../../domain/scenario_effect.dart';
import '../../domain/scenario_state.dart';

/// Runner'ın oyun motoruna verdiği komutlar. game.dart bunu implemente eder;
/// her komut tamamlanınca runner'ın ilgili geri-çağrısını (advance/choose/
/// onCombatResult) tetikler.
abstract class EncounterHost {
  void showDialogue(DialogueNodeDef node);
  void showChoice(ChoiceDef choice);
  void showDiceCheck(DiceCheckDef check, DiceResult result);
  void startCombat(CombatStep step);
  void showReward(RewardStep step);
  void onCombatLost(EncounterDef encounter);
  void onEncounterComplete(EncounterDef encounter);
}

class EncounterRunner {
  EncounterRunner({
    required this.def,
    required this.state,
    required this.rng,
    required this.host,
    this.onStateChanged,
  });

  final EncounterDef def;
  final ScenarioState state;
  final Rng rng;
  final EncounterHost host;

  /// ScenarioState her değiştiğinde (efekt/tamamlama) tetiklenir. Kalıcılık (Faz H)
  /// burada GameSession.persist'e bağlanır → runner GameSession'a bağımlı kalmaz
  /// (tek-yön bağımlılık korunur).
  final void Function()? onStateChanged;

  int _index = -1;
  int get stepIndex => _index;
  EncounterStepDef? get current =>
      (_index >= 0 && _index < def.steps.length) ? def.steps[_index] : null;

  /// Encounter'ı başlat (ilk adıma geç). Geçici flag'leri (zar sonucu vb.)
  /// temizler → tekrar oynatma temiz başlar (kalıcı ilerleme flag'leri kalır).
  void start() {
    var cleared = false;
    for (final f in def.clearFlagsOnStart) {
      if (state.hasFlag(f)) {
        state.clearFlag(f);
        cleared = true;
      }
    }
    if (cleared) {
      onStateChanged?.call(); // temizlik de kalıcı olsun (diskten sil)
    }
    _index = -1;
    _advance();
  }

  /// Dallanmayan adım (diyalog/zar/ödül) kapatılınca çağrılır → sıradaki adım.
  void next() => _advance();

  /// Bir seçim yapıldığında: seçeneğin efektlerini uygula, sonra ilerle.
  void choose(int optionIndex) {
    final step = current;
    if (step is! ChoiceStep) return;
    final opts = step.choice.options;
    if (optionIndex < 0 || optionIndex >= opts.length) return;
    for (final e in opts[optionIndex].effects) {
      _applyEffect(e);
    }
    onStateChanged?.call();
    _advance();
  }

  /// Combat adımı bittiğinde host çağırır. WIN → sıradaki (ödül) adım;
  /// LOSS → host retry/menü kararını verir (runner combat adımında bekler).
  void onCombatResult(bool won) {
    final step = current;
    if (step is! CombatStep) return;
    if (won) {
      _advance();
    } else {
      host.onCombatLost(def);
    }
  }

  /// Kayıp sonrası tekrar dene: aynı combat adımını yeniden başlat.
  void retryCombat() {
    final step = current;
    if (step is CombatStep) host.startCombat(step);
  }

  // --- iç ---
  void _advance() {
    _index++;
    final step = current;
    if (step == null) {
      final firstTime = !state.isCompleted(def.id);
      state.markCompleted(def.id);
      if (firstTime) onStateChanged?.call();
      host.onEncounterComplete(def);
      return;
    }
    switch (step) {
      case DialogueStep(:final node):
        host.showDialogue(node);
      case ChoiceStep(:final choice):
        host.showChoice(choice);
      case DiceCheckStep(:final check):
        final result = DiceService.roll(
          check,
          rng,
          statBonus: state.stat(check.stat),
        );
        final effects = result.success ? check.onSuccess : check.onFailure;
        for (final e in effects) {
          _applyEffect(e);
        }
        onStateChanged?.call();
        host.showDiceCheck(check, result);
      case CombatStep():
        host.startCombat(step);
      case RewardStep(:final effects):
        // Ödül YALNIZ ilk tamamlamada verilir (completedEncounters kalıcı → çift
        // ödül yok). KRİTİK: ödül + tamamlandı işareti ATOMİK yazılır; reward
        // ekranındayken çökme olsa bile tekrar açılışta ödül yeniden verilmez.
        if (!state.isCompleted(def.id)) {
          for (final e in effects) {
            _applyEffect(e);
          }
          state.markCompleted(def.id);
          onStateChanged?.call();
        }
        host.showReward(step);
    }
  }

  void _applyEffect(ScenarioEffect e) => applyScenarioEffect(e, state);
}
