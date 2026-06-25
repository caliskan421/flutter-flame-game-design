part of 'overlays.dart';

class BossSelectOverlay extends StatelessWidget {
  final BossArenaGame game;
  const BossSelectOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return _Scrim(
      child: PixelFrame(
        width: 620,
        padding: const EdgeInsets.fromLTRB(34, 30, 34, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Kicker('MAÇ'),
            const SizedBox(height: 8),
            const _Title('RAKİBİNİ SEÇ'),
            const SizedBox(height: 6),
            const _Body(
              'Gerçek maç: ikiniz de ölebilirsiniz. Canı biten kaybeder.',
            ),
            const SizedBox(height: 18),
            for (final def in kOpponents) ...[
              _BossCard(game: game, def: def),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 2),
            PixelButton(
              label: 'GERİ',
              primary: false,
              controllerFocusScope: 'bossSelect',
              onTap: game.closeBossSelect,
            ),
          ],
        ),
      ),
    );
  }
}

class _BossCard extends StatelessWidget {
  final BossArenaGame game;
  final CharacterDef def;
  const _BossCard({required this.game, required this.def});

  @override
  Widget build(BuildContext context) {
    final idleFrames = def.sheets['idle']?.frames ?? 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PixelPortrait(
          asset: 'assets/images/chars/${def.id}/idle.png',
          frameCount: idleFrames,
          size: 72,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Title(def.name.toUpperCase(), size: 22),
              if (def.title.isNotEmpty) ...[
                const SizedBox(height: 2),
                _Body(def.title),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        PixelButton(
          label: 'DÖVÜŞ',
          primary: true,
          controllerFocusScope: 'bossSelect',
          onTap: () => game.startNormalMatch(def),
        ),
      ],
    );
  }
}
