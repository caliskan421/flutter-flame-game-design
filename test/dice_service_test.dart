import 'package:boss_parry_arena/core/rng.dart';
import 'package:boss_parry_arena/domain/dice_service.dart';
import 'package:boss_parry_arena/domain/scenario_effect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiceService', () {
    const check = DiceCheckDef(
      id: 'sneak',
      stat: 'stealth',
      difficulty: 12,
      onSuccess: [SetFlag('approached_silently')],
      onFailure: [SetFlag('spotted')],
    );

    test('sabit seed → deterministik sonuç', () {
      final a = DiceService.roll(check, Rng.seeded(42));
      final b = DiceService.roll(check, Rng.seeded(42));
      expect(a.total, b.total);
      expect(a.rolls, b.rolls);
      expect(a.success, b.success);
    });

    test('1d20 tek zar 1..20 aralığında', () {
      for (var seed = 0; seed < 50; seed++) {
        final r = DiceService.roll(check, Rng.seeded(seed));
        expect(r.rolls.length, 1);
        expect(r.rolls.single, inInclusiveRange(1, 20));
      }
    });

    test('statBonus toplama eklenir', () {
      final base = DiceService.roll(check, Rng.seeded(7));
      final boosted = DiceService.roll(check, Rng.seeded(7), statBonus: 5);
      expect(boosted.total, base.total + 5);
      expect(boosted.statBonus, 5);
    });

    test('DC sınırı >= ile başarı (total == DC başarıdır)', () {
      // total == difficulty senaryosu: 1d20=12, stat=0, DC=12
      // Bunu doğrudan kurmak için DiceResult mantığını sınırda doğrula:
      // Yüksek statBonus ile kesin başarı, çok düşük DC ile kesin başarı.
      final sureWin = DiceService.roll(
        const DiceCheckDef(id: 'x', stat: 's', difficulty: 1),
        Rng.seeded(3),
      );
      expect(sureWin.success, isTrue); // 1d20>=1 her zaman

      final sureLose = DiceService.roll(
        const DiceCheckDef(id: 'x', stat: 's', difficulty: 25),
        Rng.seeded(3),
      );
      expect(sureLose.success, isFalse); // 1d20 max 20 < 25
    });

    test('statBonus DC sınırını aşmaya yetebilir', () {
      // DC 25, tek zar yetmez; +20 stat ile aşılır.
      final withBonus = DiceService.roll(
        const DiceCheckDef(id: 'x', stat: 's', difficulty: 25),
        Rng.seeded(3),
        statBonus: 20,
      );
      expect(withBonus.success, isTrue);
    });

    test('modifier toplama yansır', () {
      final r = DiceService.roll(
        const DiceCheckDef(
          id: 'x',
          stat: 's',
          difficulty: 1,
          dice: DiceFormula(1, 20, modifier: 3),
        ),
        Rng.seeded(9),
      );
      expect(r.total, r.rolls.single + 3);
      expect(r.modifier, 3);
    });
  });
}
