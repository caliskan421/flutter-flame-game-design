// Faz D — AnimationBinding + markerFrames testleri.
//
// Doğrular:
//  1) Binding çözümü (id eşleşmesi): knight_1 + oyuncu hamle id'leri.
//  2) Eksik marker → FALLBACK (eski `mid = n/2` davranışı birebir korunur).
//  3) HİZALAMA: contact karesi mekanik `active` penceresine düşer
//     - render yolu (knight_1, attackFrame): active fazda gösterilen kare == contact.
//     - timeline + binding birlikte (samuray): contact, `active` penceresinde
//       lineer `once`'ın gösterdiği kare aralığına düşer.
//  4) knight_1 contact == mid → görsel çıktı BİREBİR aynı (regresyon yok).

import 'package:boss_parry_arena/characters.dart';
import 'package:boss_parry_arena/combat/data/action_timeline.dart';
import 'package:boss_parry_arena/combat/data/move_def.dart';
import 'package:boss_parry_arena/combat/rules/hitbox_model.dart';
import 'package:boss_parry_arena/presentation/animation_binding.dart';
import 'package:boss_parry_arena/sprite_strip.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz D ÖNCESİ `attackFrame`'in kare-indeks mantığının bağımsız kopyası.
/// `attackFrameIndex(contactFrame: null)` bununla BİREBİR aynı kalmalı (refactor
/// kayması olursa bu yakalar).
int _legacyIndex(int n, AttackPhase phase, double progress) {
  final mid = (n / 2).floor().clamp(0, n - 1);
  final p = progress.clamp(0.0, 1.0);
  switch (phase) {
    case AttackPhase.windup:
      final span = mid;
      return span <= 0 ? 0 : (p * span).floor().clamp(0, span - 1);
    case AttackPhase.active:
      return mid;
    case AttackPhase.recover:
      final start = (mid + 1).clamp(0, n - 1);
      final span = n - start;
      return span <= 0 ? n - 1 : (start + p * span).floor().clamp(start, n - 1);
  }
}

/// Oyuncunun lineer `SpriteStripBank.once(key, total - t, total)` kare indeksi.
int _onceIndex(int n, double t, double total) =>
    ((t / total) * n).floor().clamp(0, n - 1);

const _phases = AttackPhase.values;
const _progressSamples = [0.0, 0.13, 0.37, 0.5, 0.74, 0.99, 1.0];

void main() {
  group('binding çözümü (id eşleşmesi)', () {
    test('knight_1 saldırı sheet binding\'leri çözülür', () {
      for (final key in [
        'knight_1.attack1',
        'knight_1.attack2',
        'knight_1.attack3',
      ]) {
        final b = resolveAnimationBinding(key);
        expect(b, isNotNull, reason: '$key kayıtlı olmalı');
        expect(b!.sheetKey, isNotEmpty);
        expect(
          b.contactFrame,
          isNotNull,
          reason: '$key contact karesi taşımalı',
        );
      }
    });

    test(
      'oyuncu hamle id\'leri (Faz C yer tutucuları) gerçek binding\'e çözülür',
      () {
        for (final move in [
          kPlayerLight,
          kPlayerHeavy,
          kPlayerParry,
          kPlayerDodge,
        ]) {
          final b = resolveAnimationBinding(move.animationBindingId);
          expect(
            b,
            isNotNull,
            reason: '${move.animationBindingId} kayıtta çözülmeli',
          );
          expect(b!.id, move.animationBindingId);
        }
      },
    );

    test('bilinmeyen / null id → null (çağıran fallback\'e düşer)', () {
      expect(resolveAnimationBinding(null), isNull);
      expect(resolveAnimationBinding('yok.boyle.bir.sey'), isNull);
    });
  });

  group('eksik marker → fallback (eski mid=n/2 davranışı)', () {
    test(
      'contactFrame:null tüm faz/ilerleme/kare-sayısında legacy ile aynı',
      () {
        for (var n = 1; n <= 8; n++) {
          for (final phase in _phases) {
            for (final p in _progressSamples) {
              expect(
                attackFrameIndex(n: n, phase: phase, progress: p),
                _legacyIndex(n, phase, p),
                reason: 'n=$n phase=$phase p=$p fallback legacy\'den sapmamalı',
              );
            }
          }
        }
      },
    );

    test('contact\'sız binding (parry/dodge) fallback verir', () {
      final parry = resolveAnimationBinding('player.parry')!;
      expect(parry.contactFrame, isNull);
      // contactFrame null → attackFrameIndex legacy ile aynı.
      expect(
        attackFrameIndex(
          n: 4,
          phase: AttackPhase.active,
          progress: .5,
          contactFrame: parry.contactFrame,
        ),
        _legacyIndex(4, AttackPhase.active, .5),
      );
    });

    test('sheetKey EŞLEŞMEZSE binding yok sayılır (yanlış id → fallback)', () {
      final b = resolveAnimationBinding(
        'knight_1.attack1',
      )!; // sheetKey 'attack1'
      // Doğru sheet: contact uygulanır.
      expect(contactFrameFor(b, 'attack1'), b.contactFrame);
      // Yanlış sheet: null → çağıran fallback'e düşer (sessiz görsel kayma yok).
      expect(contactFrameFor(b, 'attack2'), isNull);
      expect(contactFrameFor(null, 'attack1'), isNull);
    });

    test('contactFrame kare sayısının DIŞINDA ise güvenli clamp (release\'te '
        'çökmez)', () {
      // assert debug'da yakalar; release davranışı: geçerli indekse clamp.
      expect(
        attackFrameIndex(
          n: 4,
          phase: AttackPhase.active,
          progress: 0,
          contactFrame: 99,
        ),
        3,
      );
      expect(
        attackFrameIndex(
          n: 4,
          phase: AttackPhase.active,
          progress: 0,
          contactFrame: -5,
        ),
        0,
      );
    });
  });

  group('knight_1: contact == mid → render BİREBİR aynı (regresyon yok)', () {
    test(
      'her saldırı için contact == (n/2).floor() ve tüm fazlarda fallback ile özdeş',
      () {
        final beats = kTestOpponent.combos.first.beats;
        for (final beat in beats) {
          final binding = resolveAnimationBinding(beat.animationBindingId)!;
          final n = kTestOpponent.sheets[beat.animKey]!.frames;
          final mid = (n / 2).floor();
          expect(
            binding.contactFrame,
            mid,
            reason:
                '${binding.id}: contact mid\'e eşit olmalı (davranış-koruyan)',
          );

          for (final phase in _phases) {
            for (final p in _progressSamples) {
              expect(
                attackFrameIndex(
                  n: n,
                  phase: phase,
                  progress: p,
                  contactFrame: binding.contactFrame,
                ),
                attackFrameIndex(n: n, phase: phase, progress: p), // fallback
                reason:
                    '${binding.id} phase=$phase p=$p: binding render\'ı '
                    'değiştirmemeli',
              );
            }
          }
        }
      },
    );
  });

  group('hizalama: contact karesi active penceresine düşer', () {
    test('render yolu (knight_1): active fazda gösterilen kare == contact', () {
      final beats = kTestOpponent.combos.first.beats;
      for (final beat in beats) {
        final binding = resolveAnimationBinding(beat.animationBindingId)!;
        final n = kTestOpponent.sheets[beat.animKey]!.frames;
        for (final p in _progressSamples) {
          expect(
            attackFrameIndex(
              n: n,
              phase: AttackPhase.active,
              progress: p,
              contactFrame: binding.contactFrame,
            ),
            binding.contactFrame,
            reason:
                '${binding.id}: active boyunca DARBE karesi sabit gösterilir',
          );
        }
      }
    });

    test('timeline + binding (samuray): contact, active penceresinde once\'ın '
        'gösterdiği kare aralığına düşer', () {
      // Oyuncu light: lineer `once` ile çizilir; binding contact karesi mekanik
      // `active` penceresinde fiilen gösterilen kareler içinde olmalı.
      final binding = resolveAnimationBinding(kPlayerLight.animationBindingId)!;
      final total = kPlayerLight.timeline.duration;
      final active = kPlayerLight.timeline.windowFor(CombatWindowKind.active)!;
      final n = kPlayerDef.sheets[binding.sheetKey]!.frames;

      final loFrame = _onceIndex(n, active.start, total);
      final hiFrame = _onceIndex(n, active.end, total);
      expect(binding.contactFrame, isNotNull);
      expect(
        binding.contactFrame! >= loFrame && binding.contactFrame! <= hiFrame,
        isTrue,
        reason:
            'contact=${binding.contactFrame} active aralığı '
            '[$loFrame..$hiFrame] içinde olmalı (asset mekaniğe hizalı)',
      );
    });
  });

  group('HitboxSpec — ayağa-normalize standart', () {
    test('knight_1.attack2 örneği makul sınırlarda (0..1, öne erim)', () {
      const h = kKnight1Attack2Hitbox;
      expect(h.x, greaterThan(0), reason: 'erim öne (+x) uzanmalı');
      for (final v in [h.x, h.y, h.width, h.height]) {
        expect(v, inInclusiveRange(0.0, 1.0), reason: 'birimsiz, ~0..1');
      }
      expect(h.left, lessThan(h.right));
      expect(h.bottom, lessThan(h.top));
    });
  });
}
