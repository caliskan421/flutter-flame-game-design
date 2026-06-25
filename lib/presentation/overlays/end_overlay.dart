part of 'overlays.dart';

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

// ============================================================================
//  ENCOUNTER OVERLAY'LERİ (Faz G) — yalnız VERİ render eder, mantık tutmaz.
//  Her buton game'e KOMUT yollar; akışı EncounterRunner yürütür (§8.2, ilke).
// ============================================================================

/// Diyalog: node satırlarını sırayla gösterir; son satırda runner'a ilerler.
