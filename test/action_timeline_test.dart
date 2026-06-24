// ActionTimeline saf veri modelinin davranış testleri (Faz C). Flame/Flutter
// bağı yoktur; yalnız zaman + pencere sorgusu. isIn sınırları DAHİL olmalı.

import 'package:boss_parry_arena/combat/data/action_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActionWindow', () {
    test('duration = end - start', () {
      const w = ActionWindow(CombatWindowKind.active, 0.07, 0.17);
      expect(w.duration, closeTo(0.10, 1e-12));
    });
  });

  group('ActionTimeline.isIn (sınırlar DAHİL)', () {
    const tl = ActionTimeline(
      id: 'test',
      duration: 0.30,
      windows: [
        ActionWindow(CombatWindowKind.windup, 0.0, 0.10),
        ActionWindow(CombatWindowKind.active, 0.10, 0.20),
        ActionWindow(CombatWindowKind.recovery, 0.20, 0.30),
      ],
    );

    test('pencere içi an true döner', () {
      expect(tl.isIn(CombatWindowKind.windup, 0.05), isTrue);
      expect(tl.isIn(CombatWindowKind.active, 0.15), isTrue);
      expect(tl.isIn(CombatWindowKind.recovery, 0.25), isTrue);
    });

    test('start ve end sınırları DAHİL', () {
      expect(tl.isIn(CombatWindowKind.windup, 0.0), isTrue, reason: 'start');
      expect(tl.isIn(CombatWindowKind.windup, 0.10), isTrue, reason: 'end');
      // Bitişik pencerelerin ortak sınırı her ikisinde de geçerli (kapalı aralık).
      expect(tl.isIn(CombatWindowKind.active, 0.10), isTrue);
      expect(tl.isIn(CombatWindowKind.active, 0.20), isTrue);
    });

    test('pencere dışı an false döner', () {
      expect(tl.isIn(CombatWindowKind.windup, 0.101), isFalse);
      expect(tl.isIn(CombatWindowKind.active, 0.05), isFalse);
      expect(tl.isIn(CombatWindowKind.recovery, 0.19), isFalse);
    });

    test('tanımsız tür her zaman false', () {
      expect(tl.isIn(CombatWindowKind.parry, 0.15), isFalse);
      expect(tl.isIn(CombatWindowKind.iframe, 0.15), isFalse);
    });
  });

  group('windowFor / durationOf', () {
    const tl = ActionTimeline(
      id: 'd',
      duration: 0.20,
      windows: [ActionWindow(CombatWindowKind.iframe, 0.02, 0.20)],
    );

    test('windowFor mevcut türü bulur, olmayan için null', () {
      expect(tl.windowFor(CombatWindowKind.iframe), isNotNull);
      expect(tl.windowFor(CombatWindowKind.iframe)!.start, 0.02);
      expect(tl.windowFor(CombatWindowKind.windup), isNull);
    });

    test('durationOf pencere süresini, yoksa 0 döner', () {
      expect(tl.durationOf(CombatWindowKind.iframe), closeTo(0.18, 1e-12));
      expect(tl.durationOf(CombatWindowKind.recovery), 0);
    });
  });
}
