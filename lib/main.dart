// ============================================================================
//  BOSS PARRY ARENA  —  uygulama girişi
// ----------------------------------------------------------------------------
//  AKIŞ:  testSelect → playing → won/lost.
//  Oyun çekirdeği game.dart'ta; overlay'ler overlays.dart'ta.
// ============================================================================

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'audio.dart';
import 'core/shared_prefs_save_store.dart';
import 'domain/save_repository.dart';
import 'game.dart';
import 'overlays.dart';

final BossArenaGame game = BossArenaGame();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ses havuzlarını önceden hazırla → tuşa basıldığında anlık çalsın.
  await Sfx.init();
  // Kalıcılık (Faz H): kayıtlı ilerlemeyi yükle (varsa) — combat/input'tan ayrı.
  await game.session.attachPersistence(SaveRepository(SharedPrefsSaveStore()));
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
          // Faz G — encounter akış overlay'leri.
          'dialogue': (ctx, g) => EncounterDialogueOverlay(g),
          'choice': (ctx, g) => EncounterChoiceOverlay(g),
          'dice': (ctx, g) => EncounterDiceOverlay(g),
          'reward': (ctx, g) => EncounterRewardOverlay(g),
          // Faz H — yeni oyun onayı.
          'confirmReset': (ctx, g) => ConfirmResetOverlay(g),
        },
        // Açılış: doğrudan combat/test arenası.
        initialActiveOverlays: const ['testSelect'],
      ),
    ),
  );
}
