# 05 — Oyuncu Saldırı & Kombo Sistemi

> **Özet:** README, hafif ve ağır saldırı arasındaki farkın "ritim ve taahhüt"
> olduğunu söyler. Mevcut sistemde ağır saldırı **yalnız test modunda** açık,
> oyuncunun saldırıları zincirlenmiyor (light→light→heavy string yok), animation
> cancel/feint yok ve saldırı yalnız boss açıkken anlamlı. Bu dosya oyuncu
> saldırısını tek-tuş "vur" eyleminden ifade gücü olan bir kombo sistemine taşır.

## Mevcut Durum

- `Player.tryAttack(type)`: light/heavy var; light/heavy zamanlamaları tanımlı
  (`atkWindup/Active/Recover`, `heavyAtk*`).
- `game.dart tryPlayerHeavyAttack`: **`if (!testMode) return;`** → gerçek maçta heavy yok.
- Saldırı teması `onPlayerAttackContact` → menzilde ise `boss.receivePlayerAttack`.
- Boss tarafı hasar: `staggered` (büyük), `offBalance` (orta), açık değilse posture chip.
- `storedCombo` boss'taki **parry** zincirini sayar; oyuncunun saldırı kombosu yok.
- Tempo (`hasTempo`) saldırıya +4 HP verir (küçük bonus).

## Eksikler / Sorunlar

- Heavy attack tüm modlarda kullanılamıyor (test-gated).
- Saldırı zincirleme yok: ardışık light'lar farklı animasyon/etki üretmiyor.
- Animation cancel (light → dodge/parry iptali) yok → README'nin "light ile defansı
  test et, iptal et" akışı yok.
- "Whiff/greed" cezası zayıf: açık değilken vurmak yalnız posture chip + risk düşük.
- Ağır saldırının "commitment" (animasyona kilitlenme, geri dönüşü yok) hissi var ama
  ödül/risk dengesi tek bağlamda (yalnız açıkken).

## Eklenebilecekler (Tam Tasarım)

### Heavy'yi her moda aç
- `tryPlayerHeavyAttack`'tan test kısıtını kaldır; bunun yerine **stamina** (`01`) ile
  sınırla. Heavy = yüksek posture/stagger gücü + uzun recovery + yüksek stamina.

### Kombo string'leri
- Light → Light → (Light veya Heavy finisher) zinciri:
  - ardışık light'lar `comboStep` arttırır; her adım farklı `attackN` animasyonu.
  - finisher heavy ekstra posture hasarı + knockback.
  - zincir penceresi kaçırılırsa idle'a düşer (combo drop).
- Boss açıkken yapılan finisher → bonus HP (mevcut stagger/offBalance ile çarpan).

### Animation cancel
- Light'ın recovery'sinin erken kısmı **dodge/parry ile iptal edilebilir** (defansa
  pürüzsüz geçiş). Heavy iptal edilemez (taahhüt).

### Whiff / greed dengesi
- Açık değilken saldırı: küçük posture chip ama oyuncu **kendi recovery'sinde
  savunmasız** → boss bunu okuyup punish edebilir (bkz. `09`).
- Iska (menzil dışı) zaten `whiff` veriyor; recovery'de ek kırılganlık eklenebilir.

### Yönlü / kalkan-kırıcı saldırı (opsiyonel)
- Oyuncunun da bir "guard break" saldırısı: boss blok/guard'dayken posture'ı hızlı
  açan ağır vuruş (boss guard sistemi `_shieldLightBlock` ile zaten var).

## Teknik Dokunulacak Alanlar

- `lib/game.dart`
  - `tryPlayerHeavyAttack`: test kısıtını kaldır, stamina kontrolüne bağla.
  - `onPlayerAttackContact`: combo step / finisher çarpanı; `heavyHits` metriği
    (şu an `lightHits` her ikisi için artıyor — ayır).
- `lib/player.dart`
  - `comboStep`, combo penceresi zamanlayıcısı; `tryAttack` zincir mantığı.
  - light recovery'de cancel-to-defense izni.
  - heavy stamina maliyeti.
- `lib/boss.dart` `receivePlayerAttack`: finisher/combo step'e göre hasar çarpanı;
  oyuncu recovery'sinde punish okuması (AI ile).
- `lib/audio.dart`: light seri sesi vs heavy tok ses ayrımı (`heavyHit` artık çağrılsın).
- `lib/fx.dart`: heavy isabetinde daha büyük screen shake/popup (bkz. `11`).

## Kabul Kriterleri

- Heavy attack her modda stamina ile kullanılabilir.
- Light saldırılar zincirlenir ve finisher belirgin ekstra etki verir.
- Light recovery dodge/parry ile iptal edilebilir; heavy edilemez (taahhüt korunur).
- `lightHits` ve `heavyHits` metrikleri doğru ayrışır.

## Bağlı Sistemler
- `01_stamina_kaynak_sistemi`, `06_deathblow_infaz_sistemi` (finisher → infaz),
  `09_boss_ai_adaptasyon_sistemi` (greed punish), `11_game_feel_feedback_sistemi`.

## Öncelik
**Yüksek** — saldırı şu an en sığ katman; ifade gücü buradan gelir.
