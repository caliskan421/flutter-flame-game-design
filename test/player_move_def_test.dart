// PlayerMoveDef sabitlerinin Faz C öncesi DAVRANIŞLA BİREBİR uyumunu kilitler.
// Süreler taşınırken (player.dart → move_def.dart) sayısal sapma OLMAMALI:
// parry 0.13, dodge i-frame 0.02–0.20, light 0.07/0.10/0.18, heavy 0.24/0.12/0.42.
// Bu testler regresyon kilididir (architecture §6.3, Faz C risk §7).

import 'package:boss_parry_arena/combat/data/action_timeline.dart';
import 'package:boss_parry_arena/combat/data/move_def.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('süre sabitleri (TEK KAYNAK) eski değerlerle birebir', () {
    test('light fazları 0.07 / 0.10 / 0.18', () {
      expect(kPlayerLightWindup, 0.07);
      expect(kPlayerLightActive, 0.10);
      expect(kPlayerLightRecover, 0.18);
    });
    test('heavy fazları 0.24 / 0.12 / 0.42', () {
      expect(kPlayerHeavyWindup, 0.24);
      expect(kPlayerHeavyActive, 0.12);
      expect(kPlayerHeavyRecover, 0.42);
    });
    test('parry penceresi 0.13 / low 0.18', () {
      expect(kPlayerParryWindow, 0.13);
      expect(kPlayerLowParryWindow, 0.18);
    });
    test('dodge pencere 0.20, i-frame 0.02–0.20', () {
      expect(kPlayerDodgeDuration, 0.20);
      expect(kPlayerDodgeIframeFrom, 0.02);
      expect(kPlayerDodgeIframeTo, 0.20);
    });
  });

  group('kPlayerLight timeline', () {
    test('toplam süre = windup + active + recover', () {
      expect(
        kPlayerLight.timeline.duration,
        closeTo(
          kPlayerLightWindup + kPlayerLightActive + kPlayerLightRecover,
          1e-12,
        ),
      );
    });
    test('windup/active/recovery pencere süreleri', () {
      final tl = kPlayerLight.timeline;
      expect(tl.durationOf(CombatWindowKind.windup), closeTo(0.07, 1e-12));
      expect(tl.durationOf(CombatWindowKind.active), closeTo(0.10, 1e-12));
      expect(tl.durationOf(CombatWindowKind.recovery), closeTo(0.18, 1e-12));
    });
    test('fazlar sırayla bitişik (boşluk/çakışma yok)', () {
      final tl = kPlayerLight.timeline;
      expect(tl.isIn(CombatWindowKind.windup, 0.0), isTrue);
      expect(tl.isIn(CombatWindowKind.active, kPlayerLightWindup), isTrue);
      expect(
        tl.isIn(
          CombatWindowKind.recovery,
          kPlayerLightWindup + kPlayerLightActive,
        ),
        isTrue,
      );
    });
    test('light defansa iptal edilebilir (recovery cancel)', () {
      expect(kPlayerLight.canCancelIntoDefense, isTrue);
    });
  });

  group('kPlayerHeavy timeline', () {
    test('toplam süre = windup + active + recover (0.78)', () {
      expect(
        kPlayerHeavy.timeline.duration,
        closeTo(
          kPlayerHeavyWindup + kPlayerHeavyActive + kPlayerHeavyRecover,
          1e-12,
        ),
      );
      expect(kPlayerHeavy.timeline.duration, closeTo(0.78, 1e-12));
    });
    test('windup/active/recovery pencere süreleri 0.24 / 0.12 / 0.42', () {
      final tl = kPlayerHeavy.timeline;
      expect(tl.durationOf(CombatWindowKind.windup), closeTo(0.24, 1e-12));
      expect(tl.durationOf(CombatWindowKind.active), closeTo(0.12, 1e-12));
      expect(tl.durationOf(CombatWindowKind.recovery), closeTo(0.42, 1e-12));
    });
    test('heavy iptal edilemez', () {
      expect(kPlayerHeavy.canCancelIntoDefense, isFalse);
    });
  });

  group('kPlayerParry timeline', () {
    test('tek parry penceresi 0–0.13', () {
      final w = kPlayerParry.timeline.windowFor(CombatWindowKind.parry);
      expect(w, isNotNull);
      expect(w!.start, 0.0);
      expect(w.end, 0.13);
      expect(kPlayerParry.timeline.duration, 0.13);
    });
  });

  group('kPlayerDodge timeline', () {
    test('i-frame penceresi 0.02–0.20 (sınırlar dahil)', () {
      final tl = kPlayerDodge.timeline;
      expect(tl.isIn(CombatWindowKind.iframe, 0.02), isTrue);
      expect(tl.isIn(CombatWindowKind.iframe, 0.20), isTrue);
      expect(tl.isIn(CombatWindowKind.iframe, 0.0), isFalse);
      expect(tl.isIn(CombatWindowKind.iframe, 0.01), isFalse);
      expect(tl.isIn(CombatWindowKind.iframe, 0.21), isFalse);
    });
  });

  group('stamina maliyeti yalnız REFERANS (otorite ArenaActionSystem)', () {
    // Sayılar belge amaçlı; Player bu alanı harcama için kullanmaz. Yine de
    // referansın eski değerlerden sapmadığını kilitle.
    test('referans değerler eski sabitlerle uyumlu', () {
      expect(kPlayerLight.staminaCost, 8);
      expect(kPlayerHeavy.staminaCost, 30);
      expect(kPlayerDodge.staminaCost, 22);
      expect(kPlayerParry.staminaCost, 0);
    });
  });
}
