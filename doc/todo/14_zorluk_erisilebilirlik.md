# 14 — Zorluk & Erişilebilirlik Sistemi

> **Özet:** Oyunun tek bir sabit zorluğu var; timing penceresi, boss agresifliği,
> hasar ölçeği ayarlanamıyor ve görsel/işitsel yardım/erişilebilirlik seçenekleri
> yok. Sekiro-tarzı sıkı timing oyunlarında ayarlanabilir zorluk ve erişilebilirlik
> (timing assist, renk körü modu, efekt kısma) oyuncu tabanını ciddi genişletir.
> Bu dosya zorluk ölçekleme ve erişilebilirlik katmanını tasarlar.

## Mevcut Durum

- `ArenaActionSystem` modları (test/normal) bazı parametreleri (ölüm, knockback,
  rejen) ayırıyor ama **kullanıcıya açık zorluk seçimi yok.**
- Timing pencereleri sabit (`parryWindowDuration`, `dodgePre`, `preWindow`, `grace`).
- Boss agresifliği koda gömülü (`chainChance`, `_tempoScale`, EMA ağırlıkları).
- Telegraflar (kırmızı/mavi pill, "VUR F") var ama renk körü/kontrast/ses-ipucu
  alternatifi yok.
- `input_settings.dart` ile tuş atama var; oynanış erişilebilirliği (yavaşlatma,
  otomatik blok vb.) yok.

## Eksikler / Sorunlar

- Yeni oyuncu için giriş bariyeri yüksek; uzman için ayar yok.
- Renk körü oyuncular kırmızı/mavi telegraf ayrımını kaçırabilir.
- Screen-shake/flash (bkz. `11`) kıstırılamıyor (rahatsızlık/erişilebilirlik).

## Eklenebilecekler (Tam Tasarım)

### Zorluk ölçekleri
- `DifficultyProfile` (ArenaActionSystem'in üstünde veya yanında):
  ```
  parryWindowScale   (kolay: 1.4, normal: 1.0, zor: 0.8)
  dodgeWindowScale
  bossDamageScale
  bossAggressionScale (chainChance / feint sıklığı / tepki gecikmesi)
  staminaRegenScale
  ```
- Tüm sabit pencereler bu ölçeklerden geçirilmeli (şu an doğrudan sabit).

### Timing assist
- "Geç parry affı" artırma (grace genişlet), telegraf önceden uyarı süresi artırma.
- Otomatik blok (parry kaçınca chip'li blok) — kolay mod opsiyonu.

### Erişilebilirlik
- Telegraf için **renkten bağımsız** ipuçları: sembol/şekil farkı (kırmızı=üçgen,
  mavi=daire), ek ses ipucu, ekran kenarı flash yön göstergesi.
- Renk körü paletleri.
- Screen-shake / flash / hitstop yoğunluğu sliderları (0–100).
- Yazı boyutu / telegraf büyüklüğü.

### Kalıcı ayarlar
- `input_settings.dart`'taki kayıt mekanizmasına benzer şekilde zorluk/erişilebilirlik
  ayarlarının kaydı.

## Teknik Dokunulacak Alanlar

- Yeni `lib/difficulty.dart` (veya `action_system.dart` genişletme): `DifficultyProfile`
  ve ölçek alanları.
- `lib/player.dart` / `lib/boss.dart` / `lib/characters.dart`: sabit timing/hasar
  değerlerini ölçeklerden geçir.
- `lib/boss.dart`: agresiflik ölçeği (`chainChance`, feint sıklığı, tepki).
- `lib/overlays.dart`: zorluk + erişilebilirlik ayar ekranı.
- `lib/fx.dart` / `lib/game.dart`: shake/flash/hitstop yoğunluk çarpanları.
- `lib/theme.dart`: renk körü paletleri / kontrast.
- Kalıcı ayar: mevcut `InputSettings` kayıt deseni örnek alınabilir.

## Kabul Kriterleri

- Oyuncu en az kolay/normal/zor seçebilir; pencereler ve agresiflik buna göre değişir.
- Renk körü oyuncu telegrafları renkten bağımsız ayırt edebilir.
- Screen-shake/flash kısılabilir/kapatılabilir.
- Ayarlar kalıcı olarak kaydedilir.

## Bağlı Sistemler
- Tüm savaş sistemleri timing/hasar/agresiflik ölçeklerini tüketir; özellikle
  `03`, `04`, `09`, `11`.

## Öncelik
**Orta-Düşük** — çekirdek mekanikler stabilize olduktan sonra; ama renk körü/şekil
telegrafı erken yapılırsa ucuz ve değerli.
