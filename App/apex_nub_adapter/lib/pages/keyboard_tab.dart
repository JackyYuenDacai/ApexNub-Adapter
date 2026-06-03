import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import '../services/apex_nub_ble_service.dart';
import 'full_size_keyboard.dart';
import 'dart:typed_data';

class KeyboardTab extends StatefulWidget {
  final BleDevice device;

  const KeyboardTab({super.key, required this.device});

  @override
  State<KeyboardTab> createState() => _KeyboardTabState();
}

class _KeyboardTabState extends State<KeyboardTab> {
  final ApexNubBleService _bleService = ApexNubBleService();
  final TextEditingController _textController = TextEditingController();
  final List<int> key_report = List<int>.filled(8, 0);
  bool _isShiftPressed = false;
  bool _isCapsLock = false;
  bool _isWriteInFlight = false;
  final List<Uint8List> _keyboardPacketQueue = [];

  Uint8List _buildKeyboardPacket() {
    final builder = BytesBuilder();
    builder.add(const [0xBB]);
    builder.add(key_report);
    return builder.toBytes();
  }

  bool _samePacket(Uint8List? a, Uint8List? b) {
    if (a == null || b == null) return false;
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _formatBytes(List<int> bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  void _queueKeyboardPacket(Uint8List packet) {
    final lastQueuedPacket =
        _keyboardPacketQueue.isNotEmpty ? _keyboardPacketQueue.last : null;

    if (_samePacket(packet, lastQueuedPacket)) {
      return;
    }

    print('[Keyboard] Queue packet: ${_formatBytes(packet)}');
    _keyboardPacketQueue.add(packet);
    _flushKeyboardPacket();
  }

  Future<void> _flushKeyboardPacket() async {
    if (_isWriteInFlight) return;

    if (_keyboardPacketQueue.isEmpty) return;

    final packet = _keyboardPacketQueue.removeAt(0);
    _isWriteInFlight = true;

    try {
      print('[Keyboard] Send packet: ${_formatBytes(packet)}');
      final serviceUuid = ApexNubBleService.configServiceUuid;
      final characteristicUuid = 'ABD6';
      final success = await _bleService.writeValue(
        serviceUuid: serviceUuid,
        characteristicUuid: characteristicUuid,
        value: packet,
        withoutResponse: true,
      );

      if (!success) {
        print('[Keyboard] Failed to send keyboard packet');
      }
    } finally {
      _isWriteInFlight = false;
      if (_keyboardPacketQueue.isNotEmpty) {
        _flushKeyboardPacket();
      }
    }
  }

  // TODO: 根据实际设备协议实现键盘数据发送
  // 需要配置正确的 Service UUID 和 Characteristic UUID
  Future<void> _sendKeyData(String key, int? hid_code, bool key_down) async {
    if (!_bleService.isConnected) {
      print('[Keyboard] Device not connected');
      return;
    }
    if (key_down) {
      print('[Keyboard] Key pressed: $key: $hid_code');
    } else {
      print('[Keyboard] Key released: $key: $hid_code');
    }

    if (hid_code == null) {
      return;
    }

    if (key_down) {
      if (hid_code >= 0xe0 && hid_code <= 0xe7) {
        key_report[0] |= (1 << (hid_code - 0xe0));
      } else {
        for (int i = 2; i < 8; i++) {
          if (key_report[i] == hid_code) {
            //no need add
            break;
          }
          if (key_report[i] == 0) {
            //empty space
            key_report[i] = hid_code;
            break;
          }
        }
      }
    } else {
      if (hid_code >= 0xe0 && hid_code <= 0xe7) {
        key_report[0] &= ~(1 << (hid_code - 0xe0));
      } else {
        for (int i = 2; i < 8; i++) {
          if (key_report[i] == hid_code) {
            //found
            key_report[i] = 0;
            for (int j = i; j < 7; j++) {
              if (key_report[j] == 0 && key_report[j + 1] != 0) {
                key_report[j] = key_report[j + 1];
                key_report[j + 1] = 0;
              }
            }
            break;
          }
        }
      }
    }
    _queueKeyboardPacket(_buildKeyboardPacket());
  }

  String _mapDisplayKey(String key) {
    // 特殊键不需要转换
    final specialKeys = [
      'ESC',
      'F1',
      'F2',
      'F3',
      'F4',
      'F5',
      'F6',
      'F7',
      'F8',
      'F9',
      'F10',
      'F11',
      'F12',
      'DELETE',
      'HOME',
      'PAGE_UP',
      'PAGE_DOWN',
      'END',
      'ARROW_UP',
      'ARROW_DOWN',
      'ARROW_LEFT',
      'ARROW_RIGHT',
      'BACKSPACE',
      'TAB',
      'ENTER',
      'SHIFT',
      'CAPS',
      'CTRL',
      'ALT',
      'SPACE',
    ];

    if (specialKeys.contains(key)) {
      return key;
    }

    final isShift = _isShiftPressed || _isCapsLock;
    String displayKey = key;

    // Handle letter keys with shift/caps
    if (key.length == 1 && key.contains(RegExp(r'[a-z]'))) {
      displayKey = isShift ? key.toUpperCase() : key.toLowerCase();
    }

    return displayKey;
  }

  void _onKeyDown(String key, int? hid_code) {
    _sendKeyData(key, hid_code, true);
    if (key == 'SHIFT') {
      setState(() {
        _isShiftPressed = true;
      });
      //_sendKeyData('SHIFT_DOWN');
      return;
    } else if (key == 'CAPS') {
      setState(() {
        _isCapsLock = !_isCapsLock;
      });
      //_sendKeyData('CAPS_TOGGLE');
      return;
    }

    final displayKey = _mapDisplayKey(key);
    //_sendKeyData('DOWN:$displayKey hid-code $hid_code');
  }

  void _onKeyUp(String key, int? hid_code) {
    _sendKeyData(key, hid_code, false);
    if (key == 'SHIFT') {
      setState(() {
        _isShiftPressed = false;
      });
      //_sendKeyData('SHIFT_UP');
      return;
    }

    final displayKey = _mapDisplayKey(key);
    //_sendKeyData('UP:$displayKey  hid-code $hid_code');

    // 仅在按键抬起时更新文本显示（特殊键不更新文本）
    final specialKeys = [
      'ESC',
      'F1',
      'F2',
      'F3',
      'F4',
      'F5',
      'F6',
      'F7',
      'F8',
      'F9',
      'F10',
      'F11',
      'F12',
      'DELETE',
      'HOME',
      'PAGE_UP',
      'PAGE_DOWN',
      'END',
      'ARROW_UP',
      'ARROW_DOWN',
      'ARROW_LEFT',
      'ARROW_RIGHT',
      'TAB',
      'SHIFT',
      'CAPS',
      'CTRL',
      'ALT',
    ];

    if (specialKeys.contains(key)) {
      // 特殊键不更新文本显示
      return;
    }

    if (key.length == 1 && key.contains(RegExp(r'[a-zA-Z]'))) {
      _textController.text += displayKey;
    } else if (key == 'BACKSPACE') {
      if (_textController.text.isNotEmpty) {
        _textController.text = _textController.text.substring(
          0,
          _textController.text.length - 1,
        );
      }
    } else if (key == 'SPACE') {
      _textController.text += ' ';
    } else if (key == 'ENTER') {
      _textController.text += '\n';
    } else if (key.length == 1) {
      // 数字和符号键（包括 ~）
      _textController.text += displayKey;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final keyboard = FullSizeKeyboard(
      onKeyDown: _onKeyDown,
      onKeyUp: _onKeyUp,
      isShiftPressed: _isShiftPressed,
      isCapsLock: _isCapsLock,
      fitToAvailableSize: isLandscape,
    );

    if (isLandscape) {
      return keyboard;
    }

    return Column(
      children: [
        // Status bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green[50],
          child: Row(
            children: [
              Icon(Icons.keyboard, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(
                'Keyboard Input',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ),
        // Text input area
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: _textController,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Typed text will appear here...',
              border: InputBorder.none,
            ),
            readOnly: true,
          ),
        ),
        // Full-size keyboard
        Expanded(
          child: keyboard,
        ),
      ],
    );
  }
}
