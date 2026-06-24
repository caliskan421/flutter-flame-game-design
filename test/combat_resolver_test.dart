// CombatResolver.resolveContact saf karar testleri (Faz B). boss._resolveContact
// dallanmasının Flame'siz kilidi: doğru araç+zamanlama → parry; yanlış araç/yön
// → wrongTool; dodge i-frame → dodgeSuccess; tracking i-frame'i deler. Mevcut
// combat_rules_test.dart ile çelişmez (o, Player.* timing kurallarını kilitler;
// bu, kararın o kurallar üstündeki dallanmasını kilitler).

import 'package:boss_parry_arena/characters.dart';
import 'package:boss_parry_arena/combat/rules/combat_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Ortak girdi kurucusu; testler yalnız ilgilendiği alanı değiştirir.
  ContactDecision resolve({
    DefenseProfile defense = DefenseProfile.normal,
    GuardDirection guardDirection = GuardDirection.any,
    bool isFeint = false,
    bool playerInvulnerable = false,
    bool guardMatches = true,
    double sinceParry = 999,
    double sinceDodge = 999,
    double beatPreWindow = 0.2,
    double effectiveParryWindow = 0.13,
    double dodgePre = 0.2,
  }) {
    return CombatResolver.resolveContact(
      defense: defense,
      guardDirection: guardDirection,
      isFeint: isFeint,
      playerInvulnerable: playerInvulnerable,
      guardMatches: guardMatches,
      sinceParry: sinceParry,
      sinceDodge: sinceDodge,
      beatPreWindow: beatPreWindow,
      effectiveParryWindow: effectiveParryWindow,
      dodgePre: dodgePre,
    );
  }

  group('feint & i-frame', () {
    test('aldatma her zaman feint çözümüne gider', () {
      expect(resolve(isFeint: true).action, ContactAction.feint);
    });

    test('dodge i-frame normal saldırıyı geçersiz kılar → dodgeSuccess', () {
      expect(
        resolve(playerInvulnerable: true).action,
        ContactAction.dodgeSuccess,
      );
    });

    test('tracking saldırısı i-frame\'i deler (dodgeSuccess vermez)', () {
      // Invulnerable ama tracking: dodge başarısı yok; zamanında parry ile karşılanır.
      final d = resolve(
        defense: DefenseProfile.tracking,
        playerInvulnerable: true,
        guardMatches: true,
        sinceParry: 0,
      );
      expect(d.action, ContactAction.parrySuccess);
    });
  });

  group('normal beat', () {
    test('doğru yön + zamanında parry → parrySuccess', () {
      expect(resolve(sinceParry: 0).action, ContactAction.parrySuccess);
    });

    test('geç parry (pencere dışı) → beginPending', () {
      expect(resolve(sinceParry: 0.5).action, ContactAction.beginPending);
    });

    test('zamanında ama yanlış yön + yönlü beat → wrongTool', () {
      final d = resolve(
        guardDirection: GuardDirection.high,
        guardMatches: false,
        sinceParry: 0,
      );
      expect(d.action, ContactAction.wrongTool);
      expect(d.wrongToolLabel, 'YANLIŞ YÖN!');
    });

    test('hiç savunma yoksa → beginPending', () {
      expect(resolve().action, ContactAction.beginPending);
    });

    test('spam ile daralan pencere başarıyı daraltır', () {
      // effWindow = min(preWindow, effectiveParryWindow). Daralmış pencerede
      // sinceParry pencerenin dışına düşerse parry tutmaz.
      final tight = resolve(
        sinceParry: 0.1,
        beatPreWindow: 0.2,
        effectiveParryWindow: 0.05,
      );
      expect(tight.action, ContactAction.beginPending);

      final wide = resolve(
        sinceParry: 0.1,
        beatPreWindow: 0.2,
        effectiveParryWindow: 0.13,
      );
      expect(wide.action, ContactAction.parrySuccess);
    });
  });

  group('guardBreak (kırmızı)', () {
    test('parry basıldıysa → wrongTool PARRY OLMAZ!', () {
      final d = resolve(defense: DefenseProfile.guardBreak, sinceParry: 0);
      expect(d.action, ContactAction.wrongTool);
      expect(d.wrongToolLabel, 'PARRY OLMAZ!');
    });

    test('parry basılmadıysa → beginPending (doğru cevap dodge)', () {
      expect(
        resolve(defense: DefenseProfile.guardBreak).action,
        ContactAction.beginPending,
      );
    });
  });

  group('thrust (mikiri)', () {
    test('parry basıldıysa → wrongTool MİKİRİ! KAÇ', () {
      final d = resolve(defense: DefenseProfile.thrust, sinceParry: 0);
      expect(d.action, ContactAction.wrongTool);
      expect(d.wrongToolLabel, 'MİKİRİ! KAÇ');
    });

    test('parry basılmadıysa → beginPending', () {
      expect(
        resolve(defense: DefenseProfile.thrust).action,
        ContactAction.beginPending,
      );
    });
  });

  group('tracking', () {
    test('zamanında doğru yön → parrySuccess', () {
      expect(
        resolve(defense: DefenseProfile.tracking, sinceParry: 0).action,
        ContactAction.parrySuccess,
      );
    });

    test('yanlış yön parry → wrongTool YANLIŞ YÖN!', () {
      final d = resolve(
        defense: DefenseProfile.tracking,
        guardMatches: false,
        sinceParry: 0,
      );
      expect(d.action, ContactAction.wrongTool);
      expect(d.wrongToolLabel, 'YANLIŞ YÖN!');
    });

    test('dodge denendi ama parry yok → wrongTool KAÇILMAZ!', () {
      final d = resolve(
        defense: DefenseProfile.tracking,
        sinceDodge: 0,
        dodgePre: 0.22,
      );
      expect(d.action, ContactAction.wrongTool);
      expect(d.wrongToolLabel, 'KAÇILMAZ!');
    });

    test('hiç savunma yok → beginPending', () {
      expect(
        resolve(defense: DefenseProfile.tracking).action,
        ContactAction.beginPending,
      );
    });
  });
}
