import 'dart:convert';

import 'package:boss_parry_arena/domain/save_state.dart';
import 'package:boss_parry_arena/domain/scenario_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaveState', () {
    test('ScenarioState → SaveState → JSON → geri: kayıpsız round-trip', () {
      final s = ScenarioState()
        ..setFlag('approached_silently')
        ..setFlag('boss_knight_1_defeated')
        ..giveResource('honor', 3)
        ..setStat('stealth', 5)
        ..markCompleted('ash_gate');

      final json = SaveState.fromScenario(s).toJson();
      // Gerçek serialize yolu: jsonEncode/decode üstünden geç.
      final back = SaveState.fromJson(
        (jsonDecode(jsonEncode(json)) as Map).cast<String, Object?>(),
      );

      final restored = ScenarioState();
      back.applyTo(restored);

      expect(restored.flags, s.flags);
      expect(restored.resources, s.resources);
      expect(restored.stats, s.stats);
      expect(restored.completedEncounters, s.completedEncounters);
    });

    test('version varsayılan currentVersion ve toJson içinde', () {
      final save = SaveState.fromScenario(ScenarioState());
      expect(save.version, SaveState.currentVersion);
      expect(save.toJson()['version'], SaveState.currentVersion);
    });

    test('eksik alanlar → güvenli varsayılan (boş)', () {
      final back = SaveState.fromJson(<String, Object?>{});
      expect(back.flags, isEmpty);
      expect(back.stats, isEmpty);
      expect(back.resources, isEmpty);
      expect(back.completedEncounters, isEmpty);
      expect(back.version, SaveState.currentVersion);
    });

    test('bilinmeyen / yanlış-tip alanlar tolere edilir (çökme yok)', () {
      final back = SaveState.fromJson(<String, Object?>{
        'flags': 'not-a-list',
        'stats': 5,
        'resources': <String, Object?>{'honor': 'x', 'gold': 2},
        'completedEncounters': <Object?>[1, 'ash_gate', null],
        'bogus': 123,
      });
      expect(back.flags, isEmpty); // yanlış tip → boş
      expect(back.stats, isEmpty);
      expect(back.resources, {'gold': 2}); // yalnız geçerli giriş
      expect(back.completedEncounters, ['ash_gate']); // yalnız string'ler
    });

    test('Set→List→Set dönüşümünde eleman kaybı yok', () {
      final s = ScenarioState()
        ..setFlag('a')
        ..setFlag('b')
        ..setFlag('c');
      final back = SaveState.fromJson(SaveState.fromScenario(s).toJson());
      expect(back.flags, {'a', 'b', 'c'});
    });
  });
}
