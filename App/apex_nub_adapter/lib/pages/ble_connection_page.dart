import 'dart:async';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import '../services/apex_nub_ble_service.dart';
import 'control_page.dart';

class BleConnectionPage extends StatefulWidget {
  const BleConnectionPage({super.key});

  @override
  State<BleConnectionPage> createState() => _BleConnectionPageState();
}

class _BleConnectionPageState extends State<BleConnectionPage> {
  final ApexNubBleService _bleService = ApexNubBleService();
  
  List<BleDevice> _devices = [];
  bool _isScanning = false;
  BleDevice? _connectedDevice;
  bool _isConnecting = false;
  StreamSubscription<List<BleDevice>>? _scanResultsSubscription;
  StreamSubscription<bool>? _connectionStateSubscription;

  // PNP ID constants
  static const int vendorId = 0xABCF;
  static const int productId = 0xABCF;
  static const String deviceName = 'ApexNub-Adapter';

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    // 请求权限
    await _bleService.requestPermissions();
    
    // 监听扫描结果
    _scanResultsSubscription = _bleService.scanResultsStream.listen((devices) {
      if (mounted) {
        setState(() {
          _devices = devices;
        });
      }
    });

    // 监听连接状态
    _connectionStateSubscription = _bleService.connectionStateStream.listen((connected) {
      if (mounted) {
        setState(() {
          if (connected) {
            // 查找已连接的设备
            try {
              _connectedDevice = _devices.firstWhere(
                (d) => d.deviceId == _bleService.connectedDeviceId,
              );
            } catch (e) {
              // 如果设备不在列表中，尝试从扫描结果中查找
              _connectedDevice = _bleService.scanResults.firstWhere(
                (d) => d.deviceId == _bleService.connectedDeviceId,
                orElse: () {
                  // 创建一个临时设备对象用于导航
                  return _devices.isNotEmpty ? _devices.first : 
                    BleDevice(
                      deviceId: _bleService.connectedDeviceId ?? '',
                      name: _bleService.connectedDeviceName,
                      rssi: 0,
                    );
                },
              );
            }
            // 导航到控制页面
            if (_connectedDevice != null) {
              _navigateToControlPage(_connectedDevice!);
            }
          } else {
            _connectedDevice = null;
          }
        });
      }
    });

    await _loadSystemConnectedDevice();
  }

  Future<bool> _loadSystemConnectedDevice({bool connectIfFound = false}) async {
    try {
      final systemDevice = await _bleService.getSystemApexNubDevice();
      if (!mounted || systemDevice == null) {
        return false;
      }

      setState(() {
        _devices = [
          systemDevice,
          ..._devices.where((device) => device.deviceId != systemDevice.deviceId),
        ];
      });

      if (connectIfFound) {
        await _connectToDevice(systemDevice);
      }
      return true;
    } catch (e) {
      print('Failed to load system connected device: $e');
      return false;
    }
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    // 1. 若服务层已记录连接状态，直接进入控制页面
    if (_bleService.isConnected && _bleService.connectedDeviceId != null) {
      final device = BleDevice(
        deviceId: _bleService.connectedDeviceId!,
        name: _bleService.connectedDeviceName,
        rssi: 0,
      );
      _navigateToControlPage(device);
      return;
    }

    // 2. 查询系统已连接的 ApexNub-Adapter（跨进程/重启后恢复连接）
    setState(() { _isScanning = true; });
    try {
      final foundSystemDevice = await _loadSystemConnectedDevice(connectIfFound: true);
      if (foundSystemDevice) {
        setState(() { _isScanning = false; });
        return;
      }
    } catch (_) {}

    // 3. 未发现已连接设备，执行正常扫描
    setState(() {
      _devices.clear();
    });

    try {
      await _bleService.startScan();
      setState(() {
        _isScanning = _bleService.isScanning;
      });
    } catch (e) {
      print('Failed to start scan: $e');
      setState(() {
        _isScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    }
  }

  void _navigateToControlPage(BleDevice device) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ControlPage(device: device),
      ),
    );
  }

  Future<void> _stopScan() async {
    await _bleService.stopScan();
    setState(() {
      _isScanning = _bleService.isScanning;
    });
  }

  Future<void> _connectToDevice(BleDevice device) async {
    if (_isConnecting || _connectedDevice != null) return;

    if (_isScanning) {
      setState(() {
        _isScanning = false;
      });
      try {
        await _bleService.stopScan();
      } catch (e) {
        print('Failed to stop scan before connecting: $e');
      }
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      final success = await _bleService.connectToDevice(device);
      if (!success) {
        throw Exception('Connection failed');
      }
      // 连接状态会通过 stream 更新
    } catch (e) {
      print('Failed to connect: $e');
      setState(() {
        _isConnecting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _disconnect() async {
    await _bleService.disconnect();
    setState(() {
      _connectedDevice = null;
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Device Connection'),
        actions: [
          if (_isScanning)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopScan,
              tooltip: 'Stop scan',
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _startScan,
              tooltip: 'Start scan',
            ),
        ],
      ),
      body: Column(
        children: [
          // Status card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Device Name: $deviceName'),
                  Text('Vendor ID: 0x${vendorId.toRadixString(16).toUpperCase()}'),
                  Text('Product ID: 0x${productId.toRadixString(16).toUpperCase()}'),
                  const SizedBox(height: 8),
                  if (_isScanning)
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Scanning...'),
                      ],
                    )
                  else if (_connectedDevice != null)
                    Row(
                      children: [
                        const Icon(Icons.bluetooth_connected, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('Connected: ${_connectedDevice!.name ?? 'Unknown Device'}'),
                      ],
                    )
                  else
                    const Text('Not connected'),
                ],
              ),
            ),
          ),
          // Device list
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_searching,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning
                              ? 'Searching for devices...'
                              : 'Tap the search button to start scanning. System-connected devices will appear automatically.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(device.name ?? 'Unknown Device'),
                        subtitle: Text(
                          device.isSystemDevice == true
                              ? '${device.deviceId} · System connected'
                              : device.deviceId,
                        ),
                        trailing: _isConnecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.link),
                                onPressed: () => _connectToDevice(device),
                                tooltip: 'Connect',
                              ),
                        onTap: () => _connectToDevice(device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

