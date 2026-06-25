part of 'overlays.dart';

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
