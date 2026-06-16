# 07 — Status Efekt Sistemi (Yanma / Şok / Kanama / Zehir)

> **Özet:** Büyücü bosslar (ateş, şimşek, gezgin) şu an yalnız anlık HP hasarı
> verir; ateşin yakması, şimşeğin sersemletmesi gibi **kalıcı/biriken durum
> efektleri** yok. Status efektleri, savaşa kaynak yönetimi (efekti söndürme),
> ek tehdit okuma ve karakter kimliği katar. Bu dosya jenerik bir status efekt
> altyapısı ve karakter bazlı efektleri tasarlar.

## Mevcut Durum

- `Beat.damage` anlık HP, `Beat.postureDamage` parry'de denge — **birikimli efekt yok.**
- Büyücüler (`fire_wizard`, `lightning_mage`, `wanderer_magican`) mermi atar
  (`projectileKey`); temas `_resolveContact` → savunulmazsa düz hasar.
- `Projectile` (`lib/projectile.dart`) yalnız uçar, çarpar, `deflect` olur.
- Oyuncuda `health`/`posture`/(planlı) `stamina` dışında durum yok.

## Eksikler / Sorunlar

- Ateş/şimşek/ok büyücüleri mekanik olarak **aynı** hissettiriyor (yalnız hasar/hız farkı).
- "Yanıyorsun, söndür" / "şok oldun, kısa kontrol kaybı" gibi gerilim katmanı yok.
- Parry ile mermi yansıtma var ama yansıyan merminin status etkisi yok.

## Eklenebilecekler (Tam Tasarım)

### Jenerik status altyapısı
- `enum StatusKind { burn, shock, bleed, poison, chill }`
- Oyuncu (ve gerekirse boss) üzerinde aktif statusler listesi:
  ```
  StatusInstance { kind, remaining, stacks, tickAccumulator }
  ```
- `update`'te tick: DoT hasarı, stack birikimi, süre azalması, eşik tetikleri.
- HUD'da aktif status ikonları + süre göstergesi.

### Karakter bazlı efektler (öneri)
```
fire_wizard      -> burn  : isabette yanma stack'i; eşik dolunca patlama hasarı.
                            Söndürme: dodge-roll / hareket / kaynak harca.
lightning_mage   -> shock : stack dolunca kısa "stun/parry-pencere daralması".
wanderer_magican -> bleed : saldırı yaparken birikir; yüksek bleed'de chip hasar.
(melee knight)   -> stagger-bias: ağır vuruşlar oyuncu posture'ını daha çok doldurur.
```

### Build-up (Sekiro'daki "terror/poison" mantığı)
- Status anında dolmaz; bir **build-up barı** dolunca tetiklenir. Oyuncu doğru
  oynayarak (isabet yememe / söndürme) barın dolmasını engelleyebilir.

### Yansıma etkileşimi
- Parry ile yansıtılan mermi boss'a **kendi status'ünü** uygulayabilir (örn. ateş
  topunu yansıt → boss yanar) → parry'ye ekstra ödül.

## Teknik Dokunulacak Alanlar

- Yeni `lib/status.dart`: `StatusKind`, `StatusInstance`, `StatusController` (bir
  component'e takılan mixin/alan).
- `lib/characters.dart`: `Beat`'e `statusKind` + `statusBuildup` alanları; büyücü
  beat'lerine ekle.
- `lib/player.dart`: `StatusController` ekle; `takeHit`/`_resolveContact` status
  build-up uygula; tick.
- `lib/boss.dart`: yansıyan mermi → boss'a status; `receivePlayerAttack` bleed vb.
- `lib/projectile.dart`: merminin taşıdığı status'ü temas/deflect'te aktar.
- `lib/hud.dart`: status ikon/bar gösterimi.
- `lib/fx.dart` + `lib/audio.dart`: yanma/şok görsel-işitsel.

## Kabul Kriterleri

- Her büyücü mekanik olarak ayrışır (burn/shock/bleed farklı oynanır).
- Status build-up barla birikir; oyuncu önlem alabilir (söndürme/kaçınma).
- Yansıtılan mermi boss'a status uygulayabilir.
- Statusler HUD'da okunur ve performansı bozmadan tick eder.

## Bağlı Sistemler
- `01` (söndürme stamina maliyeti), `03` (yansıma ödülü), `08` (faz bazlı
  status yoğunluğu), `12` (status temizleyen consumable).

## Öncelik
**Orta** — savaşa derinlik ve karakter kimliği katar; çekirdek tamamlandıktan sonra.
