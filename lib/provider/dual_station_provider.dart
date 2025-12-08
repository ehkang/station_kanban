import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:dio/dio.dart';
import '../model/device.dart';
import '../model/container.dart' as model;
import '../model/goods.dart';
import '../service/signalr_service.dart';
import 'dashboard_provider.dart';

/// 双站台状态管理
/// 对应 Vue 项目中的 DualStationView.vue
/// 同时管理 Tran3002 和 Tran3003 两个站台
class DualStationProvider extends ChangeNotifier {
  final SignalRService _signalRService;

  // 状态数据
  final Map<String, Device> _devices = {};
  final Map<String, model.ContainerModel> _containers = {};
  final Map<String, String> _deviceTrayMap = {}; // deviceCode -> containerCode
  final List<String> _logs = [];
  bool _isConnected = false;
  HubConnectionState _connectionState = HubConnectionState.Disconnected;
  int _reconnectCount = 0;

  // 站台3002的数据
  String _station3002Name = 'Tran3002';
  String _container3002 = '';
  final List<Goods> _goods3002 = [];

  // 站台3003的数据
  String _station3003Name = 'Tran3003';
  String _container3003 = '';
  final List<Goods> _goods3003 = [];

  // 日志限制
  static const int _maxLogCount = 100;

  DualStationProvider(this._signalRService) {
    _initSignalR();
    _initGetDeviceInfo();
  }

  // Getters
  Map<String, Device> get devices => _devices;
  Map<String, model.ContainerModel> get containers => _containers;
  List<String> get logs => _logs;
  bool get isConnected => _isConnected;
  HubConnectionState get connectionState => _connectionState;
  int get reconnectCount => _reconnectCount;

  // 站台3002
  String get station3002Name => _station3002Name;
  String get container3002 => _container3002;
  List<Goods> get goods3002 => _goods3002;

  // 站台3003
  String get station3003Name => _station3003Name;
  String get container3003 => _container3003;
  List<Goods> get goods3003 => _goods3003;

  /// 初始化 SignalR 连接
  void _initSignalR() {
    // 监听连接状态
    _signalRService.connectionState.listen((state) {
      _connectionState = state;
      _isConnected = state == HubConnectionState.Connected;
      notifyListeners();
    });

    // 监听重连次数
    _signalRService.reconnectCount.listen((count) {
      _reconnectCount = count;
      notifyListeners();
    });

    // 监听设备更新
    _signalRService.deviceUpdates.listen((event) {
      updateDevice(event.deviceNo, event.data);
    });

    // 监听服务器推送的日志
    _signalRService.logs.listen((logEvent) {
      _addLog(logEvent.message);
    });

    // 启动连接
    _signalRService.connect();
  }

  /// 手动重连
  Future<void> manualReconnect() async {
    await _signalRService.reconnect();
  }

  /// 更新设备数据
  void updateDevice(String deviceNo, Map<String, dynamic> newInfo) {
    try {
      final mappedInfo = _mapDeviceFields(newInfo);

      if (!mappedInfo.containsKey('deviceCode')) {
        mappedInfo['deviceCode'] = deviceNo;
      }

      final device = Device.fromJson(mappedInfo);
      _devices[deviceNo] = device;

      // 更新站台名称
      if (deviceNo == 'Tran3002') {
        _station3002Name = device.deviceName ?? device.deviceCode;
      } else if (deviceNo == 'Tran3003') {
        _station3003Name = device.deviceName ?? device.deviceCode;
      }

      // 更新托盘映射
      _updateDeviceTrayMap();

      // 检查两个站台的容器
      _checkStationContainer('Tran3002');
      _checkStationContainer('Tran3003');

      notifyListeners();
    } catch (e) {
      print('设备数据解析错误: $e');
      print('原始数据: $newInfo');
    }
  }

  /// 更新设备托盘映射
  void _updateDeviceTrayMap() {
    _deviceTrayMap.clear();

    for (final device in _devices.values) {
      _processDevice(device);
    }

    _deduplicateTrays();
  }

  /// 处理单个设备及其子设备
  void _processDevice(Device device) {
    final deviceCode = device.deviceCode;

    // 处理子设备
    if (device.children.isNotEmpty) {
      for (final child in device.children) {
        final childDeviceCode = child.deviceCode;

        if (_isPalletValid(child.palletCode)) {
          _deviceTrayMap[childDeviceCode] = child.palletCode!;

          if (!_containers.containsKey(child.palletCode)) {
            _containers[child.palletCode!] = model.ContainerModel(
              containerCode: child.palletCode!,
              deviceCode: childDeviceCode,
              address: child.address,
              taskCode: child.taskCode,
            );
          }
        }
      }
    }

    // 处理独立设备
    final isChildDevice = deviceCode.startsWith('Tran');
    final shouldInclude = isChildDevice ||
        (device.workStatus != null && device.workStatus != 0);

    if (shouldInclude && _isPalletValid(device.palletCode)) {
      _deviceTrayMap[deviceCode] = device.palletCode!;

      if (!_containers.containsKey(device.palletCode)) {
        _containers[device.palletCode!] = model.ContainerModel(
          containerCode: device.palletCode!,
          deviceCode: deviceCode,
          address: device.address,
          taskCode: device.taskCode,
        );
      }
    }
  }

  /// 托盘去重
  void _deduplicateTrays() {
    final Map<String, List<String>> trayDeviceGroups = {};

    for (final entry in _deviceTrayMap.entries) {
      final deviceCode = entry.key;
      final containerCode = entry.value;

      trayDeviceGroups.putIfAbsent(containerCode, () => []);
      trayDeviceGroups[containerCode]!.add(deviceCode);
    }

    for (final entry in trayDeviceGroups.entries) {
      final containerCode = entry.key;
      final deviceCodes = entry.value;

      if (deviceCodes.length > 1) {
        deviceCodes.sort((a, b) {
          final priorityA = _getDevicePriority(a);
          final priorityB = _getDevicePriority(b);
          return priorityB.compareTo(priorityA);
        });

        final keepDevice = deviceCodes.first;
        final container = _containers[containerCode];
        if (container != null) {
          final keepDeviceObj = _getDeviceByCode(keepDevice);
          _containers[containerCode] = model.ContainerModel(
            containerCode: containerCode,
            deviceCode: keepDevice,
            address: keepDeviceObj?.address,
            taskCode: keepDeviceObj?.taskCode,
            containerTypeCode: container.containerTypeCode,
            containerTypeName: container.containerTypeName,
            destAddress: container.destAddress,
            sourceAddress: container.sourceAddress,
            status: container.status,
            createTime: container.createTime,
            updateTime: container.updateTime,
          );
        }

        for (int i = 1; i < deviceCodes.length; i++) {
          _deviceTrayMap.remove(deviceCodes[i]);
        }
      }
    }
  }

  /// 根据 deviceCode 获取设备对象
  Device? _getDeviceByCode(String deviceCode) {
    if (_devices.containsKey(deviceCode)) {
      return _devices[deviceCode];
    }

    for (final device in _devices.values) {
      for (final child in device.children) {
        if (child.deviceCode == deviceCode) {
          return child;
        }
      }
    }

    return null;
  }

  /// 检查托盘编码是否有效
  bool _isPalletValid(String? palletCode) {
    return palletCode != null &&
        palletCode != '0' &&
        palletCode.trim().isNotEmpty;
  }

  /// 获取设备优先级
  int _getDevicePriority(String deviceCode) {
    if (deviceCode.startsWith('Tran')) return 3;
    if (deviceCode.startsWith('Stack')) return 2;
    if (deviceCode.startsWith('Station')) return 1;
    return 0;
  }

  /// 主动查询设备初始状态
  Future<void> _initGetDeviceInfo() async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'http://10.20.88.14:8009/api/WCS',
        connectTimeout: const Duration(seconds: 10),
        headers: {'Cache-Control': 'no-cache'},
      ));

      final watchDevices = ['Crn2002', 'TranLine3000', 'Crn2001', 'RGV01'];

      for (final deviceCode in watchDevices) {
        try {
          final response = await dio.get('/getDevice/$deviceCode');

          if (response.data != null) {
            final deviceInfo = response.data as Map<String, dynamic>;

            if (deviceInfo['childrenDevice'] != null) {
              final children = deviceInfo['childrenDevice'] as List?;
              if (children != null && children.isNotEmpty) {
                for (final child in children) {
                  final childData = child as Map<String, dynamic>;
                  final childCode = childData['code'] as String?;
                  if (childCode != null) {
                    final device = Device.fromJson(_mapDeviceFields(childData));
                    _devices[childCode] = device;

                    if (childCode == 'Tran3002') {
                      _station3002Name = device.deviceName ?? device.deviceCode;
                    } else if (childCode == 'Tran3003') {
                      _station3003Name = device.deviceName ?? device.deviceCode;
                    }
                  }
                }
              }
            } else {
              final device = Device.fromJson(_mapDeviceFields(deviceInfo));
              _devices[deviceCode] = device;
            }
          }
        } catch (e) {
          print('设备 $deviceCode 初始化失败: $e');
        }
      }

      _updateDeviceTrayMap();
      await _checkStationContainer('Tran3002');
      await _checkStationContainer('Tran3003');
      notifyListeners();
    } catch (e) {
      print('初始化设备信息失败: $e');
      Future.delayed(const Duration(seconds: 3), _initGetDeviceInfo);
    }
  }

  /// 字段名映射
  Map<String, dynamic> _mapDeviceFields(Map<String, dynamic> rawData) {
    final mappedInfo = <String, dynamic>{};

    rawData.forEach((key, value) {
      if (key == 'code') {
        mappedInfo['deviceCode'] = value;
      } else if (key == 'name') {
        mappedInfo['deviceName'] = value;
      } else if (key == 'childrenDevice') {
        mappedInfo['children'] = value;
      } else {
        mappedInfo[key] = value;
      }
    });

    return mappedInfo;
  }

  /// 检查指定站台的容器和货物
  Future<void> _checkStationContainer(String stationCode) async {
    final containerCode = _deviceTrayMap[stationCode];

    if (containerCode != null && containerCode.isNotEmpty) {
      if (stationCode == 'Tran3002') {
        if (containerCode != _container3002) {
          await _fetchGoods(stationCode, containerCode);
        }
      } else if (stationCode == 'Tran3003') {
        if (containerCode != _container3003) {
          await _fetchGoods(stationCode, containerCode);
        }
      }
    } else {
      // 站台上没有容器，清空数据
      if (stationCode == 'Tran3002') {
        if (_container3002.isNotEmpty) {
          _container3002 = '';
          _goods3002.clear();
          notifyListeners();
        }
      } else if (stationCode == 'Tran3003') {
        if (_container3003.isNotEmpty) {
          _container3003 = '';
          _goods3003.clear();
          notifyListeners();
        }
      }
    }
  }

  /// 获取容器货物信息
  Future<void> _fetchGoods(String stationCode, String containerCode) async {
    if (containerCode.isEmpty || containerCode == '0') {
      return;
    }

    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'http://10.20.88.14:8008/api/warehouse',
        connectTimeout: const Duration(seconds: 10),
        headers: {'Cache-Control': 'no-cache'},
      ));

      final url = '/Inventory/container/$containerCode';
      final response = await dio.get(url);

      if (response.data != null && response.data['errCode'] == 0) {
        final goodsList = response.data['data'] as List?;

        if (goodsList != null) {
          final goods = goodsList.map((item) => Goods.fromJson(item as Map<String, dynamic>)).toList();

          if (stationCode == 'Tran3002') {
            _container3002 = containerCode;
            _goods3002.clear();
            _goods3002.addAll(goods);
          } else if (stationCode == 'Tran3003') {
            _container3003 = containerCode;
            _goods3003.clear();
            _goods3003.addAll(goods);
          }
        }
      }

      notifyListeners();
    } catch (e) {
      print('获取货物信息失败: $e');
    }
  }

  /// 添加日志
  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _logs.add('[$timestamp] $message');

    if (_logs.length > _maxLogCount) {
      final removeCount = _logs.length - _maxLogCount;
      _logs.removeRange(0, removeCount);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    // Note: 不要在这里 dispose signalRService，因为单站台可能还在使用
    super.dispose();
  }
}

/// Provider 实例（与单站台共享 SignalRService）
final dualStationProvider = ChangeNotifierProvider<DualStationProvider>((ref) {
  // 复用单站台的 SignalRService
  final signalRService = ref.watch(signalRServiceProvider);
  return DualStationProvider(signalRService);
});
