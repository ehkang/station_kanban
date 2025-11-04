import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../model/device.dart';
import '../model/container.dart' as model;
import '../service/signalr_service.dart';

/// Dashboard 状态管理
/// 对应 Vue 项目中的 wms.ts store
class DashboardProvider extends ChangeNotifier {
  final SignalRService _signalRService;

  // 状态数据
  final Map<String, Device> _devices = {};
  final Map<String, model.ContainerModel> _containers = {};
  final Map<String, String> _deviceTrayMap = {}; // deviceCode -> containerCode
  final List<String> _logs = [];
  bool _isConnected = false;

  DashboardProvider(this._signalRService) {
    _initSignalR();
  }

  // Getters
  Map<String, Device> get devices => _devices;
  Map<String, model.ContainerModel> get containers => _containers;
  Map<String, String> get deviceTrayMap => _deviceTrayMap;
  List<String> get logs => _logs;
  bool get isConnected => _isConnected;

  /// 获取有托盘的容器列表（用于左侧托盘列表显示）
  List<model.ContainerModel> get traysWithDevices {
    return _deviceTrayMap.values
        .map((containerCode) => _containers[containerCode])
        .whereType<model.ContainerModel>()
        .toList();
  }

  /// 初始化 SignalR 连接
  void _initSignalR() {
    // 监听连接状态
    _signalRService.connectionState.listen((state) {
      _isConnected = state == HubConnectionState.Connected;
      _addLog('连接状态: ${_getConnectionStateName(state)}');
      notifyListeners();
    });

    // 监听设备更新
    _signalRService.deviceUpdates.listen((event) {
      updateDevice(event.deviceNo, event.data);
    });

    // 启动连接
    _signalRService.connect().catchError((error) {
      _addLog('SignalR 连接失败: $error');
    });
  }

  /// 更新设备数据
  /// 对应 Vue 中的 updateDevice 方法
  void updateDevice(String deviceNo, Map<String, dynamic> newInfo) {
    try {
      // Vue 项目中的字段名可能是 'code' 而不是 'deviceCode'
      // 需要做字段映射
      final mappedInfo = <String, dynamic>{};

      // 字段名映射：Vue (code) -> Flutter (deviceCode)
      newInfo.forEach((key, value) {
        if (key == 'code') {
          mappedInfo['deviceCode'] = value;
        } else if (key == 'name') {
          mappedInfo['deviceName'] = value;
        } else if (key == 'childrenDevice') {
          // Vue 中是 childrenDevice，Flutter 中是 children
          mappedInfo['children'] = value;
        } else {
          mappedInfo[key] = value;
        }
      });

      // 确保 deviceCode 字段存在
      if (!mappedInfo.containsKey('deviceCode')) {
        mappedInfo['deviceCode'] = deviceNo;
      }

      final device = Device.fromJson(mappedInfo);

      _devices[deviceNo] = device;
      _addLog('设备更新: $deviceNo');

      // 更新托盘映射
      _updateDeviceTrayMap();

      notifyListeners();
    } catch (e) {
      _addLog('更新设备失败: $e');
      // 打印详细错误信息用于调试
      print('设备数据解析错误: $e');
      print('原始数据: $newInfo');
    }
  }

  /// 更新设备托盘映射
  /// 这是核心逻辑，对应 Vue 项目中 wms.ts 的 updateDeviceTrayMap 方法
  void _updateDeviceTrayMap() {
    _deviceTrayMap.clear();

    // 遍历所有设备
    for (final device in _devices.values) {
      _processDevice(device);
    }

    // 托盘去重：同一个托盘可能在多个设备上，需要去重
    _deduplicateTrays();
  }

  /// 处理单个设备及其子设备
  /// 对应 TypeScript 中的设备处理逻辑
  void _processDevice(Device device) {
    final deviceCode = device.deviceCode;

    // 处理子设备（如穿梭车 Tran 系列）
    if (device.children.isNotEmpty) {
      for (final child in device.children) {
        final childDeviceCode = child.deviceCode;

        // 子设备逻辑：只检查托盘有效性，不检查工作状态
        // 对应 TypeScript: if (child.palletCode && child.palletCode != '0' && ...)
        if (_isPalletValid(child.palletCode)) {
          _deviceTrayMap[childDeviceCode] = child.palletCode!;

          // 如果 containers 中没有该托盘，创建一个
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
    // 对应 TypeScript: const isChildDevice = deviceCode.startsWith('Tran')
    final isChildDevice = deviceCode.startsWith('Tran');

    // 对应 TypeScript: const shouldInclude = isChildDevice || (device.workStatus != null && device.workStatus !== 0)
    final shouldInclude = isChildDevice ||
        (device.workStatus != null && device.workStatus != 0);

    if (shouldInclude && _isPalletValid(device.palletCode)) {
      _deviceTrayMap[deviceCode] = device.palletCode!;

      // 如果 containers 中没有该托盘，创建一个
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
  /// 对应 TypeScript 中的 deduplicateTrays 逻辑
  void _deduplicateTrays() {
    final Map<String, List<String>> trayDeviceGroups = {};

    // 按托盘编码分组
    for (final entry in _deviceTrayMap.entries) {
      final deviceCode = entry.key;
      final containerCode = entry.value;

      trayDeviceGroups.putIfAbsent(containerCode, () => []);
      trayDeviceGroups[containerCode]!.add(deviceCode);
    }

    // 对于同一托盘在多个设备上的情况，只保留一个
    // 优先级：Tran > Stack > Station
    for (final entry in trayDeviceGroups.entries) {
      final containerCode = entry.key;
      final deviceCodes = entry.value;

      if (deviceCodes.length > 1) {
        // 按优先级排序
        deviceCodes.sort((a, b) {
          final priorityA = _getDevicePriority(a);
          final priorityB = _getDevicePriority(b);
          return priorityB.compareTo(priorityA); // 降序
        });

        // 保留第一个，移除其他的
        final keepDevice = deviceCodes.first;
        for (int i = 1; i < deviceCodes.length; i++) {
          _deviceTrayMap.remove(deviceCodes[i]);
        }

        _addLog('托盘去重: $containerCode 保留在 $keepDevice');
      }
    }
  }

  /// 检查托盘编码是否有效
  bool _isPalletValid(String? palletCode) {
    return palletCode != null &&
        palletCode != '0' &&
        palletCode.trim().isNotEmpty;
  }

  /// 获取设备优先级（用于托盘去重）
  int _getDevicePriority(String deviceCode) {
    if (deviceCode.startsWith('Tran')) return 3; // 穿梭车优先级最高
    if (deviceCode.startsWith('Stack')) return 2; // 堆垛机次之
    if (deviceCode.startsWith('Station')) return 1; // 站台最低
    return 0;
  }

  /// 添加日志
  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _logs.insert(0, '[$timestamp] $message');

    // 只保留最近 100 条日志
    if (_logs.length > 100) {
      _logs.removeRange(100, _logs.length);
    }
  }

  /// 获取连接状态名称
  String _getConnectionStateName(HubConnectionState state) {
    switch (state) {
      case HubConnectionState.Connected:
        return '已连接';
      case HubConnectionState.Connecting:
        return '连接中';
      case HubConnectionState.Reconnecting:
        return '重连中';
      case HubConnectionState.Disconnecting:
        return '断开中';
      case HubConnectionState.Disconnected:
        return '已断开';
    }
  }

  @override
  void dispose() {
    _signalRService.dispose();
    super.dispose();
  }
}

/// Provider 实例
final signalRServiceProvider = Provider<SignalRService>((ref) => SignalRService());

final dashboardProvider = ChangeNotifierProvider<DashboardProvider>((ref) {
  final signalRService = ref.watch(signalRServiceProvider);
  return DashboardProvider(signalRService);
});