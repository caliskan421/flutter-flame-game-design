import 'package:boss_parry_arena/domain/scenario_effect.dart';
import 'package:boss_parry_arena/domain/scenario_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScenarioState', () {
    test('flag set/has/clear', () {
      final s = ScenarioState();
      expect(s.hasFlag('approached_silently'), isFalse);
      s.setFlag('approached_silently');
      expect(s.hasFlag('approached_silently'), isTrue);
      s.clearFlag('approached_silently');
      expect(s.hasFlag('approached_silently'), isFalse);
    });

    test('resource biriktirir', () {
      final s = ScenarioState();
      expect(s.resource('honor'), 0);
      s.giveResource('honor', 1);
      s.giveResource('honor', 2);
      expect(s.resource('honor'), 3);
    });

    test('stat oku/yaz', () {
      final s = ScenarioState();
      expect(s.stat('stealth'), 0);
      s.setStat('stealth', 3);
      expect(s.stat('stealth'), 3);
    });

    test('completedEncounters tekrarsız', () {
      final s = ScenarioState();
      s.markCompleted('ash_gate');
      s.markCompleted('ash_gate');
      expect(s.completedEncounters, ['ash_gate']);
      expect(s.isCompleted('ash_gate'), isTrue);
    });

    test('reset her şeyi temizler', () {
      final s = ScenarioState()
        ..setFlag('f')
        ..giveResource('honor', 5)
        ..setStat('stealth', 2)
        ..markCompleted('ash_gate');
      s.reset();
      expect(s.flags, isEmpty);
      expect(s.resources, isEmpty);
      expect(s.stats, isEmpty);
      expect(s.completedEncounters, isEmpty);
    });

    test('applyScenarioEffect: durum-mutasyonu efektleri uygular, StartCombat no-op', () {
      final s = ScenarioState();
      applyScenarioEffect(const SetFlag('boss_knight_1_defeated'), s);
      applyScenarioEffect(const GiveResource('honor', 1), s);
      applyScenarioEffect(const SetStat('stealth', 4), s);
      applyScenarioEffect(const StartCombat('knight_1'), s); // no-op
      expect(s.hasFlag('boss_knight_1_defeated'), isTrue);
      expect(s.resource('honor'), 1);
      expect(s.stat('stealth'), 4);
      // StartCombat ScenarioState'i değiştirmez
      expect(s.flags.length, 1);
    });
  });
}
