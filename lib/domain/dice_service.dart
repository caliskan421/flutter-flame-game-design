// ============================================================================
//  DiceService + zar modelleri — yalnız HİKAYEDE zar (Faz G, architecture.md §8.3/§14)
// ----------------------------------------------------------------------------
//  İlk slice: 1d20 + stat >= DC. Saf ve seedli (test edilebilir). Zar SADECE
//  encounter/hikaye sonucunu etkiler; parry/dodge başarı oranına BAĞLANMAZ (ilke 8).
// ============================================================================

import '../core/rng.dart';
import 'scenario_effect.dart';

class DiceFormula {
  const DiceFormula(this.count, this.sides, {this.modifier = 0});
  final int count;
  final int sides;
  final int modifier;

  static const DiceFormula d20 = DiceFormula(1, 20);
}

class DiceCheckDef {
  const DiceCheckDef({
    required this.id,
    required this.stat,
    required this.difficulty,
    this.dice = DiceFormula.d20,
    this.onSuccess = const <ScenarioEffect>[],
    this.onFailure = const <ScenarioEffect>[],
  });

  final String id;
  final String stat; // ScenarioState.stat(stat) zar bonusu olarak eklenir
  final int difficulty; // DC: total >= difficulty → başarı
  final DiceFormula dice;
  final List<ScenarioEffect> onSuccess;
  final List<ScenarioEffect> onFailure;
}

class DiceResult {
  const DiceResult({
    required this.rolls,
    required this.statBonus,
    required this.modifier,
    required this.total,
    required this.difficulty,
    required this.success,
  });

  final List<int> rolls;
  final int statBonus;
  final int modifier;
  final int total;
  final int difficulty;
  final bool success;
}

class DiceService {
  /// Zarı at: count×dN + modifier + statBonus; total >= DC ise başarı.
  /// [statBonus] çağıran tarafından ScenarioState'ten okunur → DiceService saf kalır.
  static DiceResult roll(DiceCheckDef check, Rng rng, {int statBonus = 0}) {
    final rolls = <int>[
      for (var i = 0; i < check.dice.count; i++) rng.rollDie(check.dice.sides),
    ];
    final sum = rolls.fold<int>(0, (a, b) => a + b);
    final total = sum + check.dice.modifier + statBonus;
    return DiceResult(
      rolls: rolls,
      statBonus: statBonus,
      modifier: check.dice.modifier,
      total: total,
      difficulty: check.difficulty,
      success: total >= check.difficulty,
    );
  }
}
