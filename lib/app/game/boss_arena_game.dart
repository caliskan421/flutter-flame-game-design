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

import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';

import 'package:boss_parry_arena/combat/config/action_system.dart';
import 'package:boss_parry_arena/app/flow/encounter_runner.dart';
import 'package:boss_parry_arena/app/flow/test_scenarios.dart';
import 'package:boss_parry_arena/presentation/arena_view.dart';
import 'package:boss_parry_arena/presentation/audio.dart';
import 'package:boss_parry_arena/combat/sim/boss.dart';
import 'package:boss_parry_arena/combat/data/characters.dart';
import 'package:boss_parry_arena/combat/rules/combat_event.dart';
import 'package:boss_parry_arena/core/event_bus.dart';
import 'package:boss_parry_arena/core/rng.dart';
import 'package:boss_parry_arena/core/time_fx.dart';
import 'package:boss_parry_arena/domain/combat_metrics.dart';
import 'package:boss_parry_arena/domain/dice_service.dart';
import 'package:boss_parry_arena/domain/encounter.dart';
import 'package:boss_parry_arena/domain/game_session.dart';
import 'package:boss_parry_arena/combat/config/normal_action_system.dart';
import 'package:boss_parry_arena/presentation/fx.dart';
import 'package:boss_parry_arena/presentation/combat_presenter.dart';
import 'package:boss_parry_arena/presentation/hud.dart';
import 'package:boss_parry_arena/app/input/input_settings.dart';
import 'package:boss_parry_arena/combat/sim/player.dart';
import 'package:boss_parry_arena/combat/config/test_action_system.dart';
import 'package:boss_parry_arena/presentation/theme.dart';
import 'package:boss_parry_arena/combat/data/player_attack_type.dart';

enum GamePhase { testSelect, intro, playing, won, lost }

// ============================================================================
//  OYUN
// ============================================================================
class BossArenaGame extends FlameGame
    with KeyboardEvents
    implements EncounterHost {
  late final Player player;
  Boss? boss; // test senaryosu seçilince (yeniden) kurulur

  // Açılışta doğrudan combat/test arenasıyla başlar.
  GamePhase phase = GamePhase.testSelect;
  ArenaActionSystem actionSystem = const TestActionSystem();
  TestAttackMode testAttackMode = TestAttackMode.attack1;
  CharacterDef? selectedChar;
  bool get movementMechanicsMode => testAttackMode == TestAttackMode.movement;

  // Normal (ölümlü) maç akışının saf durumu — seçilen boss + sonuç (Faz E).
  // game.dart bunu OKUR/YAZAR; GameSession Flame'e dokunmayan saf domain'dir.
  final GameSession session = GameSession();

  // --- ENCOUNTER / RPG AKIŞI (Faz G) ----------------------------------------
  // Aktif encounter'ın akış otoritesi EncounterRunner'dır (D6 çözümü); game.dart
  // yalnız EncounterHost olarak komutları (overlay aç / combat başlat) uygular.
  // Encounter aktif değilken null → düz menü/normal-maç yolu aynen çalışır.
  final Rng scenarioRng = Rng();
  EncounterRunner? activeEncounter;
  bool get encounterActive => activeEncounter != null;

  // Aktif overlay verileri (overlay'ler bunları render eder, mantık tutmaz).
  DialogueNodeDef? activeDialogue;
  ChoiceDef? activeChoice;
  DiceCheckDef? activeDiceCheck;
  DiceResult? activeDiceResult;
  RewardStep? activeReward;

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

  // Zaman/FX durumu (hitstop + slow-mo + screen-shake). game.dart yalnız
  // delege eder; mantık core/time_fx.dart'ta (Faz A).
  final TimeFx timeFx = TimeFx();

  // Combat olay kanalı (Faz B): combat kararı buraya `CombatEvent` yayar,
  // `CombatPresenter` ses/popup/metrik/slow-mo'ya çevirir (D3/D4).
  final EventBus bus = EventBus();
  late final CombatPresenter _combatPresenter;

  // Geliştirici combat overlay'i (` / 0 tuşu ile aç-kapa).
  bool debug = false;
  final CombatMetrics metrics = CombatMetrics();
  final InputSettings controls = InputSettings();
  StreamSubscription<NormalizedGamepadEvent>? _gamepadSubscription;
  Timer? _gamepadRefreshTimer;
  final Set<String> _activeGamepadInputs = {};
  List<GamepadController> _listedGamepads = [];
  bool _moveLeftHeld = false;
  bool _moveRightHeld = false;
  bool _moveLeftRun = false;
  bool _moveRightRun = false;
  double _lastLeftTap = -999;
  double _lastRightTap = -999;
  double _inputClock = 0;

  static const double _margin = 30;
  static const double _sidebarW = 312;
  static const double _gutter = 26;
  static const double _movementDoubleTapWindow = 0.28;

  @override
  Color backgroundColor() => kWhite;

  @override
  Future<void> onLoad() async {
    await controls.loadSavedBindings();
    // Tüm combat sunumu tek noktadan (presenter) bus üzerinden beslenir.
    _combatPresenter = CombatPresenter(bus, this);
    player = Player();
    addAll([ArenaBackground(), ArenaFrame(), player, Hud()]);
    _initGamepadInput();
    // Boss, test senaryosu seçilene kadar eklenmez.
    _ready = true;
    _layout(size);
  }

  @override
  void onRemove() {
    _combatPresenter.dispose();
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
    if (movementMechanicsMode) {
      player.place(Vector2(centerX, groundY));
      player.setMovementBounds(arenaRect.deflate(64));
    }
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

  // TEST: Şövalye I preset'i seçilince doğrudan test arenasını başlat.
  void chooseTestAttack(TestAttackMode attackMode) {
    if (attackMode == TestAttackMode.movement) {
      startMovementMechanics();
      return;
    }
    if (phase == GamePhase.testSelect && attackMode == TestAttackMode.combo) {
      startCombatScenarioIntro();
      return;
    }
    _chooseTestAttackNow(attackMode);
  }

  void _chooseTestAttackNow(TestAttackMode attackMode) {
    testAttackMode = attackMode;
    selectedChar = testDefFor(attackMode);
    _setTestRealMatch(testAttackModeUsesScenarioRules(attackMode));
    player.setMovementTrainingEnabled(false);
    _clearMovementInput();
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

  void startMovementMechanics() {
    testAttackMode = TestAttackMode.movement;
    selectedChar = null;
    actionSystem = const TestActionSystem();
    boss?.removeFromParent();
    boss = null;
    _combatIntroRunning = false;
    setIntroPresentation(false);
    player.reset();
    player.place(Vector2(arenaRect.center.dx, groundY));
    player.setMovementBounds(arenaRect.deflate(64));
    player.setMovementTrainingEnabled(true);
    _clearMovementInput();
    metrics.reset();
    timeFx.reset();
    phase = GamePhase.playing;
    overlays.remove('testSelect');
    overlays.remove('won');
    overlays.remove('lost');
    overlays.add('testPanel');
  }

  void startCombatScenarioIntro() {
    if (_combatIntroRunning) return;
    _combatIntroRunning = true;
    testAttackMode = TestAttackMode.combo;
    selectedChar = testDefFor(TestAttackMode.combo);
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
    timeFx.reset();
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
    timeFx.reset();
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
    if (movementMechanicsMode) {
      player.place(Vector2(arenaRect.center.dx, groundY));
      player.setMovementBounds(arenaRect.deflate(64));
      player.setMovementTrainingEnabled(true);
      _clearMovementInput();
      metrics.reset();
      timeFx.reset();
      return;
    }
    boss?.reset();
    if (testAttackMode == TestAttackMode.defend ||
        testAttackMode == TestAttackMode.combo) {
      boss?.enterTestGuard();
    }
    metrics.reset();
    timeFx.reset();
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
    _endEncounter(); // aktif encounter'ı bırak + encounter overlay'lerini temizle
    player.setMovementTrainingEnabled(false);
    _clearMovementInput();
    boss?.removeFromParent();
    boss = null;
    _combatIntroRunning = false;
    setIntroPresentation(false);
    player.reset();
    metrics.reset();
    timeFx.reset();
    overlays.remove('won');
    overlays.remove('lost');
    overlays.remove('testPanel');
    overlays.remove('bossSelect');
    overlays.add('testSelect');
  }

  // ==========================================================================
  //  NORMAL (ölümlü) MAÇ AKIŞI — Faz E
  // --------------------------------------------------------------------------
  //  Test arenası (sandbox) AYNEN kalır; normal modun TEK girişi buradadır ve
  //  `actionSystem`'i set eden tek-yer kuralını korur (mod seçimi → set).
  // ==========================================================================

  // Mod seçimi: rakip (boss) seçim ekranını aç.
  void openBossSelect() {
    overlays.remove('testSelect');
    overlays.remove('testPanel');
    overlays.add('bossSelect');
  }

  // Boss seçim ekranından menüye (test/eğitim seçimi) dön.
  void closeBossSelect() {
    overlays.remove('bossSelect');
    overlays.add('testSelect');
  }

  // NORMAL MAÇ: seçilen boss'a karşı gerçek (ölümlü) dövüşü başlat.
  // NormalActionSystem zaten playerCanDie/bossCanDie=true, lockBossToBaseX=false
  // verir; sandbox bayrakları (ölümsüzlük/yerinde döngü) bu yolda KAPALIDIR.
  void startNormalMatch(CharacterDef bossDef) {
    session.selectBoss(bossDef.id);
    // Eski test durumunu temizle: movement modu sızmasın, sandbox flag'i kalksın.
    testAttackMode = TestAttackMode.attack1;
    selectedChar = bossDef;
    actionSystem = const NormalActionSystem();
    player.setMovementTrainingEnabled(false);
    _clearMovementInput();
    final old = boss;
    if (old != null) old.removeFromParent();
    final b = Boss(bossDef);
    boss = b;
    add(b);
    b.place(_bossBasePos());
    overlays.remove('testSelect');
    overlays.remove('bossSelect');
    overlays.remove('testPanel');
    beginMatch();
  }

  bool get normalMatchMode => !testMode && selectedChar != null;

  // --- MAÇI BAŞLAT ---
  void beginMatch() {
    player.reset();
    player.setMovementTrainingEnabled(false);
    _clearMovementInput();
    boss?.reset();
    metrics.reset();
    timeFx.reset();
    phase = GamePhase.playing;
    overlays.remove('won');
    overlays.remove('lost');
  }

  // --- YENİDEN: mevcut combat senaryosunu baştan kur ---
  void restart() {
    overlays.remove('won');
    overlays.remove('lost');
    // Encounter aktifse: maçı encounter bağlamında (aynı combat adımı) tekrar et.
    if (encounterActive) {
      activeEncounter!.retryCombat();
      return;
    }
    if (normalMatchMode) {
      startNormalMatch(selectedChar!); // aynı boss'a karşı yeniden
      return;
    }
    if (movementMechanicsMode) {
      startMovementMechanics();
      return;
    }
    chooseTestAttack(testAttackMode);
  }

  void closeApp() => exit(0);

  // ==========================================================================
  //  ENCOUNTER / RPG AKIŞI — Faz G
  // --------------------------------------------------------------------------
  //  game.dart EncounterHost'tur: EncounterRunner adımları yürütür, burada yalnız
  //  "ne göster / combat başlat" komutları uygulanır. Akış mantığı runner'da
  //  (D6 çözümü). Zar yalnız hikayeyi etkiler (combat math'ine dokunulmaz).
  // ==========================================================================

  /// Bir encounter'ı baştan başlat (menüden çağrılır).
  void startEncounter(EncounterDef def) {
    _clearEncounterOverlays();
    overlays.remove('testSelect');
    overlays.remove('testPanel');
    overlays.remove('bossSelect');
    overlays.remove('won');
    overlays.remove('lost');
    activeEncounter = EncounterRunner(
      def: def,
      state: session.scenario,
      rng: scenarioRng,
      host: this,
      // Kalıcılık (Faz H): runner her state değişiminde merkezi persist'i tetikler.
      onStateChanged: session.persist,
    );
    activeEncounter!.start();
  }

  void _endEncounter() {
    activeEncounter = null;
    _clearEncounterOverlays();
  }

  void _clearEncounterOverlays() {
    overlays.remove('dialogue');
    overlays.remove('choice');
    overlays.remove('dice');
    overlays.remove('reward');
    activeDialogue = null;
    activeChoice = null;
    activeDiceCheck = null;
    activeDiceResult = null;
    activeReward = null;
  }

  // --- EncounterHost komutları (runner → game) ---
  @override
  void showDialogue(DialogueNodeDef node) {
    activeDialogue = node;
    overlays.add('dialogue');
  }

  @override
  void showChoice(ChoiceDef choice) {
    activeChoice = choice;
    overlays.add('choice');
  }

  @override
  void showDiceCheck(DiceCheckDef check, DiceResult result) {
    activeDiceCheck = check;
    activeDiceResult = result;
    overlays.add('dice');
  }

  @override
  void startCombat(CombatStep step) => _startEncounterCombat(step);

  @override
  void showReward(RewardStep step) {
    activeReward = step;
    overlays.add('reward');
  }

  @override
  void onCombatLost(EncounterDef encounter) {
    // Standart yenilgi ekranı; YENİDEN → restart() encounter'ı retry eder.
    overlays.add('lost');
  }

  @override
  void onEncounterComplete(EncounterDef encounter) {
    // State mutasyonu (markCompleted) + kalıcılık runner'da yapıldı (tek otorite);
    // host yalnız akış/UI ile ilgilenir. İlk slice: placeholder → menüye dön.
    backToModeSelect();
  }

  // --- Overlay → runner geri çağrıları (overlay komut yollar, mantık tutmaz) ---
  // Null guard'lar: hızlı çift-tık ikinci kez ilerletmesin (payload bir kez
  // tüketilir; ikinci çağrı erken döner).
  void dialogueAdvance() {
    if (activeDialogue == null) return;
    activeDialogue = null;
    overlays.remove('dialogue');
    activeEncounter?.next();
  }

  void choicePick(int index) {
    if (activeChoice == null) return;
    activeChoice = null;
    overlays.remove('choice');
    activeEncounter?.choose(index);
  }

  void diceAdvance() {
    if (activeDiceResult == null) return;
    activeDiceCheck = null;
    activeDiceResult = null;
    overlays.remove('dice');
    activeEncounter?.next();
  }

  void rewardAdvance() {
    if (activeReward == null) return;
    activeReward = null;
    overlays.remove('reward');
    activeEncounter?.next();
  }

  // --- Encounter combat: Faz E maçını başlat + zar modifikatörünü uygula ---
  void _startEncounterCombat(CombatStep step) {
    final def = characterById(step.bossId);
    session.selectBoss(def.id);
    testAttackMode = TestAttackMode.attack1;
    selectedChar = def;
    // Hikaye→combat modifikatörü VERİDEN okunur (içerik adı game.dart'a gömülü
    // değil): step.slowOpeningFlag set'liyse boss ilk saldırısını geciktirir.
    final slow =
        step.slowOpeningFlag != null &&
        session.scenario.hasFlag(step.slowOpeningFlag!);
    actionSystem = NormalActionSystem(
      bossOpeningDelay: slow ? step.slowOpeningDelay : 0,
    );
    player.setMovementTrainingEnabled(false);
    _clearMovementInput();
    final old = boss;
    if (old != null) old.removeFromParent();
    final b = Boss(def);
    boss = b;
    add(b);
    b.place(_bossBasePos());
    _clearEncounterOverlays();
    overlays.remove('won');
    overlays.remove('lost');
    beginMatch();
  }

  // --- KALICILIK (Faz H): yeni oyun / sıfırla (onaylı) ---
  void openResetConfirm() => overlays.add('confirmReset');
  void closeResetConfirm() => overlays.remove('confirmReset');
  void confirmNewGame() {
    overlays.remove('confirmReset');
    session.resetProgress(); // disk temizliği async; menü anında güncellenir
  }

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

  // Ağır saldırı artık HER modda kullanılabilir; test kısıtı yerine stamina
  // sınırlar (player.tryAttack maliyeti kontrol eder). (05)
  void tryPlayerHeavyAttack() {
    if (phase != GamePhase.playing) return;
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
      if (type == PlayerAttackType.heavy) {
        metrics.heavyHits++;
      } else {
        metrics.lightHits++;
      }
      b.receivePlayerAttack(
        type,
        comboStep: player.comboStep,
        finisher: player.isFinisher,
      );
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
      if (_activeGamepadInputs.remove(id)) {
        final released = GamepadInputBinding.fromId(id);
        if (released != null) {
          final action = controls.actionForGamepad(released);
          if (action != null) _handleInputActionReleased(action);
        }
      }
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
      case ArenaInputAction.block:
        player.tryBlockStart();
      case ArenaInputAction.attack:
        tryPlayerAttack();
      case ArenaInputAction.heavyAttack:
        tryPlayerHeavyAttack();
      case ArenaInputAction.controls:
        break;
    }
  }

  // Tutulan aksiyonların (blok) bırakılması: keyup / gamepad release.
  void _handleInputActionReleased(ArenaInputAction action) {
    if (action == ArenaInputAction.block) player.tryBlockEnd();
  }

  bool _handleMovementKeyDown(LogicalKeyboardKey key) {
    if (!movementMechanicsMode ||
        phase != GamePhase.playing ||
        overlays.isActive('controls')) {
      return false;
    }
    if (key == LogicalKeyboardKey.keyZ) {
      _moveLeftRun = _inputClock - _lastLeftTap <= _movementDoubleTapWindow;
      _lastLeftTap = _inputClock;
      _moveLeftHeld = true;
      _applyMovementInput();
      return true;
    }
    if (key == LogicalKeyboardKey.keyX) {
      _moveRightRun = _inputClock - _lastRightTap <= _movementDoubleTapWindow;
      _lastRightTap = _inputClock;
      _moveRightHeld = true;
      _applyMovementInput();
      return true;
    }
    return false;
  }

  bool _handleMovementKeyUp(LogicalKeyboardKey key) {
    if (!movementMechanicsMode) return false;
    if (key == LogicalKeyboardKey.keyZ) {
      _moveLeftHeld = false;
      _moveLeftRun = false;
      _applyMovementInput();
      return true;
    }
    if (key == LogicalKeyboardKey.keyX) {
      _moveRightHeld = false;
      _moveRightRun = false;
      _applyMovementInput();
      return true;
    }
    return false;
  }

  void _applyMovementInput() {
    if (_moveLeftHeld && !_moveRightHeld) {
      player.setHorizontalMove(-1, running: _moveLeftRun);
    } else if (_moveRightHeld && !_moveLeftHeld) {
      player.setHorizontalMove(1, running: _moveRightRun);
    } else if (_moveLeftHeld && _moveRightHeld) {
      final leftNewer = _lastLeftTap >= _lastRightTap;
      player.setHorizontalMove(
        leftNewer ? -1 : 1,
        running: leftNewer ? _moveLeftRun : _moveRightRun,
      );
    } else {
      player.setHorizontalMove(0, running: false);
    }
  }

  void _clearMovementInput() {
    _moveLeftHeld = false;
    _moveRightHeld = false;
    _moveLeftRun = false;
    _moveRightRun = false;
    _lastLeftTap = -999;
    _lastRightTap = -999;
    player.setHorizontalMove(0, running: false);
  }

  // --- HITSTOP & FX YARDIMCILARI (timeFx'e delege) ---
  void requestHitstop(double d) => timeFx.requestHitstop(d);

  // Deathblow/faz sineması: hitstop'u bozmadan daha uzun, daha hafif yavaşlatma.
  void requestSlowmo(double duration, double scale) =>
      timeFx.requestSlowmo(duration, scale);

  // Hafif kamera sarsıntısı (genlik px, süre s). Daha güçlü istek öncekini ezer.
  // Genlik burada screenShakeScale ile ölçeklenir; eşik mantığı timeFx'te.
  void requestShake(double amplitude, double duration) =>
      timeFx.requestShake(amplitude * actionSystem.screenShakeScale, duration);

  void spawnSpark(Vector2 pos, Color color) => add(Spark(pos, color));

  void spawnPostureBreak(
    Vector2 pos, {
    Color color = kBarBlue,
    double scale = 1,
  }) => add(PostureBreakFx(pos, color: color, ringScale: scale));

  void spawnVignette({
    Color color = const Color(0xFFC0271E),
    double maxLife = 0.6,
    int peakAlpha = 92,
  }) =>
      add(RedVignetteFx(color: color, maxLife: maxLife, peakAlpha: peakAlpha));

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
    _inputClock += dt;
    // Zaman ölçeği: hitstop (kısa sert donma) önceliklidir; yoksa slow-mo
    // (deathblow/faz, daha uzun/hafif). İkisi de gerçek dt ile azalır, sahne
    // ölçeklenmiş dt ile güncellenir. Shake zamanlayıcısı da gerçek dt ile akar.
    final scale = timeFx.update(dt);
    super.update(dt * scale);

    if (phase == GamePhase.playing) metrics.fightDuration += dt;

    if (phase == GamePhase.playing && boss != null) {
      final b = boss!;
      // Eşikler HARD-CODE değil: hangi modda kimin ölebildiği ve min can
      // actionSystem getter'larından okunur. Test sandbox'ta playerCanDie/
      // bossCanDie=false olduğundan hiçbir dal tetiklenmez (ölümsüzlük korunur);
      // normal modda (NormalActionSystem) HP minHealth'e inince sonuç gelir.
      final playerDead =
          actionSystem.playerCanDie &&
          player.health <= actionSystem.minPlayerHealth;
      final bossDead =
          actionSystem.bossCanDie && b.health <= actionSystem.minBossHealth;
      if (playerDead) {
        // takeHit zaten ölüm sekansını (saplanma → kılıç düşürme) başlattı;
        // ölüm animasyonu/sesi bitince yenilgi ekranı.
        if (player.deathDone) {
          phase = GamePhase.lost;
          // Encounter combat sonucunu normal-maç geçmişine yazma (kirlenmesin);
          // encounter kendi sonucunu flag'lerle taşır.
          if (normalMatchMode && !encounterActive) {
            session.recordResult(MatchResult.lost);
          }
          overlays.remove('testPanel');
          overlays.remove('controls');
          // Encounter aktifse sonucu runner'a bildir (retry/menü kararı orada);
          // değilse standart yenilgi ekranı.
          if (encounterActive) {
            activeEncounter!.onCombatResult(false);
          } else {
            overlays.add('lost');
          }
        }
      } else if (bossDead) {
        b.die(); // ölüm animasyonunu başlat (idempotent)
        if (b.deathDone) {
          phase = GamePhase.won;
          if (normalMatchMode && !encounterActive) {
            session.recordResult(MatchResult.won);
          }
          // BossDefeated event'i (Faz B'de rezerve, şimdi yayılıyor): akışı/
          // metrikleri besler. CombatPresenter no-op; encounter runner sonucu okur.
          bus.emit(BossDefeated(b.def.id));
          overlays.remove('testPanel');
          overlays.remove('controls');
          if (encounterActive) {
            activeEncounter!.onCombatResult(true); // → ödül adımı
          } else {
            overlays.add('won');
          }
        }
      }
    }
  }

  // Tüm sahneyi (arena + HUD) screen-shake offset'i kadar kaydır. Sıfır
  // sarsıntıda ekstra save/restore maliyeti yoktur (11).
  @override
  void render(Canvas canvas) {
    final off = timeFx.shakeOffset();
    if (off == Offset.zero) {
      super.render(canvas);
      return;
    }
    canvas.save();
    canvas.translate(off.dx, off.dy);
    super.render(canvas);
    canvas.restore();
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      if (controls.captureKeyboard(k)) return KeyEventResult.handled;
      if (_handleMovementKeyDown(k)) return KeyEventResult.handled;

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
    } else if (event is KeyUpEvent) {
      if (_handleMovementKeyUp(event.logicalKey)) {
        return KeyEventResult.handled;
      }
      final action = controls.actionForKeyboard(event.logicalKey);
      if (action != null) {
        _handleInputActionReleased(action);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.handled;
  }
}
