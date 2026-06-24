// ============================================================================
//  COMBAT RESOLVER  —  saf temas çözümü çekirdeği (Faz B, ilk dilim)
// ----------------------------------------------------------------------------
//  boss.dart'taki `_resolveContact` "hangi savunma aracı + zamanlama doğru mu?"
//  kararını buraya, SAF bir fonksiyona çeker. Flame/Sfx/popup çağırmaz; yalnız
//  girdi → `ContactDecision` döndürür. Oyuncunun saf timing kuralları
//  (`Player.parrySucceeds`) burada KULLANILIR (taşınmaz, çağrılır).
//
//  Davranış-koruyan: boss._resolveContact'taki dallanma birebir buradadır;
//  boss yalnız kararı uygular (ilgili handler'ı çağırır). Bu sayede temas
//  kararı Flame olmadan birim test edilebilir (D3).
//
//  KAPSAM: yalnız araç+pencere KARARI. Posture hasarı/HP/event üretimi hâlâ
//  boss handler'larında (bunların resolver'a taşınması Faz F).
// ============================================================================
import 'dart:math';

import '../../characters.dart';
import '../../player.dart';

/// Temas çözümünün hangi handler'a gideceği.
enum ContactAction {
  feint, // aldatma çözümü
  dodgeSuccess, // gerçek i-frame ile sıyrıldı
  parrySuccess, // doğru araç + zamanında + doğru yön
  wrongTool, // yanlış araç/yön → ceza ([wrongToolLabel] ile)
  beginPending, // henüz çözülmedi → grace penceresi başlasın
}

class ContactDecision {
  final ContactAction action;
  final String? wrongToolLabel;
  const ContactDecision(this.action, {this.wrongToolLabel});
}

class CombatResolver {
  const CombatResolver._();

  /// boss._resolveContact'ın saf kararı. Girdiler boss tarafından okunur
  /// (oyuncu durumu + beat profili); çıktı uygulanacak handler kategorisidir.
  static ContactDecision resolveContact({
    required DefenseProfile defense,
    required GuardDirection guardDirection,
    required bool isFeint,
    required bool playerInvulnerable,
    required bool guardMatches,
    required double sinceParry,
    required double sinceDodge,
    required double beatPreWindow,
    required double effectiveParryWindow,
    required double dodgePre,
  }) {
    // ALDATMA: gerçek vuruş yok; ayrı çözüm.
    if (isFeint) return const ContactDecision(ContactAction.feint);

    // Gerçek i-frame her saldırıyı geçersiz kılar AMA tracking (saplama/takip)
    // hariç: o, dokunulmazlığı delip yalnız parry ile karşılanır.
    final iFrameBeats = playerInvulnerable && defense != DefenseProfile.tracking;
    if (iFrameBeats) return const ContactDecision(ContactAction.dodgeSuccess);

    // Parry penceresi: beat penceresi ile oyuncunun (spam ile daralmış olabilen)
    // penceresinin küçüğü — spam decay başarıyı gerçekten daraltır.
    final effWindow = min(beatPreWindow, effectiveParryWindow);
    final pressedParry = Player.parrySucceeds(sinceParry, effWindow);
    final didParry = pressedParry && guardMatches;
    // triedDodge yalnız feedback için: dodge'a bastı ama i-frame'i ıskaladı.
    final triedDodge = sinceDodge <= dodgePre;

    switch (defense) {
      case DefenseProfile.guardBreak:
        // KIRMIZI: doğru cevap dodge; parry cezalanır.
        return pressedParry
            ? const ContactDecision(
                ContactAction.wrongTool,
                wrongToolLabel: 'PARRY OLMAZ!',
              )
            : const ContactDecision(ContactAction.beginPending);
      case DefenseProfile.thrust:
        // MİKİRİ: delici saldırı; doğru cevap dodge (i-frame); parry cezalanır.
        return pressedParry
            ? const ContactDecision(
                ContactAction.wrongTool,
                wrongToolLabel: 'MİKİRİ! KAÇ',
              )
            : const ContactDecision(ContactAction.beginPending);
      case DefenseProfile.tracking:
        if (didParry) return const ContactDecision(ContactAction.parrySuccess);
        if (pressedParry) {
          return const ContactDecision(
            ContactAction.wrongTool,
            wrongToolLabel: 'YANLIŞ YÖN!',
          );
        }
        if (triedDodge) {
          return const ContactDecision(
            ContactAction.wrongTool,
            wrongToolLabel: 'KAÇILMAZ!',
          );
        }
        return const ContactDecision(ContactAction.beginPending);
      default:
        // normal / heavy / delayed / feint / ranged ...: boss._resolveContact'taki
        // son `else` ile aynı — doğru yönle parry işler, yanlış yön cezalanır.
        if (didParry) return const ContactDecision(ContactAction.parrySuccess);
        if (pressedParry && guardDirection != GuardDirection.any) {
          return const ContactDecision(
            ContactAction.wrongTool,
            wrongToolLabel: 'YANLIŞ YÖN!',
          );
        }
        return const ContactDecision(ContactAction.beginPending);
    }
  }
}
