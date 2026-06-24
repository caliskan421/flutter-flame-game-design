// ============================================================================
//  BOSS PARRY ARENA  —  uygulama girişi
// ----------------------------------------------------------------------------
//  AKIŞ:  testSelect → playing → won/lost.
//  Oyun çekirdeği game.dart'ta; overlay'ler overlays.dart'ta.
// ============================================================================

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'audio.dart';
import 'game.dart';
import 'overlays.dart';

final BossArenaGame game = BossArenaGame();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ses havuzlarını önceden hazırla → tuşa basıldığında anlık çalsın.
  await Sfx.init();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GameWidget<BossArenaGame>(
        game: game,
        overlayBuilderMap: {
          'testSelect': (ctx, g) => TestSelectOverlay(g),
          'bossSelect': (ctx, g) => BossSelectOverlay(g),
          'testPanel': (ctx, g) => TestPanelOverlay(g),
          'combatIntro': (ctx, g) => CombatIntroOverlay(g),
          'controls': (ctx, g) => ControlsOverlay(g),
          'won': (ctx, g) => EndOverlay(g, won: true),
          'lost': (ctx, g) => EndOverlay(g, won: false),
        },
        // Açılış: doğrudan combat/test arenası.
        initialActiveOverlays: const ['testSelect'],
      ),
    ),
  );
}
