// ============================================================================
//  OVERLAY'LER  —  elements yeşil/parşömen görünümünde Flutter widget'ları
// ----------------------------------------------------------------------------
//  AKIŞ:  testSelect → (playing) → won/lost.
//  Menü kromu theme.dart'taki PixelButton/PixelFrame/PixelPortrait ile çizilir.
//  _Scrim arka planı bulanıklaştırır (BackdropFilter blur).
//  Tüm metin Türkçe.
// ============================================================================

import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'audio.dart';
import 'characters.dart';
import 'content/intro_sequence.dart';
import 'game.dart';
import 'input_settings.dart';
import 'theme.dart';

// ============================================================================
//  SCRIM  —  arkayı bulanıklaştırıp hafif yarı saydam dolgu (orijinalden)
// ============================================================================
class _Scrim extends StatelessWidget {
  final Widget child;
  const _Scrim({required this.child});

  @override
  Widget build(BuildContext context) {
    // Material (saydam) → metinlere düzgün DefaultTextStyle sağlar; aksi halde
    // Flutter, varsayılan sarı çift alt çizgiyi (debug) çizer.
    return Material(
      type: MaterialType.transparency,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
        child: Container(
          color: kUiWoodDark.withAlpha(110),
          alignment: Alignment.center,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
//  Küçük ortak metin parçaları (parşömen üstü)
// ----------------------------------------------------------------------------
class _Kicker extends StatelessWidget {
  final String text;
  const _Kicker(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: kUiGreenDark,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 5,
    ),
  );
}

class _Title extends StatelessWidget {
  final String text;
  final double size;
  const _Title(this.text, {this.size = 34});
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: kTextDark,
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: 3,
    ),
  );
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: kTextDark, fontSize: 13, height: 1.35),
  );
}

// ============================================================================
//  TEST SEÇ  —  Şövalye I için kombo / tek saldırı preset'i
// ============================================================================
class TestSelectOverlay extends StatelessWidget {
  final BossArenaGame game;
  const TestSelectOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final def = kTestOpponent;
    final idleFrames = def.sheets['idle']?.frames ?? 1;

    return _Scrim(
      child: PixelFrame(
        width: 620,
        padding: const EdgeInsets.fromLTRB(34, 30, 34, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Kicker('TEST ARENASI'),
            const SizedBox(height: 8),
            const _Title('ŞÖVALYE I'),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelPortrait(
                  asset: 'assets/images/chars/${def.id}/idle.png',
                  frameCount: idleFrames,
                  size: 92,
                ),
                const SizedBox(width: 18),
                const Expanded(
                  child: _Body(
                    'Samuray ve Şövalye I yakın mesafede kalır. Tekli saldırılar tekrar eder; ALT/ÜST/DEF ve HİKAYE gerçek senaryo kurallarını kullanır. Hareket mekanikleri samurayın serbest yatay hareket alanıdır.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _TestAttackGrid(game: game),
            const SizedBox(height: 12),
            PixelButton(
              label: 'KONTROLLER',
              primary: false,
              controllerFocusScope: 'testSelect',
              onTap: game.openControlsOverlay,
            ),
          ],
        ),
      ),
    );
  }
}

class _TestAttackGrid extends StatelessWidget {
  final BossArenaGame game;
  const _TestAttackGrid({required this.game});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _attackButton('TEK ALT', TestAttackMode.attack1),
        _attackButton('TEK ÜST', TestAttackMode.attack2),
        _attackButton('DEFEND 3', TestAttackMode.attack3),
        _attackButton('KALKAN', TestAttackMode.defend),
        _attackButton('HİKAYE MODU', TestAttackMode.combo),
        _attackButton('HAREKET MEKANİKLERİ', TestAttackMode.movement),
      ],
    );
  }

  Widget _attackButton(String label, TestAttackMode mode) {
    return PixelButton(
      label: label,
      selected: game.testAttackMode == mode,
      primary: true,
      controllerFocusScope: 'testSelect',
      onTap: () => game.chooseTestAttack(mode),
    );
  }
}

// ============================================================================
//  TEST PANELİ  —  oynarken preset değiştir / sıfırla / menüye dön
// ============================================================================
class TestPanelOverlay extends StatelessWidget {
  final BossArenaGame game;
  const TestPanelOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Material(
            type: MaterialType.transparency,
            child: PixelFrame(
              width: 356,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Kicker('TEST'),
                  const SizedBox(height: 7),
                  Text(
                    _testModeLabel(game.testAttackMode),
                    style: const TextStyle(
                      color: kTextDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (game.movementMechanicsMode)
                    const _MovementMechanicsHelp()
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _smallAttackButton('ALT', TestAttackMode.attack1),
                        _smallAttackButton('ÜST', TestAttackMode.attack2),
                        _smallAttackButton('DEF', TestAttackMode.attack3),
                        _smallAttackButton('KALKAN', TestAttackMode.defend),
                        _smallAttackButton('HİKAYE', TestAttackMode.combo),
                        _smallAttackButton('HAREKET', TestAttackMode.movement),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: PixelButton(
                          label: 'SIFIRLA',
                          onTap: game.resetTestMatch,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PixelButton(
                          label: 'MENÜ',
                          primary: false,
                          onTap: game.backToModeSelect,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  PixelButton(
                    label: 'KONTROLLER',
                    primary: false,
                    width: double.infinity,
                    onTap: game.openControlsOverlay,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallAttackButton(String label, TestAttackMode mode) {
    return PixelButton(
      label: label,
      selected: game.testAttackMode == mode,
      primary: true,
      onTap: () => game.changeTestAttack(mode),
    );
  }

  String _testModeLabel(TestAttackMode mode) {
    return switch (mode) {
      TestAttackMode.attack1 => 'ALT SALDIRI',
      TestAttackMode.attack2 => 'ÜST SALDIRI',
      TestAttackMode.attack3 => 'DEFEND SALDIRISI',
      TestAttackMode.defend => 'KALKAN TESTİ',
      TestAttackMode.combo => 'HİKAYE MODU',
      TestAttackMode.movement => 'HAREKET MEKANİKLERİ',
    };
  }
}

class _MovementMechanicsHelp extends StatelessWidget {
  const _MovementMechanicsHelp();

  @override
  Widget build(BuildContext context) {
    return const _Body(
      'Z sola, X sağa yürütür. Aynı tuşa hızlı çift basınca samuray koşuya geçer ve gittiği yöne döner.',
    );
  }
}

// ============================================================================
//  COMBAT GİRİŞ SUNUMU  —  siyah perde + portre/diyalog zaman çizelgesi
// ============================================================================
class CombatIntroOverlay extends StatefulWidget {
  final BossArenaGame game;
  const CombatIntroOverlay(this.game, {super.key});

  @override
  State<CombatIntroOverlay> createState() => _CombatIntroOverlayState();
}

class _CombatIntroOverlayState extends State<CombatIntroOverlay>
    with TickerProviderStateMixin {
  // Cue/müzik verisi content/intro_sequence.dart'ta (Faz A); overlay yalnız
  // render eder.
  static const IntroSequenceDef _sequence = kCombatIntroSequence;

  double _blackOpacity = 0;
  bool _curtainActive = false;
  double _curtainOpen = 1;
  DialogueCueDef? _current;
  DialogueCueDef? _previous;
  double _currentOpacity = 0;
  double _previousOpacity = 0;
  double _progressOpacity = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(_run);
  }

  Future<void> _run() async {
    await Sfx.startBackgroundMusic(file: _sequence.openingMusic);
    await _animate(
      const Duration(seconds: 2),
      (t) => _blackOpacity = t,
      curve: Curves.easeInOutCubic,
    );
    await _pause(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _blackOpacity = 0;
      _curtainActive = true;
      _curtainOpen = 0;
    });
    await _animate(
      const Duration(seconds: 2),
      (t) => _curtainOpen = t,
      curve: Curves.easeInOutCubic,
    );
    if (!mounted) return;
    setState(() => _curtainActive = false);

    for (final cue in _sequence.cues) {
      await _showCue(cue);
      await Sfx.duckBackgroundMusic();
      await Sfx.playIntroDialogue(cue.audio);
      await Sfx.restoreBackgroundMusic();
      if (!mounted) return;
    }

    setState(() {
      _previous = _current;
      _previousOpacity = _current == null ? 0 : 1;
      _current = null;
      _currentOpacity = 0;
    });
    await Future.wait([
      _animate(const Duration(seconds: 2), (t) {
        _blackOpacity = t;
        _previousOpacity = 1 - t;
      }, curve: Curves.easeInOutCubic),
      Sfx.stopBackgroundMusic(fadeDuration: const Duration(seconds: 2)),
    ]);
    if (!mounted) return;
    setState(() {
      _previous = null;
      _previousOpacity = 0;
      _progressOpacity = 1;
    });
    await Sfx.startBackgroundMusic(file: _sequence.closingMusic, volume: 0.34);
    await _pause(const Duration(milliseconds: 1600));
    await _animate(
      const Duration(milliseconds: 400),
      (t) => _progressOpacity = 1 - t,
      curve: Curves.easeOut,
    );
    if (!mounted) return;
    widget.game.prepareCombatIntroFinalReveal();
    setState(() {
      _blackOpacity = 0;
      _curtainActive = true;
      _curtainOpen = 0;
      _progressOpacity = 0;
    });
    await _animate(
      const Duration(seconds: 2),
      (t) => _curtainOpen = t,
      curve: Curves.easeInOutCubic,
    );
    if (!mounted) return;
    widget.game.completeCombatIntro();
  }

  Future<void> _showCue(DialogueCueDef cue) async {
    if (!mounted) return;
    setState(() {
      _previous = _current;
      _previousOpacity = _current == null ? 0 : 1;
      _current = cue;
      _currentOpacity = 0;
    });
    await _animate(const Duration(seconds: 1), (t) {
      _currentOpacity = t;
      _previousOpacity = 1 - t;
    }, curve: Curves.easeOutCubic);
    if (!mounted) return;
    setState(() {
      _previous = null;
      _previousOpacity = 0;
      _currentOpacity = 1;
    });
  }

  Future<void> _animate(
    Duration duration,
    void Function(double t) apply, {
    Curve curve = Curves.linear,
  }) async {
    final controller = AnimationController(vsync: this, duration: duration);
    void tick() {
      if (!mounted) return;
      setState(() => apply(curve.transform(controller.value)));
    }

    controller.addListener(tick);
    tick();
    try {
      await controller.forward().orCancel;
    } catch (_) {
      // Widget söküldüğünde zaman çizelgesi sessizce biter.
    } finally {
      controller.dispose();
    }
  }

  Future<void> _pause(Duration duration) async {
    await Future.delayed(duration);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_previous != null)
            _IntroPortrait(cue: _previous!, opacity: _previousOpacity),
          if (_current != null)
            _IntroPortrait(cue: _current!, opacity: _currentOpacity),
          if (_blackOpacity > 0)
            IgnorePointer(
              child: ColoredBox(
                color: Colors.black.withValues(
                  alpha: _blackOpacity.clamp(0, 1).toDouble(),
                ),
              ),
            ),
          if (_curtainActive)
            IgnorePointer(
              child: CustomPaint(
                painter: _CurtainPainter(_curtainOpen.clamp(0, 1).toDouble()),
              ),
            ),
          if (_progressOpacity > 0)
            IgnorePointer(
              child: Opacity(
                opacity: _progressOpacity.clamp(0, 1),
                child: const Center(
                  child: SizedBox.square(
                    dimension: 54,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IntroPortrait extends StatelessWidget {
  final DialogueCueDef cue;
  final double opacity;

  const _IntroPortrait({required this.cue, required this.opacity});

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final sideInset = max(24.0, screen.width * 0.045);
    final bottomInset = max(18.0, screen.height * 0.035);
    final rawSize = min(screen.width * 0.34, screen.height * 0.68);
    final portraitSize = rawSize.clamp(280.0, 560.0).toDouble();

    return Positioned(
      left: cue.side == IntroSide.left ? sideInset : null,
      right: cue.side == IntroSide.right ? sideInset : null,
      bottom: bottomInset,
      width: portraitSize,
      height: portraitSize,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0, 1),
          child: Image.asset(
            'giriş senaryo/${cue.image}',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          ),
        ),
      ),
    );
  }
}

class _CurtainPainter extends CustomPainter {
  final double open;
  const _CurtainPainter(this.open);

  @override
  void paint(Canvas canvas, Size size) {
    final halfClosedHeight = size.height * 0.5 * (1 - open);
    final paint = Paint()..color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, halfClosedHeight), paint);
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        size.height - halfClosedHeight,
        size.width,
        halfClosedHeight,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CurtainPainter oldDelegate) {
    return oldDelegate.open != open;
  }
}

// ============================================================================
//  KONTROLLER  —  klavye + gamepad yeniden atama paneli
// ============================================================================
class ControlsOverlay extends StatelessWidget {
  final BossArenaGame game;
  const ControlsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = min(screen.width - 28, 780.0);

    return _Scrim(
      child: AnimatedBuilder(
        animation: game.controls,
        builder: (context, _) {
          final controls = game.controls;
          return PixelFrame(
            width: width,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Kicker('AYARLAR'),
                const SizedBox(height: 8),
                const _Title('KONTROLLER', size: 30),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 680;
                    final keyboard = _BindingColumn(
                      title: 'KLAVYE',
                      children: [
                        for (final action in InputSettings.actions)
                          _KeyboardBindingRow(
                            controls: controls,
                            action: action,
                          ),
                      ],
                    );
                    final gamepad = _BindingColumn(
                      title: controls.hasGamepad
                          ? controls.gamepads.first.name.toUpperCase()
                          : 'CONTROLLER',
                      children: controls.hasGamepad
                          ? [
                              for (final action in InputSettings.actions)
                                _GamepadBindingRow(
                                  controls: controls,
                                  action: action,
                                ),
                            ]
                          : [
                              const _StatusLine('CONTROLLER BAĞLI DEĞİL'),
                              const SizedBox(height: 10),
                              PixelButton(
                                label: 'YENİLE',
                                primary: false,
                                controllerFocusScope: 'controls',
                                onTap: () => unawaited(game.refreshGamepads()),
                              ),
                            ],
                    );

                    if (narrow) {
                      return Column(
                        children: [
                          keyboard,
                          const SizedBox(height: 14),
                          gamepad,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: keyboard),
                        const SizedBox(width: 14),
                        Expanded(child: gamepad),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    PixelButton(
                      label: 'VARSAYILAN',
                      primary: false,
                      controllerFocusScope: 'controls',
                      onTap: controls.restoreDefaults,
                    ),
                    PixelButton(
                      label: 'KAPAT',
                      controllerFocusScope: 'controls',
                      onTap: game.closeControlsOverlay,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BindingColumn extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _BindingColumn({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kUiParchEdge.withAlpha(80),
        border: Border.all(color: kUiWood, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kTextDark,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _KeyboardBindingRow extends StatelessWidget {
  final InputSettings controls;
  final ArenaInputAction action;

  const _KeyboardBindingRow({required this.controls, required this.action});

  @override
  Widget build(BuildContext context) {
    final capturing = controls.keyboardCaptureAction == action;
    final label = capturing
        ? 'TUŞA BAS'
        : keyboardKeyLabel(controls.keyboardBindingFor(action));
    return _BindingRow(
      action: action,
      bindingLabel: label,
      capturing: capturing,
      controllerFocusable: false,
      onTap: () => controls.startKeyboardCapture(action),
    );
  }
}

class _GamepadBindingRow extends StatelessWidget {
  final InputSettings controls;
  final ArenaInputAction action;

  const _GamepadBindingRow({required this.controls, required this.action});

  @override
  Widget build(BuildContext context) {
    final capturing = controls.gamepadCaptureAction == action;
    final label = capturing
        ? 'TUŞA BAS'
        : controls.gamepadBindingFor(action).label;
    return _BindingRow(
      action: action,
      bindingLabel: label,
      capturing: capturing,
      onTap: () => controls.startGamepadCapture(action),
    );
  }
}

class _BindingRow extends StatefulWidget {
  final ArenaInputAction action;
  final String bindingLabel;
  final bool capturing;
  final bool controllerFocusable;
  final VoidCallback onTap;

  const _BindingRow({
    required this.action,
    required this.bindingLabel,
    required this.capturing,
    this.controllerFocusable = true,
    required this.onTap,
  });

  @override
  State<_BindingRow> createState() => _BindingRowState();
}

class _BindingRowState extends State<_BindingRow> {
  late final FocusNode _focusNode = FocusNode(debugLabel: widget.action.label);
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    if (widget.controllerFocusable) {
      ControllerFocusRegistry.instance.register(
        _focusNode,
        widget.onTap,
        scope: 'controls',
      );
    }
  }

  @override
  void didUpdateWidget(covariant _BindingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controllerFocusable) {
      ControllerFocusRegistry.instance.register(
        _focusNode,
        widget.onTap,
        scope: 'controls',
      );
    } else {
      ControllerFocusRegistry.instance.unregister(_focusNode);
    }
  }

  @override
  void dispose() {
    ControllerFocusRegistry.instance.unregister(_focusNode);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kTextDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onTap,
              child: Container(
                width: 132,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.capturing ? kUiGreen : kUiParchment,
                  border: Border.all(
                    color: widget.capturing || _focused ? kBarBlue : kUiWood,
                    width: 2,
                  ),
                  boxShadow: _focused
                      ? const [
                          BoxShadow(
                            color: kBarBlue,
                            blurRadius: 0,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  widget.bindingLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.capturing ? kTextLight : kTextDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final String text;
  const _StatusLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: kUiWoodDark,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
  }
}

// ============================================================================
//  SONUÇ  —  KAZANDIN / YENİLDİN
// ============================================================================
class EndOverlay extends StatefulWidget {
  final BossArenaGame game;
  final bool won;
  const EndOverlay(this.game, {required this.won, super.key});

  @override
  State<EndOverlay> createState() => _EndOverlayState();
}

class _EndOverlayState extends State<EndOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ControllerFocusRegistry.instance.focusFirst(scope: 'end');
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Scrim(
      child: PixelFrame(
        width: 460,
        padding: const EdgeInsets.fromLTRB(34, 30, 34, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Kicker('SONUÇ'),
            const SizedBox(height: 8),
            if (widget.won)
              Text(
                '★ ★ ★',
                style: TextStyle(
                  color: kBarGreen,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
            if (widget.won) const SizedBox(height: 8),
            _Title(widget.won ? 'KAZANDIN' : 'YENİLDİN', size: 38),
            const SizedBox(height: 12),
            _Body(
              widget.won
                  ? 'Rakibi devirdin. Tekrar denemek ister misin?'
                  : 'Canın bitti. Tekrar denemek ister misin?',
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                PixelButton(
                  label: 'YENİDEN',
                  controllerFocusScope: 'end',
                  onTap: widget.game.restart,
                ),
                PixelButton(
                  label: 'MENÜ',
                  primary: false,
                  controllerFocusScope: 'end',
                  onTap: widget.game.backToModeSelect,
                ),
                PixelButton(
                  label: 'KAPAT',
                  primary: false,
                  controllerFocusScope: 'end',
                  onTap: widget.game.closeApp,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
