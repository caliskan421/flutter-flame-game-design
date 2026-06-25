import 'dart:math';

import 'package:boss_parry_arena/characters.dart';
import 'package:boss_parry_arena/combat/ai/boss_brain.dart';
import 'package:flutter_test/flutter_test.dart';

Beat _beat({
  DefenseProfile defense = DefenseProfile.normal,
  BeatKind kind = BeatKind.meleeLight,
  String? projectileKey,
}) =>
    Beat(
      kind: kind,
      defense: defense,
      animKey: 'a',
      projectileKey: projectileKey,
    );

void main() {
  group('BossBrain — alışkanlık EMA', () {
    test('registerHabit yükseltir, clamp 1', () {
      final b = BossBrain();
      b.registerHabit(parry: true);
      expect(b.parryHabit, closeTo(0.34, 1e-9));
      for (var i = 0; i < 10; i++) {
        b.registerHabit(parry: true);
      }
      expect(b.parryHabit, 1);
    });

    test('decay düşürür, reset sıfırlar', () {
      final b = BossBrain()..registerHabit(parry: true, dodge: true, attack: true);
      final before = b.parryHabit;
      b.decay(1.0);
      expect(b.parryHabit, lessThan(before));
      b.reset();
      expect(b.parryHabit, 0);
      expect(b.dodgeHabit, 0);
      expect(b.attackHabit, 0);
    });
  });

  group('BossBrain — pickCombo', () {
    final tracking = ComboPattern([_beat(defense: DefenseProfile.tracking)], weight: 1);
    final plain = ComboPattern([_beat()], weight: 1);
    final lateGame = ComboPattern([_beat()], weight: 1, minPhase: 1);

    test('faz filtresi: minPhase>phase olan aday dışlanır', () {
      final b = BossBrain();
      // phase 0'da yalnız `plain` uygun (lateGame minPhase=1) → rng tüketmeden döner.
      final picked = b.pickCombo([plain, lateGame], 0, Random(1));
      expect(picked, same(plain));
    });

    test('aynı seed → aynı seçim (deterministik)', () {
      final b = BossBrain();
      final a = b.pickCombo([tracking, plain], 0, Random(7));
      final c = b.pickCombo([tracking, plain], 0, Random(7));
      expect(a, same(c));
    });

    test('dodgeHabit yükselince tracking deseni daha sık seçilir', () {
      int countTracking(double dodgeHabit) {
        final b = BossBrain()..dodgeHabit = dodgeHabit;
        final rng = Random(12345);
        var n = 0;
        for (var i = 0; i < 4000; i++) {
          if (identical(b.pickCombo([tracking, plain], 0, rng), tracking)) n++;
        }
        return n;
      }

      final low = countTracking(0.0);
      final high = countTracking(1.0);
      expect(high, greaterThan(low));
    });
  });

  group('BossBrain — adaptBeat', () {
    test('normal olmayan beat → null (rng tüketse de karar yok)', () {
      final b = BossBrain();
      final r = b.adaptBeat(
        base: _beat(defense: DefenseProfile.guardBreak),
        isLast: false,
        recentParries: 5,
        recentDodges: 0,
        adaptChance: 1.0,
        rng: Random(1),
      );
      expect(r, isNull);
    });

    test('ranged beat → null', () {
      final b = BossBrain();
      final r = b.adaptBeat(
        base: _beat(projectileKey: 'arrow'),
        isLast: false,
        recentParries: 5,
        recentDodges: 0,
        adaptChance: 1.0,
        rng: Random(1),
      );
      expect(r, isNull);
    });

    test('parry-eğilimli → feint dönüşümü (tam-parry sayımını düşürür)', () {
      final b = BossBrain();
      final r = b.adaptBeat(
        base: _beat(),
        isLast: false,
        recentParries: 2,
        recentDodges: 0,
        adaptChance: 1.0, // nextDouble() < 1.0 → kapı hep geçer
        rng: Random(1),
      );
      expect(r, isNotNull);
      expect(r!.beat.defense, DefenseProfile.feint);
      expect(r.beat.kind, BeatKind.feint);
      expect(r.beat.damage, 0);
      expect(r.reducesNonFeint, isTrue);
    });

    test('feint son beat olamaz (isLast) → karar yok', () {
      final b = BossBrain();
      final r = b.adaptBeat(
        base: _beat(),
        isLast: true,
        recentParries: 2,
        recentDodges: 0,
        adaptChance: 1.0,
        rng: Random(1),
      );
      expect(r, isNull);
    });

    test('dodge-eğilimli → tracking dönüşümü (sayımı düşürmez)', () {
      final b = BossBrain();
      final r = b.adaptBeat(
        base: _beat(),
        isLast: false,
        recentParries: 0,
        recentDodges: 2,
        adaptChance: 1.0,
        rng: Random(1),
      );
      expect(r, isNotNull);
      expect(r!.beat.defense, DefenseProfile.tracking);
      expect(r.reducesNonFeint, isFalse);
    });
  });

  group('BossBrain — greedPunishRoll', () {
    test('chance 1.0 → her zaman punish', () {
      final b = BossBrain();
      for (var i = 0; i < 50; i++) {
        expect(b.greedPunishRoll(1.0, 0, Random(i)), isTrue);
      }
    });

    test('faz arttıkça punish olasılığı artar', () {
      int count(int phase) {
        final b = BossBrain();
        final rng = Random(999);
        var n = 0;
        for (var i = 0; i < 4000; i++) {
          if (b.greedPunishRoll(0.4, phase, rng)) n++;
        }
        return n;
      }

      expect(count(2), greaterThan(count(0)));
    });
  });
}
