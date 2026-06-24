# FAZ C — Oyuncu Aksiyon Timeline'ı (PlayerMoveDef + ActionTimeline)

> **Durum:** ✅ Bitti — ActionTimeline + PlayerMoveDef eklendi; Player süreleri veriden okuyor (tek kaynak `k*` sabitleri), `_atkTotal=timeline.duration`, `dodgeInvulnerableAt=isIn(iframe)`. Davranış birebir korundu; analyze temiz, 100 test yeşil. **Sonraki faza not:** low-parry (`kPlayerLowParryWindow`) ayrı `ActionWindow` modeli olarak değil yalnız süre sabiti olarak taşındı → Faz D'de pencereye bağlanabilir.
> **Bağımlılık:** **Faz B bitmiş olmalı.** **Faz D ile paralel** yürüyebilir (farklı dosyalar).
> **Tür:** Refactor — davranış DEĞİŞMEZ; oyuncu aksiyonları data-driven olur.
> **Referans:** `doc/architecture.md` §6.1 (ActionTimeline), §6.3 (PlayerMoveDef), §16 (ilke 4).

---

## 0. Tek cümle
Oyuncunun parry/dodge/light/heavy süre sabitlerini `Player` sınıfına dağıtmak yerine **`ActionTimeline` + `PlayerMoveDef` verisinden** okut; böylece yeni silah/parry tipi eklerken `Player` büyümez, sadece veri + resolver genişler.

## 1. Neden
- `Player`'da süreler sabit alanlar: `parryWindowDuration=0.13` (player.dart:61), `dodgeInvulnFrom=0.02`/`dodgeInvulnTo=0.20` (88–89), `atkWindup=0.07` (120), `heavyAtkWindup`, `_atkActive`, `_atkRecover`, `_atkTotal` (220–226). Yeni aksiyon = `Player`'ı şişirir (D1).
- Pencereleri birinci-sınıf veri yapmak (`active/parry/iframe/recovery`) hem testi hem asset hizalamasını (Faz D) kolaylaştırır.

## 2. Kapsam

**DAHİL:**
- `lib/combat/data/action_timeline.dart`: `CombatWindowKind`, `ActionWindow`, `ActionEventMarker`, `ActionTimeline` (§6.1).
- `lib/combat/data/move_def.dart`: `PlayerMoveDef { id, timeline, staminaCost, animationBindingId, canCancelIntoDefense }`.
- Oyuncunun light/heavy/parry/dodge tanımlarını `PlayerMoveDef` sabitleri olarak yaz (mevcut sayısal değerlerle birebir).
- `Player`'ı bu verileri okuyacak şekilde uyarla; süre hesapları timeline'dan gelsin. Sprite seçimi timeline ilerleyişine bağlansın (windup/active/recover oranı).

**HARİÇ:**
- Boss `Beat`'ini MoveDef'e dönüştürmek → ileride (Faz F sonrası ayrı iş); bu faz **yalnız oyuncu**.
- AnimationBinding'i bağlamak → Faz D (sadece `animationBindingId` alanı yer tutucu olarak eklenir).
- Yeni gerçek aksiyon/silah eklemek (altyapı kurulur, içerik eklenmez).

## 3. Dokunulacak / eklenecek dosyalar

| Dosya | İş |
|---|---|
| `lib/combat/data/action_timeline.dart` (yeni) | Pencere modeli (§6.1). |
| `lib/combat/data/move_def.dart` (yeni) | `PlayerMoveDef` + oyuncu hamle sabitleri (`kPlayerLight`, `kPlayerHeavy`, `kPlayerParry`, `kPlayerDodge`). |
| `lib/player.dart` | Sabit süreleri timeline'dan oku; `parrySucceeds`/`decayParryWindow`/`dodgeInvulnerableAt` saf fn'leri korunur (Faz B resolver bunları kullanıyor). |
| `lib/sprite_strip.dart` | `attackFrame(phase, remaining, duration)` timeline penceresinden faz/ilerleme alacak şekilde uyumlu kalsın (Faz D'de tamamen binding'e geçecek). |
| `test/` | Yeni timeline + move def testleri. |

### ActionTimeline iskeleti (referans, §6.1)
```dart
enum CombatWindowKind { windup, active, recovery, parry, iframe, cancel, superArmor, vulnerable }
class ActionWindow      { final CombatWindowKind kind; final double start, end; const ActionWindow(this.kind, this.start, this.end); }
class ActionEventMarker { final double time; final String event; final Map<String, Object?> args; const ActionEventMarker(this.time, this.event, [this.args = const {}]); }
class ActionTimeline    { final String id; final double duration; final List<ActionWindow> windows; final List<ActionEventMarker> events;
  const ActionTimeline({required this.id, required this.duration, this.windows = const [], this.events = const []});
  bool isIn(CombatWindowKind k, double t) => windows.any((w) => w.kind == k && t >= w.start && t <= w.end);
}
```

## 4. Adım adım görevler

- [ ] **C1 — Timeline modeli.** `action_timeline.dart`'ı yaz; `isIn(kind, t)` yardımcısı + (gerekirse) `windowFor(t)`.
- [ ] **C2 — PlayerMoveDef + sabitler.** Mevcut sayılardan **birebir** türet:
  - `kPlayerParry`: parry penceresi `0.13` (player.dart:61) → `ActionWindow(parry, 0, 0.13)`; `staminaCost: 0` ama başarılı parry iadesi (`parryStaminaRefund=6`) resolver/system tarafında kalır.
  - `kPlayerDodge`: i-frame `0.02–0.20` (88–89) → `ActionWindow(iframe, 0.02, 0.20)`; `staminaCost: dodgeStaminaCost(22)`.
  - `kPlayerLight`: windup `0.07` (atkWindup,120) + active + recover (`_atkActive`/`_atkRecover` mevcut değerleri); `staminaCost: lightStaminaCost(8)`.
  - `kPlayerHeavy`: `heavyAtkWindup` + active/recover; `staminaCost: heavyStaminaCost(30)`.
  > **Stamina maliyetleri `ArenaActionSystem` getter'larından gelir** (action_system.dart:49–53); MoveDef'e gömme, system'den oku — sandbox `unlimitedStamina` muafiyeti korunsun.
- [ ] **C3 — Player'ı timeline'a bağla.** `Player`'daki `isParryActive`/`dodgeInvulnerable`/`isAttackActive`/`_atkTotal` hesaplarını ilgili `ActionTimeline.isIn(...)`/`duration` üzerinden yap. Statik saf fn'ler (`parrySucceeds` vb.) imza/davranış korunur (Faz B resolver onlara bağlı).
- [ ] **C4 — Sprite ilerleyişi.** Saldırı sprite karesi seçimini timeline fazından türet; `sprite_strip.dart`'ın windup/active/recover esnetme davranışı **görsel olarak aynı** kalmalı.
- [ ] **C5 — animationBindingId yer tutucu.** Her MoveDef'e `animationBindingId` ekle (string); Faz D bağlayacak. Şimdilik mevcut `animKey`/sheet seçimiyle eşdeğer kalsın.
- [ ] **C6 — Test + analyze + duman.** Yeni testler + mevcutlar yeşil; oyunda parry penceresi hissi, dodge i-frame, light/heavy zamanlaması **birebir** eski gibi.

## 5. Kabul kriterleri
- Oyuncu parry/dodge/light/heavy süreleri **tek yerden (MoveDef/timeline) okunuyor**; `Player` içine dağılmış sihirli sayı kalmadı (ya da belirgin azaldı).
- Stamina maliyetleri hâlâ `ArenaActionSystem`'den; sandbox sınırsız stamina korunuyor.
- `parrySucceeds`/`dodgeInvulnerableAt`/`decayParryWindow` saf fn'leri ve mevcut `combat_rules_test.dart` testleri aynen geçiyor.
- Davranış birebir korunuyor (parry/dodge timing hissi değişmedi).

## 6. Test planı
- `test/action_timeline_test.dart`: `isIn` sınır değerleri (start/end dahil), pencere çakışmaları.
- `test/player_move_def_test.dart`: light/heavy toplam süresi = windup+active+recover; dodge i-frame penceresi = `0.02–0.20`; parry penceresi = `0.13`.
- Mevcut `combat_rules_test.dart` (parry decay, dodge i-frame) **değişmeden** geçer.

## 7. Riskler & geri alma
- **Risk:** Timeline'a taşırken `0.13`/`0.02`/`0.20`/`0.07` gibi değerleri yanlış kopyalamak → timing hissi bozulur. **Önlem:** değerleri player.dart'tan **kopyala**, testle sabitlere assert koy.
- **Risk:** Sprite esnetmesi faz oranı değişirse animasyon kayar. **Önlem:** Faz D'ye kadar mevcut `attackFrame` davranışını koru.
- **Geri alma:** Faz C tek commit serisi; D ile paralel gidiyorsa ayrı branch.

## 8. Doğrulama komutları
```bash
flutter analyze
flutter test
flutter run   # parry penceresi + dodge i-frame + light/heavy zamanlaması elle
```
