part of 'boss.dart';

// Faz F: boss.dart god-object'inden `part of` ile aynı kütüphanede ayrıştırıldı.
// Davranış-koruyan saf TAŞIMA: alanlar/statikler Boss'ta kalır, metodlar bu
// extension'a birebir taşındı (yalnızca Boss statiklerine 'Boss.' niteleyici eklendi).
extension BossStateMachine on Boss {
  // ------------------------------------------------------------------ MACHINE
  void _machine(double dt) {
    switch (state) {
      case BossState.idle:
        if (_timer <= 0) {
          if (game.testAttackMode == TestAttackMode.defend) {
            enterTestGuard();
          } else {
            _beginNewCombo();
          }
        }
        break;

      case BossState.approach:
        if (def.ranged || game.actionSystem.bossStartsBeatInPlace) {
          // TEST: yaklaşma yürüyüşü yok; bitişik konumda kal, saldırıya başla.
          if (game.actionSystem.lockBossToBaseX) position.x = _basePos.x;
          _startBeat(0);
        } else {
          final target = game.player.position.x + Boss.standGap;
          position.x = max(target, position.x - Boss.walkSpeed * dt);
          if (position.x <= target + 0.5) {
            position.x = target;
            _startBeat(0);
          }
        }
        break;

      case BossState.windup:
        if (_timer <= 0) _enter(BossState.active, _beat.active);
        break;

      case BossState.active:
        if (_justEntered) {
          _justEntered = false;
          _onContact();
          if (state != BossState.active) break;
        }
        if (_timer <= 0) _enter(BossState.recover, _beat.recover);
        break;

      case BossState.recover:
        if (_timer <= 0) {
          if (_beatIndex >= activeBeats.length - 1) {
            _endCombo();
          } else {
            _enter(BossState.gap, _scaled(_beat.gapAfter));
          }
        }
        break;

      case BossState.gap:
        if (_timer <= 0) _startBeat(_beatIndex + 1);
        break;

      case BossState.guard:
        position.x = _basePos.x;
        if (_timer <= 0) {
          _enter(BossState.idle, Boss.testGuardGap);
        }
        break;

      case BossState.offBalance:
        if (_timer <= 0) {
          if (_beatIndex >= activeBeats.length - 1) {
            _endCombo();
          } else {
            _enter(BossState.gap, _scaled(_beat.gapAfter));
          }
        }
        break;

      case BossState.staggered:
        // DEATHBLOW penceresi: oyuncu infaz etmezse süre dolunca toparlanır.
        if (_timer <= 0) {
          _posture.forceFull();
          _beatIndex = -1;
          _activeCombo = null;
          _decidePressure();
        }
        break;

      case BossState.phaseTransition:
        // Kısa, DOKUNULMAZ staging: boss saldırmaz, hasar almaz. Süre dolunca
        // baskıya döner (08).
        position.x = _basePos.x;
        if (_phaseTransitionHurtHold > 0) {
          _phaseTransitionHurtHold = (_phaseTransitionHurtHold - dt)
              .clamp(0, 999)
              .toDouble();
        }
        if (_timer <= 0) {
          _posture.forceFull();
          _beatIndex = -1;
          _activeCombo = null;
          _decidePressure();
        }
        break;

      case BossState.reposition:
        {
          final d = _moveTarget - position.x;
          final step = Boss.walkSpeed * dt * (d.sign);
          if (d.abs() <= step.abs() + 0.5) {
            position.x = _moveTarget;
            _enter(BossState.idle, _scaled(0.5));
          } else {
            position.x += step;
          }
        }
        break;

      case BossState.retreat:
        final target = _basePos.x;
        position.x = min(target, position.x + Boss.runSpeed * dt);
        if (position.x >= target - 0.5) {
          position.x = target;
          _beatIndex = -1;
          _enter(BossState.idle, Boss.idleTime);
        }
        break;
    }
  }

  Beat get _beat => _beatOverrides[_beatIndex] ?? activeBeats[_beatIndex];

  // Yeni kombo turu: havuzdan ağırlıklı seçim, sonra approach (ranged → yerinde).
  void _beginNewCombo() {
    _activeCombo = _pickCombo();
    _beatOverrides.clear();
    _comboChainBroken = false;
    _parriedThisCombo = 0;
    _recentParries = 0;
    _recentDodges = 0;
    _adaptedThisCombo = false;
    _feintBaitedFollowUp = false;
    storedCombo = 0;
    _nonFeintTotal = _activeCombo!.nonFeintCount;
    _enter(BossState.approach, 0);
  }

  // Kombo havuzundan seçim. Oyuncu dodge'a abanıyorsa tracking içeren deseni,
  // parry'e abanıyorsa feint/guardBreak/delayed içeren deseni öne çıkar (BossBrain).
  ComboPattern _pickCombo() => _brain.pickCombo(def.combos, phase, _rng);

  void _startBeat(int i) {
    _beatIndex = i;
    // Kombo-İÇİ ADAPTASYON: sıradaki beat'i oyuncunun son cevaplarına göre dinamik
    // dönüştür (parry'ciye feint, dodge'cuya tracking) — desen ezberlenemesin (09).
    _adaptBeat(i);
    // DELAYED: windup'u runtime ±jitter ile değiştir; metronom ritmi kırılır (09).
    double windup = _beat.windup;
    if (_beat.defense == DefenseProfile.delayed) {
      final j = game.actionSystem.delayedWindupJitter;
      windup = (windup + (_rng.nextDouble() - 0.28) * j).clamp(0.1, 2.0);
    }
    // Tuzak ısırdıysa bu (gerçek) beat hızlanır → savunma kilidi sürerken temas
    // eder, punish GERÇEKTEN bağlanır (09).
    if (_feintBaitedFollowUp) {
      _feintBaitedFollowUp = false;
      windup = min(windup, 0.16);
    }
    _enter(BossState.windup, windup);
  }

  // Bu beat'i oyuncu eğilimine göre dönüştür (yalnız "normal", melee beat'ler).
  // Parry'ye abanan → ALDATMA tuzağı (erken parry'yi boşa düşür, arkadan punish);
  // dodge'a abanan → TRACKING (dodge'u yakalar, parry zorunlu).
  void _adaptBeat(int i) {
    // Boss tarafı kapılar: ayar kapalıysa veya bu kombo zaten dönüştürüldüyse çık
    // (rng burada TÜKETİLMEZ). Karar + rng tüketimi BossBrain'de.
    if (!game.actionSystem.bossInComboAdapt || _adaptedThisCombo) return;
    final adapt = _brain.adaptBeat(
      base: activeBeats[i],
      isLast: i >= activeBeats.length - 1,
      recentParries: _recentParries,
      recentDodges: _recentDodges,
      adaptChance: game.actionSystem.inComboAdaptChance,
      rng: _rng,
    );
    if (adapt == null) return;
    _beatOverrides[i] = adapt.beat;
    if (adapt.reducesNonFeint && _nonFeintTotal > 0) {
      _nonFeintTotal--; // feint tam-parry'ye sayılmaz
    }
    _adaptedThisCombo = true;
  }

  // Kombo bitti. Tüm (feint olmayan) beat'ler parry edildiyse büyük posture
  // hasarı (otomatik HP YOK). Sonra pressure kararı.
  void _endCombo() {
    if (_guardCounter) {
      _guardCounter = false;
      if (game.testAttackMode == TestAttackMode.defend ||
          game.testAttackMode == TestAttackMode.combo) {
        _clearPending();
        _activeCombo = null;
        _beatIndex = -1;
        _enter(BossState.idle, Boss.testGuardGap);
        return;
      }
    }
    if (!_comboChainBroken &&
        _nonFeintTotal > 0 &&
        _parriedThisCombo >= _nonFeintTotal) {
      final bonus = (_activeCombo ?? def.pattern).staggerBonus;
      game.bus.emit(
        ComboTextRequested(_topCenter, '×$_parriedThisCombo  TAM PARRY'),
      );
      game.bus.emit(
        PopupRequested(
          _topCenter + Vector2(0, 34),
          '-$bonus DENGE',
          fontSize: 18,
          color: kBarBlue,
        ),
      );
      applyPostureDamage(bonus);
      if (state == BossState.staggered) return; // kırıldı → stagger sürüyor
      _hurtT = 0.3;
    }
    _decidePressure();
  }

  // ----------------------------------------------------------- PRESSURE LOOP
  // Kombo/punish çözülünce: eski yere dönmek yerine baskıyı sürdür.
  void _decidePressure() {
    _clearPending();
    _beatIndex = -1;
    _activeCombo = null;
    // Faz eşiği aşıldıysa baskı yerine önce kısa faz geçişi sahnesi (08).
    if (_maybePhaseTransition()) return;
    if (game.testAttackMode == TestAttackMode.defend ||
        game.testAttackMode == TestAttackMode.combo) {
      position.x = _basePos.x;
      _enter(BossState.guard, Boss.testGuardDuration);
      return;
    }
    // TEST: yer değiştirme/geri çekilme yok. Yerinde kısa düşün → yeni kombo.
    if (game.actionSystem.bossKeepsPressureInPlace) {
      position.x = _basePos.x;
      _enter(BossState.idle, _scaled(0.45));
      return;
    }
    final ph = phase;
    final chainChance = ph >= 2 ? 0.80 : (ph == 1 ? 0.60 : 0.42);
    final r = _rng.nextDouble();
    if (r < chainChance) {
      _enter(
        BossState.idle,
        _scaled(0.45),
      ); // kısa düşün → yeni kombo (yerinde)
    } else if (r < chainChance + 0.32) {
      final side = Boss.standGap * (0.8 + _rng.nextDouble() * 0.9);
      _moveTarget = _clampX(game.player.position.x + side);
      _enter(BossState.reposition, 0);
    } else {
      _enter(BossState.retreat, 0); // tam reset (nadir)
    }
  }

  double _clampX(double x) {
    final r = game.arenaRect;
    if (r.isEmpty) return x;
    return x.clamp(r.left + 70, r.right - 50).toDouble();
  }
}
