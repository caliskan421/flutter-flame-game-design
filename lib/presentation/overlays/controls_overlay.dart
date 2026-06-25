part of 'overlays.dart';

class ControlsOverlay extends StatelessWidget {
  final BossArenaGame game;
  const ControlsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = min(screen.width - 28, 780.0);

    return _Scrim(
      child: AnimatedBuilder(
        animation: game.controls,
        builder: (context, _) {
          final controls = game.controls;
          return PixelFrame(
            width: width,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Kicker('AYARLAR'),
                const SizedBox(height: 8),
                const _Title('KONTROLLER', size: 30),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 680;
                    final keyboard = _BindingColumn(
                      title: 'KLAVYE',
                      children: [
                        for (final action in InputSettings.actions)
                          _KeyboardBindingRow(
                            controls: controls,
                            action: action,
                          ),
                      ],
                    );
                    final gamepad = _BindingColumn(
                      title: controls.hasGamepad
                          ? controls.gamepads.first.name.toUpperCase()
                          : 'CONTROLLER',
                      children: controls.hasGamepad
                          ? [
                              for (final action in InputSettings.actions)
                                _GamepadBindingRow(
                                  controls: controls,
                                  action: action,
                                ),
                            ]
                          : [
                              const _StatusLine('CONTROLLER BAĞLI DEĞİL'),
                              const SizedBox(height: 10),
                              PixelButton(
                                label: 'YENİLE',
                                primary: false,
                                controllerFocusScope: 'controls',
                                onTap: () => unawaited(game.refreshGamepads()),
                              ),
                            ],
                    );

                    if (narrow) {
                      return Column(
                        children: [
                          keyboard,
                          const SizedBox(height: 14),
                          gamepad,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: keyboard),
                        const SizedBox(width: 14),
                        Expanded(child: gamepad),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    PixelButton(
                      label: 'VARSAYILAN',
                      primary: false,
                      controllerFocusScope: 'controls',
                      onTap: controls.restoreDefaults,
                    ),
                    PixelButton(
                      label: 'KAPAT',
                      controllerFocusScope: 'controls',
                      onTap: game.closeControlsOverlay,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BindingColumn extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _BindingColumn({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kUiParchEdge.withAlpha(80),
        border: Border.all(color: kUiWood, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kTextDark,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _KeyboardBindingRow extends StatelessWidget {
  final InputSettings controls;
  final ArenaInputAction action;

  const _KeyboardBindingRow({required this.controls, required this.action});

  @override
  Widget build(BuildContext context) {
    final capturing = controls.keyboardCaptureAction == action;
    final label = capturing
        ? 'TUŞA BAS'
        : keyboardKeyLabel(controls.keyboardBindingFor(action));
    return _BindingRow(
      action: action,
      bindingLabel: label,
      capturing: capturing,
      controllerFocusable: false,
      onTap: () => controls.startKeyboardCapture(action),
    );
  }
}

class _GamepadBindingRow extends StatelessWidget {
  final InputSettings controls;
  final ArenaInputAction action;

  const _GamepadBindingRow({required this.controls, required this.action});

  @override
  Widget build(BuildContext context) {
    final capturing = controls.gamepadCaptureAction == action;
    final label = capturing
        ? 'TUŞA BAS'
        : controls.gamepadBindingFor(action).label;
    return _BindingRow(
      action: action,
      bindingLabel: label,
      capturing: capturing,
      onTap: () => controls.startGamepadCapture(action),
    );
  }
}

class _BindingRow extends StatefulWidget {
  final ArenaInputAction action;
  final String bindingLabel;
  final bool capturing;
  final bool controllerFocusable;
  final VoidCallback onTap;

  const _BindingRow({
    required this.action,
    required this.bindingLabel,
    required this.capturing,
    this.controllerFocusable = true,
    required this.onTap,
  });

  @override
  State<_BindingRow> createState() => _BindingRowState();
}

class _BindingRowState extends State<_BindingRow> {
  late final FocusNode _focusNode = FocusNode(debugLabel: widget.action.label);
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    if (widget.controllerFocusable) {
      ControllerFocusRegistry.instance.register(
        _focusNode,
        widget.onTap,
        scope: 'controls',
      );
    }
  }

  @override
  void didUpdateWidget(covariant _BindingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controllerFocusable) {
      ControllerFocusRegistry.instance.register(
        _focusNode,
        widget.onTap,
        scope: 'controls',
      );
    } else {
      ControllerFocusRegistry.instance.unregister(_focusNode);
    }
  }

  @override
  void dispose() {
    ControllerFocusRegistry.instance.unregister(_focusNode);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kTextDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onTap,
              child: Container(
                width: 132,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.capturing ? kUiGreen : kUiParchment,
                  border: Border.all(
                    color: widget.capturing || _focused ? kBarBlue : kUiWood,
                    width: 2,
                  ),
                  boxShadow: _focused
                      ? const [
                          BoxShadow(
                            color: kBarBlue,
                            blurRadius: 0,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  widget.bindingLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.capturing ? kTextLight : kTextDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final String text;
  const _StatusLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: kUiWoodDark,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
  }
}

// ============================================================================
//  SONUÇ  —  KAZANDIN / YENİLDİN
// ============================================================================
