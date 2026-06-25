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

import 'package:boss_parry_arena/app/flow/test_scenarios.dart';
import 'package:boss_parry_arena/presentation/audio.dart';
import 'package:boss_parry_arena/combat/data/characters.dart';
import 'package:boss_parry_arena/content/encounters/ash_gate.dart';
import 'package:boss_parry_arena/content/intro_sequence.dart';
import 'package:boss_parry_arena/app/game/boss_arena_game.dart';
import 'package:boss_parry_arena/app/input/input_settings.dart';
import 'package:boss_parry_arena/presentation/theme.dart';

// ============================================================================
//  SCRIM  —  arkayı bulanıklaştırıp hafif yarı saydam dolgu (orijinalden)
// ============================================================================

part 'shared.dart';
part 'test_select_overlay.dart';
part 'boss_select_overlay.dart';
part 'test_attack_grid.dart';
part 'test_panel_overlay.dart';
part 'combat_intro_overlay.dart';
part 'controls_overlay.dart';
part 'end_overlay.dart';
part 'encounter_overlays.dart';
