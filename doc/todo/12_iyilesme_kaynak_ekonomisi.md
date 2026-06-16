# 12 — İyileşme / Consumable Kaynak Ekonomisi

> **Özet:** Oyuncunun savaş içinde canını yenilemesinin bir yolu yok (test rejeni
> hariç, gerçek maçta `playerHealthRegenPerSecond = 0`). Sekiro'nun "şifa kabağı"
> (Healing Gourd) gibi sınırlı, kararla kullanılan bir iyileşme kaynağı, savaşa
> risk/zamanlama katmanı ekler ("ne zaman içmeliyim?"). Bu dosya iyileşme ve
> consumable ekonomisini tasarlar.

## Mevcut Durum

- `Player.health` yalnız hasarla düşer; gerçek maçta yenilenmez (`NormalActionSystem
  .playerHealthRegenPerSecond = 0`).
- Test modunda otomatik rejen var (`TestActionSystem`: 18/s) — yalnız sandbox.
- Posture / (planlı) stamina pasif rejen olabilir ama **HP için aktif iyileşme yok.**
- Consumable/eşya kavramı yok.

## Eksikler / Sorunlar

- Uzun bir maçta toparlanma yolu yok → hata affı sıfır veya rejenle bedava (test).
- "Ne zaman iyileş?" kararı yok → savaşta önemli bir gerilim katmanı eksik.
- Boss yenince turlar arası toparlanma yok (bkz. `10` arena ilerleyişi).

## Eklenebilecekler (Tam Tasarım)

### Şifa kaynağı (gourd)
- `int healCharges`, `int maxHealCharges` (örn. 3).
- İyileşme **anlık değil**: kısa bir içme animasyonu/penceresi (savunmasız) → "güvenli
  anı bul" kararı. İçerken vurulursa iyileşme iptal/yarım.
- İyileşme miktarı sabit veya % (örn. +%40 HP).
- Şarj **savaş içinde kazanılabilir**: belirli sayıda posture-break / deathblow başına
  +1 şarj → agresif/yetenekli oyunu ödüllendir.

### Consumable çeşitliliği (opsiyonel/ileri)
- Status temizleyici (yanma/zehir söndür — bkz. `07`).
- Geçici buff (kısa süre posture/stamina artışı, hasar zammı).
- Sınırlı sayıda; kararla kullanılır.

### Turlar arası ekonomi
- Bir boss yenince (bkz. `10`) şarjlar kısmen dolar; tam dolmaz → arena boyu kaynak
  yönetimi (risk birikir).

### Test modu davranışı
- Test modunda sınırsız/otomatik (mevcut rejen mantığı korunur).

## Teknik Dokunulacak Alanlar

- `lib/player.dart`
  - `healCharges`, içme durumu (`PlayerState.heal` veya mevcut bir state + kilit),
    iptal mantığı (vurulursa).
  - `reset` / tur geçişinde şarj yönetimi.
- `lib/action_system.dart` + alt sınıflar: `startingHealCharges`, `healAmount`,
  iyileşme açık mı (test vs normal).
- `lib/game.dart`: heal input aksiyonu (`ArenaInputAction.heal`); şarj kazanım
  hook'ları (posture-break/deathblow sonrası).
- `lib/input_settings.dart` + `ArenaInputAction`: `heal` binding.
- `lib/hud.dart`: şifa şarjı göstergesi.
- `lib/boss.dart`: oyuncu iyileşirken AI'nın bunu okuyup baskı yapması (bkz. `09`).

## Kabul Kriterleri

- Oyuncu sınırlı sayıda, savunmasız bir pencerede iyileşebilir.
- İyileşme kararı risk taşır (boss punish edebilir); spam mümkün değil.
- Şarjlar yetenekli oyunla (posture-break/deathblow) kazanılabilir.
- Test modu eğitim için sınırsız/otomatik kalır.

## Bağlı Sistemler
- `10_normal_mac_mod_akisi` (turlar arası ekonomi), `09` (iyileşme punish),
  `07` (status temizleme), `06` (şarj kazanımı), `15` (kapasite unlock'ları).

## Öncelik
**Orta** — gerçek maç akışı (`10`) ile birlikte anlam kazanır.
