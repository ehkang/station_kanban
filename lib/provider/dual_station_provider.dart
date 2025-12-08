import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:dio/dio.dart';
import '../model/device.dart';
import '../model/container.dart' as model;
import '../model/goods.dart';
import '../service/signalr_service.dart';
import '../utils/list_diff_updater.dart';
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

  // 站台3002的数据
  String _station3002Name = 'Tran3002';
  String _container3002 = '';
  final List<Goods> _goods3002 = [];

  // 站台3003的数据
  String _station3003Name = 'Tran3003';
  String _container3003 = '';
  final List<Goods> _goods3003 = [];

  // 定时刷新相关
  Timer? _refreshTimer3002; // 站台 3002 的定时刷新定时器
  Timer? _refreshTimer3003; // 站台 3003 的定时刷新定时器
  static const Duration _refreshInterval = Duration(seconds: 10); // 刷新间隔：10秒

  // 🎯 Stream 订阅管理（防止内存泄漏和 dispose 后被调用）
  // 注意：连接状态由 DashboardProvider 统一管理，此处只订阅必要的业务数据
  StreamSubscription<DeviceUpdateEvent>? _deviceUpdatesSubscription;
  StreamSubscription<LogEvent>? _logsSubscription;

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
  // 注意：连接状态通过 DashboardProvider 统一提供，此处不再暴露

  // 站台3002
  String get station3002Name => _station3002Name;
  String get container3002 => _container3002;
  List<Goods> get goods3002 => _goods3002;

  // 站台3003
  String get station3003Name => _station3003Name;
  String get container3003 => _container3003;
  List<Goods> get goods3003 => _goods3003;

  /// 初始化 SignalR 连接
  /// 注意：连接状态由 DashboardProvider 统一管理，此处只订阅业务数据
  void _initSignalR() {
    // 🎯 监听设备更新（保存订阅引用）
    _deviceUpdatesSubscription = _signalRService.deviceUpdates.listen((event) {
      updateDevice(event.deviceNo, event.data);
    });

    // 🎯 监听服务器推送的日志（保存订阅引用）
    _logsSubscription = _signalRService.logs.listen((logEvent) {
      _addLog(logEvent.message);
    });

    // 启动连接（SignalRService 内部已有防重复逻辑）
    _signalRService.connect();
  }

  // 注意：手动重连功能由 DashboardProvider 统一提供

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
  ///
  /// 📍 关键逻辑：
  /// - 容器出现：立即获取货物 + 启动 10 秒定时刷新
  /// - 容器离开：停止定时刷新 + 清空数据
  Future<void> _checkStationContainer(String stationCode) async {
    final containerCode = _deviceTrayMap[stationCode];

    if (containerCode != null && containerCode.isNotEmpty) {
      // 🎯 场景 1：容器出现或变化
      if (stationCode == 'Tran3002') {
        if (containerCode != _container3002) {
          // 立即获取货物数据
          await _fetchGoods(stationCode, containerCode);
          // 启动定时刷新
          _startRefreshTimer('Tran3002', containerCode);
        }
      } else if (stationCode == 'Tran3003') {
        if (containerCode != _container3003) {
          // 立即获取货物数据
          await _fetchGoods(stationCode, containerCode);
          // 启动定时刷新
          _startRefreshTimer('Tran3003', containerCode);
        }
      }
    } else {
      // 🎯 场景 2：容器离开站台
      if (stationCode == 'Tran3002') {
        if (_container3002.isNotEmpty) {
          // 停止定时刷新
          _stopRefreshTimer('Tran3002');
          // 清空数据
          _container3002 = '';
          _goods3002.clear();
          notifyListeners();
        }
      } else if (stationCode == 'Tran3003') {
        if (_container3003.isNotEmpty) {
          // 停止定时刷新
          _stopRefreshTimer('Tran3003');
          // 清空数据
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
          final newGoods = goodsList.map((item) => Goods.fromJson(item as Map<String, dynamic>)).toList();

          bool hasChanges = false;

          if (stationCode == 'Tran3002') {
            _container3002 = containerCode;
            // 🎯 使用智能差异更新，避免不必要的重建
            hasChanges = ListDiffUpdater.updateGoodsList(_goods3002, newGoods);
          } else if (stationCode == 'Tran3003') {
            _container3003 = containerCode;
            // 🎯 使用智能差异更新，避免不必要的重建
            hasChanges = ListDiffUpdater.updateGoodsList(_goods3003, newGoods);
          }

          // 🎯 只有数据真正变化时才通知 UI 更新
          if (hasChanges) {
            notifyListeners();
          }
        }
      }
    } catch (e) {
      print('获取货物信息失败: $e');
    }
  }

  /// 启动指定站台的定时刷新
  ///
  /// 📍 触发时机：容器出现在站台上时
  /// 📍 刷新频率：每 10 秒一次
  void _startRefreshTimer(String stationCode, String containerCode) {
    // 先停止旧的定时器（如果存在）
    _stopRefreshTimer(stationCode);

    // 创建新的定时刷新定时器
    final timer = Timer.periodic(_refreshInterval, (timer) {
      // 定时刷新货物数据
      _fetchGoods(stationCode, containerCode);
    });

    // 保存到对应的定时器字段
    if (stationCode == 'Tran3002') {
      _refreshTimer3002 = timer;
    } else if (stationCode == 'Tran3003') {
      _refreshTimer3003 = timer;
    }
  }

  /// 停止指定站台的定时刷新
  ///
  /// 📍 触发时机：容器离开站台时、dispose 时
  void _stopRefreshTimer(String stationCode) {
    if (stationCode == 'Tran3002') {
      _refreshTimer3002?.cancel();
      _refreshTimer3002 = null;
    } else if (stationCode == 'Tran3003') {
      _refreshTimer3003?.cancel();
      _refreshTimer3003 = null;
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
    // 🎯 取消业务数据订阅（防止 disposed 后被调用）
    _deviceUpdatesSubscription?.cancel();
    _logsSubscription?.cancel();

    // 🎯 清理所有定时器
    _stopRefreshTimer('Tran3002');
    _stopRefreshTimer('Tran3003');

    // Note: 不要在这里 dispose signalRService，因为 DashboardProvider 可能还在使用
    super.dispose();
  }
}

/// Provider 实例（与单站台共享 SignalRService）
/// 🎯 使用 autoDispose 确保页面卸载时自动清理定时器
final dualStationProvider = ChangeNotifierProvider.autoDispose<DualStationProvider>((ref) {
  // 复用单站台的 SignalRService
  final signalRService = ref.watch(signalRServiceProvider);
  return DualStationProvider(signalRService);
});
