// ============================================================================
//  BOSS  —  data-driven dövüşçü (posture + pressure loop + adaptif AI)
// ----------------------------------------------------------------------------
//  REDESIGN (COMBAT_REDESIGN_PHASES):
//   * Parry artık HP değil POSTURE (denge) hasarı verir. Denge kırılınca boss
//     `staggered` olur; gerçek HP hasarı OYUNCUNUN saldırısından gelir.
//   * Dodge yalnız `punishOnDodge` (ağır/committed) beat'lerde açılış yaratır;
//     hafif saldırıyı dodge etmek boss'u durdurmaz, kombo akar.
//   * Her beat bir DefenseProfile taşır: yanlış araç (guardBreak'e parry,
//     tracking'e dodge) ve aldatma/erken basış cezalandırılır.
//   * Boss her kombo sonunda eski yerine DÖNMEZ: chain / reposition / retreat
//     kararıyla baskıyı sürdürür. Kombo havuzundan oyuncu alışkanlığına göre
//     ağırlıklı seçim yapar. Düşük HP'de tempo artar.
// ============================================================================

import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'audio.dart';
import 'characters.dart';
import 'fx.dart';
import 'game.dart';
import 'projectile.dart';
import 'sprite_strip.dart';
import 'theme.dart';

const Color _kAmber = Color(0xFFE0A82E);

enum BossState {
  idle,
  approach,
  windup,
  active,
  recover,
  gap,
  guard,
  offBalance, // committed saldırı dodge'lanınca açılan punish penceresi
  staggered, // posture kırıldı: oyuncu gerçek HP hasarı verir
  reposition, // pressure loop: oyuncunun etrafında yer değiştir
  retreat,
}

class Boss extends PositionComponent with HasGameReference<BossArenaGame> {
  final CharacterDef def;

  Boss(this.def) : super(size: Vector2(96, 112), anchor: Anchor.bottomCenter);

  BossState state = BossState.idle;
  int health = 100;
  double displayHealth = 100;

  // --- POSTURE (denge) ---
  late final int maxPosture = def.maxPosture;
  late double posture = maxPosture.toDouble();
  late double displayPosture = maxPosture.toDouble();
  double _postureIdle = 0; // son denge hasarından bu yana (regen gecikmesi)
  static const double postureRegen = 8; // /s
  static const double postureBreakDur = 1.15;

  double _timer = 0;
  bool _justEntered = true;

  int storedCombo = 0;

  Vector2 _basePos = Vector2.zero();
  double _moveTarget = 0;
  double _t = 0;
  double _hurtT = 0;

  // Aktif kombo durumu.
  ComboPattern? _activeCombo;
  int _beatIndex = -1;
  int _parriedThisCombo = 0;
  int _nonFeintTotal = 0;
  bool _comboChainBroken = false; // dodge/hit → tam-parry bonusu iptal
  bool _guardCounter = false;
  GuardDirection? _followUpGuard;
  double _followUpTimer = 0;

  // Bekleyen vuruş (temas sonrası tolerans).
  bool _pending = false;
  double _pendingGrace = 0;
  Beat? _pendingBeat;
  Projectile? _pendingProjectile;

  static const double _freshPress = 0.045;

  // --- LOKOMOSYON ---
  static const double walkSpeed = 150;
  static const double runSpeed = 440;
  static const double standGap = 82;
  static const double idleTime = 0.9;
  static const double punishWindow = 0.62;
  static const double testGuardDuration = 0.72;
  static const double testGuardGap = 0.34;

  // --- OYUNCU SALDIRI HASARI (tek saldırı) ---
  static const int attackHpStagger = 18; // denge kırıkken (asıl pencere)
  static const int attackHpOpen = 14; // kırmızıyı dodge sonrası açıkken
  static const int attackPostureChip = 8; // boss açık değilken (riskli poke)

  // --- ADAPTASYON: oyuncu alışkanlık EMA'ları (0..1) ---
  double _parryHabit = 0, _dodgeHabit = 0, _attackHabit = 0;

  final Random _rng = Random();

  // --- SPRITE ---
  late final SpriteStripBank _sprites = SpriteStripBank(def);
  Sprite? _portrait;

  Sprite? get portraitSprite => _portrait;
  int get currentBeatIndex => _beatIndex;
  List<Beat> get activeBeats => (_activeCombo ?? def.pattern).beats;
  Beat? get currentBeat => (_beatIndex >= 0 && _beatIndex < activeBeats.length)
      ? activeBeats[_beatIndex]
      : null;

  // Boss HP fazı: 0 (yüksek), 1 (<=%50), 2 (<=%25). Tempo/agresiflik ölçer.
  int get phase => health <= 25 ? 2 : (health <= 50 ? 1 : 0);
  double get _tempoScale => phase >= 2 ? 0.72 : (phase == 1 ? 0.86 : 1.0);
  double _scaled(double t) => t * _tempoScale;

  // Ölüm sekansı.
  bool dying = false;
  bool deathDone = false;
  double _deathT = 0;
  bool _swordDropPlayed = false;
  static const double _deathFrameTime = 0.13;
  int get _deadFrames => def.sheets['dead']?.frames ?? 1;
  double get _deathDur => _deathFrameTime * (_deadFrames - 1) + 0.4;

  @override
  Future<void> onLoad() async {
    await _sprites.load(game.images.load);
    _portrait = _sprites.firstOrNull('idle');
  }

  void place(Vector2 p) {
    position = p;
    _basePos = p.clone();
  }

  void reset() {
    health = 100;
    displayHealth = 100;
    posture = maxPosture.toDouble();
    displayPosture = maxPosture.toDouble();
    _postureIdle = 0;
    storedCombo = 0;
    _parriedThisCombo = 0;
    _nonFeintTotal = 0;
    _comboChainBroken = false;
    _guardCounter = false;
    _followUpGuard = null;
    _followUpTimer = 0;
    _activeCombo = null;
    _beatIndex = -1;
    _pending = false;
    _pendingGrace = 0;
    _pendingBeat = null;
    _pendingProjectile = null;
    _hurtT = 0;
    _parryHabit = _dodgeHabit = _attackHabit = 0;
    dying = false;
    deathDone = false;
    _deathT = 0;
    _swordDropPlayed = false;
    if (_basePos != Vector2.zero()) position = _basePos.clone();
    _enter(BossState.idle, idleTime);
  }

  // TEST: ölümsüzlük için can ~0'a inerse tabanda tut, ölme.
  double _testRegenAcc = 0;

  void die() {
    if (!game.actionSystem.bossCanDie) return;
    if (dying) return;
    dying = true;
    deathDone = false;
    _deathT = 0;
    _swordDropPlayed = false;
    _pending = false;
    _pendingBeat = null;
    _pendingProjectile = null;
    state = BossState.idle;
    Sfx.hit();
  }

  @override
  void onMount() {
    super.onMount();
    if (_basePos == Vector2.zero()) _basePos = position.clone();
    _enter(BossState.idle, idleTime);
  }

  void _enter(BossState s, double t) {
    state = s;
    _timer = t;
    _justEntered = true;
  }

  void enterTestGuard() {
    _clearPending();
    _activeCombo = null;
    _beatIndex = -1;
    _guardCounter = false;
    posture = maxPosture.toDouble();
    position.x = _basePos.x;
    _enter(BossState.guard, testGuardDuration);
  }

  void takeDamage(int dmg) =>
      health = (health - dmg).clamp(game.actionSystem.minBossHealth, 100);

  // --- POSTURE API ---
  void applyPostureDamage(int dmg) {
    if (dmg <= 0 || dying) return;
    posture = (posture - dmg).clamp(0, maxPosture).toDouble();
    _postureIdle = 0;
    if (posture <= 0 && state != BossState.staggered) breakPosture();
  }

  void breakPosture() {
    if (dying) return;
    posture = 0;
    _clearPending();
    game.metrics.bossPostureBreaks++;
    game.add(ComboText(_topCenter, 'DENGE KIRILDI'));
    game.spawnPostureBreak(_topCenter);
    Sfx.hit();
    game.requestHitstop(0.13);
    _enter(BossState.staggered, postureBreakDur);
  }

  Vector2 get _topCenter => Vector2(position.x, position.y - 116);

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_hurtT > 0) _hurtT -= dt;
    displayHealth += (health - displayHealth) * (dt * 8).clamp(0, 1);
    displayPosture += (posture - displayPosture) * (dt * 9).clamp(0, 1);

    // Alışkanlık EMA'ları yavaşça söner.
    _parryHabit = (_parryHabit - _parryHabit * dt * 0.22).clamp(0, 1);
    _dodgeHabit = (_dodgeHabit - _dodgeHabit * dt * 0.22).clamp(0, 1);
    _attackHabit = (_attackHabit - _attackHabit * dt * 0.22).clamp(0, 1);
    if (_followUpTimer > 0) {
      _followUpTimer -= dt;
      if (_followUpTimer <= 0) _followUpGuard = null;
    }

    if (dying) {
      _deathT += dt;
      if (!_swordDropPlayed && _deathT >= _deathDur * 0.55) {
        _swordDropPlayed = true;
        Sfx.swordDrop();
      }
      if (_deathT >= _deathDur) deathDone = true;
      return;
    }

    if (game.phase == GamePhase.playing) {
      // TEST: ölmesin diye can yavaşça dolar (hasar görünür, sonra toparlar).
      final regen = game.actionSystem.bossHealthRegenPerSecond;
      if (regen > 0 && health < 100) {
        _testRegenAcc += regen * dt;
        if (_testRegenAcc >= 1) {
          final inc = _testRegenAcc.floor();
          health = (health + inc).clamp(0, 100);
          _testRegenAcc -= inc;
        }
      }
      // Posture rejenerasyonu: stagger DIŞINDA, kısa gecikmeden sonra.
      _postureIdle += dt;
      if (state != BossState.staggered &&
          _postureIdle > 1.1 &&
          posture < maxPosture) {
        posture = (posture + postureRegen * dt).clamp(0, maxPosture).toDouble();
      }
      _timer -= dt;
      _machine(dt);
      _tickPending(dt);
    } else {
      if (state != BossState.idle) state = BossState.idle;
    }

    if (game.actionSystem.lockBossToBaseX) position.x = _basePos.x;
    position.y = _basePos.y;
  }

  void _registerHabit({
    bool parry = false,
    bool dodge = false,
    bool attack = false,
  }) {
    if (parry) _parryHabit = (_parryHabit + 0.34).clamp(0, 1);
    if (dodge) _dodgeHabit = (_dodgeHabit + 0.34).clamp(0, 1);
    if (attack) _attackHabit = (_attackHabit + 0.30).clamp(0, 1);
  }

  // ------------------------------------------------------------------ MACHINE
  void _machine(double dt) {
    switch (state) {
      case BossState.idle:
        if (_timer <= 0) {
          if (game.testAttackMode == TestAttackMode.defend) {
            enterTestGuard();
          } else {
            _beginNewCombo();
          }
        }
        break;

      case BossState.approach:
        if (def.ranged || game.actionSystem.bossStartsBeatInPlace) {
          // TEST: yaklaşma yürüyüşü yok; bitişik konumda kal, saldırıya başla.
          if (game.actionSystem.lockBossToBaseX) position.x = _basePos.x;
          _startBeat(0);
        } else {
          final target = game.player.position.x + standGap;
          position.x = max(target, position.x - walkSpeed * dt);
          if (position.x <= target + 0.5) {
            position.x = target;
            _startBeat(0);
          }
        }
        break;

      case BossState.windup:
        if (_timer <= 0) _enter(BossState.active, _beat.active);
        break;

      case BossState.active:
        if (_justEntered) {
          _justEntered = false;
          _onContact();
          if (state != BossState.active) break;
        }
        if (_timer <= 0) _enter(BossState.recover, _beat.recover);
        break;

      case BossState.recover:
        if (_timer <= 0) {
          if (_beatIndex >= activeBeats.length - 1) {
            _endCombo();
          } else {
            _enter(BossState.gap, _scaled(_beat.gapAfter));
          }
        }
        break;

      case BossState.gap:
        if (_timer <= 0) _startBeat(_beatIndex + 1);
        break;

      case BossState.guard:
        position.x = _basePos.x;
        if (_timer <= 0) {
          _enter(BossState.idle, testGuardGap);
        }
        break;

      case BossState.offBalance:
        if (_timer <= 0) {
          if (_beatIndex >= activeBeats.length - 1) {
            _endCombo();
          } else {
            _enter(BossState.gap, _scaled(_beat.gapAfter));
          }
        }
        break;

      case BossState.staggered:
        if (_timer <= 0) {
          posture = maxPosture.toDouble();
          _beatIndex = -1;
          _activeCombo = null;
          _decidePressure();
        }
        break;

      case BossState.reposition:
        {
          final d = _moveTarget - position.x;
          final step = walkSpeed * dt * (d.sign);
          if (d.abs() <= step.abs() + 0.5) {
            position.x = _moveTarget;
            _enter(BossState.idle, _scaled(0.5));
          } else {
            position.x += step;
          }
        }
        break;

      case BossState.retreat:
        final target = _basePos.x;
        position.x = min(target, position.x + runSpeed * dt);
        if (position.x >= target - 0.5) {
          position.x = target;
          _beatIndex = -1;
          _enter(BossState.idle, idleTime);
        }
        break;
    }
  }

  Beat get _beat => activeBeats[_beatIndex];

  // Yeni kombo turu: havuzdan ağırlıklı seçim, sonra approach (ranged → yerinde).
  void _beginNewCombo() {
    _activeCombo = _pickCombo();
    _comboChainBroken = false;
    _parriedThisCombo = 0;
    storedCombo = 0;
    _nonFeintTotal = _activeCombo!.nonFeintCount;
    _enter(BossState.approach, 0);
  }

  // Kombo havuzundan seçim. Oyuncu dodge'a abanıyorsa tracking içeren deseni,
  // parry'e abanıyorsa feint/guardBreak/delayed içeren deseni öne çıkar.
  ComboPattern _pickCombo() {
    final avail = def.combos.where((c) => c.minPhase <= phase).toList();
    if (avail.isEmpty) return def.combos.first;
    if (avail.length == 1) return avail.first;

    double weightOf(ComboPattern c) {
      double w = c.weight;
      final hasTracking = c.beats.any(
        (b) => b.defense == DefenseProfile.tracking,
      );
      final hasAntiParry = c.beats.any(
        (b) =>
            b.defense == DefenseProfile.feint ||
            b.defense == DefenseProfile.guardBreak ||
            b.defense == DefenseProfile.delayed,
      );
      if (hasTracking) w *= 1 + _dodgeHabit * 1.6;
      if (hasAntiParry) w *= 1 + _parryHabit * 1.6;
      return w;
    }

    final weights = avail.map(weightOf).toList();
    final total = weights.fold<double>(0, (s, w) => s + w);
    double r = _rng.nextDouble() * total;
    for (int i = 0; i < avail.length; i++) {
      r -= weights[i];
      if (r <= 0) return avail[i];
    }
    return avail.last;
  }

  void _startBeat(int i) {
    _beatIndex = i;
    _enter(BossState.windup, _beat.windup);
  }

  // Kombo bitti. Tüm (feint olmayan) beat'ler parry edildiyse büyük posture
  // hasarı (otomatik HP YOK). Sonra pressure kararı.
  void _endCombo() {
    if (_guardCounter) {
      _guardCounter = false;
      if (game.testAttackMode == TestAttackMode.defend ||
          game.testAttackMode == TestAttackMode.combo) {
        _clearPending();
        _activeCombo = null;
        _beatIndex = -1;
        _enter(BossState.idle, testGuardGap);
        return;
      }
    }
    if (!_comboChainBroken &&
        _nonFeintTotal > 0 &&
        _parriedThisCombo >= _nonFeintTotal) {
      final bonus = (_activeCombo ?? def.pattern).staggerBonus;
      game.add(ComboText(_topCenter, '×$_parriedThisCombo  TAM PARRY'));
      game.spawnPopup(
        _topCenter + Vector2(0, 34),
        '-$bonus DENGE',
        fontSize: 18,
        color: kBarBlue,
      );
      applyPostureDamage(bonus);
      if (state == BossState.staggered) return; // kırıldı → stagger sürüyor
      _hurtT = 0.3;
    }
    _decidePressure();
  }

  // ----------------------------------------------------------- PRESSURE LOOP
  // Kombo/punish çözülünce: eski yere dönmek yerine baskıyı sürdür.
  void _decidePressure() {
    _clearPending();
    _beatIndex = -1;
    _activeCombo = null;
    if (game.testAttackMode == TestAttackMode.defend ||
        game.testAttackMode == TestAttackMode.combo) {
      position.x = _basePos.x;
      _enter(BossState.guard, testGuardDuration);
      return;
    }
    // TEST: yer değiştirme/geri çekilme yok. Yerinde kısa düşün → yeni kombo.
    if (game.actionSystem.bossKeepsPressureInPlace) {
      position.x = _basePos.x;
      _enter(BossState.idle, _scaled(0.45));
      return;
    }
    final ph = phase;
    final chainChance = ph >= 2 ? 0.80 : (ph == 1 ? 0.60 : 0.42);
    final r = _rng.nextDouble();
    if (r < chainChance) {
      _enter(
        BossState.idle,
        _scaled(0.45),
      ); // kısa düşün → yeni kombo (yerinde)
    } else if (r < chainChance + 0.32) {
      final side = standGap * (0.8 + _rng.nextDouble() * 0.9);
      _moveTarget = _clampX(game.player.position.x + side);
      _enter(BossState.reposition, 0);
    } else {
      _enter(BossState.retreat, 0); // tam reset (nadir)
    }
  }

  double _clampX(double x) {
    final r = game.arenaRect;
    if (r.isEmpty) return x;
    return x.clamp(r.left + 70, r.right - 50).toDouble();
  }

  // ----------------------------------------------------------------- CONTACT
  void _onContact() {
    final beat = _beat;
    if (_guardCounter) {
      _applyHit(beat, null);
      return;
    }
    if (beat.isRanged) {
      _spawnProjectile(beat);
    } else {
      _resolveContact(beat, null);
    }
  }

  void _spawnProjectile(Beat beat) {
    final from = _topCenter;
    final to = Vector2(
      game.player.position.x,
      game.player.position.y - game.player.size.y * 0.5,
    );
    final frames = beat.projectileKey == null
        ? const <Sprite>[]
        : _sprites.frames(beat.projectileKey!);
    final proj = Projectile(
      from,
      to,
      beat.projectileSpeed,
      frame: () {
        if (frames.isEmpty) return _sprites.frames('idle').first;
        return frames[(_t / 0.06).floor() % frames.length];
      },
      onArrive: (self) => _resolveContact(beat, self),
    );
    game.add(proj);
  }

  // Temas çözümü — SADE MODEL: tek istisna KIRMIZI (guardBreak) = dodge.
  //   guardBreak → dodge doğru; parry cezalandırılır.
  //   diğer her şey → parry VEYA dodge işe yarar (parry denge kırar; en iyisi).
  void _resolveContact(Beat beat, Projectile? proj) {
    if (dying) return;
    final p = game.player;
    final pressedParry = p.sinceParry <= beat.preWindow;
    final didParry = pressedParry && _guardMatches(beat);
    final didDodge = p.sinceDodge <= beat.dodgePre;

    if (beat.defense == DefenseProfile.guardBreak) {
      if (didDodge) {
        _dodgeSuccess(beat, proj);
      } else if (pressedParry) {
        _wrongTool(beat, proj, 'PARRY OLMAZ!');
      } else {
        _beginPending(beat, proj);
      }
    } else if (beat.defense == DefenseProfile.tracking) {
      if (didParry) {
        _parrySuccess(beat, proj);
      } else if (pressedParry) {
        _wrongTool(beat, proj, 'YANLIŞ YÖN!');
      } else if (didDodge) {
        _wrongTool(beat, proj, 'KAÇILMAZ!');
      } else {
        _beginPending(beat, proj);
      }
    } else {
      if (didParry) {
        _parrySuccess(beat, proj);
      } else if (pressedParry && beat.guardDirection != GuardDirection.any) {
        _wrongTool(beat, proj, 'YANLIŞ YÖN!');
      } else if (didDodge) {
        _dodgeSuccess(beat, proj);
      } else {
        _beginPending(beat, proj);
      }
    }
  }

  void _beginPending(Beat beat, Projectile? proj) {
    _pending = true;
    _pendingGrace = beat.grace;
    _pendingBeat = beat;
    _pendingProjectile = proj;
  }

  void _tickPending(double dt) {
    if (!_pending) return;
    final beat = _pendingBeat!;
    final p = game.player;
    // Temas sonrası TAZE basış: profile uygunsa say.
    final freshParry = p.sinceParry <= _freshPress;
    final freshDodge = p.sinceDodge <= _freshPress;
    if (freshParry && beat.defense != DefenseProfile.guardBreak) {
      final proj = _pendingProjectile;
      _clearPending();
      if (!_guardMatches(beat)) {
        _wrongTool(beat, proj, 'YANLIŞ YÖN!');
        return;
      }
      _parrySuccess(beat, proj);
      return;
    }
    if (freshDodge) {
      final proj = _pendingProjectile;
      _clearPending();
      if (beat.defense == DefenseProfile.tracking) {
        _wrongTool(beat, proj, 'KAÇILMAZ!');
        return;
      }
      _dodgeSuccess(beat, proj);
      return;
    }
    _pendingGrace -= dt;
    if (_pendingGrace <= 0) {
      final proj = _pendingProjectile;
      _clearPending();
      _applyHit(beat, proj);
    }
  }

  bool _guardMatches(Beat beat) {
    return switch (beat.guardDirection) {
      GuardDirection.any => game.player.parryGuard == GuardDirection.any,
      GuardDirection.high => game.player.parryGuard == GuardDirection.high,
      GuardDirection.low => game.player.parryGuard == GuardDirection.low,
    };
  }

  void _clearPending() {
    _pending = false;
    _pendingGrace = 0;
    _pendingBeat = null;
    _pendingProjectile = null;
  }

  bool tryParryFollowUp(GuardDirection input) {
    if (!game.actionSystem.isTest || dying) return false;
    if (_followUpTimer <= 0 || _followUpGuard == null) return false;
    if (_followUpGuard != input) return false;
    _followUpGuard = null;
    _followUpTimer = 0;
    const hp = 10;
    takeDamage(hp);
    game.player.playParryFollowUp(input);
    game.metrics.bossDamageTaken += hp;
    Sfx.hit();
    game.requestHitstop(0.07);
    _hurtT = 0.18;
    game.spawnPopup(_topCenter + Vector2(0, 30), '-$hp', fontSize: 19);
    return true;
  }

  // PARRY BAŞARILI — HP DEĞİL POSTURE hasarı + tempo penceresi.
  void _parrySuccess(Beat beat, Projectile? proj) {
    Sfx.parry();
    game.player.onParrySuccess();
    game.metrics.parrySuccesses++;
    _registerHabit(parry: true);
    _hurtT = 0.30;
    proj?.deflect();
    game.requestHitstop(0.05);
    game.spawnSpark(_topCenter, kBarBlue);

    if (beat.kind == BeatKind.feint) {
      game.spawnPopup(_topCenter, 'ALDATMA', fontSize: 14, color: kGray500);
      return;
    }

    _parriedThisCombo++;
    storedCombo = _parriedThisCombo;
    _armParryFollowUp(beat);
    applyPostureDamage(beat.postureDamage);
    game.spawnPopup(
      _topCenter,
      '-${beat.postureDamage} DENGE',
      fontSize: 15,
      color: kBarBlue,
    );
  }

  void _armParryFollowUp(Beat beat) {
    if (!game.actionSystem.isTest) return;
    _followUpGuard = switch (beat.guardDirection) {
      GuardDirection.low => GuardDirection.high,
      GuardDirection.high => GuardDirection.low,
      GuardDirection.any => GuardDirection.any,
    };
    _followUpTimer = 0.46;
    final label = switch (_followUpGuard!) {
      GuardDirection.low => '↓ KARŞI',
      GuardDirection.high => '↑ KARŞI',
      GuardDirection.any => 'SPACE KARŞI',
    };
    game.spawnPopup(_topCenter + Vector2(0, -24), label, fontSize: 13);
  }

  void _applyHit(Beat beat, Projectile? proj) {
    if (beat.kind == BeatKind.feint || beat.damage <= 0) {
      proj?.deflect();
      return;
    }
    // NEDEN yedin? Yakın zamanda bastıysan zamanlama; basmadıysan savunmadın.
    final p = game.player;
    final pressed = p.sinceParry < 0.45 || p.sinceDodge < 0.45;
    final reason = pressed ? 'ZAMANLAMA!' : 'SAVUNMADIN!';
    game.player.takeHit(beat.damage, -1);
    game.spawnPopup(
      Vector2(game.player.position.x, game.player.position.y - size.y * 1.05),
      reason,
      fontSize: 14,
      color: kBarRed,
      rise: 30,
    );
    game.spawnPopup(
      Vector2(game.player.position.x, game.player.position.y - size.y * 0.8),
      '-${beat.damage}',
      fontSize: beat.damage >= 20 ? 23 : 17,
    );
    _comboChainBroken = true; // vuruş yedin: tam-parry bonusu iptal
  }

  // DODGE BAŞARILI — hasarsız sıyrılma. Yalnız punishOnDodge beat'lerde açılış.
  void _dodgeSuccess(Beat beat, Projectile? proj) {
    Sfx.dodge();
    game.player.onDodgeSuccess();
    game.metrics.dodgeSuccesses++;
    _registerHabit(dodge: true);
    proj?.deflect();
    _comboChainBroken = true; // parry zinciri kırıldı (bonus yok)

    if (beat.kind == BeatKind.feint) {
      game.spawnPopup(_topCenter, 'ALDATMA', fontSize: 14, color: kGray500);
      return;
    }

    if (beat.punishOnDodge) {
      game.spawnPopup(
        _topCenter,
        'AÇIK!',
        fontSize: 15,
        color: kGray700,
        rise: 28,
      );
      _enter(BossState.offBalance, punishWindow);
    } else {
      // Hafif saldırıyı sıyırdın: konum avantajı ama boss komboya DEVAM eder.
      game.spawnPopup(
        _topCenter,
        'SIYRILDIN',
        fontSize: 13,
        color: kGray500,
        rise: 24,
      );
    }
  }

  // YANLIŞ ARAÇ: guardBreak'e parry / tracking'e dodge → ceza, boss devam eder.
  void _wrongTool(Beat beat, Projectile? proj, String label) {
    proj?.deflect();
    final chip = (beat.damage * 0.35).round();
    game.player.getStunned(0.4, chip: chip);
    game.spawnPopup(
      Vector2(game.player.position.x, game.player.position.y - size.y * 0.8),
      label,
      fontSize: 14,
      color: kBarRed,
      rise: 30,
    );
    if (chip > 0) {
      game.spawnPopup(
        Vector2(game.player.position.x, game.player.position.y - size.y * 0.5),
        '-$chip',
        fontSize: 16,
      );
    }
    _comboChainBroken = true;
  }

  bool get isOpen =>
      !dying && (state == BossState.offBalance || state == BossState.staggered);

  // OYUNCU SALDIRISI temas etti (game.onPlayerAttackContact menzili doğrular).
  // staggered → büyük HP; offBalance → HP; açık değilse → posture chip (riskli).
  void receivePlayerAttack(PlayerAttackType type) {
    if (dying) return;
    _registerHabit(attack: true);

    if (state == BossState.guard) {
      if (type == PlayerAttackType.heavy) {
        _shieldHeavyPunish();
      } else {
        _shieldLightBlock();
      }
    } else if (state == BossState.idle && game.actionSystem.isTest) {
      final hp = type == PlayerAttackType.light ? 10 : 0;
      if (hp <= 0) {
        Sfx.whiff();
        game.spawnPopup(_topCenter, 'ETKİ YOK', fontSize: 13, color: kGray500);
        return;
      }
      takeDamage(hp);
      game.metrics.bossDamageTaken += hp;
      Sfx.hit();
      game.requestHitstop(0.06);
      _hurtT = 0.16;
      game.spawnPopup(_topCenter + Vector2(0, 30), '-$hp', fontSize: 18);
    } else if (game.testAttackMode == TestAttackMode.defend) {
      Sfx.whiff();
      game.spawnPopup(_topCenter, 'ETKİ YOK', fontSize: 13, color: kGray500);
    } else if (state == BossState.staggered) {
      final hp = game.actionSystem.isTest
          ? (type == PlayerAttackType.heavy ? 40 : 10)
          : attackHpStagger + (game.player.hasTempo ? 4 : 0);
      takeDamage(hp);
      game.metrics.bossDamageTaken += hp;
      Sfx.hit();
      game.requestHitstop(type == PlayerAttackType.heavy ? 0.14 : 0.10);
      _hurtT = 0.2;
      game.spawnPopup(
        _topCenter + Vector2(0, 30),
        '-$hp',
        fontSize: type == PlayerAttackType.heavy ? 26 : 22,
      );
    } else if (state == BossState.offBalance) {
      final hp = attackHpOpen + (game.player.hasTempo ? 4 : 0);
      takeDamage(hp);
      game.metrics.bossDamageTaken += hp;
      Sfx.hit();
      game.requestHitstop(0.08);
      game.add(ComboText(_topCenter, 'CEZA'));
      game.spawnPopup(_topCenter + Vector2(0, 30), '-$hp', fontSize: 20);
      _decidePressure();
    } else {
      // Boss açık değil: yalnız posture chip. Riskli (boss saldırısı sürebilir).
      applyPostureDamage(attackPostureChip);
      Sfx.parry();
      game.spawnSpark(_topCenter, _kAmber);
      game.spawnPopup(
        _topCenter,
        '-$attackPostureChip DENGE',
        fontSize: 13,
        color: kBarBlue,
      );
    }
  }

  void _shieldLightBlock() {
    game.player.takePostureDamage(22);
    Sfx.block();
    game.requestHitstop(0.06);
    game.spawnSpark(_topCenter, _kAmber);
    game.spawnPopup(_topCenter, 'KALKAN', fontSize: 15, color: _kAmber);
    game.spawnPopup(
      Vector2(game.player.position.x, game.player.position.y - size.y * 0.72),
      'DENGE -22',
      fontSize: 13,
      color: kBarRed,
      rise: 24,
    );
  }

  void _shieldHeavyPunish() {
    _clearPending();
    _comboChainBroken = true;
    game.player.breakPosture();
    Sfx.block();
    game.requestHitstop(0.09);
    game.spawnSpark(_topCenter, _kAmber);
    game.spawnPopup(_topCenter, 'AĞIR HATA!', fontSize: 16, color: _kAmber);
    game.spawnPopup(
      Vector2(game.player.position.x, game.player.position.y - size.y * 0.72),
      'DENGE SIFIR',
      fontSize: 14,
      color: kBarRed,
      rise: 28,
    );

    final source = def.pattern.beats[2];
    final counter = Beat(
      kind: source.kind,
      defense: DefenseProfile.normal,
      animKey: source.animKey,
      windup: .18,
      active: source.active,
      recover: source.recover,
      gapAfter: .18,
      preWindow: 0,
      grace: 0,
      dodgePre: 0,
      damage: source.damage,
      postureDamage: 0,
      punishOnDodge: false,
      mustDefend: true,
      projectileKey: source.projectileKey,
      projectileSpeed: source.projectileSpeed,
    );
    _activeCombo = ComboPattern([counter], staggerBonus: 0);
    _nonFeintTotal = 1;
    _parriedThisCombo = 0;
    storedCombo = 0;
    _guardCounter = true;
    _beatIndex = 0;
    _enter(BossState.windup, counter.windup);
  }

  // -------------------------------------------------------------- SPRITE PICK
  Sprite _frameFor() {
    if (dying) return _sprites.deathFrame(_deathT, _deathFrameTime);
    switch (state) {
      case BossState.idle:
      case BossState.gap:
        return _sprites.loop('idle', _t, 0.10);
      case BossState.guard:
        return _sprites.frames('defend').last;
      case BossState.approach:
        if (game.actionSystem.bossUsesIdleApproachSprite) {
          return _sprites.loop('idle', _t, 0.10);
        }
        return _sprites.loop('walk', _t, 0.09);
      case BossState.reposition:
        return _sprites.loop('walk', _t, 0.09);
      case BossState.retreat:
        return _sprites.loop('run', _t, 0.07);
      case BossState.offBalance:
      case BossState.staggered:
        return _sprites.loop('hurt', _t, 0.12);
      case BossState.windup:
        return _sprites.attackFrame(
          _beat.animKey,
          _timer,
          _beat.windup,
          phase: AttackPhase.windup,
        );
      case BossState.active:
        if (_hurtT > 0) return _sprites.loop('hurt', _t, 0.08);
        return _sprites.attackFrame(
          _beat.animKey,
          _timer,
          _beat.active,
          phase: AttackPhase.active,
        );
      case BossState.recover:
        if (_hurtT > 0) return _sprites.loop('hurt', _t, 0.08);
        return _sprites.attackFrame(
          _beat.animKey,
          _timer,
          _beat.recover,
          phase: AttackPhase.recover,
        );
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_sprites.isLoaded) return;

    final sprite = _frameFor();
    final s = def.cellPx;
    final left = size.x / 2 - s / 2;
    final top = size.y - def.feetV * s;

    final mirror = game.player.position.x < position.x;
    canvas.save();
    if (mirror) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }
    sprite.render(canvas, position: Vector2(left, top), size: Vector2(s, s));
    canvas.restore();

    _renderTelegraph(canvas);
    _renderOpenMarker(canvas);
  }

  // TELEGRAF — SADE MODEL: yalnız KIRMIZI (kaçılması gereken) saldırıyı işaretler.
  // Renksiz = parry (varsayılan). Kırmızı görürsen DODGE. Tek istisna budur.
  void _renderTelegraph(Canvas canvas) {
    if (state != BossState.windup && state != BossState.active) return;
    final beat = currentBeat;
    if (beat == null) return;
    final String label;
    final Color color;
    if (beat.defense == DefenseProfile.guardBreak) {
      label = 'KAÇ!  (SHIFT)';
      color = kBarRed;
    } else if (beat.guardDirection == GuardDirection.high &&
        game.actionSystem.upArrowParries) {
      label = beat.defense == DefenseProfile.tracking
          ? '↑ SAVUŞTUR'
          : '↑ / SHIFT';
      color = kBarBlue;
    } else if (beat.guardDirection == GuardDirection.low &&
        game.actionSystem.downArrowParries) {
      label = beat.defense == DefenseProfile.tracking
          ? '↓ SAVUŞTUR'
          : '↓ / SHIFT';
      color = kBarBlue;
    } else if (beat.defense == DefenseProfile.tracking &&
        beat.guardDirection == GuardDirection.any) {
      label = 'SPACE SAVUŞTUR';
      color = kBarBlue;
    } else {
      return;
    }

    final pulse = 0.55 + 0.45 * sin(_t * 18);
    final tp = TextPaint(
      style: TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    );
    final m = tp.getLineMetrics(label);
    // Sprite başı ~ y=-(cellPx - 112). Pili onun da üstüne, net bir bantta koy.
    final double cy = -(def.cellPx - size.y) - 22;
    final double pillW = m.width + 22;
    final pill = Rect.fromCenter(
      center: Offset(size.x / 2, cy),
      width: pillW,
      height: 24,
    );
    final rr = RRect.fromRectAndRadius(pill, const Radius.circular(5));
    canvas.drawRRect(rr, Paint()..color = kWhite.withAlpha(235));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = color.withAlpha((150 + 105 * pulse).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    tp.render(canvas, label, Vector2(size.x / 2 - m.width / 2, cy - 7));
  }

  void _renderOpenMarker(Canvas canvas) {
    if (!isOpen) return;
    final pulse = 0.5 + 0.5 * sin(_t * 16);
    final infl = 5 + pulse * 5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        size.toRect().inflate(infl),
        const Radius.circular(10),
      ),
      Paint()
        ..color = kBlack.withAlpha((150 + 105 * pulse).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    const label = 'VUR  F';
    final tp = TextPaint(
      style: TextStyle(
        color: kBarGreen,
        fontSize: 16,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
    final m = tp.getLineMetrics(label);
    final double cy = -(def.cellPx - size.y) - 22;
    final pill = Rect.fromCenter(
      center: Offset(size.x / 2, cy),
      width: m.width + 22,
      height: 24,
    );
    final rr = RRect.fromRectAndRadius(pill, const Radius.circular(5));
    canvas.drawRRect(rr, Paint()..color = kWhite.withAlpha(235));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = kBarGreen.withAlpha((150 + 105 * pulse).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    tp.render(canvas, label, Vector2(size.x / 2 - m.width / 2, cy - 7));
  }

  String get phaseLabelTr {
    if (dying) return 'Devrildi';
    switch (state) {
      case BossState.idle:
        return 'Bekliyor';
      case BossState.approach:
        return 'Yaklaşıyor';
      case BossState.windup:
        return 'Hazırlanıyor';
      case BossState.active:
        return 'VURUYOR';
      case BossState.recover:
        return 'Toparlanıyor';
      case BossState.gap:
        return 'Ara';
      case BossState.guard:
        return 'KALKAN';
      case BossState.offBalance:
        return 'AÇIK!';
      case BossState.staggered:
        return 'DENGESİ KIRIK';
      case BossState.reposition:
        return 'Yer değiştiriyor';
      case BossState.retreat:
        return 'Geri çekiliyor';
    }
  }
}
