import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/device.dart';
import '../model/container.dart' as model;
import '../model/goods.dart';
import '../service/signalr_service.dart';
import '../utils/list_diff_updater.dart';

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
  HubConnectionState _connectionState = HubConnectionState.Disconnected;
  int _reconnectCount = 0;

  // 站台监控相关
  String _selectedStation = 'Tran3001'; // 当前选中的站台
  String _stationName = '未知站台'; // 站台名称
  String _currentContainer = ''; // 当前站台上的容器编号
  final List<Goods> _currentGoods = []; // 当前容器的货物列表

  // 定时刷新相关
  Timer? _goodsRefreshTimer; // 货物数据定时刷新定时器
  static const Duration _refreshInterval = Duration(seconds: 10); // 刷新间隔：10秒

  // 日志配置：限制最大日志数量，防止内存暴增
  // 100条日志约占用 20-30KB 内存（每条平均100字符）
  static const int _maxLogCount = 100;

  // SharedPreferences 存储 key
  static const String _selectedStationKey = 'selected_station';

  // 可选站台列表
  static const List<String> availableStations = [
    'Tran3001',
    'Tran3002',
    'Tran3003',
    'Tran3004',
  ];

  DashboardProvider(this._signalRService) {
    _loadSavedStation();
    _initSignalR();
    // 主动查询设备初始状态（不等 WebSocket 连接）
    _initGetDeviceInfo();
  }

  // Getters
  Map<String, Device> get devices => _devices;
  Map<String, model.ContainerModel> get containers => _containers;
  Map<String, String> get deviceTrayMap => _deviceTrayMap;
  List<String> get logs => _logs;
  bool get isConnected => _isConnected;
  HubConnectionState get connectionState => _connectionState;
  int get reconnectCount => _reconnectCount;

  // 站台相关 Getters
  String get selectedStation => _selectedStation;
  String get stationName => _stationName;
  String get currentContainer => _currentContainer;
  List<Goods> get currentGoods => _currentGoods;

  /// 获取站台编号（去除前缀，如 Tran3001 -> 3001）
  String get stationNumber {
    // 提取数字部分，去除 "Tran" 等前缀
    final match = RegExp(r'\d+').firstMatch(_selectedStation);
    return match?.group(0) ?? _selectedStation;
  }

  /// 获取有托盘的容器列表（用于左侧托盘列表显示）
  /// 对应 Vue 版本中的 containers 逻辑
  /// 注意：去重逻辑在 _deduplicateTrays() 中完成，这里只需要简单映射即可
  List<model.ContainerModel> get traysWithDevices {
    return _deviceTrayMap.values
        .map((containerCode) => _containers[containerCode])
        .whereType<model.ContainerModel>()
        .toList();
  }

  /// 从本地存储加载上次选择的站台
  Future<void> _loadSavedStation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStation = prefs.getString(_selectedStationKey);

      if (savedStation != null && availableStations.contains(savedStation)) {
        _selectedStation = savedStation;
        notifyListeners();
      }
    } catch (e) {
      // 静默失败，使用默认站台
    }
  }

  /// 保存当前选择的站台到本地存储
  Future<void> _saveStation(String station) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedStationKey, station);
    } catch (e) {
      // 静默失败
    }
  }

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
    // 对应 Vue 项目中的: signalRConnection.on("logger", ...)
    _signalRService.logs.listen((logEvent) {
      _addLog(logEvent.message);
    });

    // 启动连接
    _signalRService.connect();
  }

  /// 手动重连
  /// 供 UI 调用，用户可以主动触发重连
  Future<void> manualReconnect() async {
    await _signalRService.reconnect();
  }

  /// 更新设备数据
  /// 对应 Vue 中的 updateDevice 方法
  void updateDevice(String deviceNo, Map<String, dynamic> newInfo) {
    try {
      // 使用统一的字段映射方法
      final mappedInfo = _mapDeviceFields(newInfo);

      // 确保 deviceCode 字段存在
      if (!mappedInfo.containsKey('deviceCode')) {
        mappedInfo['deviceCode'] = deviceNo;
      }

      final device = Device.fromJson(mappedInfo);

      _devices[deviceNo] = device;

      // 更新站台名称（如果这是当前选中的站台）
      if (deviceNo == _selectedStation) {
        _stationName = device.deviceName ?? device.deviceCode;
      }

      // 更新托盘映射
      _updateDeviceTrayMap();

      // 检查当前站台的容器是否变化
      _checkCurrentStationContainer();

      notifyListeners();
    } catch (e) {
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

        // 更新容器的 deviceCode 为保留的设备
        final container = _containers[containerCode];
        if (container != null) {
          // 从保留的设备获取最新的地址和任务信息
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

        // 移除其他设备上的托盘映射
        for (int i = 1; i < deviceCodes.length; i++) {
          _deviceTrayMap.remove(deviceCodes[i]);
        }
      }
    }
  }

  /// 根据 deviceCode 获取设备对象（包括子设备）
  Device? _getDeviceByCode(String deviceCode) {
    // 先在顶层设备中查找
    if (_devices.containsKey(deviceCode)) {
      return _devices[deviceCode];
    }

    // 在子设备中查找
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

  /// 获取设备优先级（用于托盘去重）
  int _getDevicePriority(String deviceCode) {
    if (deviceCode.startsWith('Tran')) return 3; // 穿梭车优先级最高
    if (deviceCode.startsWith('Stack')) return 2; // 堆垛机次之
    if (deviceCode.startsWith('Station')) return 1; // 站台最低
    return 0;
  }

  /// 切换监视的站台
  /// 对应 Vue 中的 onStationChange
  Future<void> changeStation(String newStation) async {
    if (_selectedStation == newStation) return;

    _selectedStation = newStation;

    // 保存站台选择到本地存储
    await _saveStation(newStation);

    // 更新站台名称
    final device = _devices[newStation];
    if (device != null) {
      _stationName = device.deviceName ?? device.deviceCode;
    } else {
      _stationName = newStation;
    }

    // 🎯 停止旧站台的定时刷新
    _stopGoodsRefreshTimer();

    // 清空当前货物数据
    _currentContainer = '';
    _currentGoods.clear();

    // 主动查询设备状态（不依赖 WebSocket 推送）
    // 对应 Vue 版本：切换站台时重新初始化设备信息
    await _initGetDeviceInfo();

    notifyListeners();
  }

  /// 主动查询设备初始状态
  /// 对应 Vue 中的 initGetDeviceInfo
  /// 在程序初始化和切换站台时调用，不依赖 WebSocket 连接
  Future<void> _initGetDeviceInfo() async {
    try {
      // WCS API 配置（对应 Vue 版本的 wcsAPI）
      final dio = Dio(BaseOptions(
        baseUrl: 'http://10.20.88.14:8009/api/WCS',
        connectTimeout: const Duration(seconds: 10),
        headers: {'Cache-Control': 'no-cache'},
      ));

      // 监控的设备列表（对应 Vue 版本的 watchDeviceCodes + coordinateDevices）
      final watchDevices = ['Crn2002', 'TranLine3000', 'Crn2001', 'RGV01'];

      for (final deviceCode in watchDevices) {
        try {
          // 调用 WCS API 获取设备状态
          final response = await dio.get('/getDevice/$deviceCode');

          if (response.data != null) {
            final deviceInfo = response.data as Map<String, dynamic>;

            // 处理子设备（如 TranLine3000 下的 Tran3001, Tran3002...）
            if (deviceInfo['childrenDevice'] != null) {
              final children = deviceInfo['childrenDevice'] as List?;
              if (children != null && children.isNotEmpty) {
                for (final child in children) {
                  final childData = child as Map<String, dynamic>;
                  final childCode = childData['code'] as String?;
                  if (childCode != null) {
                    // 直接存储子设备（不触发 updateDevice，避免重复处理）
                    final device = Device.fromJson(_mapDeviceFields(childData));
                    _devices[childCode] = device;

                    // 更新站台名称（如果这是当前选中的站台）
                    if (childCode == _selectedStation) {
                      _stationName = device.deviceName ?? device.deviceCode;
                    }
                  }
                }
              }
            } else {
              // 处理独立设备
              final device = Device.fromJson(_mapDeviceFields(deviceInfo));
              _devices[deviceCode] = device;

              if (deviceCode == _selectedStation) {
                _stationName = device.deviceName ?? device.deviceCode;
              }
            }
          }
        } catch (e) {
          print('设备 $deviceCode 初始化失败: $e');
          // 继续查询其他设备
        }
      }

      // 批量初始化完成后，统一处理一次（更新托盘映射、检查站台）
      _updateDeviceTrayMap();
      await _checkCurrentStationContainer();
      notifyListeners();
    } catch (e) {
      print('初始化设备信息失败: $e');
      // 3秒后重试（对应 Vue 版本的重试逻辑）
      Future.delayed(const Duration(seconds: 3), _initGetDeviceInfo);
    }
  }

  /// 字段名映射：Vue API (code, name, childrenDevice) -> Flutter (deviceCode, deviceName, children)
  /// 提取为独立方法，供 initGetDeviceInfo 和 updateDevice 复用
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

  /// 检查当前站台的容器和货物
  /// 对应 Vue 中的 checkCurrentStationTray
  ///
  /// 📍 关键逻辑：
  /// - 容器出现：立即获取货物 + 启动 10 秒定时刷新
  /// - 容器离开：停止定时刷新 + 清空数据
  Future<void> _checkCurrentStationContainer() async {
    // 从 deviceTrayMap 获取当前站台上的容器编号
    final containerCode = _deviceTrayMap[_selectedStation];

    if (containerCode != null && containerCode.isNotEmpty) {
      // 🎯 场景 1：容器出现或变化
      if (containerCode != _currentContainer) {
        // 立即获取货物数据
        await _fetchGoods(containerCode);

        // 启动定时刷新（10 秒一次）
        _startGoodsRefreshTimer(containerCode);
      }
      // 🎯 场景 2：容器未变化（定时器会自动刷新，这里无需处理）
    } else {
      // 🎯 场景 3：容器离开站台
      if (_currentContainer.isNotEmpty) {
        // 停止定时刷新
        _stopGoodsRefreshTimer();

        // 清空数据
        _currentContainer = '';
        _currentGoods.clear();
        notifyListeners();
      }
    }
  }

  /// 获取容器货物信息
  /// 对应 Vue 中的 getGoods 和 getContainerGoods
  Future<void> _fetchGoods(String containerCode) async {
    if (containerCode.isEmpty || containerCode == '0') {
      _currentGoods.clear();
      _currentContainer = '';
      notifyListeners();
      return;
    }

    try {
      _currentContainer = containerCode;

      // 调用 WMS API 获取容器货物信息
      // 对应 Vue 版本的 API 配置: http://10.20.88.14:8008/api/warehouse
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
          final newGoods = goodsList
              .map((item) => Goods.fromJson(item as Map<String, dynamic>))
              .toList();

          // 🎯 使用智能差异更新，避免不必要的重建
          final hasChanges = ListDiffUpdater.updateGoodsList(_currentGoods, newGoods);

          // 🎯 只有数据真正变化时才通知 UI 更新
          if (hasChanges) {
            notifyListeners();
          }
        } else {
          _currentGoods.clear();
          notifyListeners();
        }
      } else {
        _currentGoods.clear();
        notifyListeners();
      }
    } catch (e) {
      _currentGoods.clear();
      notifyListeners();
    }
  }

  /// 启动货物数据定时刷新
  ///
  /// 📍 触发时机：容器出现在站台上时
  /// 📍 刷新频率：每 10 秒一次
  void _startGoodsRefreshTimer(String containerCode) {
    // 先停止旧的定时器（如果存在）
    _stopGoodsRefreshTimer();

    // 创建新的定时刷新定时器
    _goodsRefreshTimer = Timer.periodic(_refreshInterval, (timer) {
      // 定时刷新货物数据
      _fetchGoods(containerCode);
    });
  }

  /// 停止货物数据定时刷新
  ///
  /// 📍 触发时机：容器离开站台时、切换站台时、dispose 时
  void _stopGoodsRefreshTimer() {
    _goodsRefreshTimer?.cancel();
    _goodsRefreshTimer = null;
  }

  /// 添加日志（仅用于接收服务器推送的日志）
  ///
  /// 内存管理策略：
  /// - 限制最大日志数量为 _maxLogCount (100条)
  /// - 超过限制时删除最旧的日志（FIFO策略）
  /// - 每条日志平均100字符，100条约占用20-30KB内存
  /// - 使用 removeRange 批量删除，性能优于逐条删除
  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _logs.add('[$timestamp] $message'); // 添加到末尾，最新的在下面

    // 内存控制：只保留最近 _maxLogCount 条日志，删除旧的
    // 使用批量删除，避免频繁的内存分配/释放
    if (_logs.length > _maxLogCount) {
      // 一次性删除多余的旧日志
      final removeCount = _logs.length - _maxLogCount;
      _logs.removeRange(0, removeCount);
    }

    // 通知 UI 更新
    notifyListeners();
  }

  @override
  void dispose() {
    // 🎯 清理定时器
    _stopGoodsRefreshTimer();

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