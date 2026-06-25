part of 'overlays.dart';

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
