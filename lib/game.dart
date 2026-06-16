// ============================================================================
//  BOSS PARRY ARENA  —  oyun çekirdeği (combat/test arenası + dövüş döngüsü)
// ----------------------------------------------------------------------------
//  KONTROL:  SPACE = parry/savunma (oyun sırasında).
//
//  AKIŞ:  testSelect → playing → won/lost.
//  SOL dövüşçü = oyuncu (beyaz yuvarlatılmış kutu). SAĞ dövüşçü = seçilen BOSS.
//  Menü/UI yeşil/parşömen 'elements' görünümünde; DÖVÜŞ sahnesi orijinal
//  minimal siyah/beyaz görünümde kalır.
// ============================================================================

import 'dart:async';
import 'dart:io' show exit;
import 'dart:math';

import 'package:flame/components.dart' hide Timer;
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';

import 'action_system.dart';
import 'audio.dart';
import 'boss.dart';
import 'characters.dart';
import 'fx.dart';
import 'hud.dart';
import 'input_settings.dart';
import 'player.dart';
import 'test_action_system.dart';
import 'theme.dart';

enum GamePhase { testSelect, intro, playing, won, lost }

enum TestAttackMode { combo, attack1, attack2, attack3, defend }

enum PlayerAttackType { light, heavy }

// ============================================================================
//  OYUN
// ============================================================================
class BossArenaGame extends FlameGame with KeyboardEvents {
  late final Player player;
  Boss? boss; // test senaryosu seçilince (yeniden) kurulur

  // Açılışta doğrudan combat/test arenasıyla başlar.
  GamePhase phase = GamePhase.testSelect;
  ArenaActionSystem actionSystem = const TestActionSystem();
  TestAttackMode testAttackMode = TestAttackMode.attack1;
  CharacterDef? selectedChar;

  // Test arenası açık mı? (ölümsüzlük + sabit yakın mesafe + yerinde döngü)
  bool get testMode => actionSystem.isTest;

  void _setTestRealMatch(bool enabled) {
    actionSystem = TestActionSystem(realMatch: enabled);
  }

  Rect arenaRect = Rect.zero;
  Rect sidebarRect = Rect.zero;
  double groundY = 0;
  bool _ready = false;
  bool introPresentation = false;
  double combatantScale = 1.0;
  bool _combatIntroRunning = false;

  // Oyuncu saldırısının boss'a "değdiği" yatay menzil (px). Boss bundan uzaktaysa
  // saldırı ıskalar (whiff) — neutral'da bedava vuruşu engeller.
  static const double attackRange = 150;

  // Hitstop: temas anında oyunu kısa süre "donuk" hissettiren zaman ölçeği.
  double _hitstop = 0;

  // Geliştirici combat overlay'i (` / 0 tuşu ile aç-kapa).
  bool debug = false;
  final CombatMetrics metrics = CombatMetrics();
  final InputSettings controls = InputSettings();
  StreamSubscription<NormalizedGamepadEvent>? _gamepadSubscription;
  Timer? _gamepadRefreshTimer;
  final Set<String> _activeGamepadInputs = {};
  List<GamepadController> _listedGamepads = [];

  static const double _margin = 30;
  static const double _sidebarW = 312;
  static const double _gutter = 26;

  @override
  Color backgroundColor() => kWhite;

  @override
  Future<void> onLoad() async {
    await controls.loadSavedBindings();
    player = Player();
    addAll([ArenaBackground(), ArenaFrame(), player, Hud()]);
    _initGamepadInput();
    // Boss, test senaryosu seçilene kadar eklenmez.
    _ready = true;
    _layout(size);
  }

  @override
  void onRemove() {
    _gamepadRefreshTimer?.cancel();
    _gamepadSubscription?.cancel();
    for (final gamepad in _listedGamepads) {
      unawaited(gamepad.dispose());
    }
    super.onRemove();
  }

  void _initGamepadInput() {
    _gamepadSubscription = Gamepads.normalizedEvents.listen(_onGamepadEvent);
    unawaited(refreshGamepads());
    _gamepadRefreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(refreshGamepads()),
    );
  }

  Future<void> refreshGamepads() async {
    final gamepads = await Gamepads.list();
    final current = _listedGamepads
        .map((gamepad) => '${gamepad.id}:${gamepad.name}')
        .join('|');
    final incoming = gamepads
        .map((gamepad) => '${gamepad.id}:${gamepad.name}')
        .join('|');
    if (current == incoming) {
      for (final gamepad in gamepads) {
        unawaited(gamepad.dispose());
      }
      return;
    }

    for (final gamepad in _listedGamepads) {
      unawaited(gamepad.dispose());
    }
    _listedGamepads = gamepads;
    controls.setConnectedGamepads([
      for (final gamepad in gamepads)
        ConnectedGamepad(id: gamepad.id, name: gamepad.name),
    ]);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_ready) _layout(size);
  }

  void _layout(Vector2 s) {
    if (introPresentation) {
      const introMargin = 14.0;
      sidebarRect = Rect.zero;
      arenaRect = Rect.fromLTWH(
        introMargin,
        introMargin,
        s.x - introMargin * 2,
        s.y - introMargin * 2,
      );
    } else {
      final sideX = s.x - _margin - _sidebarW;
      sidebarRect = Rect.fromLTWH(sideX, _margin, _sidebarW, s.y - _margin * 2);
      final arenaW = (sideX - _gutter) - _margin;
      arenaRect = Rect.fromLTWH(_margin, _margin, arenaW, s.y - _margin * 2);
    }

    groundY = arenaRect.top + arenaRect.height * 0.74;
    final centerX = arenaRect.center.dx;
    player.place(Vector2(centerX - Boss.standGap / 2, groundY));
    boss?.place(_bossBasePos());
    boss?.scale = Vector2.all(combatantScale);
  }

  Vector2 _bossBasePos() {
    return actionSystem.bossBasePosition(
      arenaRect: arenaRect,
      playerPosition: player.position,
      groundY: groundY,
      standGap: Boss.standGap,
    );
  }

  CharacterDef _testDefFor(TestAttackMode attackMode) {
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
    };
    final label = switch (attackMode) {
      TestAttackMode.attack1 => 'ALT SALDIRI',
      TestAttackMode.attack2 => 'ÜST SALDIRI',
      TestAttackMode.attack3 => 'DEFEND SALDIRISI',
      TestAttackMode.combo => 'HİKAYE MODU',
      TestAttackMode.defend => 'KALKAN TESTİ',
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
    );
  }

  // TEST: Şövalye I preset'i seçilince doğrudan test arenasını başlat.
  void chooseTestAttack(TestAttackMode attackMode) {
    if (phase == GamePhase.testSelect && attackMode == TestAttackMode.combo) {
      startCombatScenarioIntro();
      return;
    }
    _chooseTestAttackNow(attackMode);
  }

  void _chooseTestAttackNow(TestAttackMode attackMode) {
    testAttackMode = attackMode;
    selectedChar = _testDefFor(attackMode);
    _setTestRealMatch(attackMode == TestAttackMode.combo);
    final old = boss;
    if (old != null) old.removeFromParent();
    final b = Boss(selectedChar!);
    boss = b;
    add(b);
    b.place(_bossBasePos());
    overlays.remove('testSelect');
    overlays.remove('testPanel');
    beginMatch();
    if (attackMode == TestAttackMode.defend ||
        attackMode == TestAttackMode.combo) {
      b.enterTestGuard();
    }
    overlays.add('testPanel');
  }

  void startCombatScenarioIntro() {
    if (_combatIntroRunning) return;
    _combatIntroRunning = true;
    testAttackMode = TestAttackMode.combo;
    selectedChar = _testDefFor(TestAttackMode.combo);
    _setTestRealMatch(true);
    final old = boss;
    if (old != null) old.removeFromParent();
    final b = Boss(selectedChar!);
    boss = b;
    add(b);
    phase = GamePhase.intro;
    setIntroPresentation(true);
    player.reset();
    b.reset();
    metrics.reset();
    _hitstop = 0;
    overlays.remove('testSelect');
    overlays.remove('testPanel');
    overlays.remove('won');
    overlays.remove('lost');
    overlays.add('combatIntro');
  }

  void setIntroPresentation(bool enabled) {
    introPresentation = enabled;
    combatantScale = enabled ? 1.35 : 1.0;
    _layout(size);
  }

  void prepareCombatIntroFinalReveal() {
    setIntroPresentation(false);
    player.reset();
    boss?.reset();
    metrics.reset();
    _hitstop = 0;
  }

  void completeCombatIntro() {
    _combatIntroRunning = false;
    overlays.remove('combatIntro');
    beginMatch();
    if (testAttackMode == TestAttackMode.combo) {
      boss?.enterTestGuard();
    }
    overlays.add('testPanel');
  }

  // TEST paneli: maçı yeniden başlatmadan can/denge/konum sıfırla.
  void resetTestMatch() {
    player.reset();
    boss?.reset();
    if (testAttackMode == TestAttackMode.defend ||
        testAttackMode == TestAttackMode.combo) {
      boss?.enterTestGuard();
    }
    metrics.reset();
    _hitstop = 0;
  }

  void changeTestAttack(TestAttackMode attackMode) {
    if (!testMode) return;
    chooseTestAttack(attackMode);
  }

  // TEST: combat seçim menüsüne dön.
  void backToModeSelect() {
    phase = GamePhase.testSelect;
    actionSystem = const TestActionSystem();
    testAttackMode = TestAttackMode.attack1;
    selectedChar = null;
    boss?.removeFromParent();
    boss = null;
    _combatIntroRunning = false;
    setIntroPresentation(false);
    player.reset();
    metrics.reset();
    _hitstop = 0;
    overlays.remove('won');
    overlays.remove('lost');
    overlays.remove('testPanel');
    overlays.add('testSelect');
  }

  // --- MAÇI BAŞLAT ---
  void beginMatch() {
    player.reset();
    boss?.reset();
    metrics.reset();
    _hitstop = 0;
    phase = GamePhase.playing;
    overlays.remove('won');
    overlays.remove('lost');
  }

  // --- YENİDEN: mevcut combat senaryosunu baştan kur ---
  void restart() {
    overlays.remove('won');
    overlays.remove('lost');
    chooseTestAttack(testAttackMode);
  }

  void closeApp() => exit(0);

  void openControlsOverlay() {
    overlays.add('controls');
  }

  void closeControlsOverlay() {
    overlays.remove('controls');
    controls.cancelCapture();
  }

  void toggleControlsOverlay() {
    if (overlays.isActive('controls')) {
      closeControlsOverlay();
    } else {
      openControlsOverlay();
    }
  }

  // --- OYUNCU SALDIRISI (tek tip, F) ---
  // Animasyon her zaman oynar (responsive); gerçek temas saldırının active
  // karesinde onPlayerAttackContact ile menzile göre çözülür.
  void tryPlayerAttack() {
    if (phase != GamePhase.playing) return;
    if (!player.attackReady) return;
    player.tryAttack(PlayerAttackType.light);
  }

  void tryPlayerHeavyAttack() {
    if (phase != GamePhase.playing) return;
    if (!testMode) return;
    if (!player.attackReady) return;
    player.tryAttack(PlayerAttackType.heavy);
  }

  // Saldırının active karesinde Player tarafından çağrılır. Boss menzildeyse
  // temas eder (posture/HP), uzaktaysa ıskalar.
  void onPlayerAttackContact(PlayerAttackType type) {
    if (phase != GamePhase.playing) return;
    final b = boss;
    if (b == null || b.dying) return;
    final dist = (b.position.x - player.position.x).abs();
    if (dist <= attackRange) {
      metrics.lightHits++;
      b.receivePlayerAttack(type);
    } else {
      metrics.attackWhiffs++;
      Sfx.whiff();
      spawnPopup(
        Vector2(player.position.x + 30, player.position.y - size.y * 0.6),
        'ISKA',
        fontSize: 13,
        color: kGray500,
        rise: 22,
      );
    }
  }

  void _onGamepadEvent(NormalizedGamepadEvent event) {
    if (!controls.hasGamepadId(event.gamepadId)) {
      unawaited(refreshGamepads());
    }

    for (final id in GamepadInputBinding.releasedIds(event)) {
      _activeGamepadInputs.remove(id);
    }

    final binding = GamepadInputBinding.fromEvent(event);
    if (binding == null) return;
    if (!_activeGamepadInputs.add(binding.id)) return;

    if (controls.captureGamepad(binding)) return;
    if (_handleGamepadMenuInput(binding)) return;
    final action = controls.actionForGamepad(binding);
    if (action != null) _handleInputAction(action);
  }

  bool _handleGamepadMenuInput(GamepadInputBinding binding) {
    if (!_menuNavigationActive || controls.gamepadCaptureAction != null) {
      return false;
    }

    final button = binding.button;
    if (button == GamepadButton.a) {
      _activateFocusedControl();
      return true;
    }
    if (button == GamepadButton.b && overlays.isActive('controls')) {
      closeControlsOverlay();
      return true;
    }

    final direction = _menuDirectionFor(binding);
    if (direction == null) return false;
    _moveMenuFocus(direction);
    return true;
  }

  bool get _menuNavigationActive {
    return overlays.isActive('controls') ||
        overlays.isActive('testSelect') ||
        overlays.isActive('won') ||
        overlays.isActive('lost');
  }

  TraversalDirection? _menuDirectionFor(GamepadInputBinding binding) {
    final button = binding.button;
    if (button != null) {
      return switch (button) {
        GamepadButton.dpadUp => TraversalDirection.up,
        GamepadButton.dpadDown => TraversalDirection.down,
        GamepadButton.dpadLeft => TraversalDirection.left,
        GamepadButton.dpadRight => TraversalDirection.right,
        _ => null,
      };
    }

    return switch (binding.axis) {
      GamepadAxis.leftStickY || GamepadAxis.rightStickY =>
        binding.direction > 0 ? TraversalDirection.up : TraversalDirection.down,
      GamepadAxis.leftStickX || GamepadAxis.rightStickX =>
        binding.direction > 0
            ? TraversalDirection.right
            : TraversalDirection.left,
      _ => null,
    };
  }

  void _moveMenuFocus(TraversalDirection direction) {
    ControllerFocusRegistry.instance.move(direction, scope: _menuFocusScope);
  }

  void _activateFocusedControl() {
    ControllerFocusRegistry.instance.activate(scope: _menuFocusScope);
  }

  String get _menuFocusScope {
    if (overlays.isActive('won') || overlays.isActive('lost')) return 'end';
    if (overlays.isActive('controls')) return 'controls';
    return 'testSelect';
  }

  void _handleInputAction(ArenaInputAction action) {
    if (action == ArenaInputAction.controls) {
      toggleControlsOverlay();
      return;
    }

    if (phase != GamePhase.playing || overlays.isActive('controls')) return;

    switch (action) {
      case ArenaInputAction.parry:
        if (boss?.tryParryFollowUp(GuardDirection.any) ?? false) return;
        metrics.parryAttempts++;
        player.tryParry();
      case ArenaInputAction.parryHigh:
        if (!actionSystem.upArrowParries) return;
        if (boss?.tryParryFollowUp(GuardDirection.high) ?? false) return;
        metrics.parryAttempts++;
        player.tryParry(GuardDirection.high);
      case ArenaInputAction.parryLow:
        if (!actionSystem.downArrowParries) return;
        if (boss?.tryParryFollowUp(GuardDirection.low) ?? false) return;
        metrics.parryAttempts++;
        player.tryParry(GuardDirection.low);
      case ArenaInputAction.dodge:
        metrics.dodgeAttempts++;
        player.tryDodge();
      case ArenaInputAction.attack:
        tryPlayerAttack();
      case ArenaInputAction.heavyAttack:
        tryPlayerHeavyAttack();
      case ArenaInputAction.controls:
        break;
    }
  }

  // --- HITSTOP & FX YARDIMCILARI ---
  void requestHitstop(double d) {
    if (d > _hitstop) _hitstop = d;
  }

  void spawnSpark(Vector2 pos, Color color) => add(Spark(pos, color));

  void spawnPostureBreak(Vector2 pos) => add(PostureBreakFx(pos));

  void spawnPopup(
    Vector2 pos,
    String text, {
    Color color = kBlack,
    double fontSize = 19,
    double rise = 34,
  }) {
    add(Popup(pos, text, color: color, fontSize: fontSize, rise: rise));
  }

  @override
  void update(double dt) {
    // Hitstop: temas anında kısa "donma". Zamanlayıcı GERÇEK dt ile azalır,
    // sahne ise ölçeklenmiş dt ile güncellenir (her şey yavaşlar).
    double sdt = dt;
    if (_hitstop > 0) {
      _hitstop = (_hitstop - dt).clamp(0, 999).toDouble();
      sdt = dt * 0.06;
    }
    super.update(sdt);

    if (phase == GamePhase.playing) metrics.fightDuration += dt;

    if (phase == GamePhase.playing && boss != null) {
      final b = boss!;
      if (player.health <= 0) {
        // takeHit zaten ölüm sekansını (saplanma → kılıç düşürme) başlattı;
        // ölüm animasyonu/sesi bitince yenilgi ekranı.
        if (player.deathDone) {
          phase = GamePhase.lost;
          overlays.remove('testPanel');
          overlays.remove('controls');
          overlays.add('lost');
        }
      } else if (b.health <= 0) {
        b.die(); // ölüm animasyonunu başlat (idempotent)
        if (b.deathDone) {
          phase = GamePhase.won;
          overlays.remove('testPanel');
          overlays.remove('controls');
          overlays.add('won');
        }
      }
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      if (controls.captureKeyboard(k)) return KeyEventResult.handled;

      // Debug overlay aç/kapa (her fazda).
      if (k == LogicalKeyboardKey.backquote || k == LogicalKeyboardKey.digit0) {
        debug = !debug;
        return KeyEventResult.handled;
      }

      final action = controls.actionForKeyboard(k);
      if (action != null) {
        _handleInputAction(action);
        return KeyEventResult.handled;
      }
      // Diğer fazlarda enter/space yok sayılır — seçim butonlarla yapılır.
    }
    return KeyEventResult.handled;
  }
}

// ============================================================================
//  COMBAT METRICS  —  tuning/debug için canlı sayaçlar (Faz 6)
// ----------------------------------------------------------------------------
//  Bir maçın hangi aksiyonla kazanıldığını/kaybedildiğini ve baskın stratejiyi
//  gözlemlemeye yarar. Debug overlay (` / 0) bunları gösterir.
// ============================================================================
class CombatMetrics {
  double fightDuration = 0;
  int playerDamageTaken = 0;
  int bossDamageTaken = 0;
  int bossPostureBreaks = 0;
  int parryAttempts = 0;
  int parrySuccesses = 0;
  int dodgeAttempts = 0;
  int dodgeSuccesses = 0;
  int attackWhiffs = 0;
  int lightHits = 0;
  int heavyHits = 0;

  void reset() {
    fightDuration = 0;
    playerDamageTaken = 0;
    bossDamageTaken = 0;
    bossPostureBreaks = 0;
    parryAttempts = 0;
    parrySuccesses = 0;
    dodgeAttempts = 0;
    dodgeSuccesses = 0;
    attackWhiffs = 0;
    lightHits = 0;
    heavyHits = 0;
  }
}

// ============================================================================
//  ARENA ARKA PLANI  —  m8 dağ manzarası (orijinalden birebir)
// ============================================================================
class ArenaBackground extends PositionComponent
    with HasGameReference<BossArenaGame> {
  ArenaBackground() : super(priority: -11); // çerçevenin de arkasında

  final List<Sprite> _layers = [];

  @override
  Future<void> onLoad() async {
    for (final f in const ['bg/m8_1.png', 'bg/m8_2.png', 'bg/m8_3.png']) {
      _layers.add(await Sprite.load(f));
    }
  }

  @override
  void render(Canvas canvas) {
    final r = game.arenaRect;
    if (r.isEmpty || _layers.isEmpty) return;

    final imgW = _layers.first.srcSize.x;
    final imgH = _layers.first.srcSize.y;
    // COVER: arenayı tamamen doldur (taşanı kırp), en-boy oranını koru.
    final scale = max(r.width / imgW, r.height / imgH);
    final dw = imgW * scale, dh = imgH * scale;
    final dx = r.left + (r.width - dw) / 2;
    final dy = r.top + (r.height - dh) / 2;

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)));
    for (final s in _layers) {
      s.render(canvas, position: Vector2(dx, dy), size: Vector2(dw, dh));
    }
    canvas.restore();
  }
}

// ============================================================================
//  ARENA ÇERÇEVESİ  —  orijinalden birebir
// ============================================================================
class ArenaFrame extends PositionComponent
    with HasGameReference<BossArenaGame> {
  ArenaFrame() : super(priority: -10);

  @override
  void render(Canvas canvas) {
    final r = game.arenaRect;
    if (r.isEmpty) return;

    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(4)),
      Paint()
        ..color = kBlack
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final corner = Paint()
      ..color = kBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    const double t = 22, p = 10;
    canvas.drawLine(
      Offset(r.left + p, r.top + p),
      Offset(r.left + p + t, r.top + p),
      corner,
    );
    canvas.drawLine(
      Offset(r.left + p, r.top + p),
      Offset(r.left + p, r.top + p + t),
      corner,
    );
    canvas.drawLine(
      Offset(r.right - p, r.top + p),
      Offset(r.right - p - t, r.top + p),
      corner,
    );
    canvas.drawLine(
      Offset(r.right - p, r.top + p),
      Offset(r.right - p, r.top + p + t),
      corner,
    );
    canvas.drawLine(
      Offset(r.left + p, r.bottom - p),
      Offset(r.left + p + t, r.bottom - p),
      corner,
    );
    canvas.drawLine(
      Offset(r.left + p, r.bottom - p),
      Offset(r.left + p, r.bottom - p - t),
      corner,
    );
    canvas.drawLine(
      Offset(r.right - p, r.bottom - p),
      Offset(r.right - p - t, r.bottom - p),
      corner,
    );
    canvas.drawLine(
      Offset(r.right - p, r.bottom - p),
      Offset(r.right - p, r.bottom - p - t),
      corner,
    );

    canvas.drawLine(
      Offset(r.left + 40, game.groundY),
      Offset(r.right - 40, game.groundY),
      Paint()
        ..color = kHair
        ..strokeWidth = 1.5,
    );
  }
}
