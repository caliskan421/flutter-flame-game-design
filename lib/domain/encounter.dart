// ============================================================================
//  Encounter modeli — RPG dikey kesit veri tipleri (Faz G, architecture.md §8.1)
// ----------------------------------------------------------------------------
//  Encounter = sıralı adımlar: diyalog → seçim → zar → combat → ödül. Tümü VERİ;
//  akışı EncounterRunner yürütür, overlay'ler yalnız render eder. Saf domain.
// ============================================================================

import 'dice_service.dart';
import 'scenario_effect.dart';

enum EncounterStepKind { dialogue, choice, diceCheck, combat, reward }

// --- DİYALOG ---
class DialogueLine {
  const DialogueLine(this.speaker, this.text, {this.portrait, this.left = true});
  final String speaker;
  final String text;
  final String? portrait; // opsiyonel portre asset'i
  final bool left; // konuşmacı sol/sağ (sahne yerleşimi)
}

class DialogueNodeDef {
  const DialogueNodeDef(this.id, this.lines);
  final String id;
  final List<DialogueLine> lines;
}

// --- SEÇİM ---
class ChoiceOption {
  const ChoiceOption(this.label, {this.effects = const <ScenarioEffect>[], this.hint});
  final String label;
  final List<ScenarioEffect> effects; // seçilince uygulanır (örn. SetStat stealth)
  final String? hint; // küçük açıklama (ör. "Gizlilik kontrolü")
}

class ChoiceDef {
  const ChoiceDef(this.prompt, this.options);
  final String prompt;
  final List<ChoiceOption> options;
}

// --- ADIMLAR (sealed) ---
sealed class EncounterStepDef {
  const EncounterStepDef();
  EncounterStepKind get kind;
}

class DialogueStep extends EncounterStepDef {
  const DialogueStep(this.node);
  final DialogueNodeDef node;
  @override
  EncounterStepKind get kind => EncounterStepKind.dialogue;
}

class ChoiceStep extends EncounterStepDef {
  const ChoiceStep(this.choice);
  final ChoiceDef choice;
  @override
  EncounterStepKind get kind => EncounterStepKind.choice;
}

class DiceCheckStep extends EncounterStepDef {
  const DiceCheckStep(this.check);
  final DiceCheckDef check;
  @override
  EncounterStepKind get kind => EncounterStepKind.diceCheck;
}

class CombatStep extends EncounterStepDef {
  const CombatStep(
    this.bossId, {
    this.introText,
    this.slowOpeningFlag,
    this.slowOpeningDelay = 0,
  });
  final String bossId;
  final String? introText;
  // Hikaye→combat modifikatörü (VERİDE): bu flag set'liyse boss ilk saldırısını
  // [slowOpeningDelay] sn geciktirir (sessiz yaklaşma ödülü). game.dart içerik
  // adını bilmez; yalnız bu alanları okur (parry/dodge math'ine dokunulmaz).
  final String? slowOpeningFlag;
  final double slowOpeningDelay;
  @override
  EncounterStepKind get kind => EncounterStepKind.combat;
}

class RewardStep extends EncounterStepDef {
  const RewardStep({
    required this.title,
    required this.text,
    this.effects = const <ScenarioEffect>[],
  });
  final String title;
  final String text;
  final List<ScenarioEffect> effects; // maça WIN'de ulaşılır → flag/reward
  @override
  EncounterStepKind get kind => EncounterStepKind.reward;
}

class EncounterDef {
  const EncounterDef({
    required this.id,
    required this.title,
    required this.steps,
    this.clearFlagsOnStart = const <String>[],
  });
  final String id;
  final String title;
  final List<EncounterStepDef> steps;
  // Encounter başında temizlenecek GEÇİCİ flag'ler (örn. zar sonucu). Kalıcı
  // ilerleme flag'leri (boss_*_defeated) burada OLMAZ → tekrar oynatma temiz başlar.
  final List<String> clearFlagsOnStart;
}
