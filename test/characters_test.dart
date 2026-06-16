import 'package:boss_parry_arena/characters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('character data', () {
    test('all characters have required animation sheets and combo beats', () {
      for (final character in kCharacters) {
        expect(character.sheets, contains('idle'), reason: character.id);
        expect(character.sheets, contains('dead'), reason: character.id);
        expect(character.combos, isNotEmpty, reason: character.id);
        for (final combo in character.combos) {
          expect(combo.beats, isNotEmpty, reason: character.id);
          expect(combo.weight, greaterThan(0), reason: character.id);
        }
      }
    });

    test('pattern getter returns the first combo (backward compat)', () {
      for (final character in kCharacters) {
        expect(
          identical(character.pattern, character.combos.first),
          isTrue,
          reason: character.id,
        );
      }
    });

    test('beat projectile keys match character sheets', () {
      for (final character in kCharacters) {
        for (final combo in character.combos) {
          for (final beat in combo.beats) {
            if (beat.isRanged) {
              expect(
                character.sheets,
                contains(beat.projectileKey),
                reason: '${character.id} uses ${beat.projectileKey}',
              );
            } else {
              expect(beat.projectileKey, isNull, reason: character.id);
            }
          }
        }
      }
    });

    test('demo opponent roster is valid and does not include the player', () {
      expect(kPlayerDef.id, 'samurai');
      expect(kOpponents, hasLength(kOpponentIds.length));
      expect(kOpponents.map((e) => e.id), isNot(contains(kPlayerDef.id)));

      for (final opponent in kOpponents) {
        expect(kCharacters, contains(opponent));
      }
    });

    test('character sheet paths are normalized under chars directory', () {
      expect(charSheetPath(kPlayerDef, 'idle'), 'chars/samurai/idle.png');

      for (final character in kCharacters) {
        for (final key in character.sheets.keys) {
          expect(charSheetPath(character, key), startsWith('chars/'));
          expect(charSheetPath(character, key), endsWith('.png'));
        }
      }
    });
  });

  group('combat defense model', () {
    Iterable<Beat> allBeats() sync* {
      for (final c in kCharacters) {
        for (final combo in c.combos) {
          yield* combo.beats;
        }
      }
    }

    test('feint beats deal no HP and no posture damage', () {
      for (final beat in allBeats()) {
        if (beat.defense == DefenseProfile.feint) {
          expect(beat.damage, 0);
          expect(beat.postureDamage, 0);
        }
      }
    });

    test('only committed profiles open a punish window on dodge', () {
      // Hafif, normal saldırıyı dodge etmek boss\'u AÇMAMALI.
      for (final beat in allBeats()) {
        if (beat.defense == DefenseProfile.normal &&
            beat.kind == BeatKind.meleeLight) {
          expect(beat.punishOnDodge, isFalse);
        }
      }
      // punishOnDodge yalnız committed (heavy/guardBreak/thrust/delayed) profillerde.
      const committed = {
        DefenseProfile.heavy,
        DefenseProfile.guardBreak,
        DefenseProfile.thrust,
        DefenseProfile.delayed,
      };
      for (final beat in allBeats()) {
        if (beat.punishOnDodge) {
          expect(committed, contains(beat.defense));
        }
      }
    });

    test(
      'ranged characters use the ranged defense profile for projectiles',
      () {
        for (final c in kCharacters.where((e) => e.ranged)) {
          for (final combo in c.combos) {
            for (final beat in combo.beats) {
              if (beat.isRanged) {
                expect(beat.defense, DefenseProfile.ranged, reason: c.id);
              }
            }
          }
        }
      },
    );

    test('demo opponents expose readable mix-up profiles', () {
      // knight_2: dodge-punish açan bir ağır saldırı içerir.
      final k2 = characterById('knight_2');
      expect(
        k2.combos.expand((c) => c.beats).any((b) => b.punishOnDodge),
        isTrue,
      );
      // knight_3: parry\'i cezalandıran bir guardBreak içerir.
      final k3 = characterById('knight_3');
      expect(
        k3.combos
            .expand((c) => c.beats)
            .any((b) => b.defense == DefenseProfile.guardBreak),
        isTrue,
      );
    });

    test('non-feint beats carry positive posture damage', () {
      // guardBreak (kaç) ve thrust (mikiri) parry'le çözülmez → posture'a gerek yok.
      for (final beat in allBeats()) {
        if (beat.kind != BeatKind.feint &&
            beat.defense != DefenseProfile.guardBreak &&
            beat.defense != DefenseProfile.thrust) {
          expect(beat.postureDamage, greaterThan(0));
        }
      }
    });
  });
}
