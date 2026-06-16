import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:gamepads/gamepads.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ArenaInputAction {
  parry,
  parryHigh,
  parryLow,
  dodge,
  attack,
  heavyAttack,
  controls,
}

extension ArenaInputActionLabels on ArenaInputAction {
  String get label {
    return switch (this) {
      ArenaInputAction.parry => 'DEFEND',
      ArenaInputAction.parryHigh => 'ÜST SAVUNMA',
      ArenaInputAction.parryLow => 'ALT SAVUNMA',
      ArenaInputAction.dodge => 'DODGE',
      ArenaInputAction.attack => 'SALDIRI',
      ArenaInputAction.heavyAttack => 'AĞIR SALDIRI',
      ArenaInputAction.controls => 'AYARLAR',
    };
  }
}

class ConnectedGamepad {
  final String id;
  final String name;

  const ConnectedGamepad({required this.id, required this.name});
}

class GamepadInputBinding {
  final GamepadButton? button;
  final GamepadAxis? axis;
  final int direction;

  const GamepadInputBinding.button(this.button) : axis = null, direction = 0;

  const GamepadInputBinding.axis(this.axis, this.direction) : button = null;

  static GamepadInputBinding? fromEvent(
    NormalizedGamepadEvent event, {
    double threshold = 0.55,
  }) {
    final button = event.button;
    if (button != null) {
      return event.value >= threshold
          ? GamepadInputBinding.button(button)
          : null;
    }

    final axis = event.axis;
    if (axis == null) return null;
    if (event.value >= threshold) return GamepadInputBinding.axis(axis, 1);
    if (event.value <= -threshold) return GamepadInputBinding.axis(axis, -1);
    return null;
  }

  static GamepadInputBinding? fromId(String id) {
    final parts = id.split(':');
    if (parts.length == 2 && parts[0] == 'button') {
      final button = _gamepadButtonByName(parts[1]);
      return button == null ? null : GamepadInputBinding.button(button);
    }
    if (parts.length == 3 && parts[0] == 'axis') {
      final axis = _gamepadAxisByName(parts[1]);
      final direction = int.tryParse(parts[2])?.sign;
      if (axis == null || direction == null || direction == 0) return null;
      return GamepadInputBinding.axis(axis, direction);
    }
    return null;
  }

  static Iterable<String> releasedIds(
    NormalizedGamepadEvent event, {
    double threshold = 0.25,
  }) sync* {
    final button = event.button;
    if (button != null) {
      if (event.value <= threshold) yield _buttonId(button);
      return;
    }

    final axis = event.axis;
    if (axis == null) return;
    if (event.value < threshold) yield _axisId(axis, 1);
    if (event.value > -threshold) yield _axisId(axis, -1);
  }

  String get id {
    final button = this.button;
    if (button != null) return _buttonId(button);
    return _axisId(axis!, direction);
  }

  String get label {
    final button = this.button;
    if (button != null) return _buttonLabel(button);
    final sign = direction > 0 ? '+' : '-';
    return '${_axisLabel(axis!)} $sign';
  }

  static String _buttonId(GamepadButton button) => 'button:${button.name}';

  static String _axisId(GamepadAxis axis, int direction) {
    return 'axis:${axis.name}:${direction.sign}';
  }

  static String _buttonLabel(GamepadButton button) {
    return switch (button) {
      GamepadButton.a => 'X / A',
      GamepadButton.b => 'O / B',
      GamepadButton.x => 'KARE / X',
      GamepadButton.y => 'ÜÇGEN / Y',
      GamepadButton.leftBumper => 'L1 / LB',
      GamepadButton.rightBumper => 'R1 / RB',
      GamepadButton.leftTrigger => 'L2',
      GamepadButton.rightTrigger => 'R2',
      GamepadButton.back => 'SHARE',
      GamepadButton.start => 'OPTIONS',
      GamepadButton.home => 'PS',
      GamepadButton.leftStick => 'L3',
      GamepadButton.rightStick => 'R3',
      GamepadButton.dpadUp => 'DPAD ↑',
      GamepadButton.dpadDown => 'DPAD ↓',
      GamepadButton.dpadLeft => 'DPAD ←',
      GamepadButton.dpadRight => 'DPAD →',
      GamepadButton.touchpad => 'TOUCHPAD',
    };
  }

  static String _axisLabel(GamepadAxis axis) {
    return switch (axis) {
      GamepadAxis.leftStickX => 'SOL STICK X',
      GamepadAxis.leftStickY => 'SOL STICK Y',
      GamepadAxis.rightStickX => 'SAĞ STICK X',
      GamepadAxis.rightStickY => 'SAĞ STICK Y',
      GamepadAxis.leftTrigger => 'L2 ANALOG',
      GamepadAxis.rightTrigger => 'R2 ANALOG',
    };
  }

  static GamepadButton? _gamepadButtonByName(String name) {
    for (final button in GamepadButton.values) {
      if (button.name == name) return button;
    }
    return null;
  }

  static GamepadAxis? _gamepadAxisByName(String name) {
    for (final axis in GamepadAxis.values) {
      if (axis.name == name) return axis;
    }
    return null;
  }
}

class InputSettings extends ChangeNotifier {
  static const actions = ArenaInputAction.values;
  static const _storageVersion = 2;
  static const _versionKey = 'input.bindings.version';
  static const _keyboardPrefix = 'input.keyboard.';
  static const _gamepadPrefix = 'input.gamepad.';

  final Map<ArenaInputAction, LogicalKeyboardKey> _keyboardBindings = {};

  final Map<ArenaInputAction, GamepadInputBinding> _gamepadBindings = {};

  List<ConnectedGamepad> _gamepads = const [];
  ArenaInputAction? keyboardCaptureAction;
  ArenaInputAction? gamepadCaptureAction;

  InputSettings() {
    _restoreDefaultMaps();
  }

  List<ConnectedGamepad> get gamepads => _gamepads;
  bool get hasGamepad => _gamepads.isNotEmpty;

  Future<void> loadSavedBindings() async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getInt(_versionKey);
    if (version != _storageVersion) {
      _restoreDefaultMaps();
      await _writeAllBindings();
      notifyListeners();
      return;
    }

    var changed = false;

    for (final action in actions) {
      final keyId = prefs.getInt('$_keyboardPrefix${action.name}');
      final key = keyId == null
          ? null
          : LogicalKeyboardKey.findKeyByKeyId(keyId);
      if (key != null) {
        _keyboardBindings[action] = _normalizedKeyboardKey(key);
        changed = true;
      }

      final gamepadId = prefs.getString('$_gamepadPrefix${action.name}');
      final gamepadBinding = gamepadId == null
          ? null
          : GamepadInputBinding.fromId(gamepadId);
      if (gamepadBinding != null) {
        _gamepadBindings[action] = gamepadBinding;
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }

  LogicalKeyboardKey keyboardBindingFor(ArenaInputAction action) {
    return _keyboardBindings[action]!;
  }

  GamepadInputBinding gamepadBindingFor(ArenaInputAction action) {
    return _gamepadBindings[action]!;
  }

  void startKeyboardCapture(ArenaInputAction action) {
    keyboardCaptureAction = action;
    gamepadCaptureAction = null;
    notifyListeners();
  }

  void startGamepadCapture(ArenaInputAction action) {
    gamepadCaptureAction = action;
    keyboardCaptureAction = null;
    notifyListeners();
  }

  void cancelCapture() {
    keyboardCaptureAction = null;
    gamepadCaptureAction = null;
    notifyListeners();
  }

  bool captureKeyboard(LogicalKeyboardKey key) {
    final action = keyboardCaptureAction;
    if (action == null) return false;
    _keyboardBindings[action] = _normalizedKeyboardKey(key);
    keyboardCaptureAction = null;
    _saveKeyboardBinding(action);
    notifyListeners();
    return true;
  }

  bool captureGamepad(GamepadInputBinding binding) {
    final action = gamepadCaptureAction;
    if (action == null) return false;
    _gamepadBindings[action] = binding;
    gamepadCaptureAction = null;
    _saveGamepadBinding(action);
    notifyListeners();
    return true;
  }

  ArenaInputAction? actionForKeyboard(LogicalKeyboardKey key) {
    final normalized = _normalizedKeyboardKey(key);
    for (final entry in _keyboardBindings.entries) {
      if (entry.value == normalized) return entry.key;
    }
    return null;
  }

  ArenaInputAction? actionForGamepad(GamepadInputBinding binding) {
    for (final entry in _gamepadBindings.entries) {
      if (entry.value.id == binding.id) return entry.key;
    }
    return null;
  }

  bool hasGamepadId(String id) {
    return _gamepads.any((gamepad) => gamepad.id == id);
  }

  void setConnectedGamepads(List<ConnectedGamepad> gamepads) {
    _gamepads = List.unmodifiable(gamepads);
    notifyListeners();
  }

  void restoreDefaults() {
    _restoreDefaultMaps();
    keyboardCaptureAction = null;
    gamepadCaptureAction = null;
    _saveAllBindings();
    notifyListeners();
  }

  void _restoreDefaultMaps() {
    _keyboardBindings
      ..clear()
      ..addAll({
        ArenaInputAction.parry: LogicalKeyboardKey.space,
        ArenaInputAction.parryHigh: LogicalKeyboardKey.arrowUp,
        ArenaInputAction.parryLow: LogicalKeyboardKey.arrowDown,
        ArenaInputAction.dodge: LogicalKeyboardKey.shiftLeft,
        ArenaInputAction.attack: LogicalKeyboardKey.keyF,
        ArenaInputAction.heavyAttack: LogicalKeyboardKey.keyG,
        ArenaInputAction.controls: LogicalKeyboardKey.escape,
      });
    _gamepadBindings
      ..clear()
      ..addAll({
        ArenaInputAction.parry: const GamepadInputBinding.button(
          GamepadButton.leftBumper,
        ),
        ArenaInputAction.parryHigh: const GamepadInputBinding.button(
          GamepadButton.rightBumper,
        ),
        ArenaInputAction.parryLow: const GamepadInputBinding.axis(
          GamepadAxis.rightTrigger,
          1,
        ),
        ArenaInputAction.dodge: const GamepadInputBinding.axis(
          GamepadAxis.leftTrigger,
          1,
        ),
        ArenaInputAction.attack: const GamepadInputBinding.button(
          GamepadButton.a,
        ),
        ArenaInputAction.heavyAttack: const GamepadInputBinding.button(
          GamepadButton.x,
        ),
        ArenaInputAction.controls: const GamepadInputBinding.button(
          GamepadButton.start,
        ),
      });
  }

  void _saveKeyboardBinding(ArenaInputAction action) {
    unawaited(_writeKeyboardBinding(action));
  }

  Future<void> _writeKeyboardBinding(ArenaInputAction action) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$_keyboardPrefix${action.name}',
      _keyboardBindings[action]!.keyId,
    );
  }

  void _saveGamepadBinding(ArenaInputAction action) {
    unawaited(_writeGamepadBinding(action));
  }

  Future<void> _writeGamepadBinding(ArenaInputAction action) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_gamepadPrefix${action.name}',
      _gamepadBindings[action]!.id,
    );
  }

  void _saveAllBindings() {
    unawaited(_writeAllBindings());
  }

  Future<void> _writeAllBindings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_versionKey, _storageVersion);
    for (final action in actions) {
      await prefs.setInt(
        '$_keyboardPrefix${action.name}',
        _keyboardBindings[action]!.keyId,
      );
      await prefs.setString(
        '$_gamepadPrefix${action.name}',
        _gamepadBindings[action]!.id,
      );
    }
  }

  static LogicalKeyboardKey _normalizedKeyboardKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight) {
      return LogicalKeyboardKey.shiftLeft;
    }
    return key;
  }
}

String keyboardKeyLabel(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.shiftLeft) return 'SHIFT';
  if (key == LogicalKeyboardKey.space) return 'SPACE';
  if (key == LogicalKeyboardKey.escape) return 'ESC';
  if (key == LogicalKeyboardKey.arrowUp) return '↑';
  if (key == LogicalKeyboardKey.arrowDown) return '↓';
  if (key == LogicalKeyboardKey.arrowLeft) return '←';
  if (key == LogicalKeyboardKey.arrowRight) return '→';

  final label = key.keyLabel.trim();
  if (label.isNotEmpty) return label.toUpperCase();
  return key.debugName?.toUpperCase() ?? key.keyId.toRadixString(16);
}

class ControllerFocusRegistry {
  ControllerFocusRegistry._();

  static final instance = ControllerFocusRegistry._();

  final List<FocusNode> _nodes = [];
  final Map<FocusNode, VoidCallback> _actions = {};
  final Map<FocusNode, String> _scopes = {};

  void register(
    FocusNode node,
    VoidCallback onActivate, {
    String scope = 'global',
  }) {
    if (!_nodes.contains(node)) _nodes.add(node);
    _actions[node] = onActivate;
    _scopes[node] = scope;
  }

  void unregister(FocusNode node) {
    _nodes.remove(node);
    _actions.remove(node);
    _scopes.remove(node);
  }

  bool move(TraversalDirection direction, {String scope = 'global'}) {
    final nodes = _activeNodes(scope);
    if (nodes.isEmpty) return false;

    final current = FocusManager.instance.primaryFocus;
    final currentIndex = nodes.indexWhere(
      (node) => node == current || node.hasFocus,
    );
    final delta =
        direction == TraversalDirection.up ||
            direction == TraversalDirection.left
        ? -1
        : 1;
    final nextIndex = currentIndex < 0
        ? 0
        : (currentIndex + delta).clamp(0, nodes.length - 1);
    nodes[nextIndex].requestFocus();
    return true;
  }

  bool activate({String scope = 'global'}) {
    final nodes = _activeNodes(scope);
    if (nodes.isEmpty) return false;

    final current = FocusManager.instance.primaryFocus;
    final index = nodes.indexWhere((node) => node == current || node.hasFocus);
    if (index < 0) {
      nodes.first.requestFocus();
      _actions[nodes.first]?.call();
      return true;
    }

    _actions[nodes[index]]?.call();
    return true;
  }

  void focusFirst({String scope = 'global'}) {
    final nodes = _activeNodes(scope);
    if (nodes.isEmpty) return;
    nodes.first.requestFocus();
  }

  List<FocusNode> _activeNodes(String scope) {
    return [
      for (final node in _nodes)
        if (_scopes[node] == scope && _isUsable(node)) node,
    ];
  }

  bool _isUsable(FocusNode node) {
    final context = node.context;
    if (context == null || !node.canRequestFocus) return false;
    final renderObject = context.findRenderObject();
    return renderObject != null && renderObject.attached;
  }
}
