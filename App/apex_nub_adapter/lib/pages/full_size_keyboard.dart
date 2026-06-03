import 'package:flutter/material.dart';

class FullSizeKeyboard extends StatelessWidget {
  static const double _keyHeight = 62;
  static const double _gap = 6;
  static const double _navPanelWidth = 214;
  static const double _minKeyboardWidth = 1040;

  final void Function(String, int?) onKeyDown;
  final void Function(String, int?) onKeyUp;
  final bool isShiftPressed;
  final bool isCapsLock;
  final bool fitToAvailableSize;

  const FullSizeKeyboard({
    super.key,
    required this.onKeyDown,
    required this.onKeyUp,
    this.isShiftPressed = false,
    this.isCapsLock = false,
    this.fitToAvailableSize = false,
  });

    String _getKeyLabel(String key, bool shift) {
      if (shift) {
        switch (key) {
          case '`':
            return '~';
          case '1':
            return '!';
          case '2':
            return '@';
          case '3':
            return '#';
          case '4':
            return r'$';
          case '5':
            return '%';
          case '6':
            return '^';
          case '7':
            return '&';
          case '8':
            return '*';
          case '9':
            return '(';
          case '0':
            return ')';
          case '-':
            return '_';
          case '=':
            return '+';
          case '[':
            return '{';
          case ']':
            return '}';
          case '\\':
            return '|';
          case ';':
            return ':';
          case "'":
            return '"';
          case ',':
            return '<';
          case '.':
            return '>';
          case '/':
            return '?';
          default:
            return key.toUpperCase();
        }
      }
      return key;
    }

    String _getKeyValue(String key, bool shift) {
      return _getKeyLabel(key, shift);
    }

    Widget _buildFlexKey({
      required String label,
      required String value,
      int? hidCode,
      int flex = 10,
      Color? color,
      bool active = false,
      double? height,
    }) {
      return Expanded(
        flex: flex,
        child: _buildKeySurface(
          label: label,
          value: value,
          hidCode: hidCode,
          color: color,
          active: active,
          height: height ?? _keyHeight,
        ),
      );
    }

    Widget _buildKeySurface({
      required String label,
      required String value,
      int? hidCode,
      Color? color,
      bool active = false,
      required double height,
    }) {
      final baseColor = color ?? Colors.grey.shade100;
      final background = active ? baseColor.withValues(alpha: 0.95) : baseColor;
      final borderColor = active ? Colors.black87 : Colors.grey.shade400;

      return Padding(
        padding: const EdgeInsets.all(_gap / 2),
        child: SizedBox(
          height: height,
          child: GestureDetector(
            onTapDown: (_) => onKeyDown(value, hidCode),
            onTapUp: (_) => onKeyUp(value, hidCode),
            onTapCancel: () => onKeyUp(value, hidCode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: active ? 2 : 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: label.length > 4 ? 14 : 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget _buildMainRow(List<Widget> children) {
      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: children);
    }

    Widget _buildNavPanel() {
      return SizedBox(
        width: _navPanelWidth,
        child: Column(
          children: [
            _buildMainRow([
              _buildFlexKey(
                label: 'Del',
                value: 'DELETE',
                color: Colors.red.shade300,
                hidCode: 0x4c,
              ),
              _buildFlexKey(
                label: 'Home',
                value: 'HOME',
                color: Colors.indigo.shade300,
                hidCode: 0x4a,
              ),
            ]),
            _buildMainRow([
              _buildFlexKey(
                label: 'PgUp',
                value: 'PAGE_UP',
                color: Colors.indigo.shade300,
                hidCode: 0x4b,
              ),
              _buildFlexKey(
                label: 'End',
                value: 'END',
                color: Colors.indigo.shade300,
                hidCode: 0x4d,
              ),
            ]),
            _buildMainRow([
              _buildFlexKey(
                label: 'PgDn',
                value: 'PAGE_DOWN',
                color: Colors.indigo.shade300,
                hidCode: 0x4e,
              ),
              const Expanded(flex: 10, child: SizedBox()),
            ]),
            const SizedBox(height: 8),
            _buildMainRow([
              const Expanded(flex: 10, child: SizedBox()),
              _buildFlexKey(
                label: '↑',
                value: 'ARROW_UP',
                color: Colors.amber.shade300,
                hidCode: 0x52,
              ),
              const Expanded(flex: 10, child: SizedBox()),
            ]),
            _buildMainRow([
              _buildFlexKey(
                label: '←',
                value: 'ARROW_LEFT',
                color: Colors.amber.shade300,
                hidCode: 0x50,
              ),
              _buildFlexKey(
                label: '↓',
                value: 'ARROW_DOWN',
                color: Colors.amber.shade300,
                hidCode: 0x51,
              ),
              _buildFlexKey(
                label: '→',
                value: 'ARROW_RIGHT',
                color: Colors.amber.shade300,
                hidCode: 0x4f,
              ),
            ]),
          ],
        ),
      );
    }

    Widget _buildKeyboardLayout(bool shift, double keyboardWidth) {
      final mainKeyboardWidth = keyboardWidth - _navPanelWidth - 10;

      return SizedBox(
        width: keyboardWidth,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: mainKeyboardWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                          _buildMainRow([
                            _buildFlexKey(
                              label: 'Esc',
                              value: 'ESC',
                              color: Colors.red.shade300,
                              hidCode: 0x29,
                              flex: 12,
                            ),
                            _buildFlexKey(label: 'F1', value: 'F1', color: Colors.teal.shade300, hidCode: 0x3a, flex: 9),
                            _buildFlexKey(label: 'F2', value: 'F2', color: Colors.teal.shade300, hidCode: 0x3b, flex: 9),
                            _buildFlexKey(label: 'F3', value: 'F3', color: Colors.teal.shade300, hidCode: 0x3c, flex: 9),
                            _buildFlexKey(label: 'F4', value: 'F4', color: Colors.teal.shade300, hidCode: 0x3d, flex: 9),
                            _buildFlexKey(label: 'F5', value: 'F5', color: Colors.teal.shade300, hidCode: 0x3e, flex: 9),
                            _buildFlexKey(label: 'F6', value: 'F6', color: Colors.teal.shade300, hidCode: 0x3f, flex: 9),
                            _buildFlexKey(label: 'F7', value: 'F7', color: Colors.teal.shade300, hidCode: 0x40, flex: 9),
                            _buildFlexKey(label: 'F8', value: 'F8', color: Colors.teal.shade300, hidCode: 0x41, flex: 9),
                            _buildFlexKey(label: 'F9', value: 'F9', color: Colors.teal.shade300, hidCode: 0x42, flex: 9),
                            _buildFlexKey(label: 'F10', value: 'F10', color: Colors.teal.shade300, hidCode: 0x43, flex: 9),
                            _buildFlexKey(label: 'F11', value: 'F11', color: Colors.teal.shade300, hidCode: 0x44, flex: 9),
                            _buildFlexKey(label: 'F12', value: 'F12', color: Colors.teal.shade300, hidCode: 0x45, flex: 9),
                          ]),
                          _buildMainRow([
                            _buildFlexKey(label: _getKeyLabel('`', shift), value: _getKeyValue('`', shift), hidCode: 0x35),
                            _buildFlexKey(label: _getKeyLabel('1', shift), value: _getKeyValue('1', shift), hidCode: 0x1e),
                            _buildFlexKey(label: _getKeyLabel('2', shift), value: _getKeyValue('2', shift), hidCode: 0x1f),
                            _buildFlexKey(label: _getKeyLabel('3', shift), value: _getKeyValue('3', shift), hidCode: 0x20),
                            _buildFlexKey(label: _getKeyLabel('4', shift), value: _getKeyValue('4', shift), hidCode: 0x21),
                            _buildFlexKey(label: _getKeyLabel('5', shift), value: _getKeyValue('5', shift), hidCode: 0x22),
                            _buildFlexKey(label: _getKeyLabel('6', shift), value: _getKeyValue('6', shift), hidCode: 0x23),
                            _buildFlexKey(label: _getKeyLabel('7', shift), value: _getKeyValue('7', shift), hidCode: 0x24),
                            _buildFlexKey(label: _getKeyLabel('8', shift), value: _getKeyValue('8', shift), hidCode: 0x25),
                            _buildFlexKey(label: _getKeyLabel('9', shift), value: _getKeyValue('9', shift), hidCode: 0x26),
                            _buildFlexKey(label: _getKeyLabel('0', shift), value: _getKeyValue('0', shift), hidCode: 0x27),
                            _buildFlexKey(label: _getKeyLabel('-', shift), value: _getKeyValue('-', shift), hidCode: 0x2d),
                            _buildFlexKey(label: _getKeyLabel('=', shift), value: _getKeyValue('=', shift), hidCode: 0x2e),
                            _buildFlexKey(
                              label: '⌫',
                              value: 'BACKSPACE',
                              color: Colors.orange.shade300,
                              hidCode: 0x2a,
                              flex: 16,
                            ),
                          ]),
                          _buildMainRow([
                            _buildFlexKey(label: 'Tab', value: 'TAB', color: Colors.blue.shade300, hidCode: 0x2b, flex: 14),
                            _buildFlexKey(label: _getKeyLabel('q', shift), value: _getKeyValue('q', shift), hidCode: 0x14),
                            _buildFlexKey(label: _getKeyLabel('w', shift), value: _getKeyValue('w', shift), hidCode: 0x1a),
                            _buildFlexKey(label: _getKeyLabel('e', shift), value: _getKeyValue('e', shift), hidCode: 0x08),
                            _buildFlexKey(label: _getKeyLabel('r', shift), value: _getKeyValue('r', shift), hidCode: 0x15),
                            _buildFlexKey(label: _getKeyLabel('t', shift), value: _getKeyValue('t', shift), hidCode: 0x17),
                            _buildFlexKey(label: _getKeyLabel('y', shift), value: _getKeyValue('y', shift), hidCode: 0x1c),
                            _buildFlexKey(label: _getKeyLabel('u', shift), value: _getKeyValue('u', shift), hidCode: 0x18),
                            _buildFlexKey(label: _getKeyLabel('i', shift), value: _getKeyValue('i', shift), hidCode: 0x0c),
                            _buildFlexKey(label: _getKeyLabel('o', shift), value: _getKeyValue('o', shift), hidCode: 0x12),
                            _buildFlexKey(label: _getKeyLabel('p', shift), value: _getKeyValue('p', shift), hidCode: 0x13),
                            _buildFlexKey(label: _getKeyLabel('[', shift), value: _getKeyValue('[', shift), hidCode: 0x2f),
                            _buildFlexKey(label: _getKeyLabel(']', shift), value: _getKeyValue(']', shift), hidCode: 0x30),
                            _buildFlexKey(label: _getKeyLabel('\\', shift), value: _getKeyValue('\\', shift), hidCode: 0x31, flex: 12),
                          ]),
                          _buildMainRow([
                            _buildFlexKey(
                              label: 'Caps',
                              value: 'CAPS',
                              color: Colors.purple.shade300,
                              active: isCapsLock,
                              hidCode: 0x39,
                              flex: 16,
                            ),
                            _buildFlexKey(label: _getKeyLabel('a', shift), value: _getKeyValue('a', shift), hidCode: 0x04),
                            _buildFlexKey(label: _getKeyLabel('s', shift), value: _getKeyValue('s', shift), hidCode: 0x16),
                            _buildFlexKey(label: _getKeyLabel('d', shift), value: _getKeyValue('d', shift), hidCode: 0x07),
                            _buildFlexKey(label: _getKeyLabel('f', shift), value: _getKeyValue('f', shift), hidCode: 0x09),
                            _buildFlexKey(label: _getKeyLabel('g', shift), value: _getKeyValue('g', shift), hidCode: 0x0a),
                            _buildFlexKey(label: _getKeyLabel('h', shift), value: _getKeyValue('h', shift), hidCode: 0x0b),
                            _buildFlexKey(label: _getKeyLabel('j', shift), value: _getKeyValue('j', shift), hidCode: 0x0d),
                            _buildFlexKey(label: _getKeyLabel('k', shift), value: _getKeyValue('k', shift), hidCode: 0x0e),
                            _buildFlexKey(label: _getKeyLabel('l', shift), value: _getKeyValue('l', shift), hidCode: 0x0f),
                            _buildFlexKey(label: _getKeyLabel(';', shift), value: _getKeyValue(';', shift), hidCode: 0x33),
                            _buildFlexKey(label: _getKeyLabel("'", shift), value: _getKeyValue("'", shift), hidCode: 0x34),
                            _buildFlexKey(label: 'Enter', value: 'ENTER', color: Colors.green.shade300, hidCode: 0x28, flex: 18),
                          ]),
                          _buildMainRow([
                            _buildFlexKey(
                              label: 'Shift',
                              value: 'SHIFT',
                              color: Colors.pink.shade300,
                              active: isShiftPressed,
                              hidCode: 0xe1,
                              flex: 18,
                            ),
                            _buildFlexKey(label: _getKeyLabel('z', shift), value: _getKeyValue('z', shift), hidCode: 0x1d),
                            _buildFlexKey(label: _getKeyLabel('x', shift), value: _getKeyValue('x', shift), hidCode: 0x1b),
                            _buildFlexKey(label: _getKeyLabel('c', shift), value: _getKeyValue('c', shift), hidCode: 0x06),
                            _buildFlexKey(label: _getKeyLabel('v', shift), value: _getKeyValue('v', shift), hidCode: 0x19),
                            _buildFlexKey(label: _getKeyLabel('b', shift), value: _getKeyValue('b', shift), hidCode: 0x05),
                            _buildFlexKey(label: _getKeyLabel('n', shift), value: _getKeyValue('n', shift), hidCode: 0x11),
                            _buildFlexKey(label: _getKeyLabel('m', shift), value: _getKeyValue('m', shift), hidCode: 0x10),
                            _buildFlexKey(label: _getKeyLabel(',', shift), value: _getKeyValue(',', shift), hidCode: 0x36),
                            _buildFlexKey(label: _getKeyLabel('.', shift), value: _getKeyValue('.', shift), hidCode: 0x37),
                            _buildFlexKey(label: _getKeyLabel('/', shift), value: _getKeyValue('/', shift), hidCode: 0x38),
                            _buildFlexKey(
                              label: 'Shift',
                              value: 'SHIFT',
                              color: Colors.pink.shade300,
                              active: isShiftPressed,
                              hidCode: 0xe5,
                              flex: 18,
                            ),
                          ]),
                          _buildMainRow([
                            _buildFlexKey(label: 'Ctrl', value: 'CTRL', color: Colors.cyan.shade300, hidCode: 0xe0, flex: 12),
                            _buildFlexKey(label: 'Alt', value: 'ALT', color: Colors.cyan.shade300, hidCode: 0xe2, flex: 12),
                            _buildFlexKey(label: '', value: 'SPACE', color: Colors.grey.shade400, hidCode: 0x2c, flex: 46),
                            _buildFlexKey(label: 'Alt', value: 'ALT', color: Colors.cyan.shade300, hidCode: 0xe6, flex: 12),
                            _buildFlexKey(label: 'Ctrl', value: 'CTRL', color: Colors.cyan.shade300, hidCode: 0xe4, flex: 12),
                          ]),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _buildNavPanel(),
          ],
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      final shift = isShiftPressed || isCapsLock;

      return LayoutBuilder(
        builder: (context, constraints) {
          final scrollableKeyboardWidth = constraints.maxWidth > _minKeyboardWidth
              ? constraints.maxWidth
              : _minKeyboardWidth;

          if (fitToAvailableSize) {
            return Container(
              color: Colors.grey.shade300,
              padding: const EdgeInsets.all(8),
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: _buildKeyboardLayout(shift, _minKeyboardWidth),
                ),
              ),
            );
          }

          return Container(
            color: Colors.grey.shade300,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildKeyboardLayout(shift, scrollableKeyboardWidth),
              ),
            ),
          );
        },
      );
    }
  }
