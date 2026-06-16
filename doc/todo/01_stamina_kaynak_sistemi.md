# 01 — Oyuncu Stamina / Kaynak Sistemi

> **Özet:** Oyuncunun dodge, ağır saldırı, blok ve panik aksiyonlarını sınırlayan
> bir **stamina** kaynağı yok. Redesign planında merkezî kaynak olarak geçer ama
> kodda yalnız `posture` var. Stamina, "dodge → F" spam'ini doğal olarak kısar,
> kararlara maliyet ekler ve oyuncuyu kaynak yönetimine zorlar. Bu dosya stamina
> sisteminin tam tasarımını ve diğer sistemlerle bağını anlatır.

## Mevcut Durum

- `Player` (`lib/player.dart`): `health` ve `posture` var; **stamina yok.**
- Dodge yalnız `_dodgeCooldown` (0.42s) ile sınırlı; tekrar tekrar atılabilir.
- Ağır saldırı yalnız `_attackCooldown` ile sınırlı, kaynak tüketmez.
- `COMBAT_REDESIGN_PHASES.md` Faz 1 "Player stamina" görevini tanımlar ama
  uygulanmamıştır.

## Eksikler / Sorunlar

- Kararların maliyeti yok: dodge ve heavy "bedava" tekrarlanabilir.
- Risk/ödül zayıf: panik spam cezasız.
- Posture (oyuncunun) yalnız blok/yanlış-araç ile düşer; aktif kaynak yönetimi yok.

## Eklenebilecekler (Tam Tasarım)

### Çekirdek kaynak
- `double stamina`, `double maxStamina` (örn. 100), `double displayStamina`.
- Pasif regen: aksiyon sonrası kısa gecikme (`_staminaIdle > 0.6s`) → `regen/s`.
- Düşük staminada (örn. < %15) **"yorgun"** durumu: aksiyonlar daha yavaş veya
  zayıf; HUD'da bar kırmızı yanıp söner.

### Tüketim tablosu (öneri)
```
dodge            -> 22
ağır saldırı     -> 30
hafif saldırı    ->  8  (veya 0; ritmi bozmamak için düşük)
blok darbe emme  -> 12  (bkz. 02_blok_guard_sistemi)
parry            ->  0  (parry ödül aracı; ücretsiz kalmalı)
panik (stamina yokken aksiyon denemesi) -> reddedilir + kısa "boş" feedback
```

### Kazanım kanalları
- Başarılı **parry** küçük stamina iadesi verir (örn. +6) → agresif savunmayı ödüllendirir.
- **Tempo** penceresinde yapılan saldırılar indirimli stamina kullanır.
- Boss `staggered` iken saldırılar stamina tüketmez (infaz fırsatı serbest).

### Etkileşim kuralları
- Stamina yetmezse dodge **başlamaz** (veya "zayıf dodge": kısa i-frame, yarı mesafe).
- Stamina yetmezse heavy başlamaz; light'a düşürülebilir.
- Stamina ↔ posture ayrımı net olmalı: stamina = oyuncunun *eylem bütçesi*,
  posture = *dengesi/stun riski*.

## Teknik Dokunulacak Alanlar

- `lib/player.dart`
  - alanlar: `stamina`, `maxStamina`, `displayStamina`, `_staminaIdle`.
  - `tryDodge`, `tryAttack` içinde maliyet kontrolü + tüketim.
  - `onParrySuccess` içinde iade.
  - `update` içinde regen + display lerp.
  - `reset` içinde sıfırlama.
- `lib/hud.dart`: stamina barı (HP ve posture'ın yanına).
- `lib/action_system.dart` + alt sınıflar: `staminaRegenPerSecond`,
  `dodgeStaminaCost`, `heavyStaminaCost` gibi ayarlanabilir alanlar (test modunda
  sınırsız stamina seçeneği).
- `lib/game.dart` `CombatMetrics`: `staminaEmptyDenials` sayacı (tuning için).

## Kabul Kriterleri

- Dodge ve heavy artık tükenen bir kaynağa bağlı; ardışık spam mümkün değil.
- Stamina bittiğinde oyuncu net bir "yorgun" feedback'i alır, aksiyon reddedilir.
- Parry hâlâ ücretsiz ve hatta küçük iade verir → agresif savunma teşvik edilir.
- Test modunda stamina sınırsız kılınabilir (mevcut test akışı bozulmaz).

## Bağlı Sistemler
- `02_blok_guard_sistemi` (blok stamina tüketir), `03_parry_pencere_dinamigi`
  (parry iadesi), `05_oyuncu_saldiri_kombo_sistemi` (heavy maliyeti),
  `16_test_metrik_dengeleme` (denial metrikleri).

## Öncelik
**Yüksek** — diğer risk/ödül dosyalarının çoğu stamina varsayar.
