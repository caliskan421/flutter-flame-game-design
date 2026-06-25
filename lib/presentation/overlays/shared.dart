part of 'overlays.dart';

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
