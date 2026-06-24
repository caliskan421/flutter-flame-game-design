// ============================================================================
//  EVENT BUS  —  minik senkron combat olay kanalı (Faz B)
// ----------------------------------------------------------------------------
//  Combat kararı (boss.dart / combat/rules) artık doğrudan Sfx/spawnPopup/metrics
//  çağırmaz; bir `CombatEvent` yayar. Sunum (CombatPresenter) ve ileride domain
//  (flag) bu event'lere abone olur. Tek-yön bağımlılık: yayan taraf aboneleri
//  bilmez (D3/D4).
//
//  * Senkron + FIFO: emit anında abonelere yayıldığı sırayla çağrılır → ses /
//    slow-mo zamanlaması mevcut çağrı sırasıyla birebir korunur.
//  * Exception-safe: bir abone patlarsa diğerleri yine çalışır.
// ============================================================================
import '../combat/rules/combat_event.dart';

typedef CombatEventHandler = void Function(CombatEvent event);

class EventBus {
  final List<CombatEventHandler> _handlers = <CombatEventHandler>[];

  /// Abone ekler; dönen kapatma fonksiyonu çağrılınca aboneliği kaldırır.
  void Function() subscribe(CombatEventHandler handler) {
    _handlers.add(handler);
    return () => _handlers.remove(handler);
  }

  /// Olayı tüm abonelere ekleniş sırasında yayar. Yayım sırasında abone
  /// listesi değişse de güvenli olsun diye bir kopya üzerinde gezinir; bir
  /// abone hata fırlatırsa kalanlar etkilenmez.
  void emit(CombatEvent event) {
    for (final handler in List<CombatEventHandler>.of(_handlers)) {
      try {
        handler(event);
      } catch (_) {
        // Bir abonenin hatası diğer aboneleri ve combat akışını durdurmaz.
      }
    }
  }
}
