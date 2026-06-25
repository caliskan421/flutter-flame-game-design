part of 'overlays.dart';

class _TestAttackGrid extends StatelessWidget {
  final BossArenaGame game;
  const _TestAttackGrid({required this.game});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _attackButton('TEK ALT', TestAttackMode.attack1),
        _attackButton('TEK ÜST', TestAttackMode.attack2),
        _attackButton('DEFEND 3', TestAttackMode.attack3),
        _attackButton('KALKAN', TestAttackMode.defend),
        _attackButton('HİKAYE MODU', TestAttackMode.combo),
        _attackButton('HAREKET MEKANİKLERİ', TestAttackMode.movement),
      ],
    );
  }

  Widget _attackButton(String label, TestAttackMode mode) {
    return PixelButton(
      label: label,
      selected: game.testAttackMode == mode,
      primary: true,
      controllerFocusScope: 'testSelect',
      onTap: () => game.chooseTestAttack(mode),
    );
  }
}

// ============================================================================
//  TEST PANELİ  —  oynarken preset değiştir / sıfırla / menüye dön
// ============================================================================
