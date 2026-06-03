import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import '../services/apex_nub_ble_service.dart';

class _MouseHidState {
  int buttons = 0;
  int pendingMoveX = 0;
  int pendingMoveY = 0;
  int pendingScroll = 0;
  bool _dirty = false;

  bool get hasPendingChanges {
    return _dirty ||
        pendingMoveX != 0 ||
        pendingMoveY != 0 ||
        pendingScroll != 0;
  }

  void addMovement(double deltaX, double deltaY) {
    pendingMoveX += deltaX.round();
    pendingMoveY += deltaY.round();
    _dirty = true;
  }

  void addScroll(double delta) {
    pendingScroll += delta.round();
    _dirty = true;
  }

  void pressButton(int buttonMask) {
    buttons |= buttonMask;
    _dirty = true;
  }

  void releaseButton(int buttonMask) {
    buttons &= ~buttonMask;
    _dirty = true;
  }

  List<int> consumeMouseReport() {
    final reportX = _consumeAxisValue(() => pendingMoveX, (value) => pendingMoveX = value);
    final reportY = _consumeAxisValue(() => pendingMoveY, (value) => pendingMoveY = value);
    final reportScroll = _consumeAxisValue(() => pendingScroll, (value) => pendingScroll = value);

    _dirty = false;

    return [
      buttons & 0x07,
      reportX & 0xFF,
      reportY & 0xFF,
      reportScroll & 0xFF,
    ];
  }

  int _consumeAxisValue(int Function() getter, void Function(int value) setter) {
    final value = getter();
    if (value == 0) {
      return 0;
    }

    final clamped = value.clamp(-127, 127);
    setter(value - clamped);
    return clamped;
  }
}

class MouseControlTab extends StatefulWidget {
  final BleDevice device;

  const MouseControlTab({super.key, required this.device});

  @override
  State<MouseControlTab> createState() => _MouseControlTabState();
}

class _MouseControlTabState extends State<MouseControlTab> {
  static const int _leftButtonMask = 0x01;
  static const int _rightButtonMask = 0x02;
  static const int _middleButtonMask = 0x04;
  static const int _mousePacketPrefix = 0xAA;
  static const int _mouseReportId = 0x02;
  static const Duration _mouseSendInterval = Duration(milliseconds: 20);

  final ApexNubBleService _bleService = ApexNubBleService();
  final _MouseHidState _mouseState = _MouseHidState();

  Timer? _mouseSendTimer;
  bool _isMouseWriteInFlight = false;

  @override
  void initState() {
    super.initState();
    _mouseSendTimer = Timer.periodic(_mouseSendInterval, (_) {
      _flushMouseState();
    });
  }

  Uint8List _buildMousePacket(_MouseHidState state) {
    final builder = BytesBuilder();
    builder.add(const [_mousePacketPrefix, _mouseReportId]);
    builder.add(state.consumeMouseReport());
    return builder.toBytes();
  }

  String _formatBytes(List<int> bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  Future<void> _flushMouseState() async {
    if (_isMouseWriteInFlight || !_mouseState.hasPendingChanges) {
      return;
    }

    if (!_bleService.isConnected) {
      return;
    }

    final packet = _buildMousePacket(_mouseState);
    _isMouseWriteInFlight = true;

    try {
      print('[Mouse] Send packet: ${_formatBytes(packet)}');
      final success = await _bleService.writeValue(
        serviceUuid: ApexNubBleService.configServiceUuid,
        characteristicUuid: 'ABD6',
        value: packet,
        withoutResponse: true,
      );

      if (!success) {
        print('[Mouse] Failed to send mouse packet');
      }
    } finally {
      _isMouseWriteInFlight = false;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _mouseState.addMovement(details.delta.dx, details.delta.dy);
  }

  void _onMouseButtonDown(int buttonMask) {
    _mouseState.pressButton(buttonMask);
  }

  void _onMouseButtonUp(int buttonMask) {
    _mouseState.releaseButton(buttonMask);
  }

  Widget _buildMouseButton({
    required String label,
    required int buttonMask,
  }) {
    return GestureDetector(
      onTapDown: (_) => _onMouseButtonDown(buttonMask),
      onTapUp: (_) => _onMouseButtonUp(buttonMask),
      onTapCancel: () => _onMouseButtonUp(buttonMask),
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minWidth: 72, minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue.shade600,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _onScroll(double delta) {
    _mouseState.addScroll(delta);
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Row(
        children: [
          Icon(Icons.mouse, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Text(
            'Mouse Control',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMousePad({EdgeInsetsGeometry margin = const EdgeInsets.all(16)}) {
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mouse,
                size: 64,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 16),
              Text(
                'Move the mouse in this area \n(movement only, no clicks)',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons({Axis direction = Axis.horizontal}) {
    final controls = [
      _buildMouseButton(
        label: 'Left',
        buttonMask: _leftButtonMask,
      ),
      _buildMouseButton(
        label: 'Middle',
        buttonMask: _middleButtonMask,
      ),
      _buildMouseButton(
        label: 'Right',
        buttonMask: _rightButtonMask,
      ),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _onScroll(1),
            icon: const Icon(Icons.arrow_upward),
            tooltip: 'Scroll up',
          ),
          IconButton(
            onPressed: () => _onScroll(-1),
            icon: const Icon(Icons.arrow_downward),
            tooltip: 'Scroll down',
          ),
        ],
      ),
    ];

    if (direction == Axis.vertical) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final control in controls) ...[
            control,
            const SizedBox(height: 12),
          ],
        ]..removeLast(),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: controls,
    );
  }

  @override
  void dispose() {
    _mouseSendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    if (isLandscape) {
      return Row(
        children: [
          Expanded(
            child: _buildMousePad(
              margin: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            ),
          ),
          SizedBox(
            width: 180,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  //_buildStatusBar(),
                  //const SizedBox(height: 16),
                  Expanded(
                    child: _buildControlButtons(direction: Axis.vertical),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildStatusBar(),
        Expanded(
          child: _buildMousePad(),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildControlButtons(),
        ),
      ],
    );
  }
}

