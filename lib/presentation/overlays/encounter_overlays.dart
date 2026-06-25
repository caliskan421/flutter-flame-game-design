part of 'overlays.dart';

class EncounterDialogueOverlay extends StatefulWidget {
  final BossArenaGame game;
  const EncounterDialogueOverlay(this.game, {super.key});
  @override
  State<EncounterDialogueOverlay> createState() =>
      _EncounterDialogueOverlayState();
}

class _EncounterDialogueOverlayState extends State<EncounterDialogueOverlay> {
  int _line = 0;

  @override
  Widget build(BuildContext context) {
    final node = widget.game.activeDialogue;
    if (node == null || node.lines.isEmpty) return const SizedBox.shrink();
    final idx = _line.clamp(0, node.lines.length - 1);
    final line = node.lines[idx];
    final isLast = idx >= node.lines.length - 1;
    return _Scrim(
      child: PixelFrame(
        width: 620,
        padding: const EdgeInsets.fromLTRB(34, 30, 34, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Kicker('DİYALOG'),
            const SizedBox(height: 8),
            _Title(line.speaker.toUpperCase(), size: 22),
            const SizedBox(height: 14),
            _Body(line.text),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: PixelButton(
                label: isLast ? 'DEVAM' : 'İLERİ',
                controllerFocusScope: 'dialogue',
                onTap: () {
                  if (isLast) {
                    widget.game.dialogueAdvance();
                  } else {
                    setState(() => _line++);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seçim: prompt + seçenekler. Tıklama game.choicePick(i) komutu yollar.
class EncounterChoiceOverlay extends StatelessWidget {
  final BossArenaGame game;
  const EncounterChoiceOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final choice = game.activeChoice;
    if (choice == null) return const SizedBox.shrink();
    return _Scrim(
      child: PixelFrame(
        width: 620,
        padding: const EdgeInsets.fromLTRB(34, 30, 34, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Kicker('KARAR'),
            const SizedBox(height: 8),
            _Title(choice.prompt, size: 22),
            const SizedBox(height: 18),
            for (var i = 0; i < choice.options.length; i++) ...[
              PixelButton(
                label: choice.options[i].label,
                width: double.infinity,
                primary: i == 0,
                controllerFocusScope: 'choice',
                onTap: () => game.choicePick(i),
              ),
              if (choice.options[i].hint != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    choice.options[i].hint!,
                    style: const TextStyle(
                      color: kUiGreenDark,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// Zar sonucu: 1d20 + stat vs DC; başarı/başarısızlık. game.diceAdvance() ile devam.
class EncounterDiceOverlay extends StatelessWidget {
  final BossArenaGame game;
  const EncounterDiceOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final res = game.activeDiceResult;
    if (res == null) return const SizedBox.shrink();
    final rollStr = res.rolls.join(' + ');
    return _Scrim(
      child: PixelFrame(
        width: 520,
        padding: const EdgeInsets.fromLTRB(34, 30, 34, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Kicker('ZAR — GİZLİLİK'),
            const SizedBox(height: 8),
            Text(
              res.success ? 'BAŞARILI' : 'BAŞARISIZ',
              style: TextStyle(
                color: res.success ? kBarGreen : kBarRed,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 14),
            _Body(
              '1d20: [$rollStr]'
              '${res.statBonus != 0 ? '  + gizlilik ${res.statBonus}' : ''}'
              '${res.modifier != 0 ? '  + ${res.modifier}' : ''}'
              '  =  ${res.total}     (DC ${res.difficulty})',
            ),
            const SizedBox(height: 10),
            _Body(
              res.success
                  ? 'Gölgelerden süzüldün. Bekçi seni geç fark edecek — ilk vuruşları yavaş gelir.'
                  : 'Ayak sesin yankılandı. Bekçi tetikte; baştan baskı kuracak.',
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: PixelButton(
                label: 'DEVAM',
                controllerFocusScope: 'dice',
                onTap: game.diceAdvance,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yeni oyun onayı (Faz H): kaydı kalıcı olarak siler. game'e komut yollar.
class ConfirmResetOverlay extends StatelessWidget {
  final BossArenaGame game;
  const ConfirmResetOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return _Scrim(
      child: PixelFrame(
        width: 460,
        padding: const EdgeInsets.fromLTRB(34, 30, 34, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Kicker('YENİ OYUN'),
            const SizedBox(height: 8),
            const _Title('EMİN MİSİN?', size: 28),
            const SizedBox(height: 12),
            const _Body(
              'Tüm ilerleme (flag, onur, tamamlanan encounter) kalıcı olarak '
              'silinecek. Bu işlem geri alınamaz.',
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                PixelButton(
                  label: 'EVET, SIFIRLA',
                  controllerFocusScope: 'confirmReset',
                  onTap: game.confirmNewGame,
                ),
                PixelButton(
                  label: 'İPTAL',
                  primary: false,
                  controllerFocusScope: 'confirmReset',
                  onTap: game.closeResetConfirm,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ödül: zafer anlatısı + kazanılanlar. game.rewardAdvance() ile encounter sonu.
class EncounterRewardOverlay extends StatelessWidget {
  final BossArenaGame game;
  const EncounterRewardOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final step = game.activeReward;
    if (step == null) return const SizedBox.shrink();
    final honor = game.session.scenario.resource('honor');
    return _Scrim(
      child: PixelFrame(
        width: 520,
        padding: const EdgeInsets.fromLTRB(34, 30, 34, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Kicker('ÖDÜL'),
            const SizedBox(height: 8),
            _Title(step.title, size: 26),
            const SizedBox(height: 14),
            _Body(step.text),
            const SizedBox(height: 12),
            Text(
              'Onur: $honor',
              style: const TextStyle(
                color: kUiGreenDark,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: PixelButton(
                label: 'DEVAM',
                controllerFocusScope: 'reward',
                onTap: game.rewardAdvance,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
