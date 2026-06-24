// ============================================================================
//  OYUNCU  —  SAMURAY + spring fizik + parry / dodge / saldırı
// ----------------------------------------------------------------------------
//  SADE MODEL (2 cevap):
//    SPACE  Parry   — VARSAYILAN cevap. Boss'un DENGESİNİ kırar + kısa tempo verir.
//    SHIFT  Dodge   — yalnız KIRMIZI (kaçılması gereken) saldırılarda. Hasarsız
//                     sıyrıl; kırmızıyı dodge'larsan boss AÇILIR.
//    F      Saldır  — boss AÇIKKEN (denge kırık / dodge sonrası) gerçek HP hasarı.
//
//  Kırmızı saldırıyı parry'lemek cezalandırılır (getStunned): kısa kilit + chip.
// ============================================================================

import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'audio.dart';
import 'characters.dart';
import 'combat/data/action_timeline.dart';
import 'combat/data/move_def.dart';
import 'game.dart';
import 'sprite_strip.dart';
import 'theme.dart';

enum PlayerState {
  idle,
  parry,
  block,
  counter,
  riposte,
  dodge,
  attack,
  hurt,
  stunned,
  dead,
}

/// Başarılı parry'nin zamanlama kalitesi (03_parry_pencere_dinamigi).
///   perfect → pencerenin ilk diliminde; ekstra posture + tam hitstop + parlak.
///   late    → pencerenin geç dilimi; daha tok, az posture, hitstop yok.
enum ParryQuality { perfect, late }

class Player extends PositionComponent with HasGameReference<BossArenaGame> {
  PlayerState state = PlayerState.idle;
  int health = 100;
  double displayHealth = 100;
  int posture = 100;
  double displayPosture = 100;

  // --- STAMINA / KAYNAK (01) ---
  double stamina = 100;
  double maxStamina = 100;
  double displayStamina = 100;
  double _staminaIdle = 0; // son aksiyondan bu yana (regen gecikmesi)
  bool get unlimitedStamina => game.actionSystem.unlimitedStamina;
  // "Yorgun": düşük staminada HUD barı kırmızı yanıp söner, aksiyonlar reddedilir.
  bool get isExhausted =>
      !unlimitedStamina &&
      stamina < maxStamina * game.actionSystem.lowStaminaFraction;

  // --- PARRY (hassas) ---
  // Süreler `kPlayerParry`/move_def'den (TEK KAYNAK) gelir; bu const'lar
  // alias'tır (boss.dart + birim testler bunları const olarak okur).
  static const double parryWindowDuration = kPlayerParryWindow;
  static const double lowParryWindowDuration = kPlayerLowParryWindow;
  static const double parryCooldownDuration = 0.34;
  double _parryWindow = 0;
  double _parryWindowMax = parryWindowDuration;
  double _parryCooldown = 0;
  GuardDirection _parryGuard = GuardDirection.any;
  GuardDirection _counterGuard = GuardDirection.any;

  // --- PARRY DECAY & KALİTE (03) ---
  // Ardışık (kısa aralıklı) basışlar penceresi daraltır: parry spam'i cezalanır.
  static const double _parrySpamGap = 0.5; // bu süreden uzaksa sayaç sıfırlanır
  static const double _parryWindowFloor = 0.05;
  int _parrySpam = 0;
  // Son başarılı parry'nin kalitesi (boss juice/feedback için okur).
  ParryQuality lastParryQuality = ParryQuality.perfect;

  // --- DODGE (geniş pencere; yalnız kırmızı saldırılarda anlamlı) ---
  // Süre/i-frame sınırları `kPlayerDodge`/move_def'den (TEK KAYNAK) gelir.
  static const double dodgeWindowDuration = kPlayerDodgeDuration;
  static const double dodgeCooldownDuration = 0.42;
  double _dodgeWindow = 0;
  double _dodgeCooldown = 0;
  double _dodgeT = 999;
  double _dodgeDur = dodgeWindowDuration;
  // --- DODGE i-FRAME (04) ---
  // Dodge animasyonunun ortasında gerçek dokunulmazlık aralığı; bu pencerede
  // HER hasar kaynağı (melee/mermi) geçersiz. İlk dilim "perfect" (slow-mo ödülü).
  static const double dodgeInvulnFrom = kPlayerDodgeIframeFrom;
  static const double dodgeInvulnTo = kPlayerDodgeIframeTo;
  static const double perfectDodgeUntil = kPlayerDodgePerfectUntil;
  bool get isInvulnerable =>
      state == PlayerState.dodge && dodgeInvulnerableAt(_dodgeT);
  // i-frame'in erken (perfect) diliminde miyiz? Boss daha uzun punish + slow-mo verir.
  bool get isPerfectDodge =>
      state == PlayerState.dodge && _dodgeT <= perfectDodgeUntil;

  // --- SAF KURAL FONKSİYONLARI (boss çözümü + birim testler aynısını kullanır) ---
  // Dodge başından bu yana geçen süre dokunulmazlık (i-frame) aralığında mı?
  // ARALIK DIŞINDA dodge başlamış olsa bile saldırı isabet eder (greed cezası, 04).
  static bool dodgeInvulnerableAt(double dodgeT) =>
      kPlayerDodge.timeline.isIn(CombatWindowKind.iframe, dodgeT);

  // Ardışık spam sayacına göre daralan parry penceresi (03). Sayaç arttıkça daralır,
  // bir tabanın altına inmez.
  static double decayParryWindow(double base, int spam) =>
      max(_parryWindowFloor, base * pow(0.7, spam).toDouble());

  // Parry başarısı: basıştan bu yana geçen süre, EFEKTİF pencereden küçük/eşitse.
  // Efektif pencere = beat penceresi ile oyuncunun (daralmış olabilen) penceresinin
  // küçüğü → spam sonrası eski beat penceresi başarıyı kurtaramaz.
  static bool parrySucceeds(double sinceParry, double effectiveWindow) =>
      sinceParry <= effectiveWindow;

  // --- TEMPO (comboWindow): başarılı parry sonrası kısa saldırı avantajı ---
  static const double tempoDuration = 0.6;
  double _tempo = 0;
  bool get hasTempo => _tempo > 0;

  // --- SALDIRI (tek tip) ---
  // Faz fazları `kPlayerLight`/`kPlayerHeavy` timeline'larından (TEK KAYNAK) gelir;
  // bu const'lar alias'tır (boss.dart + birim testler const olarak okur).
  static const double atkWindup = kPlayerLightWindup;
  static const double atkActive = kPlayerLightActive;
  static const double atkRecover = kPlayerLightRecover;
  static const double heavyAtkWindup = kPlayerHeavyWindup;
  static const double heavyAtkActive = kPlayerHeavyActive;
  static const double heavyAtkRecover = kPlayerHeavyRecover;
  static const double attackCooldownDuration = 0.18;
  double _attackCooldown = 0;
  double _atkT = 0;
  bool _atkContacted = false;
  PlayerAttackType _attackType = PlayerAttackType.light;

  // --- KOMBO ZİNCİRİ (05) ---
  // Ardışık light'lar comboStep arttırır; heavy = finisher. Zincir penceresi
  // kaçırılırsa idle'a düşer ve sayaç sıfırlanır.
  static const double comboWindowDuration = 0.55;
  int comboStep = 0;
  double _comboWindow = 0;
  bool _lastAttackWasFinisher = false;
  bool get isFinisher => _lastAttackWasFinisher;

  // --- BLOK / GUARD (02) ---
  bool _blockHeld = false;
  static const double riposteDuration = 0.22;
  double _riposteT = 0;
  String _riposteKey = 'attack1';

  double _stateTimer = 0;
  double _t = 0;
  bool _movementTraining = false;
  int _moveDir = 0;
  bool _moveRunning = false;
  int _facing = 1;
  double _moveOffset = 0;
  Rect _moveBounds = Rect.zero;

  // Son parry / dodge basışından bu yana geçen süre (boss tolerans okur).
  double sinceParry = 999;
  double sinceDodge = 999;

  Color _fill = kWhite;
  Vector2 _basePos = Vector2.zero();

  // Spring tabanlı animasyon
  double _kb = 0, _kbV = 0;
  double _sq = 0, _sqV = 0;
  double _tilt = 0, _tiltV = 0;

  // Ölüm sekansı
  bool dying = false;
  bool deathDone = false;
  double _deathT = 0;
  bool _swordDropPlayed = false;

  Player() : super(size: Vector2(96, 112), anchor: Anchor.bottomCenter);

  final CharacterDef _def = kPlayerDef;
  late final SpriteStripBank _sprites = SpriteStripBank(_def);
  double get _cellPx => _def.cellPx;
  double get _feetV => _def.feetV;

  static const double _deathFrameTime = 0.16;
  int get _deadFrames => _def.sheets['dead']?.frames ?? 1;
  double get _deathDur => _deathFrameTime * (_deadFrames - 1) + 0.5;

  static final Paint _spritePaint = Paint()..filterQuality = FilterQuality.none;

  bool get isParrying => _parryWindow > 0;
  GuardDirection get parryGuard => _parryGuard;
  // Oyuncunun şu anki (spam ile daralmış olabilen) parry penceresi. Boss temas
  // çözümünde beat penceresiyle birlikte bunun küçüğünü kullanır (03).
  double get effectiveParryWindow => _parryWindowMax;
  bool get isDodging => _dodgeWindow > 0;
  bool get isAttacking => state == PlayerState.attack;
  bool get isBlocking => state == PlayerState.block;
  bool get movementTrainingActive => _movementTraining;
  bool get isMovingHorizontally => _movementTraining && _moveDir != 0;
  bool get isRunningHorizontally => isMovingHorizontally && _moveRunning;
  bool get isBusy =>
      isAttacking ||
      state == PlayerState.riposte ||
      state == PlayerState.stunned ||
      state == PlayerState.hurt;

  // Boss'un GREED okuması için (09): saldırının savunmasız RECOVERY dilimindeyiz
  // (active bitti, henüz idle değiliz) — light burada cancel edilebilir, ama hâlâ
  // boss'un hızlı karşı-beat'i için "açık" sayılır. Heavy ise tüm recovery boyunca.
  bool get isInAttackRecovery =>
      isAttacking && _atkT >= _atkWindup + _atkActive;

  // Boss'un GUARD-BREAK punish okuması için (09).
  bool get isStunned => state == PlayerState.stunned;

  // Light saldırının recovery'sinin geç kısmı dodge/parry ile iptal edilebilir
  // (defansa pürüzsüz geçiş). Heavy taahhüttür: iptal edilemez (05).
  bool get _canCancelAttack =>
      isAttacking &&
      _attackType == PlayerAttackType.light &&
      _atkT >= _atkWindup + _atkActive;

  // Aktif saldırının veri tanımı (light/heavy). Süreler buradaki timeline'dan
  // okunur; `Player` artık süreyi kendi içinde toplamaz (C3).
  PlayerMoveDef get _attackMove =>
      _attackType == PlayerAttackType.heavy ? kPlayerHeavy : kPlayerLight;
  double get _atkWindup =>
      _attackType == PlayerAttackType.heavy ? heavyAtkWindup : atkWindup;
  double get _atkActive =>
      _attackType == PlayerAttackType.heavy ? heavyAtkActive : atkActive;
  double get _atkTotal => _attackMove.timeline.duration;

  @override
  Future<void> onLoad() async {
    await _sprites.load(game.images.load);
  }

  void place(Vector2 p) {
    position = p;
    _basePos = p.clone();
    _moveOffset = 0;
  }

  void setMovementTrainingEnabled(bool enabled) {
    _movementTraining = enabled;
    if (!enabled) {
      _moveDir = 0;
      _moveRunning = false;
      _moveOffset = 0;
    }
  }

  void setMovementBounds(Rect bounds) {
    _moveBounds = bounds;
  }

  void setHorizontalMove(int direction, {required bool running}) {
    _moveDir = direction.sign;
    _moveRunning = running && _moveDir != 0;
    if (_moveDir != 0) _facing = _moveDir;
  }

  void reset() {
    health = 100;
    displayHealth = 100;
    posture = 100;
    displayPosture = 100;
    maxStamina = game.actionSystem.maxStamina;
    stamina = maxStamina;
    displayStamina = maxStamina;
    _staminaIdle = 0;
    _tempo = 0;
    state = PlayerState.idle;
    _fill = kWhite;
    _parryWindow = 0;
    _parryWindowMax = parryWindowDuration;
    _parryCooldown = 0;
    _parrySpam = 0;
    lastParryQuality = ParryQuality.perfect;
    _parryGuard = GuardDirection.any;
    _counterGuard = GuardDirection.any;
    _dodgeWindow = 0;
    _dodgeCooldown = 0;
    _dodgeT = 999;
    _dodgeDur = dodgeWindowDuration;
    _attackCooldown = 0;
    _atkT = 0;
    _atkContacted = false;
    _attackType = PlayerAttackType.light;
    comboStep = 0;
    _comboWindow = 0;
    _lastAttackWasFinisher = false;
    _blockHeld = false;
    _riposteT = 0;
    _riposteKey = 'attack1';
    _stateTimer = 0;
    sinceParry = 999;
    sinceDodge = 999;
    dying = false;
    deathDone = false;
    _deathT = 0;
    _swordDropPlayed = false;
    _testRegenAcc = 0;
    _kb = _kbV = _sq = _sqV = _tilt = _tiltV = 0;
    _moveDir = 0;
    _moveRunning = false;
    _moveOffset = 0;
    if (_basePos != Vector2.zero()) position = _basePos.clone();
  }

  // -------------------------------------------------------------- GİRDİLER
  // Stamina harcama denemesi. Sınırsızsa hep başarılı. Yetmezse reddedilir,
  // "yorgun" feedback'i verilir ve denial metriği artar (01).
  bool _spendStamina(double cost) {
    if (unlimitedStamina || cost <= 0) {
      _staminaIdle = 0;
      return true;
    }
    if (stamina < cost) {
      game.metrics.staminaEmptyDenials++;
      Sfx.tired();
      spawnExhaustedFeedback();
      return false;
    }
    stamina -= cost;
    _staminaIdle = 0;
    return true;
  }

  void spawnExhaustedFeedback() {
    game.spawnPopup(
      Vector2(position.x, position.y - size.y * 0.7),
      'YORGUN',
      fontSize: 13,
      color: kBarRed,
      rise: 20,
    );
  }

  void tryParry([GuardDirection guard = GuardDirection.any]) {
    if (game.phase != GamePhase.playing || dying) return;
    if (_canCancelAttack) _cancelAttackToDefense();
    if (isBusy || state == PlayerState.dodge) return;
    if (_parryCooldown > 0) return;
    // Window decay: kısa aralıkla ardışık basışta sayaç artar, pencere daralır.
    if (sinceParry < _parrySpamGap) {
      _parrySpam++;
    } else {
      _parrySpam = 0;
    }
    final base = guard == GuardDirection.low
        ? lowParryWindowDuration
        : parryWindowDuration;
    _parryWindowMax = decayParryWindow(base, _parrySpam);
    _parryWindow = _parryWindowMax;
    _parryCooldown = parryCooldownDuration;
    _parryGuard = guard;
    sinceParry = 0;
    if (state == PlayerState.block) _blockHeld = false;
    state = PlayerState.parry;
  }

  // Bir parry başarısının perfect mi late mi olduğunu, basışın pencerenin neresine
  // denk geldiğine göre belirler (boss temas anında çağırır). Küçük sinceParry =
  // temasa yakın basış = mükemmel zamanlama.
  ParryQuality classifyParry() {
    final perfect = sinceParry <= _parryWindowMax * 0.45;
    lastParryQuality = perfect ? ParryQuality.perfect : ParryQuality.late;
    return lastParryQuality;
  }

  void tryDodge() {
    if (game.phase != GamePhase.playing || dying) return;
    if (_canCancelAttack) _cancelAttackToDefense();
    if (isBusy) return;
    if (_dodgeCooldown > 0) return;
    if (!_spendStamina(game.actionSystem.dodgeStaminaCost)) return;
    _dodgeWindow = dodgeWindowDuration;
    _dodgeCooldown = dodgeCooldownDuration;
    _dodgeT = 0;
    _dodgeDur = dodgeWindowDuration + 0.04;
    sinceDodge = 0;
    if (state == PlayerState.block) _blockHeld = false;
    state = PlayerState.dodge;
    _stateTimer = _dodgeDur;
    _kbV += game.actionSystem.playerDodgeKnockbackImpulse;
    _sq = 0.12;
    _sqV = 0;
    _tiltV -= 5;
  }

  // -------------------------------------------------------------- BLOK / GUARD
  // Tutulan savunma: HP yemez ama posture+stamina maliyeti, knockback ve donuk
  // metal sesi. Posture dolarsa guard break → sersem (02).
  void tryBlockStart() {
    if (game.phase != GamePhase.playing || dying) return;
    _blockHeld = true;
    if (isBusy || state == PlayerState.dodge || isParrying) return;
    state = PlayerState.block;
  }

  void tryBlockEnd() {
    _blockHeld = false;
    if (state == PlayerState.block) {
      state = PlayerState.idle;
      _fill = kWhite;
    }
  }

  // Boss saldırısı blok sırasında geldi. guardBreak (kırmızı) blokta delip geçer:
  // chip HP + büyük posture; diğerleri hasarsız ama posture+stamina yer.
  void takeBlockedHit(Beat beat) {
    if (dying) return;
    final bool perilous = beat.defense == DefenseProfile.guardBreak;
    int posMul = beat.kind == BeatKind.meleeHeavy ? 34 : 18;
    if (perilous) posMul = 46;
    // Stamina yetmezse blok zayıflar: daha çok posture + bir miktar chip sızar.
    final paid = _spendStamina(game.actionSystem.blockStaminaCost);
    if (!paid) posMul = (posMul * 1.5).round();
    _kbV += game.actionSystem.playerHitKnockbackImpulse(-1, beat.damage) * 0.5;
    _sq = -0.16;
    _sqV = 0;
    _tiltV += 5;
    Sfx.block();
    if (perilous || !paid) {
      final chip = perilous
          ? (beat.damage * 0.5).round()
          : (beat.damage * 0.25).round();
      if (chip > 0) {
        health = (health - chip).clamp(game.actionSystem.minPlayerHealth, 100);
        game.metrics.playerDamageTaken += chip;
        game.spawnPopup(
          Vector2(position.x, position.y - size.y * 0.8),
          '-$chip',
          fontSize: 15,
          color: kBarRed,
        );
      }
    }
    takePostureDamage(posMul);
    if (health <= 0) _startDeath();
  }

  // F/G: saldırı. Light'lar zincirlenir (comboStep), heavy finisher'dır. Animasyon
  // her zaman oynar; temas active karesinde çözülür. Stamina'ya bağlıdır (05).
  void tryAttack([PlayerAttackType type = PlayerAttackType.light]) {
    if (game.phase != GamePhase.playing || dying) return;
    if (isBusy || _attackCooldown > 0) return;
    if (state == PlayerState.dodge && _dodgeWindow > 0) return;
    final cost = type == PlayerAttackType.heavy
        ? game.actionSystem.heavyStaminaCost
        : game.actionSystem.lightStaminaCost;
    if (!_spendStamina(cost)) return;

    // Kombo adımı: zincir penceresi açıksa ilerle, değilse baştan başla.
    if (type == PlayerAttackType.heavy) {
      // Heavy: zincir varsa finisher, yoksa tek ağır vuruş.
      _lastAttackWasFinisher = _comboWindow > 0 && comboStep > 0;
      comboStep = 0;
    } else {
      comboStep = _comboWindow > 0 ? (comboStep + 1).clamp(0, 2) : 0;
      _lastAttackWasFinisher = false;
    }

    if (state == PlayerState.block) _blockHeld = false;
    state = PlayerState.attack;
    _attackType = type;
    _atkT = 0;
    _atkContacted = false;
    _attackCooldown = attackCooldownDuration;
    _fill = kBlack;
    _sq = type == PlayerAttackType.heavy ? 0.28 : 0.20;
    _sqV = 0;
    _kbV += game.actionSystem.playerAttackKnockbackImpulse;
    _tiltV += type == PlayerAttackType.heavy ? -5 : -3;
  }

  // Light recovery'sinden defansa pürüzsüz geçiş: saldırıyı kes, zinciri koru.
  void _cancelAttackToDefense() {
    state = PlayerState.idle;
    _fill = kWhite;
    _atkContacted = true;
    // Kombo penceresini açık tut: iptal sonrası saldırıya dönülürse zincir sürer.
    _comboWindow = comboWindowDuration;
  }

  bool get attackReady => _attackCooldown <= 0 && !isBusy && !dying;

  // Başarılı parry: pop + boss'a kısa itiş + TEMPO penceresi.
  void onParrySuccess() {
    state = PlayerState.counter;
    _stateTimer = 0.22;
    _counterGuard = _parryGuard;
    _fill = kBlack;
    _sq = 0.24;
    _sqV = 0;
    _kbV += 320;
    _tiltV += -3;
    _tempo = tempoDuration;
    // Parry ödül aracı: ücretsiz, üstüne küçük stamina iadesi (agresif savunma).
    if (!unlimitedStamina) {
      stamina = (stamina + game.actionSystem.parryStaminaRefund).clamp(
        0,
        maxStamina,
      );
    }
  }

  void onDodgeSuccess() {
    _sq = 0.10;
    _sqV = 0;
    _tiltV += 3;
  }

  void playParryFollowUp(GuardDirection input) {
    if (game.phase != GamePhase.playing || dying) return;
    _riposteKey = switch (input) {
      GuardDirection.low => 'attack3',
      GuardDirection.high => 'attack2',
      GuardDirection.any => 'attack1',
    };
    state = PlayerState.riposte;
    _riposteT = 0;
    _parryWindow = 0;
    _dodgeWindow = 0;
    _fill = kBlack;
    _sq = 0.20;
    _sqV = 0;
    _kbV += 180;
    _tiltV += input == GuardDirection.low ? -5 : -3;
  }

  void takeHit(int dmg, double dir) {
    if (dying) return;
    health = (health - dmg).clamp(game.actionSystem.minPlayerHealth, 100);
    game.metrics.playerDamageTaken += dmg;
    state = PlayerState.hurt;
    _stateTimer = 0.32;
    _fill = kGray800;
    _tempo = 0;
    _kbV += game.actionSystem.playerHitKnockbackImpulse(dir, dmg);
    _sq = -0.26;
    _sqV = 0;
    _tiltV += dir * 9;
    Sfx.hit();
    if (health <= 0) _startDeath();
  }

  void takePostureDamage(int dmg) {
    if (dmg <= 0 || dying) return;
    posture = (posture - dmg).clamp(0, 100);
    displayPosture = displayPosture.clamp(0, 100);
    _sq = -0.10;
    _tiltV += 3;
    if (posture <= 0) {
      getStunned(0.62);
    }
  }

  void breakPosture() {
    posture = 0;
    displayPosture = 0;
    getStunned(0.82);
  }

  // Kırmızı saldırıyı parry'leme cezası: kısa kilit + chip hasar.
  void getStunned(double dur, {int chip = 0}) {
    if (dying) return;
    _tempo = 0;
    _parryWindow = 0;
    _dodgeWindow = 0;
    _parryCooldown = max(_parryCooldown, 0.18);
    _dodgeCooldown = max(_dodgeCooldown, 0.18);
    if (chip > 0) {
      health = (health - chip).clamp(game.actionSystem.minPlayerHealth, 100);
      game.metrics.playerDamageTaken += chip;
    }
    state = PlayerState.stunned;
    _stateTimer = dur;
    _fill = kGray700;
    _sq = -0.14;
    _tiltV += 4;
    if (health <= 0) _startDeath();
  }

  // FEINT TUZAĞI (09): aldatmaya kanıp erken savunma yaptın. Hasarsız ama kısa
  // SAVUNMA KİLİDİ: parry/dodge cooldown'ı uzar, tempo gider → arkadan gelen
  // gerçek beat'i karşılayamazsın. Stun değil (kontrol sende), yalnız "yanlış
  // anda harcadın" cezası.
  void baitPunish(double lock) {
    if (dying) return;
    _tempo = 0;
    _parryWindow = 0;
    _dodgeWindow = 0;
    _parryCooldown = max(_parryCooldown, lock);
    _dodgeCooldown = max(_dodgeCooldown, lock);
    if (state == PlayerState.parry || state == PlayerState.block) {
      state = PlayerState.idle;
      _parryGuard = GuardDirection.any;
      _fill = kWhite;
    }
    _sq = -0.08;
    _tiltV += 3;
  }

  // TEST: ölümsüzlük için can rejeni biriktiricisi.
  double _testRegenAcc = 0;

  void _startDeath() {
    if (!game.actionSystem.playerCanDie) return;
    if (dying) return;
    dying = true;
    deathDone = false;
    _deathT = 0;
    _swordDropPlayed = false;
    state = PlayerState.dead;
  }

  void _springs(double dt) {
    _kbV += (-150.0 * _kb - 14.0 * _kbV) * dt;
    _kb += _kbV * dt;
    _sqV += (-300.0 * _sq - 19.0 * _sqV) * dt;
    _sq += _sqV * dt;
    _tiltV += (-260.0 * _tilt - 17.0 * _tiltV) * dt;
    _tilt += _tiltV * dt;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    sinceParry += dt;
    sinceDodge += dt;
    if (_tempo > 0) _tempo -= dt;
    if (_comboWindow > 0) {
      _comboWindow -= dt;
      if (_comboWindow <= 0 && !isAttacking) comboStep = 0;
    }
    displayHealth += (health - displayHealth) * (dt * 8).clamp(0, 1);
    displayPosture += (posture - displayPosture) * (dt * 8).clamp(0, 1);
    displayStamina += (stamina - displayStamina) * (dt * 10).clamp(0, 1);

    // Stamina regen: son aksiyondan sonra kısa gecikme, sonra /s dolum.
    _staminaIdle += dt;
    if (!unlimitedStamina &&
        stamina < maxStamina &&
        _staminaIdle > game.actionSystem.staminaRegenDelay) {
      stamina = (stamina + game.actionSystem.staminaRegenPerSecond * dt).clamp(
        0,
        maxStamina,
      );
    } else if (unlimitedStamina) {
      stamina = maxStamina;
      displayStamina = maxStamina;
    }

    if (dying) {
      _deathT += dt;
      if (!_swordDropPlayed && _deathT >= _deathDur * 0.55) {
        _swordDropPlayed = true;
        Sfx.swordDrop();
      }
      if (_deathT >= _deathDur) deathDone = true;
      _springs(dt);
      _applyTransform();
      return;
    }

    if (_parryWindow > 0) _parryWindow -= dt;
    if (_parryCooldown > 0) _parryCooldown -= dt;
    if (_dodgeWindow > 0) _dodgeWindow -= dt;
    if (_dodgeCooldown > 0) _dodgeCooldown -= dt;
    if (_attackCooldown > 0) _attackCooldown -= dt;
    _updateMovementTraining(dt);

    final regen = game.actionSystem.playerHealthRegenPerSecond;
    if (regen > 0 && health < 100) {
      _testRegenAcc += regen * dt;
      if (_testRegenAcc >= 1) {
        final inc = _testRegenAcc.floor();
        health = (health + inc).clamp(0, 100);
        _testRegenAcc -= inc;
      }
    }

    if (state == PlayerState.riposte) {
      _riposteT += dt;
      if (_riposteT >= riposteDuration) {
        state = PlayerState.idle;
        _fill = kWhite;
      }
    } else if (isAttacking) {
      _atkT += dt;
      if (!_atkContacted && _atkT >= _atkWindup) {
        _atkContacted = true;
        game.onPlayerAttackContact(_attackType);
      }
      if (_atkT >= _atkTotal) {
        // Light bitince zincir penceresi açılır; heavy finisher zinciri kapatır.
        if (_attackType == PlayerAttackType.light && comboStep < 2) {
          _comboWindow = comboWindowDuration;
        } else {
          _comboWindow = 0;
          comboStep = 0;
        }
        state = PlayerState.idle;
        _fill = kWhite;
      }
    } else if (state == PlayerState.block) {
      // Blok tutuluyorsa süresiz aktif; bırakılınca idle'a düşer.
      if (!_blockHeld) {
        state = PlayerState.idle;
        _fill = kWhite;
      }
    } else if (_stateTimer > 0) {
      _stateTimer -= dt;
      if (state == PlayerState.dodge) _dodgeT += dt;
      if (_stateTimer <= 0) {
        state = PlayerState.idle;
        _fill = kWhite;
      }
    } else if (_parryWindow <= 0 && state == PlayerState.parry) {
      // Parry bitti: blok hâlâ basılıysa bloğa dön, değilse idle.
      state = _blockHeld ? PlayerState.block : PlayerState.idle;
      _parryGuard = GuardDirection.any;
    }

    _springs(dt);
    _applyTransform();
  }

  void _applyTransform() {
    final bob = sin(_t * 1.8) * 0.012;
    final sy = (1 + _sq + bob).clamp(0.45, 1.7);
    final sceneScale = game.combatantScale;
    scale.setValues(sceneScale / sy, sceneScale * sy);
    angle = (_tilt * 0.035).clamp(-0.5, 0.5);
    position =
        _basePos +
        Vector2(
          _moveOffset +
              game.actionSystem.playerRenderKnockback(_kb) +
              _dodgeVisualOffset(),
          0,
        );
  }

  void _updateMovementTraining(double dt) {
    if (!_movementTraining || _moveDir == 0 || isBusy || dying) return;
    final speed = _moveRunning ? 410.0 : 170.0;
    _moveOffset += _moveDir * speed * dt;
    if (!_moveBounds.isEmpty) {
      final minOffset = _moveBounds.left - _basePos.x;
      final maxOffset = _moveBounds.right - _basePos.x;
      _moveOffset = _moveOffset.clamp(minOffset, maxOffset).toDouble();
    }
  }

  double _dodgeVisualOffset() {
    if (state != PlayerState.dodge || !game.actionSystem.isTest) return 0;
    final p = (_dodgeT / _dodgeDur).clamp(0.0, 1.0);
    if (p < 0.42) {
      final k = p / 0.42;
      return -34 * sin(k * pi / 2);
    }
    final k = ((p - 0.42) / 0.58).clamp(0.0, 1.0);
    return -34 * cos(k * pi / 2) + 13 * sin(k * pi);
  }

  // -------------------------------------------------------------- SPRITE PICK
  Sprite _frameFor() {
    switch (state) {
      case PlayerState.idle:
        if (_movementTraining && _moveDir != 0) {
          return _sprites.loop(_moveRunning ? 'run' : 'walk', _t, 0.075);
        }
        return _sprites.loop('idle', _t, 0.16);
      case PlayerState.parry:
        if (_parryGuard == GuardDirection.low) {
          return _sprites.once('attack2', _parryWindow, _parryWindowMax);
        }
        return _sprites.hold('defend', _parryWindow, _parryWindowMax);
      case PlayerState.block:
        return _sprites.frames('protect').last;
      case PlayerState.counter:
        if (game.actionSystem.isTest) {
          if (_counterGuard == GuardDirection.low) {
            return _sprites.frames('attack2').last;
          }
          return _sprites.frames('defend').last;
        }
        return _sprites.once('attack2', _stateTimer, 0.22);
      case PlayerState.riposte:
        return _sprites.once(
          _riposteKey,
          riposteDuration - _riposteT,
          riposteDuration,
        );
      case PlayerState.dodge:
        if (game.actionSystem.isTest) {
          return _sprites.loop('run', _dodgeT, 0.035);
        }
        return _sprites.loop('run', _t, 0.05);
      case PlayerState.attack:
        final key = _attackType == PlayerAttackType.heavy
            ? 'attack1'
            : switch (comboStep) {
                1 => 'attack1',
                2 => 'attack2',
                _ => 'attack3',
              };
        return _sprites.once(key, _atkTotal - _atkT, _atkTotal);
      case PlayerState.hurt:
      case PlayerState.stunned:
        return _sprites.loop('hurt', _t, 0.10);
      case PlayerState.dead:
        return _sprites.deathFrame(_deathT, _deathFrameTime);
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_sprites.isLoaded) {
      _renderBox(canvas);
      return;
    }

    final sprite = _frameFor();
    final s = _cellPx;
    final left = size.x / 2 - s / 2;
    final top = size.y - _feetV * s;

    final hurtFlash =
        state == PlayerState.hurt ||
        state == PlayerState.stunned ||
        state == PlayerState.dead;
    final paint = hurtFlash
        ? (Paint()
            ..filterQuality = FilterQuality.none
            ..colorFilter = ColorFilter.mode(
              kBarRed.withAlpha(120),
              BlendMode.srcATop,
            ))
        : _spritePaint;

    canvas.save();
    if (_facing < 0) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }
    sprite.render(
      canvas,
      position: Vector2(left, top),
      size: Vector2(s, s),
      overridePaint: paint,
    );
    canvas.restore();

    _renderParryRing(canvas);
    _renderDodgeStreak(canvas);
  }

  void _renderParryRing(Canvas canvas) {
    if (!isParrying) return;
    final k = (_parryWindow / _parryWindowMax).clamp(0.0, 1.0);
    final infl = 6 + (1 - k) * 6;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        size.toRect().inflate(infl),
        const Radius.circular(13),
      ),
      Paint()
        ..color = kBlack.withAlpha((255 * (0.35 + 0.65 * k)).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + 2.5 * k,
    );
  }

  void _renderDodgeStreak(Canvas canvas) {
    if (!isDodging) return;
    final k = (_dodgeWindow / dodgeWindowDuration).clamp(0.0, 1.0);
    final a = (110 * k).toInt();
    for (int i = 1; i <= 2; i++) {
      final dx = i * 10.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          size.toRect().translate(dx, 0).inflate(2),
          const Radius.circular(11),
        ),
        Paint()
          ..color = kBlack.withAlpha((a ~/ i))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _renderBox(Canvas canvas) {
    final r = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(9));
    canvas.drawRRect(r, Paint()..color = _fill);
    canvas.drawRRect(
      r,
      Paint()
        ..color = kBlack
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    _renderParryRing(canvas);
  }
}
