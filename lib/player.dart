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
import 'game.dart';
import 'sprite_strip.dart';
import 'theme.dart';

enum PlayerState {
  idle,
  parry,
  counter,
  riposte,
  dodge,
  attack,
  hurt,
  stunned,
  dead,
}

class Player extends PositionComponent with HasGameReference<BossArenaGame> {
  PlayerState state = PlayerState.idle;
  int health = 100;
  double displayHealth = 100;
  int posture = 100;
  double displayPosture = 100;

  // --- PARRY (hassas) ---
  static const double parryWindowDuration = 0.13;
  static const double lowParryWindowDuration = 0.18;
  static const double parryCooldownDuration = 0.34;
  double _parryWindow = 0;
  double _parryWindowMax = parryWindowDuration;
  double _parryCooldown = 0;
  GuardDirection _parryGuard = GuardDirection.any;
  GuardDirection _counterGuard = GuardDirection.any;

  // --- DODGE (geniş pencere; yalnız kırmızı saldırılarda anlamlı) ---
  static const double dodgeWindowDuration = 0.20;
  static const double dodgeCooldownDuration = 0.42;
  double _dodgeWindow = 0;
  double _dodgeCooldown = 0;
  double _dodgeT = 999;
  double _dodgeDur = dodgeWindowDuration;

  // --- TEMPO (comboWindow): başarılı parry sonrası kısa saldırı avantajı ---
  static const double tempoDuration = 0.6;
  double _tempo = 0;
  bool get hasTempo => _tempo > 0;

  // --- SALDIRI (tek tip) ---
  static const double atkWindup = 0.07;
  static const double atkActive = 0.10;
  static const double atkRecover = 0.18;
  static const double heavyAtkWindup = 0.24;
  static const double heavyAtkActive = 0.12;
  static const double heavyAtkRecover = 0.42;
  static const double attackCooldownDuration = 0.18;
  double _attackCooldown = 0;
  double _atkT = 0;
  bool _atkContacted = false;
  PlayerAttackType _attackType = PlayerAttackType.light;
  static const double riposteDuration = 0.22;
  double _riposteT = 0;
  String _riposteKey = 'attack1';

  double _stateTimer = 0;
  double _t = 0;

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
  bool get isDodging => _dodgeWindow > 0;
  bool get isAttacking => state == PlayerState.attack;
  bool get isBusy =>
      isAttacking ||
      state == PlayerState.riposte ||
      state == PlayerState.stunned ||
      state == PlayerState.hurt;

  double get _atkWindup =>
      _attackType == PlayerAttackType.heavy ? heavyAtkWindup : atkWindup;
  double get _atkActive =>
      _attackType == PlayerAttackType.heavy ? heavyAtkActive : atkActive;
  double get _atkRecover =>
      _attackType == PlayerAttackType.heavy ? heavyAtkRecover : atkRecover;
  double get _atkTotal => _atkWindup + _atkActive + _atkRecover;

  @override
  Future<void> onLoad() async {
    await _sprites.load(game.images.load);
  }

  void place(Vector2 p) {
    position = p;
    _basePos = p.clone();
  }

  void reset() {
    health = 100;
    displayHealth = 100;
    posture = 100;
    displayPosture = 100;
    _tempo = 0;
    state = PlayerState.idle;
    _fill = kWhite;
    _parryWindow = 0;
    _parryWindowMax = parryWindowDuration;
    _parryCooldown = 0;
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
    if (_basePos != Vector2.zero()) position = _basePos.clone();
  }

  // -------------------------------------------------------------- GİRDİLER
  void tryParry([GuardDirection guard = GuardDirection.any]) {
    if (game.phase != GamePhase.playing || dying) return;
    if (isBusy || state == PlayerState.dodge) return;
    if (_parryCooldown > 0) return;
    _parryWindowMax = guard == GuardDirection.low
        ? lowParryWindowDuration
        : parryWindowDuration;
    _parryWindow = _parryWindowMax;
    _parryCooldown = parryCooldownDuration;
    _parryGuard = guard;
    sinceParry = 0;
    state = PlayerState.parry;
  }

  void tryDodge() {
    if (game.phase != GamePhase.playing || dying) return;
    if (isBusy) return;
    if (_dodgeCooldown > 0) return;
    _dodgeWindow = dodgeWindowDuration;
    _dodgeCooldown = dodgeCooldownDuration;
    _dodgeT = 0;
    _dodgeDur = dodgeWindowDuration + 0.04;
    sinceDodge = 0;
    state = PlayerState.dodge;
    _stateTimer = _dodgeDur;
    _kbV += game.actionSystem.playerDodgeKnockbackImpulse;
    _sq = 0.12;
    _sqV = 0;
    _tiltV -= 5;
  }

  // F: tek saldırı. Animasyon her zaman oynar; temas active karesinde çözülür.
  void tryAttack([PlayerAttackType type = PlayerAttackType.light]) {
    if (game.phase != GamePhase.playing || dying) return;
    if (isBusy || _attackCooldown > 0) return;
    if (state == PlayerState.dodge && _dodgeWindow > 0) return;
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
    displayHealth += (health - displayHealth) * (dt * 8).clamp(0, 1);
    displayPosture += (posture - displayPosture) * (dt * 8).clamp(0, 1);

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
      state = PlayerState.idle;
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
          game.actionSystem.playerRenderKnockback(_kb) + _dodgeVisualOffset(),
          0,
        );
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
        return _sprites.loop('idle', _t, 0.16);
      case PlayerState.parry:
        if (_parryGuard == GuardDirection.low) {
          return _sprites.once('attack2', _parryWindow, _parryWindowMax);
        }
        return _sprites.hold('defend', _parryWindow, _parryWindowMax);
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
            : 'attack3';
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

    sprite.render(
      canvas,
      position: Vector2(left, top),
      size: Vector2(s, s),
      overridePaint: paint,
    );

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
