# 08 — Boss Faz Geçiş Sistemi

> **Özet:** Boss'un `phase` değeri (HP'ye göre 0/1/2) şu an yalnız **tempoyu
> ölçekler** (`_tempoScale`) ve kombo havuzu ağırlığını etkiler; yeni moveset,
> faz geçiş sahnesi, görsel dönüşüm veya yeni mekanik açılmaz. Sekiro/Soulslike
> bosslarının kimliği faz geçişlerinden gelir. Bu dosya HP fazlarını gerçek
> "ikinci/üçüncü faz" deneyimine dönüştürür.

## Mevcut Durum

- `Boss.phase`: `health<=25 ? 2 : (health<=50 ? 1 : 0)`.
- `_tempoScale`: faz 2 → 0.72, faz 1 → 0.86, faz 0 → 1.0 (saldırılar hızlanır).
- `_pickCombo`: `ComboPattern.minPhase` ile bazı kombolar yalnız düşük HP'de açılır;
  alışkanlığa göre ağırlık.
- `_decidePressure`: faza göre chain olasılığı artar (daha agresif).

## Eksikler / Sorunlar

- Faz geçişi **görünmez**: oyuncu "ikinci faza geçti" anını yaşamaz (staging yok).
- Yeni moveset/mekanik açılmıyor; yalnız aynı kombolar daha hızlı.
- README/redesign'daki "boss faz değişiminde kısa staging" (Faz 5) uygulanmamış.
- Faz, yalnızca boss HP'sine bağlı; posture-break sayısı, süre, oyuncu davranışı
  gibi tetikleyiciler yok.

## Eklenebilecekler (Tam Tasarım)

### Faz geçiş sahnesi (staging)
- Faz eşiği aşılınca kısa, dokunulmaz bir **geçiş anı**:
  - boss geri çekilir / kükrer / poz alır,
  - ekran kısa kararma veya renk değişimi,
  - yeni faz adı/uyarısı ("II. FAZ"),
  - kısa müzik katmanı değişimi.

### Faza özel moveset
- `CharacterDef`'e faz bazlı kombo etiketleri (zaten `minPhase` var → genişlet):
  - Faz 1: yeni feint/delayed beat'ler devreye girer.
  - Faz 2: yeni ranged/AOE, daha uzun kombolar, daha agresif pressure.
- Faza özel **yeni saldırı tipi** (örn. faz 2'de bir guard-break + thrust karışımı).

### Faza özel mekanik açılımları
- Faz 2'de status build-up hızı artar (bkz. `07`).
- Faz 2'de boss posture daha çabuk dolar ama daha çabuk regen eder → tempo baskısı.

### Çok-deathblow ile entegrasyon
- Her deathblow (bkz. `06`) bir faz segmenti bitirir → infaz + faz geçişi birlikte.

### Tetikleyici çeşitliliği
- Yalnız HP değil; "X saniye boyunca hasar yiyemedi" veya "ardışık parry" boss'u
  daha agresif faza itebilir (opsiyonel, ileri seviye).

## Teknik Dokunulacak Alanlar

- `lib/boss.dart`
  - `phase` değişimini izleyen bir `_lastPhase`; değişince `_enterPhaseTransition()`.
  - yeni `BossState.phaseTransition` (dokunulmaz, kısa staging).
  - `_pickCombo`: faza özel havuzun genişletilmesi.
- `lib/characters.dart`: faz bazlı yeni `ComboPattern`/`Beat`'ler (feint, delayed,
  thrust, AOE); `minPhase` kullanımının yaygınlaştırılması.
- `lib/game.dart`: faz geçişinde kısa kamera/efekt + müzik katmanı çağrısı.
- `lib/audio.dart`: faz müziği / geçiş sesi.
- `lib/hud.dart`: faz göstergesi (HP barı segment renkleri).
- `lib/fx.dart`: faz geçiş efekti.

## Kabul Kriterleri

- Faz geçişi oyuncuya net bir an olarak hissedilir (staging + ses + uyarı).
- Her faz görünür biçimde farklı oynanır (yeni beat/mekanik), sadece daha hızlı değil.
- Geçiş anı dokunulmaz ve dengeli (oyuncuyu haksızca yakalamaz).
- Deathblow segmentleriyle (varsa) tutarlı.

## Bağlı Sistemler
- `06_deathblow_infaz_sistemi`, `07_status_efekt_sistemi`,
  `09_boss_ai_adaptasyon_sistemi`, `11_game_feel_feedback_sistemi`.

## Öncelik
**Orta** — içerik derinliği ve boss kimliği; çekirdek savaş oturduktan sonra.
