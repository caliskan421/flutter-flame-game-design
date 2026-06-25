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

import 'characters.dart';
import 'combat/ai/boss_brain.dart';
import 'combat/rules/combat_event.dart';
import 'combat/rules/combat_resolver.dart';
import 'combat/sim/posture_system.dart';
import 'game.dart';
import 'player.dart';
import 'presentation/boss_view.dart';
import 'projectile.dart';
import 'sprite_strip.dart';
import 'theme.dart';

const Color _kAmber = Color(0xFFE0A82E);
const Color _kThrust = Color(
  0xFF9B5DE5,
); // mikiri/thrust telegrafı (kırmızıdan ayrı)

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
  // Denge durumu/kuralları saf PostureSystem'de (Faz F). Aşağıdaki getter'lar
  // eski public alanları (HUD okur) birebir korur.
  late final PostureSystem _posture = PostureSystem(def.maxPosture);
  int get maxPosture => _posture.max;
  double get posture => _posture.value;
  double get displayPosture => _posture.display;
  // Denge kırılınca boss bu kadar açık kalır = DEATHBLOW (infaz) penceresi.
  // Oyuncunun F ile birkaç hafif kesik veya G ile ağır infaz seçmesine yetecek
  // kadar geniş; süre dolarsa boss toparlanır (Sekiro deathblow penceresi hissi).
  static const double postureBreakDur = 1.6;
  // G infazı hasarı ve faz/ölüm sonucu, ağır saldırı temas hesabında değil,
  // kılıcın saplandığı gecikmiş impact anında bağlanır. Faz geçişi başlasa bile
  // boss, oyuncunun ağır saldırısının kalan active+recover süresinde hurt kalır.
  static const double phaseTransitionDeathblowHurtHold =
      Player.heavyAtkActive + Player.heavyAtkRecover;
  // G infazının kesilme sesi, hasarın bağlandığı ilk active anında değil,
  // ağır kılıç çekişi biraz ilerledikten sonra duyulur.
  static const double heavyDeathblowSfxDelay = Player.heavyAtkActive + 0.08;

  double _timer = 0;
  bool _justEntered = true;
  double _phaseTransitionHurtHold = 0;
  double _queuedDeathblowImpactDelay = -1;
  int _queuedDeathblowHpBefore = 0;
  bool _queuedDeathblowHeavy = false;

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
  static const int attackHpOpen = 14; // kırmızıyı dodge sonrası açıkken
  static const int attackHpStaggeredLight = 15; // denge kırıkken F kesikleri
  static const int attackPostureChip = 8; // boss açık değilken (riskli poke)

  // --- ADAPTASYON / AI: saf karar çekirdeği (alışkanlık EMA'ları, kombo seçimi,
  //     beat adaptasyonu, greed-punish kararı) BossBrain'de (Faz F). _rng burada
  //     paylaşılır → tüm rastgele çağrıların SIRASI birebir korunur.
  final BossBrain _brain = BossBrain();
  final Random _rng = Random();

  // --- SPRITE ---
  late final SpriteStripBank _sprites = SpriteStripBank(def);
  Sprite? _portrait;

  // --- GÖRSEL SUNUM (Faz F: render presentation/boss_view.dart'a taşındı) ---
  // BossView yalnız aşağıdaki salt-okunur durumu okuyup çizer (tek-yön bağımlılık).
  late final BossView _view = BossView(this);
  SpriteStripBank get sprites => _sprites;
  double get t => _t; // render animasyon saati
  double get hurtT => _hurtT;
  double get timer => _timer;
  double get deathT => _deathT;
  double get deathFrameTime => _deathFrameTime;
  double get phaseTransitionHurtHold => _phaseTransitionHurtHold;

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
    _posture.reset();
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
    _phaseTransitionHurtHold = 0;
    _queuedDeathblowImpactDelay = -1;
    _queuedDeathblowHpBefore = 0;
    _queuedDeathblowHeavy = false;
    _pending = false;
    _pendingGrace = 0;
    _pendingBeat = null;
    _pendingProjectile = null;
    _hurtT = 0;
    _brain.reset();
    dying = false;
    deathDone = false;
    _deathT = 0;
    _swordDropPlayed = false;
    if (_basePos != Vector2.zero()) position = _basePos.clone();
    _enter(BossState.idle, idleTime);
  }

  // TEST: ölümsüzlük için can ~0'a inerse tabanda tut, ölme.
  double _testRegenAcc = 0;

  void die({bool playHit = true}) {
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
    if (playHit) game.bus.emit(const SfxRequested(SfxCue.hit));
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
    _posture.forceFull();
    position.x = _basePos.x;
    _enter(BossState.guard, testGuardDuration);
  }

  void takeDamage(int dmg) =>
      health = (health - dmg).clamp(game.actionSystem.minBossHealth, 100);

  // --- POSTURE API ---
  void applyPostureDamage(int dmg) {
    final broke = _posture.applyDamage(
      dmg,
      dying: dying,
      staggered: state == BossState.staggered,
    );
    if (broke) breakPosture();
  }

  void breakPosture() {
    if (dying) return;
    _posture.onBroken();
    _clearPending();
    game.bus.emit(const PostureBroken());
    game.bus.emit(ComboTextRequested(_topCenter, 'DENGE KIRILDI'));
    // Daha büyük, ayrı renkli şok halkası + ayrışmış posture-break sesi + orta
    // şiddette ekran sarsıntısı: artık bu bir DEATHBLOW fırsatı (06/11).
    game.bus.emit(PostureBreakFxRequested(_topCenter, color: _kAmber, scale: 1.4));
    game.bus.emit(const SfxRequested(SfxCue.postureBreak));
    game.bus.emit(const HitstopRequested(0.13));
    game.bus.emit(ShakeRequested(7, 0.3));
    _enter(BossState.staggered, postureBreakDur);
  }

  Vector2 get _topCenter => Vector2(position.x, position.y - 116);

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_hurtT > 0) _hurtT -= dt;
    displayHealth += (health - displayHealth) * (dt * 8).clamp(0, 1);
    _posture.tickDisplay(dt);

    // Alışkanlık EMA'ları yavaşça söner.
    _brain.decay(dt);
    _tickQueuedDeathblowImpact(dt);
    if (_followUpTimer > 0) {
      _followUpTimer -= dt;
      if (_followUpTimer <= 0) _followUpGuard = null;
    }

    if (dying) {
      _deathT += dt;
      if (!_swordDropPlayed && _deathT >= _deathDur * 0.55) {
        _swordDropPlayed = true;
        game.bus.emit(const SfxRequested(SfxCue.swordDrop));
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
      _posture.tickRegen(dt, staggered: state == BossState.staggered);
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

  void _queueDeathblowImpact({
    required double delay,
    required int hpBefore,
    required bool heavy,
  }) {
    _queuedDeathblowImpactDelay = delay.clamp(0, 999).toDouble();
    _queuedDeathblowHpBefore = hpBefore;
    _queuedDeathblowHeavy = heavy;
  }

  void _tickQueuedDeathblowImpact(double dt) {
    if (_queuedDeathblowImpactDelay < 0) return;
    _queuedDeathblowImpactDelay -= dt;
    if (_queuedDeathblowImpactDelay > 0) return;
    final hpBefore = _queuedDeathblowHpBefore;
    final heavy = _queuedDeathblowHeavy;
    _queuedDeathblowImpactDelay = -1;
    _queuedDeathblowHpBefore = 0;
    _queuedDeathblowHeavy = false;
    _resolveDeathblowImpact(hpBefore: hpBefore, heavy: heavy);
  }

  void _registerHabit({
    bool parry = false,
    bool dodge = false,
    bool attack = false,
  }) =>
      _brain.registerHabit(parry: parry, dodge: dodge, attack: attack);

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
          _posture.forceFull();
          _beatIndex = -1;
          _activeCombo = null;
          _decidePressure();
        }
        break;

      case BossState.phaseTransition:
        // Kısa, DOKUNULMAZ staging: boss saldırmaz, hasar almaz. Süre dolunca
        // baskıya döner (08).
        position.x = _basePos.x;
        if (_phaseTransitionHurtHold > 0) {
          _phaseTransitionHurtHold = (_phaseTransitionHurtHold - dt)
              .clamp(0, 999)
              .toDouble();
        }
        if (_timer <= 0) {
          _posture.forceFull();
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
  // parry'e abanıyorsa feint/guardBreak/delayed içeren deseni öne çıkar (BossBrain).
  ComboPattern _pickCombo() => _brain.pickCombo(def.combos, phase, _rng);

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
    // Boss tarafı kapılar: ayar kapalıysa veya bu kombo zaten dönüştürüldüyse çık
    // (rng burada TÜKETİLMEZ). Karar + rng tüketimi BossBrain'de.
    if (!game.actionSystem.bossInComboAdapt || _adaptedThisCombo) return;
    final adapt = _brain.adaptBeat(
      base: activeBeats[i],
      isLast: i >= activeBeats.length - 1,
      recentParries: _recentParries,
      recentDodges: _recentDodges,
      adaptChance: game.actionSystem.inComboAdaptChance,
      rng: _rng,
    );
    if (adapt == null) return;
    _beatOverrides[i] = adapt.beat;
    if (adapt.reducesNonFeint && _nonFeintTotal > 0) {
      _nonFeintTotal--; // feint tam-parry'ye sayılmaz
    }
    _adaptedThisCombo = true;
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
      game.bus.emit(ComboTextRequested(_topCenter, '×$_parriedThisCombo  TAM PARRY'));
      game.bus.emit(PopupRequested(
        _topCenter + Vector2(0, 34),
        '-$bonus DENGE',
        fontSize: 18,
        color: kBarBlue,
      ));
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

  void _enterPhaseTransition({double hurtHold = 0, bool playSfx = true}) {
    _clearPending();
    _beatIndex = -1;
    _activeCombo = null;
    _guardCounter = false;
    _phaseTransitionHurtHold = hurtHold;
    _posture.forceFull();
    position.x = _basePos.x;
    // Sinematik: kükreme + orta sarsıntı + kısa slow-mo + uyarı yazısı.
    final label = phase >= 2 ? 'III. FAZ' : 'II. FAZ';
    game.bus.emit(ComboTextRequested(_topCenter, label));
    game.bus.emit(PostureBreakFxRequested(_topCenter, color: _kThrust, scale: 1.2));
    game.bus.emit(const VignetteRequested(
      color: Color(0xFF6A3DD0),
      maxLife: 0.7,
      peakAlpha: 70,
    ));
    if (playSfx) game.bus.emit(const SfxRequested(SfxCue.phaseShift));
    game.bus.emit(ShakeRequested(8, 0.5));
    game.bus.emit(const SlowmoRequested(0.45, 0.5));
    game.bus.emit(PhaseChanged(phase));
    _enter(
      BossState.phaseTransition,
      game.actionSystem.phaseTransitionDuration,
    );
  }

  // -------------------------------------------------------- DEATHBLOW (06)
  void _performStaggerLightHit() {
    if (dying) return;
    final hpBefore = health;
    takeDamage(attackHpStaggeredLight);
    final dealt = hpBefore - health;
    if (dealt <= 0) {
      game.bus.emit(const SfxRequested(SfxCue.whiff));
      game.bus.emit(
        PopupRequested(_topCenter, 'ETKİ YOK', fontSize: 13, color: kGray500),
      );
      return;
    }
    game.bus.emit(DamageApplied(dealt, toBoss: true));
    game.bus.emit(const SfxRequested(SfxCue.hit));
    game.bus.emit(const HitstopRequested(0.07));
    _hurtT = 0.18;
    game.bus.emit(ComboTextRequested(_topCenter, 'KESİK'));
    game.bus.emit(
      PopupRequested(_topCenter + Vector2(0, 30), '-$dealt', fontSize: 19),
    );
    if (health <= 0 && game.actionSystem.bossCanDie) die(playHit: false);
  }

  // Denge kırıkken (staggered) G/ağır saldırı İNFAZ tetikler: slow-mo + kırmızı
  // vinyet + güçlü ses + büyük sarsıntı. Düşük HP'de veya son segmentte öldürür;
  // aksi halde segment siler → faz geçişi sahnesi gelir.
  void _performDeathblow(PlayerAttackType type, {bool finisher = false}) {
    if (dying) return;
    if (_queuedDeathblowImpactDelay >= 0) return;
    final int hpBefore = health;

    final bool heavy = type == PlayerAttackType.heavy || finisher;
    final delay = heavy ? heavyDeathblowSfxDelay : 0.0;
    _timer = max(_timer, delay + 0.05);
    _queueDeathblowImpact(delay: delay, hpBefore: hpBefore, heavy: heavy);
  }

  void _resolveDeathblowImpact({required int hpBefore, required bool heavy}) {
    if (dying) return;
    deathblowsDone++;

    game.bus.emit(ComboTextRequested(_topCenter, heavy ? 'İNFAZ!' : 'İNFAZ'));
    game.bus.emit(
      PostureBreakFxRequested(
        _topCenter,
        color: kBarRed,
        scale: heavy ? 1.9 : 1.7,
      ),
    );
    game.bus.emit(const VignetteRequested());
    game.bus.emit(const SfxRequested(SfxCue.deathblow));
    game.bus.emit(const HitstopRequested(0.16));
    game.bus.emit(
      SlowmoRequested(
        game.actionSystem.deathblowSlowmoDuration,
        game.actionSystem.deathblowSlowmoScale,
      ),
    );
    game.bus.emit(ShakeRequested(heavy ? 14 : 12, 0.5));

    final lethal =
        deathblowsDone >= deathblowsRequired ||
        health <= game.actionSystem.bossExecuteThresholdHp;
    game.bus.emit(Deathblow(lethal: lethal));

    if (lethal && game.actionSystem.bossCanDie) {
      takeDamage(100); // tabana indir → ölüm sekansı
      game.bus.emit(DamageApplied(hpBefore, toBoss: true));
      die(playHit: false);
      return;
    }

    // Segment silindi: HP'yi bir sonraki faz eşiğine düşür (faz görünür değişsin),
    // sonra dokunulmaz faz geçişi sahnesi. Sandbox'ta (staging kapalı) baskıya döner.
    final next = health > 50 ? 50 : (health > 25 ? 25 : 1);
    if (health > next) takeDamage(health - next);
    game.bus.emit(DamageApplied(hpBefore - health, toBoss: true));
    _posture.forceFull();
    _hurtT = 0.3;
    if (game.actionSystem.bossPhaseStaging) {
      _lastPhase = phase;
      _enterPhaseTransition(
        hurtHold: phaseTransitionDeathblowHurtHold,
        playSfx: false,
      );
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
    final p = game.player;
    // Araç+pencere KARARI saf CombatResolver'da (Flame'siz, test edilebilir).
    // Boss yalnız oyuncu/beat durumunu okur ve kararı uygular.
    final isFeint =
        beat.kind == BeatKind.feint || beat.defense == DefenseProfile.feint;
    final decision = CombatResolver.resolveContact(
      defense: beat.defense,
      guardDirection: beat.guardDirection,
      isFeint: isFeint,
      playerInvulnerable: p.isInvulnerable,
      guardMatches: _guardMatches(beat),
      sinceParry: p.sinceParry,
      sinceDodge: p.sinceDodge,
      beatPreWindow: beat.preWindow,
      effectiveParryWindow: p.effectiveParryWindow,
      dodgePre: beat.dodgePre,
    );
    switch (decision.action) {
      case ContactAction.feint:
        _resolveFeint(beat, proj);
      case ContactAction.dodgeSuccess:
        _dodgeSuccess(beat, proj);
      case ContactAction.parrySuccess:
        _parrySuccess(beat, proj);
      case ContactAction.wrongTool:
        _wrongTool(beat, proj, decision.wrongToolLabel!);
      case ContactAction.beginPending:
        _beginPending(beat, proj);
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
      game.bus.emit(const MetricRecorded(MetricKind.feintBaited));
      // Erken savunma eğilimi → bu oyuncuya daha çok tuzak (parry habit artar).
      _registerHabit(parry: true);
      _comboChainBroken = true;
      game.bus.emit(const SfxRequested(SfxCue.whiff));
      game.bus.emit(SparkRequested(_topCenter, _kAmber));
      game.bus.emit(
        PopupRequested(
          _topCenter,
          'TUZAK!',
          fontSize: 16,
          color: _kAmber,
          rise: 26,
        ),
      );
    } else {
      game.bus.emit(
        PopupRequested(_topCenter, 'ALDATMA', fontSize: 14, color: kGray500),
      );
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
    game.bus.emit(DamageApplied(hp, toBoss: true));
    game.bus.emit(const SfxRequested(SfxCue.hit));
    game.bus.emit(const HitstopRequested(0.07));
    _hurtT = 0.18;
    game.bus.emit(
      PopupRequested(_topCenter + Vector2(0, 30), '-$hp', fontSize: 19),
    );
    return true;
  }

  // PARRY BAŞARILI — HP DEĞİL POSTURE hasarı + tempo penceresi.
  // Perfect parry (pencerenin ilk dilimi) late'den ölçülebilir biçimde daha
  // ödüllü: ekstra posture + tam hitstop + parlak spark + "ŞING" (03).
  void _parrySuccess(Beat beat, Projectile? proj) {
    final perfect = game.player.classifyParry() == ParryQuality.perfect;
    game.bus.emit(
      SfxRequested(perfect ? SfxCue.parryPerfect : SfxCue.parryLate),
    );
    game.player.onParrySuccess();
    game.bus.emit(ParrySucceeded(perfect: perfect));
    _registerHabit(parry: true);
    _hurtT = 0.30;
    proj?.deflect();
    game.bus.emit(HitstopRequested(perfect ? 0.09 : 0.03));
    game.bus.emit(SparkRequested(_topCenter, perfect ? _kAmber : kBarBlue));
    if (perfect) game.bus.emit(SparkRequested(_topCenter, kBarBlue));

    if (beat.kind == BeatKind.feint) {
      game.bus.emit(
        PopupRequested(_topCenter, 'ALDATMA', fontSize: 14, color: kGray500),
      );
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
      game.bus.emit(
        PopupRequested(
          _topCenter + Vector2(0, -2),
          'MÜKEMMEL',
          fontSize: 14,
          color: _kAmber,
        ),
      );
    }
    game.bus.emit(
      PopupRequested(
        _topCenter + Vector2(0, perfect ? 16 : 0),
        '-$dmg DENGE',
        fontSize: 15,
        color: kBarBlue,
      ),
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
    game.bus.emit(
      PopupRequested(_topCenter + Vector2(0, -24), label, fontSize: 13),
    );
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
      game.bus.emit(SparkRequested(_topCenter, _kAmber));
      game.bus.emit(
        PopupRequested(
          Vector2(
            game.player.position.x,
            game.player.position.y - size.y * 0.9,
          ),
          beat.defense == DefenseProfile.guardBreak ? 'BLOK DELİNDİ' : 'BLOK',
          fontSize: 13,
          color: _kAmber,
          rise: 24,
        ),
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
    game.bus.emit(DamageApplied(beat.damage, toBoss: false));
    game.bus.emit(
      PopupRequested(
        Vector2(game.player.position.x, game.player.position.y - size.y * 1.05),
        reason,
        fontSize: 14,
        color: kBarRed,
        rise: 30,
      ),
    );
    game.bus.emit(
      PopupRequested(
        Vector2(game.player.position.x, game.player.position.y - size.y * 0.8),
        '-${beat.damage}',
        fontSize: beat.damage >= 20 ? 23 : 17,
      ),
    );
    _comboChainBroken = true; // vuruş yedin: tam-parry bonusu iptal
  }

  // DODGE BAŞARILI — hasarsız sıyrılma. Perfect dodge (i-frame'in erken dilimi)
  // her zaman açılış + slow-mo verir; committed/thrust de açar; hafif geç dodge
  // yalnız kurtarır (04).
  void _dodgeSuccess(Beat beat, Projectile? proj) {
    final perfect = game.player.isPerfectDodge;
    game.bus.emit(const SfxRequested(SfxCue.dodge));
    game.player.onDodgeSuccess();
    game.bus.emit(DodgeSucceeded(perfect: perfect));
    _registerHabit(dodge: true);
    _recentDodges++;
    proj?.deflect();
    _comboChainBroken = true; // parry zinciri kırıldı (bonus yok)

    if (beat.kind == BeatKind.feint) {
      game.bus.emit(
        PopupRequested(_topCenter, 'ALDATMA', fontSize: 14, color: kGray500),
      );
      return;
    }

    // Açılış YALNIZ committed/kırmızı/thrust beat'lerde: dodge bunların doğru
    // cevabı. Normal saldırının asıl ödül aracı YÖNLÜ PARRY'dir (posture +
    // karşı vuruş); dodge onları açmaz, yoksa parry'nin değeri düşer.
    final opens = beat.punishOnDodge || beat.defense == DefenseProfile.thrust;
    // Perfect dodge HER durumda slow-mo flourish verir (his ödülü).
    if (perfect) {
      game.bus.emit(const HitstopRequested(0.12));
      game.bus.emit(SparkRequested(_topCenter, _kAmber));
    }
    if (opens) {
      game.bus.emit(
        PopupRequested(
          _topCenter,
          perfect ? 'TAM SIYRILMA!' : 'AÇIK!',
          fontSize: perfect ? 16 : 15,
          color: perfect ? _kAmber : kGray700,
          rise: 28,
        ),
      );
      // Perfect dodge daha uzun punish penceresi açar.
      _enter(BossState.offBalance, perfect ? punishWindow * 1.4 : punishWindow);
    } else {
      // Normal saldırıyı sıyırdın: hasarsız kurtuluş (+perfect'te slow-mo) ama
      // boss komboya DEVAM eder. Açmak istiyorsan yönlü parry'le.
      game.bus.emit(
        PopupRequested(
          _topCenter,
          perfect ? 'TAM SIYRILMA' : 'SIYRILDIN',
          fontSize: perfect ? 14 : 13,
          color: perfect ? _kAmber : kGray500,
          rise: 24,
        ),
      );
    }
  }

  // YANLIŞ ARAÇ: guardBreak'e parry / tracking'e dodge → ceza, boss devam eder.
  void _wrongTool(Beat beat, Projectile? proj, String label) {
    proj?.deflect();
    final chip = (beat.damage * 0.35).round();
    game.player.getStunned(0.4, chip: chip);
    game.bus.emit(
      PopupRequested(
        Vector2(game.player.position.x, game.player.position.y - size.y * 0.8),
        label,
        fontSize: 14,
        color: kBarRed,
        rise: 30,
      ),
    );
    if (chip > 0) {
      game.bus.emit(
        PopupRequested(
          Vector2(
            game.player.position.x,
            game.player.position.y - size.y * 0.5,
          ),
          '-$chip',
          fontSize: 16,
        ),
      );
    }
    _comboChainBroken = true;
  }

  bool get isOpen =>
      !dying && (state == BossState.offBalance || state == BossState.staggered);

  // OYUNCU SALDIRISI temas etti (game.onPlayerAttackContact menzili doğrular).
  // staggered → F çoklu küçük HP, G infaz; offBalance → HP; kapalıysa posture chip.
  void receivePlayerAttack(
    PlayerAttackType type, {
    int comboStep = 0,
    bool finisher = false,
  }) {
    if (dying) return;
    // Faz geçişi sahnesi DOKUNULMAZ: oyuncu haksız hasar veremez (08).
    if (state == BossState.phaseTransition) {
      game.bus.emit(const SfxRequested(SfxCue.whiff));
      game.bus.emit(
        PopupRequested(_topCenter, 'DOKUNULMAZ', fontSize: 13, color: kGray500),
      );
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
        game.bus.emit(const SfxRequested(SfxCue.whiff));
        game.bus.emit(
          PopupRequested(_topCenter, 'ETKİ YOK', fontSize: 13, color: kGray500),
        );
        return;
      }
      takeDamage(hp);
      game.bus.emit(DamageApplied(hp, toBoss: true));
      game.bus.emit(const SfxRequested(SfxCue.hit));
      game.bus.emit(const HitstopRequested(0.06));
      _hurtT = 0.16;
      game.bus.emit(
        PopupRequested(_topCenter + Vector2(0, 30), '-$hp', fontSize: 18),
      );
    } else if (game.testAttackMode == TestAttackMode.defend) {
      game.bus.emit(const SfxRequested(SfxCue.whiff));
      game.bus.emit(
        PopupRequested(_topCenter, 'ETKİ YOK', fontSize: 13, color: kGray500),
      );
    } else if (state == BossState.staggered) {
      if (type == PlayerAttackType.heavy) {
        _performDeathblow(type, finisher: finisher);
      } else {
        _performStaggerLightHit();
      }
    } else if (state == BossState.offBalance) {
      final hp = ((attackHpOpen + (game.player.hasTempo ? 4 : 0)) * comboMult)
          .round();
      takeDamage(hp);
      game.bus.emit(DamageApplied(hp, toBoss: true));
      game.bus.emit(
        SfxRequested(
          type == PlayerAttackType.heavy ? SfxCue.heavyHit : SfxCue.hit,
        ),
      );
      game.bus.emit(
        HitstopRequested(type == PlayerAttackType.heavy ? 0.11 : 0.08),
      );
      if (type == PlayerAttackType.heavy) {
        game.bus.emit(ShakeRequested(4, 0.16));
      }
      game.bus.emit(ComboTextRequested(_topCenter, finisher ? 'FİNİSHER' : 'CEZA'));
      game.bus.emit(
        PopupRequested(_topCenter + Vector2(0, 30), '-$hp', fontSize: 20),
      );
      _decidePressure();
    } else {
      // Boss açık değil. GREED: oyuncu açık olmadığı halde saldırıyor. Boss bunu
      // okuyup (olasılıksal, fazla göre sıklaşan) hızlı bir karşı-beat başlatabilir
      // → F spam'i artık risksiz değil (09). Aksi halde yalnız riskli posture chip.
      if (_maybeGreedPunish()) return;
      applyPostureDamage(attackPostureChip);
      game.bus.emit(const SfxRequested(SfxCue.parry));
      game.bus.emit(SparkRequested(_topCenter, _kAmber));
      game.bus.emit(
        PopupRequested(
          _topCenter,
          '-$attackPostureChip DENGE',
          fontSize: 13,
          color: kBarBlue,
        ),
      );
    }
  }

  void _shieldLightBlock() {
    game.player.takePostureDamage(22);
    game.bus.emit(const SfxRequested(SfxCue.block));
    game.bus.emit(const HitstopRequested(0.06));
    game.bus.emit(SparkRequested(_topCenter, _kAmber));
    game.bus.emit(
      PopupRequested(_topCenter, 'KALKAN', fontSize: 15, color: _kAmber),
    );
    game.bus.emit(
      PopupRequested(
        Vector2(game.player.position.x, game.player.position.y - size.y * 0.72),
        'DENGE -22',
        fontSize: 13,
        color: kBarRed,
        rise: 24,
      ),
    );
  }

  // GREED PUNISH (09): boss açık değilken saldıran oyuncuya hızlı karşı-beat.
  // Parry'lenebilir (preWindow>0) → ceza adil: reflekssiz over-extend yer, usta
  // savunma kurtarır. Faz arttıkça olasılık ve hız artar.
  bool _maybeGreedPunish() {
    if (!game.actionSystem.bossGreedPunish || dying) return false;
    if (state == BossState.phaseTransition) return false;
    if (!_brain.greedPunishRoll(
      game.actionSystem.greedPunishChance,
      phase,
      _rng,
    )) {
      return false;
    }
    game.bus.emit(const MetricRecorded(MetricKind.greedPunished));
    game.bus.emit(ComboTextRequested(_topCenter, 'AÇGÖZLÜ!'));
    game.bus.emit(const SfxRequested(SfxCue.whiff));
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
    game.bus.emit(const MetricRecorded(MetricKind.guardBreakPunished));
    game.bus.emit(ComboTextRequested(_topCenter, 'SAVUNMA KIRIK!'));
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
    game.bus.emit(const SfxRequested(SfxCue.block));
    game.bus.emit(const HitstopRequested(0.09));
    game.bus.emit(SparkRequested(_topCenter, _kAmber));
    game.bus.emit(
      PopupRequested(_topCenter, 'AĞIR HATA!', fontSize: 16, color: _kAmber),
    );
    game.bus.emit(
      PopupRequested(
        Vector2(game.player.position.x, game.player.position.y - size.y * 0.72),
        'DENGE SIFIR',
        fontSize: 14,
        color: kBarRed,
        rise: 28,
      ),
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
  @override
  void render(Canvas canvas) => _view.render(canvas);

  String get phaseLabelTr => _view.phaseLabelTr;
}
