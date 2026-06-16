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
import 'player.dart';
import 'projectile.dart';
import 'sprite_strip.dart';
import 'theme.dart';

const Color _kAmber = Color(0xFFE0A82E);
const Color _kThrust = Color(0xFF9B5DE5); // mikiri/thrust telegrafı (kırmızıdan ayrı)

enum BossState {
  idle,
  approach,
  windup,
  active,
  recover,
  gap,
  guard,
  offBalance, // committed saldırı dodge'lanınca açılan punish penceresi
  staggered, // posture kırıldı: DEATHBLOW (infaz) penceresi — oyuncu infaz eder
  phaseTransition, // faz eşiği aşıldı: kısa, DOKUNULMAZ staging (08)
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
  // Denge kırılınca boss bu kadar açık kalır = DEATHBLOW (infaz) penceresi.
  // Oyuncunun "İNFAZ F" işaretini görüp tek tuşla infaz etmesine yetecek kadar
  // geniş; basmazsa boss toparlanır (Sekiro deathblow penceresi hissi) (06).
  static const double postureBreakDur = 1.6;

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

  // --- KOMBO-İÇİ ADAPTASYON (09) ---
  // Beat'leri runtime'da (oyuncu eğilimine göre) dönüştürmek için seyrek override.
  // Kombo başında temizlenir; _beat/currentBeat önce buraya bakar.
  final Map<int, Beat> _beatOverrides = {};
  int _recentParries = 0; // bu kombo boyunca oyuncunun cevapları
  int _recentDodges = 0;
  bool _adaptedThisCombo = false; // kombo başına en fazla bir dönüşüm
  bool _playerWasStunned = false; // guard-break punish için yükselen-kenar
  bool _feintBaitedFollowUp = false; // tuzak ısırdı → sıradaki beat hızlanır
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
  // Not: denge kırıkken (staggered) artık HP hasarı YOK; o pencere DEATHBLOW
  // (infaz) ile çözülür (bkz. _performDeathblow, 06).
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
      ? (_beatOverrides[_beatIndex] ?? activeBeats[_beatIndex])
      : null;

  // --- DEATHBLOW / FAZ SEGMENT MODELİ (06 / 08) ---
  // Her başarılı infaz bir segment/faz siler; `deathblowsRequired`'inci infaz
  // (veya düşük HP eşiği) öldürür. Sade ve sağlam: HP, faz eşiklerine "düşürülür".
  late final int deathblowsRequired = def.deathblowsRequired;
  int deathblowsDone = 0;
  int _lastPhase = 0; // faz geçişi staging'i için izlenen önceki faz

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
    deathblowsDone = 0;
    _lastPhase = phase;
    storedCombo = 0;
    _parriedThisCombo = 0;
    _nonFeintTotal = 0;
    _comboChainBroken = false;
    _guardCounter = false;
    _followUpGuard = null;
    _followUpTimer = 0;
    _activeCombo = null;
    _beatIndex = -1;
    _beatOverrides.clear();
    _recentParries = 0;
    _recentDodges = 0;
    _adaptedThisCombo = false;
    _playerWasStunned = false;
    _feintBaitedFollowUp = false;
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
    // Daha büyük, ayrı renkli şok halkası + ayrışmış posture-break sesi + orta
    // şiddette ekran sarsıntısı: artık bu bir DEATHBLOW fırsatı (06/11).
    game.spawnPostureBreak(_topCenter, color: _kAmber, scale: 1.4);
    Sfx.postureBreak();
    game.requestHitstop(0.13);
    game.requestShake(7, 0.3);
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
      // GUARD-BREAK punish: oyuncunun postürü YENİ kırıldıysa (stun + posture 0)
      // garanti hızlı punish. wrongTool stun'ı (posture>0) tetiklemez (09).
      final pb = game.player.isStunned && game.player.posture <= 0;
      if (pb && !_playerWasStunned) _maybeGuardBreakPunish();
      _playerWasStunned = pb;
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
        // DEATHBLOW penceresi: oyuncu infaz etmezse süre dolunca toparlanır.
        if (_timer <= 0) {
          posture = maxPosture.toDouble();
          _beatIndex = -1;
          _activeCombo = null;
          _decidePressure();
        }
        break;

      case BossState.phaseTransition:
        // Kısa, DOKUNULMAZ staging: boss saldırmaz, hasar almaz. Süre dolunca
        // baskıya döner (08).
        position.x = _basePos.x;
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

  Beat get _beat => _beatOverrides[_beatIndex] ?? activeBeats[_beatIndex];

  // Yeni kombo turu: havuzdan ağırlıklı seçim, sonra approach (ranged → yerinde).
  void _beginNewCombo() {
    _activeCombo = _pickCombo();
    _beatOverrides.clear();
    _comboChainBroken = false;
    _parriedThisCombo = 0;
    _recentParries = 0;
    _recentDodges = 0;
    _adaptedThisCombo = false;
    _feintBaitedFollowUp = false;
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
    // Kombo-İÇİ ADAPTASYON: sıradaki beat'i oyuncunun son cevaplarına göre dinamik
    // dönüştür (parry'ciye feint, dodge'cuya tracking) — desen ezberlenemesin (09).
    _adaptBeat(i);
    // DELAYED: windup'u runtime ±jitter ile değiştir; metronom ritmi kırılır (09).
    double windup = _beat.windup;
    if (_beat.defense == DefenseProfile.delayed) {
      final j = game.actionSystem.delayedWindupJitter;
      windup = (windup + (_rng.nextDouble() - 0.28) * j).clamp(0.1, 2.0);
    }
    // Tuzak ısırdıysa bu (gerçek) beat hızlanır → savunma kilidi sürerken temas
    // eder, punish GERÇEKTEN bağlanır (09).
    if (_feintBaitedFollowUp) {
      _feintBaitedFollowUp = false;
      windup = min(windup, 0.16);
    }
    _enter(BossState.windup, windup);
  }

  // Bu beat'i oyuncu eğilimine göre dönüştür (yalnız "normal", melee beat'ler).
  // Parry'ye abanan → ALDATMA tuzağı (erken parry'yi boşa düşür, arkadan punish);
  // dodge'a abanan → TRACKING (dodge'u yakalar, parry zorunlu).
  void _adaptBeat(int i) {
    if (!game.actionSystem.bossInComboAdapt || _adaptedThisCombo) return;
    final base = activeBeats[i];
    if (base.defense != DefenseProfile.normal || base.isRanged) return;
    if (_rng.nextDouble() > game.actionSystem.inComboAdaptChance) return;

    final parryLean = _recentParries + _parryHabit * 2;
    final dodgeLean = _recentDodges + _dodgeHabit * 2;
    final isLast = i >= activeBeats.length - 1;

    if (parryLean >= 1.4 && parryLean >= dodgeLean && !isLast) {
      // Feint son beat olamaz: tuzaktan sonra punish edecek gerçek beat gerekir.
      _beatOverrides[i] = base.copyWith(
        kind: BeatKind.feint,
        defense: DefenseProfile.feint,
        damage: 0,
        postureDamage: 0,
        punishOnDodge: false,
      );
      if (_nonFeintTotal > 0) _nonFeintTotal--; // feint tam-parry'ye sayılmaz
      _adaptedThisCombo = true;
    } else if (dodgeLean >= 1.4 && dodgeLean > parryLean) {
      _beatOverrides[i] = base.copyWith(defense: DefenseProfile.tracking);
      _adaptedThisCombo = true;
    }
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
    // Faz eşiği aşıldıysa baskı yerine önce kısa faz geçişi sahnesi (08).
    if (_maybePhaseTransition()) return;
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

  // -------------------------------------------------------- FAZ GEÇİŞİ (08)
  // Faz yalnız tempo çarpanı değil: eşik AŞILINCA (yalnız zorlaşma yönünde) kısa,
  // dokunulmaz bir staging. Sandbox'ta kapalı (pratik bölünmesin). Sahnelendiyse
  // true döner (çağıran baskı kararı vermez).
  bool _maybePhaseTransition() {
    final ph = phase;
    if (!game.actionSystem.bossPhaseStaging) {
      _lastPhase = ph;
      return false;
    }
    if (ph > _lastPhase && !dying) {
      _lastPhase = ph;
      _enterPhaseTransition();
      return true;
    }
    _lastPhase = ph;
    return false;
  }

  void _enterPhaseTransition() {
    _clearPending();
    _beatIndex = -1;
    _activeCombo = null;
    _guardCounter = false;
    posture = maxPosture.toDouble();
    position.x = _basePos.x;
    // Sinematik: kükreme + orta sarsıntı + kısa slow-mo + uyarı yazısı.
    final label = phase >= 2 ? 'III. FAZ' : 'II. FAZ';
    game.add(ComboText(_topCenter, label));
    game.spawnPostureBreak(_topCenter, color: _kThrust, scale: 1.2);
    game.spawnVignette(color: const Color(0xFF6A3DD0), maxLife: 0.7, peakAlpha: 70);
    Sfx.phaseShift();
    game.requestShake(8, 0.5);
    game.requestSlowmo(0.45, 0.5);
    _enter(BossState.phaseTransition, game.actionSystem.phaseTransitionDuration);
  }

  // -------------------------------------------------------- DEATHBLOW (06)
  // Denge kırıkken (staggered) yapılan saldırı normal HP yerine İNFAZ tetikler:
  // slow-mo + kırmızı vinyet + güçlü ses + büyük sarsıntı. Düşük HP'de veya son
  // segmentte öldürür; aksi halde segment siler → faz geçişi sahnesi gelir.
  void _performDeathblow(PlayerAttackType type, {bool finisher = false}) {
    if (dying) return;
    deathblowsDone++;
    final int hpBefore = health;

    // Sinematik doruk anı. Ağır/finisher infaz biraz daha şiddetli sarsar.
    final bool heavy = type == PlayerAttackType.heavy || finisher;
    game.add(ComboText(_topCenter, heavy ? 'İNFAZ!' : 'İNFAZ'));
    game.spawnPostureBreak(_topCenter, color: kBarRed, scale: heavy ? 1.9 : 1.7);
    game.spawnVignette();
    Sfx.deathblow();
    game.requestHitstop(0.16);
    game.requestSlowmo(
      game.actionSystem.deathblowSlowmoDuration,
      game.actionSystem.deathblowSlowmoScale,
    );
    game.requestShake(heavy ? 14 : 12, 0.5);

    final lethal =
        deathblowsDone >= deathblowsRequired ||
        health <= game.actionSystem.bossExecuteThresholdHp;

    if (lethal && game.actionSystem.bossCanDie) {
      takeDamage(100); // tabana indir → ölüm sekansı
      game.metrics.bossDamageTaken += hpBefore;
      die();
      return;
    }

    // Segment silindi: HP'yi bir sonraki faz eşiğine düşür (faz görünür değişsin),
    // sonra dokunulmaz faz geçişi sahnesi. Sandbox'ta (staging kapalı) baskıya döner.
    final next = health > 50 ? 50 : (health > 25 ? 25 : 1);
    if (health > next) takeDamage(health - next);
    game.metrics.bossDamageTaken += (hpBefore - health);
    posture = maxPosture.toDouble();
    _hurtT = 0.3;
    if (game.actionSystem.bossPhaseStaging) {
      _lastPhase = phase;
      _enterPhaseTransition();
    } else {
      _beatIndex = -1;
      _activeCombo = null;
      _decidePressure();
    }
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
  // i-frame bu beat'i geçersiz kılar mı? Tracking (takip/saplama) HARİÇ: o,
  // dokunulmazlığı delip bulur ve yalnız parry ile karşılanır.
  bool _iFrameBeats(Beat beat) =>
      game.player.isInvulnerable && beat.defense != DefenseProfile.tracking;

  void _resolveContact(Beat beat, Projectile? proj) {
    if (dying) return;
    // ALDATMA: gerçek vuruş YOK. Önceden/erken savunan oyuncu tuzağa düşer (09).
    if (beat.kind == BeatKind.feint || beat.defense == DefenseProfile.feint) {
      _resolveFeint(beat, proj);
      return;
    }
    final p = game.player;
    // Gerçek i-frame: dodge'un dokunulmazlık penceresindeyse HER saldırı geçersiz
    // (tracking dahil). Sıkı bir pencere; usta zamanlamayı ödüllendirir (04).
    // i-frame her şeyi geçer AMA tracking (saplama/takip) hariç: takip saldırısı
    // i-frame'i delip seni bulur → yalnız SPACE (parry) ile karşılanır.
    if (_iFrameBeats(beat)) {
      _dodgeSuccess(beat, proj);
      return;
    }
    // Parry penceresi: beat penceresi ile oyuncunun (spam ile daralmış olabilen)
    // penceresinin küçüğü. Böylece spam decay başarıyı gerçekten daraltır (03).
    final effWindow = min(beat.preWindow, p.effectiveParryWindow);
    final pressedParry = Player.parrySucceeds(p.sinceParry, effWindow);
    final didParry = pressedParry && _guardMatches(beat);
    // Dodge başarısı GERÇEK i-frame'e bağlı (yukarıda isInvulnerable ile çözüldü).
    // triedDodge yalnız FEEDBACK içindir: dodge'a bastı ama i-frame'i ıskaladı →
    // başarı yok, greed cezalanır (04).
    final triedDodge = p.sinceDodge <= beat.dodgePre;

    if (beat.defense == DefenseProfile.guardBreak) {
      if (pressedParry) {
        _wrongTool(beat, proj, 'PARRY OLMAZ!');
      } else {
        _beginPending(beat, proj);
      }
    } else if (beat.defense == DefenseProfile.thrust) {
      // MİKİRİ: delici saldırı. Doğru cevap dodge (i-frame); parry cezalanır.
      if (pressedParry) {
        _wrongTool(beat, proj, 'MİKİRİ! KAÇ');
      } else {
        _beginPending(beat, proj);
      }
    } else if (beat.defense == DefenseProfile.tracking) {
      if (didParry) {
        _parrySuccess(beat, proj);
      } else if (pressedParry) {
        _wrongTool(beat, proj, 'YANLIŞ YÖN!');
      } else if (triedDodge) {
        _wrongTool(beat, proj, 'KAÇILMAZ!');
      } else {
        _beginPending(beat, proj);
      }
    } else {
      if (didParry) {
        _parrySuccess(beat, proj);
      } else if (pressedParry && beat.guardDirection != GuardDirection.any) {
        _wrongTool(beat, proj, 'YANLIŞ YÖN!');
      } else {
        _beginPending(beat, proj);
      }
    }
  }

  // ALDATMA (feint) çözümü (09). Telegraf normal saldırı gibi görünür ama vuruş
  // gelmez. Erken/önceden savunan (parry/dodge) oyuncu YEM YUTAR → kısa savunma
  // kilidi; arkadan gelen gerçek beat punish eder. BASMAMAK her zaman güvenli:
  // disiplinli oyuncu cezalanmaz, yalnız refleksle erken basan tuzağa düşer.
  void _resolveFeint(Beat beat, Projectile? proj) {
    proj?.deflect();
    final p = game.player;
    final w = game.actionSystem.feintBaitWindow;
    final baited =
        game.actionSystem.bossFeintTrap &&
        (p.isParrying ||
            p.isDodging ||
            p.isInvulnerable ||
            p.sinceParry <= w ||
            p.sinceDodge <= w);
    if (baited) {
      p.baitPunish(game.actionSystem.feintBaitLock);
      _feintBaitedFollowUp = true; // sıradaki gerçek beat hızlanıp punish etsin
      game.metrics.feintBaited++;
      // Erken savunma eğilimi → bu oyuncuya daha çok tuzak (parry habit artar).
      _registerHabit(parry: true);
      _comboChainBroken = true;
      Sfx.whiff();
      game.spawnSpark(_topCenter, _kAmber);
      game.spawnPopup(_topCenter, 'TUZAK!', fontSize: 16, color: _kAmber, rise: 26);
    } else {
      game.spawnPopup(_topCenter, 'ALDATMA', fontSize: 14, color: kGray500);
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
    // i-frame penceresine girildiyse temas geçersiz (tracking hariç) (04).
    if (_iFrameBeats(beat)) {
      final proj = _pendingProjectile;
      _clearPending();
      _dodgeSuccess(beat, proj);
      return;
    }
    // Temas sonrası TAZE parry basışı (input-lag affı). Dodge için ayrı taze yol
    // YOK: dodge başarısı yalnız i-frame'den gelir (yukarıda kontrol edildi) (04).
    final freshParry = p.sinceParry <= _freshPress;
    final parryForbidden =
        beat.defense == DefenseProfile.guardBreak ||
        beat.defense == DefenseProfile.thrust;
    if (freshParry && !parryForbidden) {
      final proj = _pendingProjectile;
      _clearPending();
      if (!_guardMatches(beat)) {
        _wrongTool(beat, proj, 'YANLIŞ YÖN!');
        return;
      }
      _parrySuccess(beat, proj);
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
  // Perfect parry (pencerenin ilk dilimi) late'den ölçülebilir biçimde daha
  // ödüllü: ekstra posture + tam hitstop + parlak spark + "ŞING" (03).
  void _parrySuccess(Beat beat, Projectile? proj) {
    final perfect =
        game.player.classifyParry() == ParryQuality.perfect;
    perfect ? Sfx.parryPerfect() : Sfx.parryLate();
    game.player.onParrySuccess();
    game.metrics.parrySuccesses++;
    _registerHabit(parry: true);
    _hurtT = 0.30;
    proj?.deflect();
    game.requestHitstop(perfect ? 0.09 : 0.03);
    game.spawnSpark(_topCenter, perfect ? _kAmber : kBarBlue);
    if (perfect) game.spawnSpark(_topCenter, kBarBlue);

    if (beat.kind == BeatKind.feint) {
      game.spawnPopup(_topCenter, 'ALDATMA', fontSize: 14, color: kGray500);
      return;
    }

    _parriedThisCombo++;
    _recentParries++;
    storedCombo = _parriedThisCombo;
    _armParryFollowUp(beat);
    final dmg = perfect
        ? (beat.postureDamage * 1.5).round()
        : beat.postureDamage;
    applyPostureDamage(dmg);
    if (perfect) {
      game.spawnPopup(
        _topCenter + Vector2(0, -2),
        'MÜKEMMEL',
        fontSize: 14,
        color: _kAmber,
      );
    }
    game.spawnPopup(
      _topCenter + Vector2(0, perfect ? 16 : 0),
      '-$dmg DENGE',
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
    final p = game.player;
    // Son bir kontrol: i-frame penceresine girdiyse darbe geçersiz (tracking hariç).
    if (_iFrameBeats(beat)) {
      _dodgeSuccess(beat, proj);
      return;
    }
    // Oyuncu blok tutuyorsa: HP yerine posture+stamina yer, hasarsız (02).
    if (p.isBlocking) {
      proj?.deflect();
      p.takeBlockedHit(beat);
      _comboChainBroken = true;
      game.spawnSpark(_topCenter, _kAmber);
      game.spawnPopup(
        Vector2(game.player.position.x, game.player.position.y - size.y * 0.9),
        beat.defense == DefenseProfile.guardBreak ? 'BLOK DELİNDİ' : 'BLOK',
        fontSize: 13,
        color: _kAmber,
        rise: 24,
      );
      return;
    }
    // NEDEN yedin? Erken bastıysan ritim kırıldı; yakın bastıysan zamanlama;
    // basmadıysan savunmadın.
    final pressed = p.sinceParry < 0.45 || p.sinceDodge < 0.45;
    final String reason;
    if (beat.punishesEarly && pressed) {
      reason = 'ERKEN!'; // delayed/feint: ritmi okumadan bastın
    } else {
      reason = pressed ? 'ZAMANLAMA!' : 'SAVUNMADIN!';
    }
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

  // DODGE BAŞARILI — hasarsız sıyrılma. Perfect dodge (i-frame'in erken dilimi)
  // her zaman açılış + slow-mo verir; committed/thrust de açar; hafif geç dodge
  // yalnız kurtarır (04).
  void _dodgeSuccess(Beat beat, Projectile? proj) {
    final perfect = game.player.isPerfectDodge;
    Sfx.dodge();
    game.player.onDodgeSuccess();
    game.metrics.dodgeSuccesses++;
    _registerHabit(dodge: true);
    _recentDodges++;
    proj?.deflect();
    _comboChainBroken = true; // parry zinciri kırıldı (bonus yok)

    if (beat.kind == BeatKind.feint) {
      game.spawnPopup(_topCenter, 'ALDATMA', fontSize: 14, color: kGray500);
      return;
    }

    // Açılış YALNIZ committed/kırmızı/thrust beat'lerde: dodge bunların doğru
    // cevabı. Normal saldırının asıl ödül aracı YÖNLÜ PARRY'dir (posture +
    // karşı vuruş); dodge onları açmaz, yoksa parry'nin değeri düşer.
    final opens =
        beat.punishOnDodge || beat.defense == DefenseProfile.thrust;
    // Perfect dodge HER durumda slow-mo flourish verir (his ödülü).
    if (perfect) {
      game.requestHitstop(0.12);
      game.spawnSpark(_topCenter, _kAmber);
    }
    if (opens) {
      game.spawnPopup(
        _topCenter,
        perfect ? 'TAM SIYRILMA!' : 'AÇIK!',
        fontSize: perfect ? 16 : 15,
        color: perfect ? _kAmber : kGray700,
        rise: 28,
      );
      // Perfect dodge daha uzun punish penceresi açar.
      _enter(BossState.offBalance, perfect ? punishWindow * 1.4 : punishWindow);
    } else {
      // Normal saldırıyı sıyırdın: hasarsız kurtuluş (+perfect'te slow-mo) ama
      // boss komboya DEVAM eder. Açmak istiyorsan yönlü parry'le.
      game.spawnPopup(
        _topCenter,
        perfect ? 'TAM SIYRILMA' : 'SIYRILDIN',
        fontSize: perfect ? 14 : 13,
        color: perfect ? _kAmber : kGray500,
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
  void receivePlayerAttack(
    PlayerAttackType type, {
    int comboStep = 0,
    bool finisher = false,
  }) {
    if (dying) return;
    // Faz geçişi sahnesi DOKUNULMAZ: oyuncu haksız hasar veremez (08).
    if (state == BossState.phaseTransition) {
      Sfx.whiff();
      game.spawnPopup(_topCenter, 'DOKUNULMAZ', fontSize: 13, color: kGray500);
      return;
    }
    _registerHabit(attack: true);
    // Kombo derinliği / finisher → hasar çarpanı (05).
    final double comboMult = finisher ? 1.5 : (1 + comboStep * 0.12);

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
      // Denge kırık: normal HP hasarı DEĞİL, özel İNFAZ akışı (06).
      _performDeathblow(type, finisher: finisher);
    } else if (state == BossState.offBalance) {
      final hp = ((attackHpOpen + (game.player.hasTempo ? 4 : 0)) * comboMult)
          .round();
      takeDamage(hp);
      game.metrics.bossDamageTaken += hp;
      type == PlayerAttackType.heavy ? Sfx.heavyHit() : Sfx.hit();
      game.requestHitstop(type == PlayerAttackType.heavy ? 0.11 : 0.08);
      if (type == PlayerAttackType.heavy) game.requestShake(4, 0.16);
      game.add(ComboText(_topCenter, finisher ? 'FİNİSHER' : 'CEZA'));
      game.spawnPopup(_topCenter + Vector2(0, 30), '-$hp', fontSize: 20);
      _decidePressure();
    } else {
      // Boss açık değil. GREED: oyuncu açık olmadığı halde saldırıyor. Boss bunu
      // okuyup (olasılıksal, fazla göre sıklaşan) hızlı bir karşı-beat başlatabilir
      // → F spam'i artık risksiz değil (09). Aksi halde yalnız riskli posture chip.
      if (_maybeGreedPunish()) return;
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

  // GREED PUNISH (09): boss açık değilken saldıran oyuncuya hızlı karşı-beat.
  // Parry'lenebilir (preWindow>0) → ceza adil: reflekssiz over-extend yer, usta
  // savunma kurtarır. Faz arttıkça olasılık ve hız artar.
  bool _maybeGreedPunish() {
    if (!game.actionSystem.bossGreedPunish || dying) return false;
    if (state == BossState.phaseTransition) return false;
    final chance = game.actionSystem.greedPunishChance * (1 + phase * 0.25);
    if (_rng.nextDouble() > chance) return false;
    game.metrics.greedPunished++;
    game.add(ComboText(_topCenter, 'AÇGÖZLÜ!'));
    Sfx.whiff();
    _startCounterBeat(windup: 0.18 - phase * 0.02, damage: 14);
    return true;
  }

  // GUARD-BREAK PUNISH (09): oyuncunun postürü kırılıp açık kaldıysa boss GARANTİ
  // hızlı punish başlatır. Oyuncu zaten kilitli olduğundan bu beat'i karşılayamaz.
  void _maybeGuardBreakPunish() {
    if (!game.actionSystem.bossGuardBreakPunish || dying) return;
    if (state == BossState.staggered ||
        state == BossState.phaseTransition ||
        state == BossState.offBalance) {
      return;
    }
    game.metrics.guardBreakPunished++;
    game.add(ComboText(_topCenter, 'SAVUNMA KIRIK!'));
    _startCounterBeat(windup: 0.22, damage: 16);
  }

  // Tek-beat hızlı punish komboyu kur ve windup'a gir (greed / guard-break).
  void _startCounterBeat({required double windup, required int damage}) {
    _clearPending();
    _beatOverrides.clear();
    _comboChainBroken = true;
    _guardCounter = false;
    final source = def.pattern.beats.last;
    final counter = Beat(
      kind: source.kind == BeatKind.feint ? BeatKind.meleeLight : source.kind,
      defense: DefenseProfile.normal,
      animKey: source.animKey,
      windup: windup.clamp(0.1, 1.0),
      active: source.active,
      recover: source.recover,
      gapAfter: .18,
      preWindow: 0.12,
      grace: 0.05,
      dodgePre: 0.22,
      damage: damage,
      postureDamage: 0,
      punishOnDodge: false,
      mustDefend: true,
      projectileKey: source.projectileKey,
      projectileSpeed: source.projectileSpeed,
    );
    _activeCombo = ComboPattern([counter], staggerBonus: 0);
    _nonFeintTotal = 1;
    _parriedThisCombo = 0;
    _recentParries = 0;
    _recentDodges = 0;
    _adaptedThisCombo = true; // tek-beat punish tekrar dönüştürülmesin
    storedCombo = 0;
    _beatIndex = 0;
    _enter(BossState.windup, counter.windup);
  }

  void _shieldHeavyPunish() {
    _clearPending();
    _beatOverrides.clear();
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
      case BossState.phaseTransition:
        // Dirilme/poz alma: savunma duruşunu tut (kısa staging).
        return _sprites.frames('defend').last;
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
    } else if (beat.defense == DefenseProfile.thrust) {
      label = 'MİKİRİ!  (SHIFT)';
      color = _kThrust;
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
    // Denge kırık → DEATHBLOW (güçlü, kırmızı "İNFAZ"); dodge sonrası açık →
    // normal yeşil "VUR" marker'ı. İkisi görsel olarak net ayrışır (06).
    final bool deathblow = state == BossState.staggered;
    final pulse = 0.5 + 0.5 * sin(_t * (deathblow ? 22 : 16));
    final infl = (deathblow ? 7 : 5) + pulse * (deathblow ? 7 : 5);
    final Color ring = deathblow ? kBarRed : kBlack;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        size.toRect().inflate(infl),
        const Radius.circular(10),
      ),
      Paint()
        ..color = ring.withAlpha((150 + 105 * pulse).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = deathblow ? 4 : 3,
    );
    final String label = deathblow ? 'İNFAZ  F' : 'VUR  F';
    final tp = TextPaint(
      style: TextStyle(
        color: deathblow ? kBarRed : kBarGreen,
        fontSize: deathblow ? 18 : 16,
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
        ..color = (deathblow ? kBarRed : kBarGreen)
            .withAlpha((150 + 105 * pulse).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = deathblow ? 3 : 2.5,
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
        return 'İNFAZ FIRSATI';
      case BossState.phaseTransition:
        return 'FAZ DEĞİŞİYOR';
      case BossState.reposition:
        return 'Yer değiştiriyor';
      case BossState.retreat:
        return 'Geri çekiliyor';
    }
  }
}
