# 13 — Konum / Mesafe / Hitbox Sistemi

> **Özet:** Savaş şu an büyük ölçüde "yerinde ritim" üzerine: test modunda boss X'e
> kilitli (`lockBossToBaseX`), oyuncu hareketi yok, saldırı teması tek bir yatay
> menzil eşiğiyle (`attackRange = 150`) çözülür. Gerçek bir dövüş hissi için
> mesafe yönetimi, oyuncu hareketi, sırt dönme/backstab ve daha zengin hitbox/
> spacing gerekir. Bu dosya konum ve mesafe katmanını tasarlar.

## Mevcut Durum

- `Boss.standGap = 82`; test modunda boss bitişik ve sabit (`lockBossToBaseX`,
  `bossStartsBeatInPlace`, `bossKeepsPressureInPlace` hepsi test'te `true`).
- Normal modda approach/reposition/retreat var (`NormalActionSystem` ile) ama mod kapalı (`10`).
- Oyuncu **hareket edemiyor**: yalnız parry/dodge/attack; yön tuşları parry yönü için.
- Saldırı teması: tek mesafe eşiği `dist <= attackRange` → isabet/iska.
- Mermiler `from→to` düz uçar; yana kaçışla pozisyonel atlatma yok (i-frame `04`).

## Eksikler / Sorunlar

- Mesafe oyunu (yaklaş/uzaklaş, spacing baskısı) test modunda yok.
- Oyuncu konumunu kontrol edemiyor → "boss arkasına geç, mesafe aç" kararları yok.
- Backstab / sırt dönme / yön avantajı yok.
- Hitbox modeli kaba: tek yatay mesafe; yükseklik (high/low) yalnız parry yönünde,
  fiili çarpışmada değil.

## Eklenebilecekler (Tam Tasarım)

### Oyuncu hareketi
- Sınırlı yatay yürüme/koşma (arena içinde), ileri-geri spacing.
- Hareket ↔ dodge ↔ saldırı geçişleri akıcı; hareket stamina'sız (veya çok ucuz).
- Test modunda opsiyonel kapalı tutulabilir (mevcut yerinde döngü korunur).

### Spacing & mesafe baskısı
- Boss menzil dışındayken saldırı iska (zaten var) → oyuncu doğru mesafeyi tutmalı.
- Boss mesafe okuyup kapatır/açar (bkz. `09`): sürekli kaçana ranged/dash; sürekli
  yapışana knockback'li beat.
- "Whiff punish": boss ıskalayınca recovery'sinde mesafe kapatıp punish fırsatı.

### Backstab / yön
- Boss arkasına geçince (yana/içeri dodge — `04`) kısa **backstab** penceresi: bonus
  hasar/posture. Boss bunu reposition/turn ile kapatmaya çalışır.
- Yönlü mirror zaten var (`render`'da `mirror`); fiili yön avantajına bağlanmalı.

### Hitbox iyileştirme
- Beat'lere yatay menzil/erim (reach) verisi (`Beat.reach`) → her saldırının kendi
  mesafesi; uzun menzilli ağır vuruş vs kısa hızlı vuruş.
- High/low çarpışmanın yalnız parry yönünde değil, gerçek temas yüksekliğinde anlam
  taşıması (örn. low saldırı zıplayışla atlanabilir — ileri seviye).

## Teknik Dokunulacak Alanlar

- `lib/player.dart`: yatay hareket (girdi + hız), arena sınırı clamp; backstab durumu.
- `lib/game.dart`: `attackRange` yerine beat bazlı reach; `onPlayerAttackContact`
  mesafe/yön hesabı; hareket inputu (`ArenaInputAction.moveLeft/Right`).
- `lib/boss.dart`: mesafe okuma ile reposition/ranged kararı (`_decidePressure`,
  `_pickCombo`); whiff punish; backstab açığı.
- `lib/characters.dart`: `Beat.reach` alanı; karakterlere menzil profili.
- `lib/action_system.dart`: hareketin modlara göre açık/kapalı olması.
- `lib/input_settings.dart`: hareket binding'leri (yön tuşları parry ile çakışmasın —
  ayrı tuş veya bağlam).

## Kabul Kriterleri

- Oyuncu (en azından normal modda) konumunu kontrol edebilir; spacing kararı var.
- Boss mesafeyi okuyup kapatır/açar; whiff'ler punish edilebilir.
- Saldırıların kendi menzili var; "doğru mesafe" bir beceri haline gelir.
- Backstab/yön avantajı en az bir somut ödül üretir.
- Test modunun yerinde-ritim deneyimi bozulmadan korunabilir (opsiyon).

## Bağlı Sistemler
- `04_dodge_iframe_sistemi` (yönlü dodge/backstab), `09` (mesafe okuma),
  `10_normal_mac_mod_akisi` (gerçek mesafe oyunu), `05` (whiff/greed).

## Öncelik
**Orta** — normal mod (`10`) açıldıktan sonra en çok değer katan derinlik.
