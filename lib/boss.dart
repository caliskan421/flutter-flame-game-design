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

// Faz F: Boss god-object'i davranış-koruyan biçimde aynı kütüphanede bölündü.
// Bu part'lar Boss üzerinde `extension` tanımlar (alanlar/statikler burada kalır):
//   * boss_state_machine — durum makinesi + kombo akışı (F5)
//   * deathblow_controller — infaz + faz geçişi (F4)
//   * boss_combat — temas/çözüm handler'ları (F3; saf karar combat_resolver'da)
part 'combat/sim/boss_state_machine.dart';
part 'combat/sim/deathblow_controller.dart';
part 'combat/sim/boss_combat.dart';

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
    // Encounter hikaye modifikatörü (Faz G): sessiz yaklaşma → boss ilk saldırıya
    // daha geç girer. Varsayılan 0 → normal maç/sandbox değişmez.
    _enter(BossState.idle, idleTime + game.actionSystem.bossOpeningDelay);
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
    // bossOpeningDelay'i burada da uygula: Flame mount sırası reset'ten SONRA
    // çalışırsa encounter açılış gecikmesi ezilmesin (varsayılan 0 → değişmez).
    _enter(BossState.idle, idleTime + game.actionSystem.bossOpeningDelay);
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


  void _registerHabit({
    bool parry = false,
    bool dodge = false,
    bool attack = false,
  }) =>
      _brain.registerHabit(parry: parry, dodge: dodge, attack: attack);



  void _clearPending() {
    _pending = false;
    _pendingGrace = 0;
    _pendingBeat = null;
    _pendingProjectile = null;
  }

  bool get isOpen =>
      !dying && (state == BossState.offBalance || state == BossState.staggered);
  @override
  void render(Canvas canvas) => _view.render(canvas);

  String get phaseLabelTr => _view.phaseLabelTr;
}
