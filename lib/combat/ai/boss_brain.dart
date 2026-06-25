// ============================================================================
//  BossBrain — boss saldırı AI'sının SAF karar çekirdeği
// ----------------------------------------------------------------------------
//  Faz F (boss.dart ayrıştırma): kombo seçimi, kombo-içi beat adaptasyonu,
//  oyuncu alışkanlık EMA'ları ve greed-punish kararı buraya taşındı. Flame/Sfx/
//  event YOK — saf Dart, Flame olmadan unit test edilebilir (architecture.md §9).
//
//  RASTGELELİK: `Random` her karara PARAMETRE olarak verilir (enjekte). Böylece
//  (a) boss.dart tek bir `_rng` örneğini paylaşıp ÇAĞRI SIRASINI birebir korur
//      (jitter/pressure rolleri hâlâ aynı akışta tüketir → davranış kaymaz),
//  (b) testte seedli `Random` ile kararlar deterministik olur (§16 ilke 9).
//
//  Davranış-koruyan: tüm ağırlık/eşik sayıları boss.dart'tan birebir taşındı.
// ============================================================================

import 'dart:math';

import '../../characters.dart';

/// `adaptBeat` sonucu: uygulanacak override beat + bunun tam-parry sayımını
/// (nonFeint) azaltıp azaltmadığı (yalnız feint dönüşümünde azalır).
class BeatAdaptation {
  const BeatAdaptation(this.beat, {required this.reducesNonFeint});
  final Beat beat;
  final bool reducesNonFeint;
}

class BossBrain {
  // --- OYUNCU ALIŞKANLIK EMA'LARI (0..1) ---
  double parryHabit = 0;
  double dodgeHabit = 0;
  double attackHabit = 0;

  void reset() {
    parryHabit = dodgeHabit = attackHabit = 0;
  }

  /// Oyuncunun son davranışını alışkanlığa işle (yükselen EMA).
  void registerHabit({bool parry = false, bool dodge = false, bool attack = false}) {
    if (parry) parryHabit = (parryHabit + 0.34).clamp(0, 1).toDouble();
    if (dodge) dodgeHabit = (dodgeHabit + 0.34).clamp(0, 1).toDouble();
    if (attack) attackHabit = (attackHabit + 0.30).clamp(0, 1).toDouble();
  }

  /// Alışkanlık EMA'larının zamanla sönmesi (eski update davranışı: dt*0.22).
  void decay(double dt) {
    parryHabit = (parryHabit - parryHabit * dt * 0.22).clamp(0, 1).toDouble();
    dodgeHabit = (dodgeHabit - dodgeHabit * dt * 0.22).clamp(0, 1).toDouble();
    attackHabit = (attackHabit - attackHabit * dt * 0.22).clamp(0, 1).toDouble();
  }

  /// Kombo havuzundan ağırlıklı seçim. Oyuncu dodge'a abanıyorsa tracking içeren
  /// deseni, parry'e abanıyorsa feint/guardBreak/delayed içeren deseni öne çıkarır.
  /// Tek aday varken (veya hiç) `Random` TÜKETİLMEZ (eski davranış).
  ComboPattern pickCombo(List<ComboPattern> combos, int phase, Random rng) {
    final avail = combos.where((c) => c.minPhase <= phase).toList();
    if (avail.isEmpty) return combos.first;
    if (avail.length == 1) return avail.first;

    double weightOf(ComboPattern c) {
      double w = c.weight;
      final hasTracking = c.beats.any(
        (b) => b.defense == DefenseProfile.tracking,
      );
      final hasAntiParry = c.beats.any(
        (b) =>
            b.defense == DefenseProfile.feint ||
            b.defense == DefenseProfile.guardBreak ||
            b.defense == DefenseProfile.delayed,
      );
      if (hasTracking) w *= 1 + dodgeHabit * 1.6;
      if (hasAntiParry) w *= 1 + parryHabit * 1.6;
      return w;
    }

    final weights = avail.map(weightOf).toList();
    final total = weights.fold<double>(0, (s, w) => s + w);
    double r = rng.nextDouble() * total;
    for (int i = 0; i < avail.length; i++) {
      r -= weights[i];
      if (r <= 0) return avail[i];
    }
    return avail.last;
  }

  /// Kombo-içi adaptasyon kararı. [base] yalnız "normal" melee beat olmalı (çağıran
  /// `bossInComboAdapt` ve `_adaptedThisCombo` kapılarını uygular). `Random` burada
  /// (eski sıra: lean hesabından ÖNCE) tüketilir → çağrı sırası korunur.
  /// Karar yoksa `null` döner (rng yine de tüketilmiş olur — eski davranış).
  BeatAdaptation? adaptBeat({
    required Beat base,
    required bool isLast,
    required int recentParries,
    required int recentDodges,
    required double adaptChance,
    required Random rng,
  }) {
    if (base.defense != DefenseProfile.normal || base.isRanged) return null;
    if (rng.nextDouble() > adaptChance) return null;

    final parryLean = recentParries + parryHabit * 2;
    final dodgeLean = recentDodges + dodgeHabit * 2;

    if (parryLean >= 1.4 && parryLean >= dodgeLean && !isLast) {
      // Feint son beat olamaz: tuzaktan sonra punish edecek gerçek beat gerekir.
      return BeatAdaptation(
        base.copyWith(
          kind: BeatKind.feint,
          defense: DefenseProfile.feint,
          damage: 0,
          postureDamage: 0,
          punishOnDodge: false,
        ),
        reducesNonFeint: true,
      );
    } else if (dodgeLean >= 1.4 && dodgeLean > parryLean) {
      return BeatAdaptation(
        base.copyWith(defense: DefenseProfile.tracking),
        reducesNonFeint: false,
      );
    }
    return null;
  }

  /// GREED PUNISH kararı: boss açık değilken saldıran oyuncuya karşı-beat atılsın
  /// mı? Faz arttıkça olasılık artar. `true` → çağıran karşı-beat'i başlatır.
  /// (Eski koşul: `rng.nextDouble() > chance` ise punish YOK.)
  bool greedPunishRoll(double baseChance, int phase, Random rng) {
    final chance = baseChance * (1 + phase * 0.25);
    return rng.nextDouble() <= chance;
  }
}
