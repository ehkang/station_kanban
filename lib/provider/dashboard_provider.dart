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
        print('加载保存的站台: $savedStation');
        notifyListeners();
      } else {
        print('没有保存的站台或站台无效，使用默认值: $_selectedStation');
      }
    } catch (e) {
      print('加载保存的站台失败: $e');
    }
  }

  /// 保存当前选择的站台到本地存储
  Future<void> _saveStation(String station) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedStationKey, station);
      print('保存站台选择: $station');
    } catch (e) {
      print('保存站台失败: $e');
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

    // 清空当前货物数据
    _currentContainer = '';
    _currentGoods.clear();

    // 检查新站台的容器和货物
    await _checkCurrentStationContainer();

    notifyListeners();
  }

  /// 检查当前站台的容器和货物
  /// 对应 Vue 中的 checkCurrentStationTray
  Future<void> _checkCurrentStationContainer() async {
    // 从 deviceTrayMap 获取当前站台上的容器编号
    final containerCode = _deviceTrayMap[_selectedStation];

    if (containerCode != null && containerCode.isNotEmpty) {
      // 如果容器编号变化了，重新获取货物
      if (containerCode != _currentContainer) {
        await _fetchGoods(containerCode);
      }
    } else {
      // 站台上没有容器，清空数据
      if (_currentContainer.isNotEmpty) {
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
          _currentGoods.clear();
          _currentGoods.addAll(
            goodsList.map((item) => Goods.fromJson(item as Map<String, dynamic>)),
          );
        }
      } else {
        _currentGoods.clear();
      }

      notifyListeners();
    } catch (e) {
      _currentGoods.clear();
      notifyListeners();
    }
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