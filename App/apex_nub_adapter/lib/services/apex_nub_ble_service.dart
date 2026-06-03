import 'dart:async';
import 'dart:typed_data';
import 'package:universal_ble/universal_ble.dart';
import 'package:permission_handler/permission_handler.dart';

/// ApexNub BLE 服务类
/// 提供蓝牙设备扫描、连接、数据读写等功能
class ApexNubBleService {
  // 单例模式
  static final ApexNubBleService _instance = ApexNubBleService._internal();
  factory ApexNubBleService() => _instance;
  ApexNubBleService._internal() {
    // HID 场景优先低延迟，避免所有 BLE 命令共用一个全局串行队列。
    UniversalBle.queueType = QueueType.perDevice;
  }

  // PNP ID constants
  static const int vendorId = 0xADCF;
  static const int productId = 0xADCF;
  static const String deviceName = 'ApexNub-Adapter';

  // 连接状态
  String? connectedDeviceId;
  String? connectedDeviceName;
  bool isConnected = false;
  bool isScanning = false;

  // 扫描结果列表
  List<BleDevice> scanResults = [];

  // 缓存 characteristic 是否支持 write without response，避免每次写入都走异常探测。
  final Map<String, bool> _withoutResponseSupportCache = {};

  // Stream controllers
  final StreamController<bool> _connectionStateController = 
      StreamController<bool>.broadcast();
  final StreamController<List<BleDevice>> _scanResultsController = 
      StreamController<List<BleDevice>>.broadcast();

  // Streams
  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  Stream<List<BleDevice>> get scanResultsStream => _scanResultsController.stream;

  // 扫描订阅
  StreamSubscription<BleDevice>? _scanSubscription;
  StreamSubscription<BleConnectionState>? _connectionSubscription;
  Completer<void>? _scanStopCompleter;

  // Service and characteristic UUIDs (如果需要的话)
  static const String configServiceUuid = "ABCF";
  static const String configServiceUuidFull = "0000ABCF-0000-1000-8000-00805F9B34FB";

  String _characteristicCacheKey(String serviceUuid, String characteristicUuid) {
    return '${BleUuidParser.string(serviceUuid)}:${BleUuidParser.string(characteristicUuid)}';
  }

  void _cacheCharacteristicProperties(List<BleService> services) {
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        final key = _characteristicCacheKey(service.uuid, characteristic.uuid);
        _withoutResponseSupportCache[key] = characteristic.properties.contains(
          CharacteristicProperty.writeWithoutResponse,
        );
      }
    }
  }

  String _formatBytes(List<int> bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  /// 检查蓝牙状态
  Future<AvailabilityState> checkBluetoothStatus() async {
    try {
      print('[BLE Service] Checking Bluetooth status...');
      final availabilityState = await UniversalBle.getBluetoothAvailabilityState()
          .timeout(const Duration(seconds: 3), onTimeout: () {
        print('[BLE Service] Bluetooth status check timed out');
        return AvailabilityState.unknown;
      });
      
      print('[BLE Service] Bluetooth status: $availabilityState');
      return availabilityState;
    } catch (e) {
      print('[BLE Service] Error checking Bluetooth status: $e');
      return AvailabilityState.unknown;
    }
  }

  /// 请求必要的权限
  Future<bool> requestPermissions() async {
    try {
      print('[BLE Service] Requesting permissions...');
      
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      // Print permission statuses
      statuses.forEach((permission, status) {
        print('[BLE Service] ${permission.toString()}: $status');
      });

      bool allGranted = statuses.values.every((status) => status.isGranted);
      print('[BLE Service] All permissions granted: $allGranted');
      
      return allGranted;
    } catch (e) {
      print('[BLE Service] Error requesting permissions: $e');
      return false;
    }
  }

  /// 开始扫描设备
  Future<void> startScan({Duration? timeout}) async {
    if (isScanning) {
      print('[BLE Service] Already scanning, skipping...');
      return;
    }

    final scanTimeout = timeout ?? const Duration(seconds: 30);
    _scanStopCompleter = Completer<void>();

    try {
      print('[BLE Service] Starting Bluetooth scan with timeout: ${scanTimeout.inSeconds}s...');
      isScanning = true;
      scanResults.clear();
      _scanResultsController.add(scanResults);

      // 检查蓝牙状态
      print('[BLE Service] Checking Bluetooth availability...');
      final availabilityState = await checkBluetoothStatus();

      if (availabilityState != AvailabilityState.poweredOn) {
        if (availabilityState == AvailabilityState.poweredOff) {
          throw Exception('Bluetooth is turned off. Please enable Bluetooth and try again.');
        } else if (availabilityState == AvailabilityState.unauthorized) {
          throw Exception('Bluetooth permission is missing. Please allow Bluetooth access in Settings.');
        } else if (availabilityState == AvailabilityState.unsupported) {
          throw Exception('This device does not support Bluetooth.');
        } else {
          throw Exception('Bluetooth is unavailable. State: $availabilityState');
        }
      }

      print('[BLE Service] Bluetooth is available and powered on');

      // 检查已连接的设备
      print('[BLE Service] Checking connected devices...');
      final connectedDevices = await UniversalBle.getSystemDevices()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        print('[BLE Service] Warning: getSystemDevices timed out');
        return <BleDevice>[];
      });

      print('[BLE Service] Found ${connectedDevices.length} connected devices');

      for (final device in connectedDevices) {
        print('[BLE Service] Connected device: ${device.name ?? "Unknown"} (${device.deviceId ?? "No ID"})');
        
        if (device.name?.isNotEmpty == true && 
            _isTargetDevice(device.name!)) {
          print('[BLE Service] Found connected target device, connecting...');
          await connectToDevice(device);
          return;
        }
      }

      // 开始扫描
      print('[BLE Service] Starting broad scan for all devices...');
      try {
        await UniversalBle.startScan();
        print('[BLE Service] Scan started successfully');
      } catch (e) {
        print('[BLE Service] Error in UniversalBle.startScan(): $e');
        print('[BLE Service] Continuing despite scan start error...');
      }

      // 监听扫描结果
      _scanSubscription = UniversalBle.scanStream.listen((device) {
        print('[BLE Service] Found device: ${device.name ?? "Unknown"} - RSSI: ${device.rssi ?? 0}');

        // 过滤目标设备
        if (device.name?.isNotEmpty == true && _isTargetDevice(device.name!)) {
          if (!scanResults.any((result) => result.deviceId == device.deviceId)) {
            scanResults.add(device);
            print('[BLE Service] Added target device: ${device.name ?? "Unknown"}');
            _scanResultsController.add(List.from(scanResults));
          }
        }
      }, onError: (error) {
        print('[BLE Service] Scan error: $error');
        isScanning = false;
        if (!(_scanStopCompleter?.isCompleted ?? true)) {
          _scanStopCompleter?.complete();
        }
      });

      // 等待扫描超时，或被外部 stopScan()/connectToDevice() 提前结束
      print('[BLE Service] Scanning for ${scanTimeout.inSeconds} seconds...');
      await Future.any([
        Future.delayed(scanTimeout),
        _scanStopCompleter!.future,
      ]);

      if (!isScanning) {
        print('[BLE Service] Scan stopped before timeout');
        return;
      }

      await stopScan();
      print('[BLE Service] Scan completed successfully');

    } catch (e) {
      print('[BLE Service] Error starting scan: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Bluetooth scan timed out. Check that Bluetooth is enabled, the device is in range, or try restarting Bluetooth.');
      } else if (e.toString().contains('permission')) {
        throw Exception('Bluetooth permission is insufficient. Please check the app permission settings.');
      } else if (e.toString().contains('not available')) {
        throw Exception('Bluetooth is unavailable. Please make sure Bluetooth is enabled.');
      } else {
        rethrow;
      }
    } finally {
      isScanning = false;
      _scanStopCompleter = null;
    }
  }

  /// 停止扫描
  Future<void> stopScan() async {
    if (!isScanning) {
      if (!(_scanStopCompleter?.isCompleted ?? true)) {
        _scanStopCompleter?.complete();
      }
      return;
    }

    try {
      print('[BLE Service] Stopping scan...');
      _scanSubscription?.cancel();
      await UniversalBle.stopScan();
      isScanning = false;
      if (!(_scanStopCompleter?.isCompleted ?? true)) {
        _scanStopCompleter?.complete();
      }
    } catch (e) {
      print('[BLE Service] Error stopping scan: $e');
      if (!(_scanStopCompleter?.isCompleted ?? true)) {
        _scanStopCompleter?.complete();
      }
    }
  }

  /// 从系统已连接设备中查找 ApexNub-Adapter，若找到则返回该设备，否则返回 null
  Future<BleDevice?> getSystemApexNubDevice() async {
    try {
      var devices = await UniversalBle.getSystemDevices(
        withServices: const [configServiceUuidFull],
      ).timeout(const Duration(seconds: 5), onTimeout: () => <BleDevice>[]);

      if (devices.isEmpty) {
        devices = await UniversalBle.getSystemDevices()
            .timeout(const Duration(seconds: 5), onTimeout: () => <BleDevice>[]);
      }

      for (final d in devices) {
        if (d.name?.isNotEmpty == true && _isTargetDevice(d.name!)) {
          return d;
        }
      }
    } catch (e) {
      print('[BLE Service] getSystemApexNubDevice error: $e');
    }
    return null;
  }

  /// 检查是否是目标设备
  bool _isTargetDevice(String name) {
    final lowerName = name.toLowerCase();
    return lowerName == deviceName.toLowerCase() ||
        lowerName.contains('apexnub') ||
        lowerName.contains('apex') ||
        lowerName.contains('nub') ||
        lowerName.contains('adapter');
  }

  /// 连接到设备（严格状态机，解决 Android GATT error 133 / Already connected 竞态）
  Future<bool> connectToDevice(BleDevice device) async {
    final deviceId = device.deviceId ?? '';
    print('[BLE Service] Connecting to device: ${device.name ?? "Unknown"} ($deviceId)');

    // 步骤 1：先停止扫描，避免扫描与连接并发导致 GATT 133
    if (isScanning) {
      await stopScan();
    }

    // 步骤 2：主动断开悬挂的旧 GATT 连接，避免 "Already connected" 竞态
    try {
      await UniversalBle.disconnect(deviceId);
    } catch (_) {}
    // 给 Android BLE 栈沉淀时间（扫描停止 + GATT 关闭）
    await Future.delayed(const Duration(milliseconds: 800));

    final completer = Completer<bool>();

    // 步骤 3：设置连接状态监听，用 Completer 等待真正的 connected 回调
    UniversalBle.onConnectionChange = (changedId, isConnectedState, error) {
      print('[BLE Service] Connection state changed for $changedId: $isConnectedState');
      if (error != null) {
        print('[BLE Service] Connection error: $error');
      }

      if (changedId != deviceId) return;

      if (isConnectedState) {
        connectedDeviceId = changedId;
        connectedDeviceName = device.name;
        isConnected = true;
        _connectionStateController.add(true);
        if (!completer.isCompleted) completer.complete(true);
      } else {
        if (connectedDeviceId == changedId) {
          connectedDeviceId = null;
          connectedDeviceName = null;
          isConnected = false;
          _connectionStateController.add(false);
        }
        if (!completer.isCompleted) completer.complete(false);
      }
    };

    try {
      await UniversalBle.connect(deviceId);
    } catch (e) {
      print('[BLE Service] connect() threw: $e');
      // 若 connect() 抛出时 onConnectionChange(true) 已先触发（"Already connected" 竞态），
      // completer 已经完成为 true，不要覆盖它。
      if (!completer.isCompleted) completer.complete(false);
    }

    // 步骤 4：等待真正的连接回调（超时 20s）
    // onTimeout 加 500ms 宽限期：onPhyUpdate 之后 onConnectionStateChange 可能仍在
    // Dart 事件队列中排队，宽限期让它有机会先处理，避免"已连接却报超时"的竞态。
    final connected = await completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () async {
        await Future.delayed(const Duration(milliseconds: 500));
        if (isConnected && connectedDeviceId == deviceId) {
          print('[BLE Service] Connected (late callback within grace period)');
          return true;
        }
        print('[BLE Service] Connection timed out');
        return false;
      },
    );

    if (!connected) {
      // 确实超时或失败：主动断开以释放 GATT 资源，避免下次重试时 error 133
      try {
        await UniversalBle.disconnect(deviceId);
      } catch (_) {}
      print('[BLE Service] Connection failed or timed out');
      return false;
    }

    // 步骤 5：连接成功后稍作等待，让 Android BLE 栈稳定
    await Future.delayed(const Duration(milliseconds: 600));

    // 步骤 6：发现服务
    try {
      final services = await UniversalBle.discoverServices(deviceId);
      _cacheCharacteristicProperties(services);
    } catch (e) {
      print('[BLE Service] Warning: Could not discover all services: $e');
    }

    return true;
  }

  /// 连接到已配对的设备
  Future<bool> connectToPairedDevice() async {
    try {
      print('[BLE Service] Attempting to connect to paired devices...');

      final pairedDevices = await UniversalBle.getSystemDevices()
          .timeout(const Duration(seconds: 10), onTimeout: () {
        print('[BLE Service] Warning: getSystemDevices timed out');
        return <BleDevice>[];
      });

      print('[BLE Service] Found ${pairedDevices.length} paired devices');

      for (final device in pairedDevices) {
        print('[BLE Service] Paired device: ${device.name ?? "Unknown"} (${device.deviceId ?? "No ID"})');

        if (device.name?.isNotEmpty == true && _isTargetDevice(device.name!)) {
          print('[BLE Service] Attempting to connect to paired device: ${device.name ?? "Unknown"}');

          try {
            bool success = await connectToDevice(device).timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                print('[BLE Service] Connection to ${device.name} timed out');
                return false;
              },
            );
            if (success) {
              return true;
            }
          } catch (e) {
            print('[BLE Service] Failed to connect to paired device ${device.name ?? "Unknown"}: $e');
            continue;
          }
        }
      }

      print('[BLE Service] No suitable paired devices found or could not connect');
      return false;
    } catch (e) {
      print('[BLE Service] Error connecting to paired devices: $e');
      return false;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    if (connectedDeviceId != null) {
      try {
        await UniversalBle.disconnect(connectedDeviceId!);
        connectedDeviceId = null;
        connectedDeviceName = null;
        isConnected = false;
        _connectionStateController.add(false);
      } catch (e) {
        print('[BLE Service] Error disconnecting: $e');
      }
    }
  }

  /// 写入数据到特征值
  Future<bool> writeValue({
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    bool withoutResponse = false,
  }) async {
    if (connectedDeviceId == null) {
      print('[BLE Service] Device not connected');
      return false;
    }

    try {
      final cacheKey = _characteristicCacheKey(serviceUuid, characteristicUuid);
      final supportsWithoutResponse =
          _withoutResponseSupportCache[cacheKey] ?? false;
      final useWithoutResponse = withoutResponse && supportsWithoutResponse;

      if (withoutResponse && !supportsWithoutResponse) {
        print('[BLE Service] Characteristic $characteristicUuid does not support writeWithoutResponse, falling back to write with response');
      }

      print('[BLE Service] Writing value to service: $serviceUuid, characteristic: $characteristicUuid, withoutResponse: $useWithoutResponse, bytes: ${_formatBytes(value)}');
      await UniversalBle.write(
        connectedDeviceId!,
        serviceUuid,
        characteristicUuid,
        Uint8List.fromList(value),
        withoutResponse: useWithoutResponse,
      );
      print('[BLE Service] Write successful');
      return true;
    } catch (e) {
      print('[BLE Service] Error writing value: $e');
      return false;
    }
  }

  /// 从特征值读取数据
  Future<Uint8List?> readValue({
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    if (connectedDeviceId == null) {
      print('[BLE Service] Device not connected');
      return null;
    }

    try {
      print('[BLE Service] Reading value from service: $serviceUuid, characteristic: $characteristicUuid');
      final value = await UniversalBle.read(
        connectedDeviceId!,
        serviceUuid,
        characteristicUuid,
      );
      print('[BLE Service] Read successful, length: ${value.length}');
      return value;
    } catch (e) {
      print('[BLE Service] Error reading value: $e');
      return null;
    }
  }

  /// 发现服务
  Future<List<BleService>> discoverServices() async {
    if (connectedDeviceId == null) {
      print('[BLE Service] Device not connected');
      return [];
    }

    try {
      print('[BLE Service] Discovering services...');
      final services = await UniversalBle.discoverServices(connectedDeviceId!);
      _cacheCharacteristicProperties(services);
      print('[BLE Service] Discovered ${services.length} services');
      return services;
    } catch (e) {
      print('[BLE Service] Error discovering services: $e');
      return [];
    }
  }

  /// 清理资源
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _connectionStateController.close();
    _scanResultsController.close();
  }
}

