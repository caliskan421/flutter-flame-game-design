# FAZ D — Animation Binding (mekanik ↔ asset kontratı)

> **Durum:** ✅ Bitti — AnimationBinding+markerFrames+HitboxSpec; attackFrame binding okur (fallback korunur), knight_1+samuray binding'li, davranış birebir. analyze temiz, 111 test yeşil. D5 (marker→event köprüsü) opsiyonel olarak ertelendi.
> **Bağımlılık:** **Faz B bitmiş olmalı.** **Faz C ile paralel** (C'nin `ActionTimeline`'ını okur; ayrı dosyalar). C bittiyse daha temiz oturur.
> **Tür:** Refactor + altyapı — davranış DEĞİŞMEZ; "darbe karesi" bilgisi sanatçı verisi olur.
> **Referans:** `doc/architecture.md` §7 (tümü), §6.2 (Beat→AnimationBinding), §16 (ilke 3).

---

## 0. Tek cümle
"Hangi sprite karesi temas/telegraf karesi?" bilgisini kodun içinden çıkarıp **`AnimationBinding.markerFrames`** verisine taşı; `sprite_strip.dart` bu binding'i okusun. Mekanik (`active` süresi) otorite kalır, görsel onu **hizalanmış** şekilde anlatır.

## 1. Neden
- Şu an mekanik temas (`active` penceresi) ile görsel temas karesi `sprite_strip.dart` `attackFrame` mantığında örtük (sprite_strip.dart:1–102). Sheet değişince hizalama elle düzeltilmeli (D7 komşusu).
- `architecture.md` §7.1: "Mekanik otorite; asset anlatır" — ama oyuncunun okuduğu kareler boş geçilmemeli; contact frame `active`'e yakın hizalanmalı.

## 2. Kapsam

**DAHİL:**
- `lib/presentation/animation_binding.dart`: `AnimationBinding { id, sheetKey, frameTime, markerFrames }` (§7.2).
- `sprite_strip.dart` (`SpriteStripBank`) `attackFrame`'i binding'in `markerFrames`'ini (`contact`, `telegraph`, `anticipation`, `recover`) okuyacak şekilde uyarla.
- İlk iki karakter için binding tanımı: **samuray (oyuncu, `kPlayerDef`)** ve **knight_1 (`kTestOpponent`)** — her `attack1/2/3` için marker kareleri.
- `HitboxSpec { x, y, width, height }` modeli (§7.4) — **ayağa normalize** koordinat standardı (henüz tüm hitbox'ları taşımak şart değil; model + samuray/knight_1 örneği).

**HARİÇ:**
- Tüm roster'ı (3 şövalye + 3 büyücü) binding'e taşımak → kademeli, sonraki iş.
- Yeni sprite/asset üretmek (kural §7.3: yeni mekanik ≠ yeni sprite).
- Mekanik süreleri değiştirmek (asset'e göre mekanik yazmak yasak — §14).

## 3. Dokunulacak / eklenecek dosyalar

| Dosya | İş |
|---|---|
| `lib/presentation/animation_binding.dart` (yeni) | `AnimationBinding` + `markerFrames` modeli. |
| `lib/combat/rules/hitbox_model.dart` (yeni) | `HitboxSpec` (ayağa normalize; ham piksele bağlanmaz). |
| `lib/sprite_strip.dart` | `attackFrame(...)` binding'in marker karelerini okusun; mevcut esnetme davranışını koru. |
| `lib/characters.dart` | `CharacterDef`/`Beat`'e `animationBindingId` referansı (Faz C'de player tarafına eklendi; burada boss `Beat`'lerine de). |
| `lib/combat/data/move_def.dart` (Faz C'den) | `animationBindingId` artık gerçek binding'e çözülür. |

### AnimationBinding iskeleti (§7.2)
```dart
class AnimationBinding {
  final String id;
  final String sheetKey;
  final double frameTime;               // kare süresi
  final Map<String, int> markerFrames;  // 'contact':2, 'telegraph':1, 'anticipation':1, 'recover':3
  const AnimationBinding({required this.id, required this.sheetKey, this.frameTime = 0.08, this.markerFrames = const {}});
}
```
Çalışan örnek (§7.2):
```text
move: knight_1.attack2
timeline:  windup 0.00-0.44 | active 0.44-0.59 | recover 0.59-0.85
binding:   sheet attack2.png  markerFrames: anticipation:1  contact:2  recover:3
→ contact (kare 2) active penceresine hizalı; "darbe karesi" sanatçı verisi, mekanik ayrı.
```

## 4. Adım adım görevler

- [ ] **D1 — AnimationBinding modeli.** `presentation/animation_binding.dart`'ı yaz. `id` ile `PlayerMoveDef.animationBindingId`/boss `Beat` eşleşir.
- [ ] **D2 — HitboxSpec modeli.** `combat/rules/hitbox_model.dart`: koordinatlar actor ayağına göre normalize (0..1 veya feet-relative; ham sprite pikseli DEĞİL). Doc yorumuyla net belgelendir.
- [ ] **D3 — sprite_strip binding okur.** `attackFrame`'i `markerFrames` üzerinden faz→kare eşlemesi yapacak şekilde uyarla. Marker yoksa **mevcut davranışa düş** (geriye uyumlu). Görsel çıktı samuray + knight_1 için birebir aynı kalmalı.
- [ ] **D4 — Samuray + knight_1 binding'leri.** `kPlayerDef` ve `kTestOpponent`'in attack sheet'leri için `markerFrames` tanımla (mevcut görsel temas karesini gözlemleyerek; `active` penceresine hizala). `characters.dart`'taki ilgili `Beat`/`CharacterDef`'e `animationBindingId` bağla.
- [ ] **D5 — Marker → event köprüsü (opsiyonel, Faz B ile uyumlu).** `ActionEventMarker`/`markerFrames`'teki `contact` anı, sunum tarafında (CombatPresenter) ses/VFX tetiğine bağlanabilir; ama **mekanik temas hâlâ `active` penceresinden** belirlenir.
- [ ] **D6 — Test + analyze + duman.** Binding çözümü testi; oyunda samuray ve knight_1 saldırı animasyonu + temas hissi **birebir** eski gibi.

## 5. Kabul kriterleri
- "Darbe karesi = kare N" bilgisi **veride** (`markerFrames`), kodda değil.
- `sprite_strip.dart` binding okur; binding yoksa eski davranışa düşer (regresyon yok).
- Samuray + knight_1 için binding tanımlı ve görsel sonuç değişmemiş.
- `HitboxSpec` ayağa-normalize standardı belgeli; en az bir örnek (knight_1) bu standartta.
- Mekanik süreler (timeline `active`) değişmedi — asset'e göre mekanik yeniden yazılmadı.

## 6. Test planı
- `test/animation_binding_test.dart`: `markerFrames` çözümü; eksik marker → fallback; contact karesinin `active` penceresine düştüğünü doğrulayan basit hizalama asserti (timeline + binding birlikte).
- Mevcut `characters_test.dart` (sheet/frame doğrulamaları) yeşil kalır.
- Elle: samuray light/heavy + knight_1 attack1/2/3 animasyonu eskisiyle aynı; temas anı ses/VFX yerinde.

## 7. Riskler & geri alma
- **Risk:** Marker karesini yanlış seçmek → görsel temas mekanik temastan kayar. **Önlem:** §7.1 kuralı — contact karesini `active` penceresine yakın hizala; göz kontrolü.
- **Risk:** `attackFrame` yeniden yazımı diğer sheet'leri bozar. **Önlem:** binding yoksa **kesin eski yol** (fallback) — yalnız samuray/knight_1 binding'li.
- **Geri alma:** binding tamamen opsiyonel katman; kaldırınca eski davranış döner.

## 8. Doğrulama komutları
```bash
flutter analyze
flutter test
flutter run   # samuray + knight_1 animasyon/temas hissi elle
```
