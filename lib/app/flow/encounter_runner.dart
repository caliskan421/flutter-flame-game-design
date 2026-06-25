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
  });

  final EncounterDef def;
  final ScenarioState state;
  final Rng rng;
  final EncounterHost host;

  int _index = -1;
  int get stepIndex => _index;
  EncounterStepDef? get current =>
      (_index >= 0 && _index < def.steps.length) ? def.steps[_index] : null;

  /// Encounter'ı başlat (ilk adıma geç). Geçici flag'leri (zar sonucu vb.)
  /// temizler → tekrar oynatma temiz başlar (kalıcı ilerleme flag'leri kalır).
  void start() {
    for (final f in def.clearFlagsOnStart) {
      state.clearFlag(f);
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
      state.markCompleted(def.id);
      host.onEncounterComplete(def);
      return;
    }
    switch (step) {
      case DialogueStep(:final node):
        host.showDialogue(node);
      case ChoiceStep(:final choice):
        host.showChoice(choice);
      case DiceCheckStep(:final check):
        final result = DiceService.roll(check, rng, statBonus: state.stat(check.stat));
        final effects = result.success ? check.onSuccess : check.onFailure;
        for (final e in effects) {
          _applyEffect(e);
        }
        host.showDiceCheck(check, result);
      case CombatStep():
        host.startCombat(step);
      case RewardStep(:final effects):
        for (final e in effects) {
          _applyEffect(e);
        }
        host.showReward(step);
    }
  }

  void _applyEffect(ScenarioEffect e) => applyScenarioEffect(e, state);
}
