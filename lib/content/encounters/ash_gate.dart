// ============================================================================
//  Ash Gate — ilk encounter (Faz G dikey kesit, architecture.md §15)
// ----------------------------------------------------------------------------
//  Menü → diyalog → 2-3 seçim → 1 zar (gizlilik) → Knight 1 normal combat →
//  win/loss → ödül/flag. Zar SADECE hikayeyi etkiler: başarı → 'approached_silently'
//  flag'i → boss ilk fazda daha geç agresifleşir (combat math'ine dokunulmaz).
//  Tümü VERİ; akışı EncounterRunner yürütür.
// ============================================================================

import '../../domain/dice_service.dart';
import '../../domain/encounter.dart';
import '../../domain/scenario_effect.dart';

const EncounterDef kAshGateEncounter = EncounterDef(
  id: 'ash_gate',
  title: 'KÜL KAPISI',
  // Tekrar oynatmada zar sonucu sızmasın diye geçici flag'ler baştan temizlenir.
  clearFlagsOnStart: ['approached_silently', 'alerted_guard'],
  steps: [
    // 1) Kısa giriş diyaloğu.
    DialogueStep(
      DialogueNodeDef('ash_gate_intro', [
        DialogueLine(
          'Anlatıcı',
          'Kül Kapısı önünde bir şövalye nöbette. Geçmenin tek yolu onu '
              'devirmek — ama nasıl yaklaştığın ilk vuruşları belirler.',
          left: true,
        ),
        DialogueLine(
          'Şövalye I',
          'Bu kapıdan canlı geçen olmadı, gezgin. Geri dön.',
          left: false,
        ),
      ]),
    ),

    // 2) Yaklaşım seçimi → gizlilik (stealth) statını belirler.
    ChoiceStep(
      ChoiceDef('Kapıya nasıl yaklaşırsın?', [
        ChoiceOption(
          'Gölgelerden sessizce süzül',
          hint: 'Gizlilik kontrolü kolaylaşır',
          effects: [SetStat('stealth', 6)],
        ),
        ChoiceOption(
          'Çevreyi gözleyip fırsat kolla',
          hint: 'Dengeli',
          effects: [SetStat('stealth', 2)],
        ),
        ChoiceOption(
          'Doğrudan, korkusuzca yürü',
          hint: 'Gizlilik neredeyse imkânsız',
          effects: [SetStat('stealth', -4)],
        ),
      ]),
    ),

    // 3) Zar: 1d20 + stealth >= 12. Başarı → sessiz yaklaşıldı.
    DiceCheckStep(
      DiceCheckDef(
        id: 'ash_gate_sneak',
        stat: 'stealth',
        difficulty: 12,
        onSuccess: [SetFlag('approached_silently')],
        onFailure: [SetFlag('alerted_guard')],
      ),
    ),

    // 4) Knight 1 ile normal (ölümlü) maç. Sessiz yaklaşma başarılıysa boss ilk
    //    saldırısını geciktirir (modifikatör VERİDE; game.dart içerik adı bilmez).
    CombatStep(
      'knight_1',
      introText: 'Şövalye I — Kül Kapısı Bekçisi',
      slowOpeningFlag: 'approached_silently',
      slowOpeningDelay: 2.2,
    ),

    // 5) Zafer ödülü (yalnız maç WIN'de ulaşılır).
    RewardStep(
      title: 'KÜL KAPISI AÇILDI',
      text: 'Bekçi devrildi. Kapı ardında daha karanlık bir yol uzanıyor...',
      effects: [SetFlag('boss_knight_1_defeated'), GiveResource('honor', 1)],
    ),
  ],
);
