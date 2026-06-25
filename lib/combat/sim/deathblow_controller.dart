part of '../../boss.dart';

// Faz F: boss.dart god-object'inden `part of` ile aynı kütüphanede ayrıştırıldı.
// Davranış-koruyan saf TAŞIMA: alanlar/statikler Boss'ta kalır, metodlar bu
// extension'a birebir taşındı (yalnızca Boss statiklerine 'Boss.' niteleyici eklendi).
extension BossDeathblow on Boss {
  void _queueDeathblowImpact({
    required double delay,
    required int hpBefore,
    required bool heavy,
  }) {
    _queuedDeathblowImpactDelay = delay.clamp(0, 999).toDouble();
    _queuedDeathblowHpBefore = hpBefore;
    _queuedDeathblowHeavy = heavy;
  }

  void _tickQueuedDeathblowImpact(double dt) {
    if (_queuedDeathblowImpactDelay < 0) return;
    _queuedDeathblowImpactDelay -= dt;
    if (_queuedDeathblowImpactDelay > 0) return;
    final hpBefore = _queuedDeathblowHpBefore;
    final heavy = _queuedDeathblowHeavy;
    _queuedDeathblowImpactDelay = -1;
    _queuedDeathblowHpBefore = 0;
    _queuedDeathblowHeavy = false;
    _resolveDeathblowImpact(hpBefore: hpBefore, heavy: heavy);
  }
  // -------------------------------------------------------- FAZ GEÇİŞİ (08)
  // Faz yalnız tempo çarpanı değil: eşik AŞILINCA (yalnız zorlaşma yönünde) kısa,
  // dokunulmaz bir staging. Sandbox'ta kapalı (pratik bölünmesin). Sahnelendiyse
  // true döner (çağıran baskı kararı vermez).
  bool _maybePhaseTransition() {
    final ph = phase;
    if (!game.actionSystem.bossPhaseStaging) {
      _lastPhase = ph;
      return false;
    }
    if (ph > _lastPhase && !dying) {
      _lastPhase = ph;
      _enterPhaseTransition();
      return true;
    }
    _lastPhase = ph;
    return false;
  }

  void _enterPhaseTransition({double hurtHold = 0, bool playSfx = true}) {
    _clearPending();
    _beatIndex = -1;
    _activeCombo = null;
    _guardCounter = false;
    _phaseTransitionHurtHold = hurtHold;
    _posture.forceFull();
    position.x = _basePos.x;
    // Sinematik: kükreme + orta sarsıntı + kısa slow-mo + uyarı yazısı.
    final label = phase >= 2 ? 'III. FAZ' : 'II. FAZ';
    game.bus.emit(ComboTextRequested(_topCenter, label));
    game.bus.emit(PostureBreakFxRequested(_topCenter, color: _kThrust, scale: 1.2));
    game.bus.emit(const VignetteRequested(
      color: Color(0xFF6A3DD0),
      maxLife: 0.7,
      peakAlpha: 70,
    ));
    if (playSfx) game.bus.emit(const SfxRequested(SfxCue.phaseShift));
    game.bus.emit(ShakeRequested(8, 0.5));
    game.bus.emit(const SlowmoRequested(0.45, 0.5));
    game.bus.emit(PhaseChanged(phase));
    _enter(
      BossState.phaseTransition,
      game.actionSystem.phaseTransitionDuration,
    );
  }

  // -------------------------------------------------------- DEATHBLOW (06)
  void _performStaggerLightHit() {
    if (dying) return;
    final hpBefore = health;
    takeDamage(Boss.attackHpStaggeredLight);
    final dealt = hpBefore - health;
    if (dealt <= 0) {
      game.bus.emit(const SfxRequested(SfxCue.whiff));
      game.bus.emit(
        PopupRequested(_topCenter, 'ETKİ YOK', fontSize: 13, color: kGray500),
      );
      return;
    }
    game.bus.emit(DamageApplied(dealt, toBoss: true));
    game.bus.emit(const SfxRequested(SfxCue.hit));
    game.bus.emit(const HitstopRequested(0.07));
    _hurtT = 0.18;
    game.bus.emit(ComboTextRequested(_topCenter, 'KESİK'));
    game.bus.emit(
      PopupRequested(_topCenter + Vector2(0, 30), '-$dealt', fontSize: 19),
    );
    if (health <= 0 && game.actionSystem.bossCanDie) die(playHit: false);
  }

  // Denge kırıkken (staggered) G/ağır saldırı İNFAZ tetikler: slow-mo + kırmızı
  // vinyet + güçlü ses + büyük sarsıntı. Düşük HP'de veya son segmentte öldürür;
  // aksi halde segment siler → faz geçişi sahnesi gelir.
  void _performDeathblow(PlayerAttackType type, {bool finisher = false}) {
    if (dying) return;
    if (_queuedDeathblowImpactDelay >= 0) return;
    final int hpBefore = health;

    final bool heavy = type == PlayerAttackType.heavy || finisher;
    final delay = heavy ? Boss.heavyDeathblowSfxDelay : 0.0;
    _timer = max(_timer, delay + 0.05);
    _queueDeathblowImpact(delay: delay, hpBefore: hpBefore, heavy: heavy);
  }

  void _resolveDeathblowImpact({required int hpBefore, required bool heavy}) {
    if (dying) return;
    deathblowsDone++;

    game.bus.emit(ComboTextRequested(_topCenter, heavy ? 'İNFAZ!' : 'İNFAZ'));
    game.bus.emit(
      PostureBreakFxRequested(
        _topCenter,
        color: kBarRed,
        scale: heavy ? 1.9 : 1.7,
      ),
    );
    game.bus.emit(const VignetteRequested());
    game.bus.emit(const SfxRequested(SfxCue.deathblow));
    game.bus.emit(const HitstopRequested(0.16));
    game.bus.emit(
      SlowmoRequested(
        game.actionSystem.deathblowSlowmoDuration,
        game.actionSystem.deathblowSlowmoScale,
      ),
    );
    game.bus.emit(ShakeRequested(heavy ? 14 : 12, 0.5));

    final lethal =
        deathblowsDone >= deathblowsRequired ||
        health <= game.actionSystem.bossExecuteThresholdHp;
    game.bus.emit(Deathblow(lethal: lethal));

    if (lethal && game.actionSystem.bossCanDie) {
      takeDamage(100); // tabana indir → ölüm sekansı
      game.bus.emit(DamageApplied(hpBefore, toBoss: true));
      die(playHit: false);
      return;
    }

    // Segment silindi: HP'yi bir sonraki faz eşiğine düşür (faz görünür değişsin),
    // sonra dokunulmaz faz geçişi sahnesi. Sandbox'ta (staging kapalı) baskıya döner.
    final next = health > 50 ? 50 : (health > 25 ? 25 : 1);
    if (health > next) takeDamage(health - next);
    game.bus.emit(DamageApplied(hpBefore - health, toBoss: true));
    _posture.forceFull();
    _hurtT = 0.3;
    if (game.actionSystem.bossPhaseStaging) {
      _lastPhase = phase;
      _enterPhaseTransition(
        hurtHold: Boss.phaseTransitionDeathblowHurtHold,
        playSfx: false,
      );
    } else {
      _beatIndex = -1;
      _activeCombo = null;
      _decidePressure();
    }
  }
}
