import 'package:boss_parry_arena/combat/data/characters.dart';

enum TestAttackMode { combo, attack1, attack2, attack3, defend, movement }

bool testAttackModeUsesScenarioRules(TestAttackMode attackMode) {
  switch (attackMode) {
    case TestAttackMode.attack1:
    case TestAttackMode.attack2:
    case TestAttackMode.attack3:
    case TestAttackMode.combo:
      return true;
    case TestAttackMode.defend:
    case TestAttackMode.movement:
      return false;
  }
}

CharacterDef testDefFor(TestAttackMode attackMode) {
  final base = kTestOpponent;
  if (attackMode == TestAttackMode.defend) {
    return base;
  }

  final index = switch (attackMode) {
    TestAttackMode.attack1 => 0,
    TestAttackMode.attack2 => 1,
    TestAttackMode.attack3 => 2,
    TestAttackMode.combo => 0,
    TestAttackMode.defend => 0,
    TestAttackMode.movement => 0,
  };
  final sourceBeat = base.pattern.beats[index];
  final lowBeat = base.pattern.beats[0];
  final highBeat = base.pattern.beats[1];
  final defendBeat = base.pattern.beats[2];

  Beat lowGuardBeat(Beat source) => Beat(
    kind: source.kind,
    defense: DefenseProfile.normal,
    animKey: source.animKey,
    windup: source.windup,
    active: source.active,
    recover: source.recover,
    gapAfter: .18,
    preWindow: .12,
    grace: .11,
    dodgePre: .32,
    damage: source.damage,
    postureDamage: source.postureDamage,
    guardDirection: GuardDirection.low,
    punishOnDodge: false,
    mustDefend: true,
    projectileKey: source.projectileKey,
    projectileSpeed: source.projectileSpeed,
  );

  Beat highGuardBeat(Beat source) => Beat(
    kind: BeatKind.meleeHeavy,
    defense: DefenseProfile.normal,
    animKey: source.animKey,
    windup: source.windup,
    active: source.active,
    recover: source.recover,
    gapAfter: .18,
    preWindow: .14,
    grace: .16,
    dodgePre: .32,
    damage: source.damage,
    postureDamage: 18,
    guardDirection: GuardDirection.high,
    punishOnDodge: false,
    mustDefend: true,
    projectileKey: source.projectileKey,
    projectileSpeed: source.projectileSpeed,
  );

  Beat centerGuardBeat(Beat source) => Beat(
    kind: source.kind,
    defense: DefenseProfile.tracking,
    animKey: source.animKey,
    windup: source.windup,
    active: source.active,
    recover: source.recover,
    gapAfter: .28,
    preWindow: .035,
    grace: .09,
    dodgePre: source.dodgePre,
    damage: source.damage,
    postureDamage: source.postureDamage,
    guardDirection: GuardDirection.any,
    punishOnDodge: false,
    mustDefend: true,
    projectileKey: source.projectileKey,
    projectileSpeed: source.projectileSpeed,
  );

  final beat = switch (attackMode) {
    TestAttackMode.attack1 => lowGuardBeat(sourceBeat),
    TestAttackMode.attack2 => highGuardBeat(sourceBeat),
    TestAttackMode.attack3 => centerGuardBeat(sourceBeat),
    TestAttackMode.combo => sourceBeat,
    TestAttackMode.defend => sourceBeat,
    TestAttackMode.movement => sourceBeat,
  };
  final label = switch (attackMode) {
    TestAttackMode.attack1 => 'ALT SALDIRI',
    TestAttackMode.attack2 => 'ÜST SALDIRI',
    TestAttackMode.attack3 => 'DEFEND SALDIRISI',
    TestAttackMode.combo => 'HİKAYE MODU',
    TestAttackMode.defend => 'KALKAN TESTİ',
    TestAttackMode.movement => 'HAREKET MEKANİKLERİ',
  };
  final blurb = switch (attackMode) {
    TestAttackMode.attack1 =>
      'Attack 1 alttan yukarı gelir; doğru anda ↓ ile attack2 son karesiyle savuştur.',
    TestAttackMode.attack2 =>
      'Attack 2 üstten gelir; doğru anda ↑ ile defend/savuştur.',
    TestAttackMode.attack3 =>
      'Attack 3 gelir; doğru anda SPACE ile defend/savuştur.',
    TestAttackMode.combo =>
      'Kalkan penceresi, alt savunma, üst savunma ve SPACE/defend aynı döngüde.',
    TestAttackMode.defend =>
      'Rakip idle/defend döner. F kalkanda denge azaltır; G kalkanda ağır ceza yedirir.',
    TestAttackMode.movement =>
      'Samuray yatay eksende yürür; çift basış aynı yönde koşuya çevirir.',
  };

  return CharacterDef(
    id: base.id,
    cls: base.cls,
    name: base.name,
    title: label,
    blurb: blurb,
    sheets: base.sheets,
    combos: attackMode == TestAttackMode.combo
        ? [
            ComboPattern([
              lowGuardBeat(lowBeat),
              highGuardBeat(highBeat),
              centerGuardBeat(defendBeat),
            ], staggerBonus: 50),
          ]
        : [
            ComboPattern([beat], staggerBonus: 8),
          ],
    cellPx: base.cellPx,
    feetV: base.feetV,
    ranged: base.ranged,
    maxPosture: base.maxPosture,
    deathblowsRequired: base.deathblowsRequired,
  );
}
