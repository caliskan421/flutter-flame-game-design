part of 'overlays.dart';

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
            const SizedBox(height: 16),
            // Macera + kalıcı ilerleme (Faz G/H). Kayıt varsa "Devam et" +
            // "Yeni oyun (sıfırla)"; ilerleme satırı kalıcılığı görünür kılar.
            if (game.session.hasProgress) ...[
              Text(
                'İlerleme — Onur: ${game.session.scenario.resource('honor')}'
                '${game.session.scenario.isCompleted('ash_gate') ? '   ·   Kül Kapısı ✓' : ''}',
                style: const TextStyle(
                  color: kUiGreenDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
            ],
            PixelButton(
              label: game.session.hasProgress
                  ? 'DEVAM ET'
                  : 'MACERA: KÜL KAPISI',
              primary: true,
              width: double.infinity,
              controllerFocusScope: 'testSelect',
              onTap: () => game.startEncounter(kAshGateEncounter),
            ),
            const SizedBox(height: 12),
            if (game.session.hasProgress) ...[
              PixelButton(
                label: 'YENİ OYUN (SIFIRLA)',
                primary: false,
                width: double.infinity,
                controllerFocusScope: 'testSelect',
                onTap: game.openResetConfirm,
              ),
              const SizedBox(height: 12),
            ],
            PixelButton(
              label: 'MAÇ (NORMAL)',
              primary: false,
              width: double.infinity,
              controllerFocusScope: 'testSelect',
              onTap: game.openBossSelect,
            ),
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

// ============================================================================
//  BOSS SEÇİMİ  —  normal (ölümlü) maç için rakip seç
// ----------------------------------------------------------------------------
//  Faz E: `kOpponents` roster'ından bir boss seç → `startNormalMatch`. Basit
//  liste yeter; ilerleme/kilit (Faz G) burada YOK.
// ============================================================================
