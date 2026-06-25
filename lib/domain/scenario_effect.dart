// ============================================================================
//  ScenarioEffect — encounter/zar sonuçlarının uyguladığı yan etkiler (Faz G)
// ----------------------------------------------------------------------------
//  Veri olarak ifade edilen komutlar (architecture.md §8). Durum-mutasyonu olanlar
//  (SetFlag/GiveResource/SetStat) `applyScenarioEffect` ile ScenarioState'e
//  uygulanır; StartCombat gibi akış komutları host (game.dart) tarafından ele
//  alınır. Saf domain — Flame bağımlılığı YOK.
// ============================================================================

import 'scenario_state.dart';

sealed class ScenarioEffect {
  const ScenarioEffect();
}

/// Bir flag set et (örn. 'approached_silently', 'boss_knight_1_defeated').
class SetFlag extends ScenarioEffect {
  const SetFlag(this.flag);
  final String flag;
}

/// Bir kaynağı artır/azalt (örn. honor +1).
class GiveResource extends ScenarioEffect {
  const GiveResource(this.resource, this.amount);
  final String resource;
  final int amount;
}

/// Bir statı ayarla (zar bonusu vb.).
class SetStat extends ScenarioEffect {
  const SetStat(this.stat, this.value);
  final String stat;
  final int value;
}

/// Combat'a geç (host/runner ele alır; ScenarioState'i değiştirmez).
class StartCombat extends ScenarioEffect {
  const StartCombat(this.bossId);
  final String bossId;
}

/// Yalnız DURUM-mutasyonu yapan efektleri ScenarioState'e uygular. Akış komutları
/// (StartCombat) burada no-op'tur; çağıran (runner) onları host'a yönlendirir.
void applyScenarioEffect(ScenarioEffect effect, ScenarioState state) {
  switch (effect) {
    case SetFlag(:final flag):
      state.setFlag(flag);
    case GiveResource(:final resource, :final amount):
      state.giveResource(resource, amount);
    case SetStat(:final stat, :final value):
      state.setStat(stat, value);
    case StartCombat():
      break; // host tarafından ele alınır
  }
}
