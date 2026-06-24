// ============================================================================
//  PLAYER MOVE DEF  —  oyuncu hamlelerinin saf veri tanımı
// ----------------------------------------------------------------------------
//  Oyuncunun parry/dodge/light/heavy süre sabitleri burada TEK KAYNAKTAN
//  tanımlanır ve `ActionTimeline` penceresi olarak ifade edilir. `Player` bu
//  verilerden okur; böylece yeni hamle eklerken `Player` şişmez (architecture.md
//  §6.3, §16 ilke 4). Hiçbir Flame/Sfx bağı yoktur.
//
//  ÖNEMLİ — sayısal değerler bugünkü davranışla BİREBİR aynıdır (Faz C
//  davranış-koruyandır). Aşağıdaki `k*` sabitleri tek doğruluk kaynağıdır;
//  hem timeline'lar hem `Player` içindeki const alias'lar bunlara dayanır.
// ============================================================================

import 'action_timeline.dart';

// --- Süre sabitleri (saniye) — TEK KAYNAK ----------------------------------
// Light saldırı fazları (eski Player.atkWindup/atkActive/atkRecover).
const double kPlayerLightWindup = 0.07;
const double kPlayerLightActive = 0.10;
const double kPlayerLightRecover = 0.18;

// Heavy saldırı fazları (eski Player.heavyAtk*).
const double kPlayerHeavyWindup = 0.24;
const double kPlayerHeavyActive = 0.12;
const double kPlayerHeavyRecover = 0.42;

// Parry penceresi (eski Player.parryWindowDuration / lowParryWindowDuration).
const double kPlayerParryWindow = 0.13;
const double kPlayerLowParryWindow = 0.18;

// Dodge: toplam pencere süresi + gerçek dokunulmazlık (i-frame) aralığı + i-frame'in
// erken "perfect" dilimi (eski Player.dodgeWindowDuration / dodgeInvulnFrom /
// dodgeInvulnTo / perfectDodgeUntil). Perfect dilim slow-mo ödülü içindir; Faz D'de
// ayrı pencere türü gelene kadar süre sabiti olarak burada tek-kaynaktan tutulur.
const double kPlayerDodgeDuration = 0.20;
const double kPlayerDodgeIframeFrom = 0.02;
const double kPlayerDodgeIframeTo = 0.20;
const double kPlayerDodgePerfectUntil = 0.11;

/// Bir oyuncu hamlesinin tanımı: kimlik + zaman çizelgesi + meta.
///
/// [staminaCost] yalnızca REFERANS/belge amaçlıdır; gerçek (sandbox-farkında)
/// maliyet `ArenaActionSystem` getter'larından okunur — `Player` bu alanı
/// harcama için KULLANMAZ (proje kuralı: "Combat tuning via action system").
/// [animationBindingId] Faz D'de bağlanacak yer tutucudur.
class PlayerMoveDef {
  final String id;
  final ActionTimeline timeline;
  final double staminaCost;
  final String animationBindingId;
  final bool canCancelIntoDefense;

  const PlayerMoveDef({
    required this.id,
    required this.timeline,
    this.staminaCost = 0,
    required this.animationBindingId,
    this.canCancelIntoDefense = false,
  });
}

// --- Oyuncu hamle sabitleri -------------------------------------------------

/// Light saldırı: windup → active → recovery (toplam 0.35 sn). Recovery'nin geç
/// kısmı defansa iptal edilebilir (Player._canCancelAttack) → canCancelIntoDefense.
const PlayerMoveDef kPlayerLight = PlayerMoveDef(
  id: 'player.light',
  animationBindingId: 'player.attack.light',
  staminaCost: 8, // referans; otorite: ArenaActionSystem.lightStaminaCost
  canCancelIntoDefense: true,
  timeline: ActionTimeline(
    id: 'player.light',
    duration: kPlayerLightWindup + kPlayerLightActive + kPlayerLightRecover,
    windows: [
      ActionWindow(CombatWindowKind.windup, 0, kPlayerLightWindup),
      ActionWindow(
        CombatWindowKind.active,
        kPlayerLightWindup,
        kPlayerLightWindup + kPlayerLightActive,
      ),
      ActionWindow(
        CombatWindowKind.recovery,
        kPlayerLightWindup + kPlayerLightActive,
        kPlayerLightWindup + kPlayerLightActive + kPlayerLightRecover,
      ),
    ],
  ),
);

/// Heavy saldırı: windup → active → recovery (toplam 0.78 sn). Taahhüt: iptal
/// edilemez → canCancelIntoDefense: false.
const PlayerMoveDef kPlayerHeavy = PlayerMoveDef(
  id: 'player.heavy',
  animationBindingId: 'player.attack.heavy',
  staminaCost: 30, // referans; otorite: ArenaActionSystem.heavyStaminaCost
  timeline: ActionTimeline(
    id: 'player.heavy',
    duration: kPlayerHeavyWindup + kPlayerHeavyActive + kPlayerHeavyRecover,
    windows: [
      ActionWindow(CombatWindowKind.windup, 0, kPlayerHeavyWindup),
      ActionWindow(
        CombatWindowKind.active,
        kPlayerHeavyWindup,
        kPlayerHeavyWindup + kPlayerHeavyActive,
      ),
      ActionWindow(
        CombatWindowKind.recovery,
        kPlayerHeavyWindup + kPlayerHeavyActive,
        kPlayerHeavyWindup + kPlayerHeavyActive + kPlayerHeavyRecover,
      ),
    ],
  ),
);

/// Parry: 0–0.13 sn parry penceresi. Başarılı parry stamina iadesi
/// (ArenaActionSystem.parryStaminaRefund) resolver/system tarafında kalır.
const PlayerMoveDef kPlayerParry = PlayerMoveDef(
  id: 'player.parry',
  animationBindingId: 'player.parry',
  timeline: ActionTimeline(
    id: 'player.parry',
    duration: kPlayerParryWindow,
    windows: [
      ActionWindow(CombatWindowKind.parry, 0, kPlayerParryWindow),
    ],
  ),
);

/// Dodge: 0.20 sn pencere; 0.02–0.20 sn arası gerçek dokunulmazlık (i-frame).
const PlayerMoveDef kPlayerDodge = PlayerMoveDef(
  id: 'player.dodge',
  animationBindingId: 'player.dodge',
  staminaCost: 22, // referans; otorite: ArenaActionSystem.dodgeStaminaCost
  timeline: ActionTimeline(
    id: 'player.dodge',
    duration: kPlayerDodgeDuration,
    windows: [
      ActionWindow(
        CombatWindowKind.iframe,
        kPlayerDodgeIframeFrom,
        kPlayerDodgeIframeTo,
      ),
    ],
  ),
);
