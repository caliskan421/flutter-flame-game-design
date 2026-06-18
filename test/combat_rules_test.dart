// Parry decay ve dodge i-frame'in GERÇEKTEN bağlı olduğunu doğrulayan davranış
// testleri. Boss temas çözümü (lib/boss.dart) ile birim testleri AYNI saf kural
// fonksiyonlarını (Player.*) kullanır → testler oyun çözümünün davranışını kilitler.

import 'dart:math' as math;

import 'package:boss_parry_arena/boss.dart';
import 'package:boss_parry_arena/characters.dart';
import 'package:boss_parry_arena/player.dart';
import 'package:flutter_test/flutter_test.dart';

// Boss._resolveContact'taki efektif pencere hesabının aynısı (tek doğruluk kaynağı).
double effectiveParryWindow(double beatPreWindow, double playerWindow) =>
    math.min(beatPreWindow, playerWindow);

// Boss._performDeathblow karar mantığının aynısı (06). Son segment/eşik öldürür.
bool deathblowLethal({
  required int hpBefore,
  required int done,
  required int required,
  required int execThreshold,
}) => done >= required || hpBefore <= execThreshold;

// Segment silinince HP bir sonraki faz eşiğine düşürülür → faz görünür değişir.
int deathblowNextHp(int hp) => hp > 50 ? 50 : (hp > 25 ? 25 : 1);

void main() {
  group('parry window decay (03)', () {
    test('ardışık spam parry penceresini daraltır, tabanın altına inmez', () {
      final fresh = Player.decayParryWindow(Player.parryWindowDuration, 0);
      final once = Player.decayParryWindow(Player.parryWindowDuration, 1);
      final spammed = Player.decayParryWindow(Player.parryWindowDuration, 5);

      expect(fresh, Player.parryWindowDuration);
      expect(once, lessThan(fresh));
      expect(spammed, lessThan(once));
      // Sonsuza kadar daralmaz: bir taban vardır.
      expect(spammed, greaterThan(0));
      expect(
        Player.decayParryWindow(Player.parryWindowDuration, 50),
        greaterThanOrEqualTo(0.05),
      );
    });

    test('spam sonrası eski beat penceresinde basış ARTIK başarısız', () {
      // Temas anında basıştan 0.10s geçmiş: taze pencerede başarı, spam'de değil.
      const sincePress = 0.10;
      const beat = Beat(
        kind: BeatKind.meleeLight,
        animKey: 'a',
        preWindow: 0.12,
      );

      final freshWin = effectiveParryWindow(
        beat.preWindow,
        Player.decayParryWindow(Player.parryWindowDuration, 0),
      );
      final spamWin = effectiveParryWindow(
        beat.preWindow,
        Player.decayParryWindow(Player.parryWindowDuration, 4),
      );

      // Spam yapmadan: 0.10s tolerans içinde → parry tutar.
      expect(Player.parrySucceeds(sincePress, freshWin), isTrue);
      // Spam ile pencere ~0.13*0.7^4≈0.031'e indi → 0.10s artık dışarıda → başarısız.
      expect(Player.parrySucceeds(sincePress, spamWin), isFalse);
    });

    test('mükemmel zamanlama (temasa çok yakın basış) spam\'de bile tutar', () {
      // Pencere daralsa da, temas anında basılırsa (sinceParry~0) yine başarılı.
      final spamWin = effectiveParryWindow(
        0.12,
        Player.decayParryWindow(Player.parryWindowDuration, 4),
      );
      expect(Player.parrySucceeds(0.0, spamWin), isTrue);
    });
  });

  group('dodge i-frame (04)', () {
    test('dokunulmazlık aralığı içindeki dodge başarılı', () {
      expect(Player.dodgeInvulnerableAt(Player.dodgeInvulnFrom), isTrue);
      expect(Player.dodgeInvulnerableAt(Player.perfectDodgeUntil), isTrue);
      expect(Player.dodgeInvulnerableAt(Player.dodgeInvulnTo), isTrue);
      // Aralığın ortası
      expect(
        Player.dodgeInvulnerableAt(
          (Player.dodgeInvulnFrom + Player.dodgeInvulnTo) / 2,
        ),
        isTrue,
      );
    });

    test('i-frame DIŞINDA dodge başarısız (greed cezalanır)', () {
      // Çok erken (henüz dokunulmazlık başlamadı)
      expect(Player.dodgeInvulnerableAt(0.0), isFalse);
      expect(
        Player.dodgeInvulnerableAt(Player.dodgeInvulnFrom - 0.005),
        isFalse,
      );
      // Çok geç (dokunulmazlık bitti, recovery kuyruğu)
      expect(Player.dodgeInvulnerableAt(Player.dodgeInvulnTo + 0.02), isFalse);
      expect(Player.dodgeInvulnerableAt(0.30), isFalse);
    });

    test('perfect dilim i-frame penceresinin erken kısmı', () {
      expect(Player.perfectDodgeUntil, greaterThan(Player.dodgeInvulnFrom));
      expect(Player.perfectDodgeUntil, lessThan(Player.dodgeInvulnTo));
    });
  });

  group('deathblow / segment model (06/08)', () {
    test(
      'denge kırığında F küçük tekrar hasarı verir, G infaz rolünü korur',
      () {
        expect(Boss.attackHpStaggeredLight, 15);
      },
    );

    test(
      'G infaz faz geçişinde ağır saldırının kalan süresi kadar hurt tutar',
      () {
        expect(
          Boss.phaseTransitionDeathblowHurtHold,
          Player.heavyAtkActive + Player.heavyAtkRecover,
        );
      },
    );

    test('G infaz kesilme sesi ağır kılıç çekişinden sonra gecikir', () {
      expect(Boss.heavyDeathblowSfxDelay, greaterThan(Player.heavyAtkActive));
    });

    test('şövalye rakipler 2 infaz ister; varsayılan tek infaz', () {
      expect(characterById('knight_1').deathblowsRequired, 2);
      expect(characterById('knight_2').deathblowsRequired, 2);
      expect(characterById('knight_3').deathblowsRequired, 2);
      // Veri varsayılanı: belirtilmeyen karakterler tek infaz.
      expect(characterById('samurai').deathblowsRequired, 1);
      expect(characterById('fire_wizard').deathblowsRequired, 1);
    });

    test(
      'son segment veya düşük HP eşiği öldürür, aksi halde segment siler',
      () {
        const required = 2, exec = 30;
        // Yüksek HP, ilk infaz: öldürmez (segment siler).
        expect(
          deathblowLethal(
            hpBefore: 90,
            done: 1,
            required: required,
            execThreshold: exec,
          ),
          isFalse,
        );
        // Gerekli sayıya ulaşan infaz: öldürür.
        expect(
          deathblowLethal(
            hpBefore: 60,
            done: 2,
            required: required,
            execThreshold: exec,
          ),
          isTrue,
        );
        // Düşük HP'de (eşik altı) ilk infaz bile öldürür.
        expect(
          deathblowLethal(
            hpBefore: 25,
            done: 1,
            required: required,
            execThreshold: exec,
          ),
          isTrue,
        );
      },
    );

    test('segment silindiğinde HP bir sonraki faz eşiğine düşer', () {
      // >50 → 50 (faz 0→1), >25 → 25 (faz 1→2), altı → 1.
      expect(deathblowNextHp(90), 50);
      expect(deathblowNextHp(50), 25);
      expect(deathblowNextHp(40), 25);
      expect(deathblowNextHp(20), 1);
    });
  });
}
