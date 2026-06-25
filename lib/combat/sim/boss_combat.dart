part of '../../boss.dart';

// Faz F: boss.dart god-object'inden `part of` ile aynı kütüphanede ayrıştırıldı.
// Davranış-koruyan saf TAŞIMA: alanlar/statikler Boss'ta kalır, metodlar bu
// extension'a birebir taşındı (yalnızca Boss statiklerine 'Boss.' niteleyici eklendi).
extension BossCombat on Boss {
  // ----------------------------------------------------------------- CONTACT
  void _onContact() {
    final beat = _beat;
    if (_guardCounter) {
      _applyHit(beat, null);
      return;
    }
    if (beat.isRanged) {
      _spawnProjectile(beat);
    } else {
      _resolveContact(beat, null);
    }
  }

  void _spawnProjectile(Beat beat) {
    final from = _topCenter;
    final to = Vector2(
      game.player.position.x,
      game.player.position.y - game.player.size.y * 0.5,
    );
    final frames = beat.projectileKey == null
        ? const <Sprite>[]
        : _sprites.frames(beat.projectileKey!);
    final proj = Projectile(
      from,
      to,
      beat.projectileSpeed,
      frame: () {
        if (frames.isEmpty) return _sprites.frames('idle').first;
        return frames[(_t / 0.06).floor() % frames.length];
      },
      onArrive: (self) => _resolveContact(beat, self),
    );
    game.add(proj);
  }

  // Temas çözümü — SADE MODEL: tek istisna KIRMIZI (guardBreak) = dodge.
  //   guardBreak → dodge doğru; parry cezalandırılır.
  //   diğer her şey → parry VEYA dodge işe yarar (parry denge kırar; en iyisi).
  // i-frame bu beat'i geçersiz kılar mı? Tracking (takip/saplama) HARİÇ: o,
  // dokunulmazlığı delip bulur ve yalnız parry ile karşılanır.
  bool _iFrameBeats(Beat beat) =>
      game.player.isInvulnerable && beat.defense != DefenseProfile.tracking;

  void _resolveContact(Beat beat, Projectile? proj) {
    if (dying) return;
    final p = game.player;
    // Araç+pencere KARARI saf CombatResolver'da (Flame'siz, test edilebilir).
    // Boss yalnız oyuncu/beat durumunu okur ve kararı uygular.
    final isFeint =
        beat.kind == BeatKind.feint || beat.defense == DefenseProfile.feint;
    final decision = CombatResolver.resolveContact(
      defense: beat.defense,
      guardDirection: beat.guardDirection,
      isFeint: isFeint,
      playerInvulnerable: p.isInvulnerable,
      guardMatches: _guardMatches(beat),
      sinceParry: p.sinceParry,
      sinceDodge: p.sinceDodge,
      beatPreWindow: beat.preWindow,
      effectiveParryWindow: p.effectiveParryWindow,
      dodgePre: beat.dodgePre,
    );
    switch (decision.action) {
      case ContactAction.feint:
        _resolveFeint(beat, proj);
      case ContactAction.dodgeSuccess:
        _dodgeSuccess(beat, proj);
      case ContactAction.parrySuccess:
        _parrySuccess(beat, proj);
      case ContactAction.wrongTool:
        _wrongTool(beat, proj, decision.wrongToolLabel!);
      case ContactAction.beginPending:
        _beginPending(beat, proj);
    }
  }

  // ALDATMA (feint) çözümü (09). Telegraf normal saldırı gibi görünür ama vuruş
  // gelmez. Erken/önceden savunan (parry/dodge) oyuncu YEM YUTAR → kısa savunma
  // kilidi; arkadan gelen gerçek beat punish eder. BASMAMAK her zaman güvenli:
  // disiplinli oyuncu cezalanmaz, yalnız refleksle erken basan tuzağa düşer.
  void _resolveFeint(Beat beat, Projectile? proj) {
    proj?.deflect();
    final p = game.player;
    final w = game.actionSystem.feintBaitWindow;
    final baited =
        game.actionSystem.bossFeintTrap &&
        (p.isParrying ||
            p.isDodging ||
            p.isInvulnerable ||
            p.sinceParry <= w ||
            p.sinceDodge <= w);
    if (baited) {
      p.baitPunish(game.actionSystem.feintBaitLock);
      _feintBaitedFollowUp = true; // sıradaki gerçek beat hızlanıp punish etsin
      game.bus.emit(const MetricRecorded(MetricKind.feintBaited));
      // Erken savunma eğilimi → bu oyuncuya daha çok tuzak (parry habit artar).
      _registerHabit(parry: true);
      _comboChainBroken = true;
      game.bus.emit(const SfxRequested(SfxCue.whiff));
      game.bus.emit(SparkRequested(_topCenter, _kAmber));
      game.bus.emit(
        PopupRequested(
          _topCenter,
          'TUZAK!',
          fontSize: 16,
          color: _kAmber,
          rise: 26,
        ),
      );
    } else {
      game.bus.emit(
        PopupRequested(_topCenter, 'ALDATMA', fontSize: 14, color: kGray500),
      );
    }
  }

  void _beginPending(Beat beat, Projectile? proj) {
    _pending = true;
    _pendingGrace = beat.grace;
    _pendingBeat = beat;
    _pendingProjectile = proj;
  }

  void _tickPending(double dt) {
    if (!_pending) return;
    final beat = _pendingBeat!;
    final p = game.player;
    // i-frame penceresine girildiyse temas geçersiz (tracking hariç) (04).
    if (_iFrameBeats(beat)) {
      final proj = _pendingProjectile;
      _clearPending();
      _dodgeSuccess(beat, proj);
      return;
    }
    // Temas sonrası TAZE parry basışı (input-lag affı). Dodge için ayrı taze yol
    // YOK: dodge başarısı yalnız i-frame'den gelir (yukarıda kontrol edildi) (04).
    final freshParry = p.sinceParry <= Boss._freshPress;
    final parryForbidden =
        beat.defense == DefenseProfile.guardBreak ||
        beat.defense == DefenseProfile.thrust;
    if (freshParry && !parryForbidden) {
      final proj = _pendingProjectile;
      _clearPending();
      if (!_guardMatches(beat)) {
        _wrongTool(beat, proj, 'YANLIŞ YÖN!');
        return;
      }
      _parrySuccess(beat, proj);
      return;
    }
    _pendingGrace -= dt;
    if (_pendingGrace <= 0) {
      final proj = _pendingProjectile;
      _clearPending();
      _applyHit(beat, proj);
    }
  }

  bool _guardMatches(Beat beat) {
    return switch (beat.guardDirection) {
      GuardDirection.any => game.player.parryGuard == GuardDirection.any,
      GuardDirection.high => game.player.parryGuard == GuardDirection.high,
      GuardDirection.low => game.player.parryGuard == GuardDirection.low,
    };
  }

  bool tryParryFollowUp(GuardDirection input) {
    if (!game.actionSystem.isTest || dying) return false;
    if (_followUpTimer <= 0 || _followUpGuard == null) return false;
    if (_followUpGuard != input) return false;
    _followUpGuard = null;
    _followUpTimer = 0;
    const hp = 10;
    takeDamage(hp);
    game.player.playParryFollowUp(input);
    game.bus.emit(DamageApplied(hp, toBoss: true));
    game.bus.emit(const SfxRequested(SfxCue.hit));
    game.bus.emit(const HitstopRequested(0.07));
    _hurtT = 0.18;
    game.bus.emit(
      PopupRequested(_topCenter + Vector2(0, 30), '-$hp', fontSize: 19),
    );
    return true;
  }

  // PARRY BAŞARILI — HP DEĞİL POSTURE hasarı + tempo penceresi.
  // Perfect parry (pencerenin ilk dilimi) late'den ölçülebilir biçimde daha
  // ödüllü: ekstra posture + tam hitstop + parlak spark + "ŞING" (03).
  void _parrySuccess(Beat beat, Projectile? proj) {
    final perfect = game.player.classifyParry() == ParryQuality.perfect;
    game.bus.emit(
      SfxRequested(perfect ? SfxCue.parryPerfect : SfxCue.parryLate),
    );
    game.player.onParrySuccess();
    game.bus.emit(ParrySucceeded(perfect: perfect));
    _registerHabit(parry: true);
    _hurtT = 0.30;
    proj?.deflect();
    game.bus.emit(HitstopRequested(perfect ? 0.09 : 0.03));
    game.bus.emit(SparkRequested(_topCenter, perfect ? _kAmber : kBarBlue));
    if (perfect) game.bus.emit(SparkRequested(_topCenter, kBarBlue));

    if (beat.kind == BeatKind.feint) {
      game.bus.emit(
        PopupRequested(_topCenter, 'ALDATMA', fontSize: 14, color: kGray500),
      );
      return;
    }

    _parriedThisCombo++;
    _recentParries++;
    storedCombo = _parriedThisCombo;
    _armParryFollowUp(beat);
    final dmg = perfect
        ? (beat.postureDamage * 1.5).round()
        : beat.postureDamage;
    applyPostureDamage(dmg);
    if (perfect) {
      game.bus.emit(
        PopupRequested(
          _topCenter + Vector2(0, -2),
          'MÜKEMMEL',
          fontSize: 14,
          color: _kAmber,
        ),
      );
    }
    game.bus.emit(
      PopupRequested(
        _topCenter + Vector2(0, perfect ? 16 : 0),
        '-$dmg DENGE',
        fontSize: 15,
        color: kBarBlue,
      ),
    );
  }

  void _armParryFollowUp(Beat beat) {
    if (!game.actionSystem.isTest) return;
    _followUpGuard = switch (beat.guardDirection) {
      GuardDirection.low => GuardDirection.high,
      GuardDirection.high => GuardDirection.low,
      GuardDirection.any => GuardDirection.any,
    };
    _followUpTimer = 0.46;
    final label = switch (_followUpGuard!) {
      GuardDirection.low => '↓ KARŞI',
      GuardDirection.high => '↑ KARŞI',
      GuardDirection.any => 'SPACE KARŞI',
    };
    game.bus.emit(
      PopupRequested(_topCenter + Vector2(0, -24), label, fontSize: 13),
    );
  }

  void _applyHit(Beat beat, Projectile? proj) {
    if (beat.kind == BeatKind.feint || beat.damage <= 0) {
      proj?.deflect();
      return;
    }
    final p = game.player;
    // Son bir kontrol: i-frame penceresine girdiyse darbe geçersiz (tracking hariç).
    if (_iFrameBeats(beat)) {
      _dodgeSuccess(beat, proj);
      return;
    }
    // Oyuncu blok tutuyorsa: HP yerine posture+stamina yer, hasarsız (02).
    if (p.isBlocking) {
      proj?.deflect();
      p.takeBlockedHit(beat);
      _comboChainBroken = true;
      game.bus.emit(SparkRequested(_topCenter, _kAmber));
      game.bus.emit(
        PopupRequested(
          Vector2(
            game.player.position.x,
            game.player.position.y - size.y * 0.9,
          ),
          beat.defense == DefenseProfile.guardBreak ? 'BLOK DELİNDİ' : 'BLOK',
          fontSize: 13,
          color: _kAmber,
          rise: 24,
        ),
      );
      return;
    }
    // NEDEN yedin? Erken bastıysan ritim kırıldı; yakın bastıysan zamanlama;
    // basmadıysan savunmadın.
    final pressed = p.sinceParry < 0.45 || p.sinceDodge < 0.45;
    final String reason;
    if (beat.punishesEarly && pressed) {
      reason = 'ERKEN!'; // delayed/feint: ritmi okumadan bastın
    } else {
      reason = pressed ? 'ZAMANLAMA!' : 'SAVUNMADIN!';
    }
    game.player.takeHit(beat.damage, -1);
    game.bus.emit(DamageApplied(beat.damage, toBoss: false));
    game.bus.emit(
      PopupRequested(
        Vector2(game.player.position.x, game.player.position.y - size.y * 1.05),
        reason,
        fontSize: 14,
        color: kBarRed,
        rise: 30,
      ),
    );
    game.bus.emit(
      PopupRequested(
        Vector2(game.player.position.x, game.player.position.y - size.y * 0.8),
        '-${beat.damage}',
        fontSize: beat.damage >= 20 ? 23 : 17,
      ),
    );
    _comboChainBroken = true; // vuruş yedin: tam-parry bonusu iptal
  }

  // DODGE BAŞARILI — hasarsız sıyrılma. Perfect dodge (i-frame'in erken dilimi)
  // her zaman açılış + slow-mo verir; committed/thrust de açar; hafif geç dodge
  // yalnız kurtarır (04).
  void _dodgeSuccess(Beat beat, Projectile? proj) {
    final perfect = game.player.isPerfectDodge;
    game.bus.emit(const SfxRequested(SfxCue.dodge));
    game.player.onDodgeSuccess();
    game.bus.emit(DodgeSucceeded(perfect: perfect));
    _registerHabit(dodge: true);
    _recentDodges++;
    proj?.deflect();
    _comboChainBroken = true; // parry zinciri kırıldı (bonus yok)

    if (beat.kind == BeatKind.feint) {
      game.bus.emit(
        PopupRequested(_topCenter, 'ALDATMA', fontSize: 14, color: kGray500),
      );
      return;
    }

    // Açılış YALNIZ committed/kırmızı/thrust beat'lerde: dodge bunların doğru
    // cevabı. Normal saldırının asıl ödül aracı YÖNLÜ PARRY'dir (posture +
    // karşı vuruş); dodge onları açmaz, yoksa parry'nin değeri düşer.
    final opens = beat.punishOnDodge || beat.defense == DefenseProfile.thrust;
    // Perfect dodge HER durumda slow-mo flourish verir (his ödülü).
    if (perfect) {
      game.bus.emit(const HitstopRequested(0.12));
      game.bus.emit(SparkRequested(_topCenter, _kAmber));
    }
    if (opens) {
      game.bus.emit(
        PopupRequested(
          _topCenter,
          perfect ? 'TAM SIYRILMA!' : 'AÇIK!',
          fontSize: perfect ? 16 : 15,
          color: perfect ? _kAmber : kGray700,
          rise: 28,
        ),
      );
      // Perfect dodge daha uzun punish penceresi açar.
      _enter(BossState.offBalance, perfect ? Boss.punishWindow * 1.4 : Boss.punishWindow);
    } else {
      // Normal saldırıyı sıyırdın: hasarsız kurtuluş (+perfect'te slow-mo) ama
      // boss komboya DEVAM eder. Açmak istiyorsan yönlü parry'le.
      game.bus.emit(
        PopupRequested(
          _topCenter,
          perfect ? 'TAM SIYRILMA' : 'SIYRILDIN',
          fontSize: perfect ? 14 : 13,
          color: perfect ? _kAmber : kGray500,
          rise: 24,
        ),
      );
    }
  }

  // YANLIŞ ARAÇ: guardBreak'e parry / tracking'e dodge → ceza, boss devam eder.
  void _wrongTool(Beat beat, Projectile? proj, String label) {
    proj?.deflect();
    final chip = (beat.damage * 0.35).round();
    game.player.getStunned(0.4, chip: chip);
    game.bus.emit(
      PopupRequested(
        Vector2(game.player.position.x, game.player.position.y - size.y * 0.8),
        label,
        fontSize: 14,
        color: kBarRed,
        rise: 30,
      ),
    );
    if (chip > 0) {
      game.bus.emit(
        PopupRequested(
          Vector2(
            game.player.position.x,
            game.player.position.y - size.y * 0.5,
          ),
          '-$chip',
          fontSize: 16,
        ),
      );
    }
    _comboChainBroken = true;
  }


  // OYUNCU SALDIRISI temas etti (game.onPlayerAttackContact menzili doğrular).
  // staggered → F çoklu küçük HP, G infaz; offBalance → HP; kapalıysa posture chip.
  void receivePlayerAttack(
    PlayerAttackType type, {
    int comboStep = 0,
    bool finisher = false,
  }) {
    if (dying) return;
    // Faz geçişi sahnesi DOKUNULMAZ: oyuncu haksız hasar veremez (08).
    if (state == BossState.phaseTransition) {
      game.bus.emit(const SfxRequested(SfxCue.whiff));
      game.bus.emit(
        PopupRequested(_topCenter, 'DOKUNULMAZ', fontSize: 13, color: kGray500),
      );
      return;
    }
    _registerHabit(attack: true);
    // Kombo derinliği / finisher → hasar çarpanı (05).
    final double comboMult = finisher ? 1.5 : (1 + comboStep * 0.12);

    if (state == BossState.guard) {
      if (type == PlayerAttackType.heavy) {
        _shieldHeavyPunish();
      } else {
        _shieldLightBlock();
      }
    } else if (state == BossState.idle && game.actionSystem.isTest) {
      final hp = type == PlayerAttackType.light ? 10 : 0;
      if (hp <= 0) {
        game.bus.emit(const SfxRequested(SfxCue.whiff));
        game.bus.emit(
          PopupRequested(_topCenter, 'ETKİ YOK', fontSize: 13, color: kGray500),
        );
        return;
      }
      takeDamage(hp);
      game.bus.emit(DamageApplied(hp, toBoss: true));
      game.bus.emit(const SfxRequested(SfxCue.hit));
      game.bus.emit(const HitstopRequested(0.06));
      _hurtT = 0.16;
      game.bus.emit(
        PopupRequested(_topCenter + Vector2(0, 30), '-$hp', fontSize: 18),
      );
    } else if (game.testAttackMode == TestAttackMode.defend) {
      game.bus.emit(const SfxRequested(SfxCue.whiff));
      game.bus.emit(
        PopupRequested(_topCenter, 'ETKİ YOK', fontSize: 13, color: kGray500),
      );
    } else if (state == BossState.staggered) {
      if (type == PlayerAttackType.heavy) {
        _performDeathblow(type, finisher: finisher);
      } else {
        _performStaggerLightHit();
      }
    } else if (state == BossState.offBalance) {
      final hp = ((Boss.attackHpOpen + (game.player.hasTempo ? 4 : 0)) * comboMult)
          .round();
      takeDamage(hp);
      game.bus.emit(DamageApplied(hp, toBoss: true));
      game.bus.emit(
        SfxRequested(
          type == PlayerAttackType.heavy ? SfxCue.heavyHit : SfxCue.hit,
        ),
      );
      game.bus.emit(
        HitstopRequested(type == PlayerAttackType.heavy ? 0.11 : 0.08),
      );
      if (type == PlayerAttackType.heavy) {
        game.bus.emit(ShakeRequested(4, 0.16));
      }
      game.bus.emit(ComboTextRequested(_topCenter, finisher ? 'FİNİSHER' : 'CEZA'));
      game.bus.emit(
        PopupRequested(_topCenter + Vector2(0, 30), '-$hp', fontSize: 20),
      );
      _decidePressure();
    } else {
      // Boss açık değil. GREED: oyuncu açık olmadığı halde saldırıyor. Boss bunu
      // okuyup (olasılıksal, fazla göre sıklaşan) hızlı bir karşı-beat başlatabilir
      // → F spam'i artık risksiz değil (09). Aksi halde yalnız riskli posture chip.
      if (_maybeGreedPunish()) return;
      applyPostureDamage(Boss.attackPostureChip);
      game.bus.emit(const SfxRequested(SfxCue.parry));
      game.bus.emit(SparkRequested(_topCenter, _kAmber));
      game.bus.emit(
        PopupRequested(
          _topCenter,
          '-${Boss.attackPostureChip} DENGE',
          fontSize: 13,
          color: kBarBlue,
        ),
      );
    }
  }

  void _shieldLightBlock() {
    game.player.takePostureDamage(22);
    game.bus.emit(const SfxRequested(SfxCue.block));
    game.bus.emit(const HitstopRequested(0.06));
    game.bus.emit(SparkRequested(_topCenter, _kAmber));
    game.bus.emit(
      PopupRequested(_topCenter, 'KALKAN', fontSize: 15, color: _kAmber),
    );
    game.bus.emit(
      PopupRequested(
        Vector2(game.player.position.x, game.player.position.y - size.y * 0.72),
        'DENGE -22',
        fontSize: 13,
        color: kBarRed,
        rise: 24,
      ),
    );
  }

  // GREED PUNISH (09): boss açık değilken saldıran oyuncuya hızlı karşı-beat.
  // Parry'lenebilir (preWindow>0) → ceza adil: reflekssiz over-extend yer, usta
  // savunma kurtarır. Faz arttıkça olasılık ve hız artar.
  bool _maybeGreedPunish() {
    if (!game.actionSystem.bossGreedPunish || dying) return false;
    if (state == BossState.phaseTransition) return false;
    if (!_brain.greedPunishRoll(
      game.actionSystem.greedPunishChance,
      phase,
      _rng,
    )) {
      return false;
    }
    game.bus.emit(const MetricRecorded(MetricKind.greedPunished));
    game.bus.emit(ComboTextRequested(_topCenter, 'AÇGÖZLÜ!'));
    game.bus.emit(const SfxRequested(SfxCue.whiff));
    _startCounterBeat(windup: 0.18 - phase * 0.02, damage: 14);
    return true;
  }

  // GUARD-BREAK PUNISH (09): oyuncunun postürü kırılıp açık kaldıysa boss GARANTİ
  // hızlı punish başlatır. Oyuncu zaten kilitli olduğundan bu beat'i karşılayamaz.
  void _maybeGuardBreakPunish() {
    if (!game.actionSystem.bossGuardBreakPunish || dying) return;
    if (state == BossState.staggered ||
        state == BossState.phaseTransition ||
        state == BossState.offBalance) {
      return;
    }
    game.bus.emit(const MetricRecorded(MetricKind.guardBreakPunished));
    game.bus.emit(ComboTextRequested(_topCenter, 'SAVUNMA KIRIK!'));
    _startCounterBeat(windup: 0.22, damage: 16);
  }

  // Tek-beat hızlı punish komboyu kur ve windup'a gir (greed / guard-break).
  void _startCounterBeat({required double windup, required int damage}) {
    _clearPending();
    _beatOverrides.clear();
    _comboChainBroken = true;
    _guardCounter = false;
    final source = def.pattern.beats.last;
    final counter = Beat(
      kind: source.kind == BeatKind.feint ? BeatKind.meleeLight : source.kind,
      defense: DefenseProfile.normal,
      animKey: source.animKey,
      windup: windup.clamp(0.1, 1.0),
      active: source.active,
      recover: source.recover,
      gapAfter: .18,
      preWindow: 0.12,
      grace: 0.05,
      dodgePre: 0.22,
      damage: damage,
      postureDamage: 0,
      punishOnDodge: false,
      mustDefend: true,
      projectileKey: source.projectileKey,
      projectileSpeed: source.projectileSpeed,
    );
    _activeCombo = ComboPattern([counter], staggerBonus: 0);
    _nonFeintTotal = 1;
    _parriedThisCombo = 0;
    _recentParries = 0;
    _recentDodges = 0;
    _adaptedThisCombo = true; // tek-beat punish tekrar dönüştürülmesin
    storedCombo = 0;
    _beatIndex = 0;
    _enter(BossState.windup, counter.windup);
  }

  void _shieldHeavyPunish() {
    _clearPending();
    _beatOverrides.clear();
    _comboChainBroken = true;
    game.player.breakPosture();
    game.bus.emit(const SfxRequested(SfxCue.block));
    game.bus.emit(const HitstopRequested(0.09));
    game.bus.emit(SparkRequested(_topCenter, _kAmber));
    game.bus.emit(
      PopupRequested(_topCenter, 'AĞIR HATA!', fontSize: 16, color: _kAmber),
    );
    game.bus.emit(
      PopupRequested(
        Vector2(game.player.position.x, game.player.position.y - size.y * 0.72),
        'DENGE SIFIR',
        fontSize: 14,
        color: kBarRed,
        rise: 28,
      ),
    );

    final source = def.pattern.beats[2];
    final counter = Beat(
      kind: source.kind,
      defense: DefenseProfile.normal,
      animKey: source.animKey,
      windup: .18,
      active: source.active,
      recover: source.recover,
      gapAfter: .18,
      preWindow: 0,
      grace: 0,
      dodgePre: 0,
      damage: source.damage,
      postureDamage: 0,
      punishOnDodge: false,
      mustDefend: true,
      projectileKey: source.projectileKey,
      projectileSpeed: source.projectileSpeed,
    );
    _activeCombo = ComboPattern([counter], staggerBonus: 0);
    _nonFeintTotal = 1;
    _parriedThisCombo = 0;
    storedCombo = 0;
    _guardCounter = true;
    _beatIndex = 0;
    _enter(BossState.windup, counter.windup);
  }

}
