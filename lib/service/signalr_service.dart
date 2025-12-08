import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';

/// SignalR WebSocket 服务
/// 对应 Vue 项目中的 SignalR 连接逻辑
class SignalRService {
  HubConnection? _hubConnection;
  final String _hubUrl = 'http://10.20.88.14:8009/hubs/wcsHub';

  // 🎯 连接状态标志，防止重复连接
  bool _isConnected = false;
  bool _isConnecting = false;

  // 🎯 当前连接状态（唯一数据源）
  HubConnectionState _currentConnectionState = HubConnectionState.Disconnected;

  /// 获取当前连接状态
  /// 注意：UI应该通过 DashboardProvider 订阅获得响应式更新
  HubConnectionState get currentConnectionState => _currentConnectionState;

  /// 连接状态流
  final _connectionStateController = StreamController<HubConnectionState>.broadcast();
  Stream<HubConnectionState> get connectionState => _connectionStateController.stream;

  /// 重连次数流
  int _reconnectCount = 0;
  final _reconnectCountController = StreamController<int>.broadcast();
  Stream<int> get reconnectCount => _reconnectCountController.stream;
  int get currentReconnectCount => _reconnectCount;

  /// 设备数据更新流
  final _deviceUpdateController = StreamController<DeviceUpdateEvent>.broadcast();
  Stream<DeviceUpdateEvent> get deviceUpdates => _deviceUpdateController.stream;

  /// 日志推送流
  final _logController = StreamController<LogEvent>.broadcast();
  Stream<LogEvent> get logs => _logController.stream;

  /// 初始化 SignalR 连接
  Future<void> connect() async {
    // 🎯 防止重复连接
    if (_isConnected || _isConnecting) {
      print('SignalR 已连接或正在连接中，跳过重复连接');
      return;
    }

    _isConnecting = true;

    // 创建连接
    _hubConnection = HubConnectionBuilder()
        .withUrl(_hubUrl)
        .withAutomaticReconnect(
          retryDelays: [0, 2000, 10000, 30000], // 重连延迟：立即、2秒、10秒、30秒
        )
        .build();

    // 监听连接状态变化
    _hubConnection?.onclose(({error}) {
      print('SignalR 连接关闭: $error');
      _isConnected = false;
      _currentConnectionState = HubConnectionState.Disconnected;  // 🎯 同步更新
      _connectionStateController.add(_currentConnectionState);
    });

    _hubConnection?.onreconnecting(({error}) {
      _reconnectCount++;
      print('SignalR 重连中... (第 $_reconnectCount 次)');
      _currentConnectionState = HubConnectionState.Reconnecting;  // 🎯 同步更新
      _reconnectCountController.add(_reconnectCount);
      _connectionStateController.add(_currentConnectionState);
    });

    _hubConnection?.onreconnected(({connectionId}) {
      print('SignalR 重连成功: $connectionId (共重连 $_reconnectCount 次)');
      _currentConnectionState = HubConnectionState.Connected;  // 🎯 同步更新
      _connectionStateController.add(_currentConnectionState);
      // 重连成功后，重置重连次数
      _reconnectCount = 0;
      _reconnectCountController.add(_reconnectCount);
    });

    // 注册设备数据更新监听
    // 对应 Vue 项目中的: signalRConnection.on("DeviceDataUpdate", ...)
    _hubConnection?.on('DeviceDataUpdate', _handleDeviceUpdate);

    // 注册日志推送监听
    // 对应 Vue 项目中的: signalRConnection.on("logger", ...)
    _hubConnection?.on('logger', _handleLogPush);

    try {
      // 启动连接
      await _hubConnection?.start();
      _isConnected = true;
      _isConnecting = false;
      _currentConnectionState = HubConnectionState.Connected;  // 🎯 同步更新
      print('SignalR 连接成功');
      _connectionStateController.add(_currentConnectionState);
    } catch (e) {
      _isConnected = false;
      _isConnecting = false;
      _currentConnectionState = HubConnectionState.Disconnected;  // 🎯 同步更新
      print('SignalR 连接失败: $e');
      _connectionStateController.add(_currentConnectionState);
      rethrow;
    }
  }

  /// 处理设备数据更新
  /// 对应 Vue 中的 DeviceDataUpdate 事件处理
  void _handleDeviceUpdate(List<Object?>? arguments) {
    if (arguments == null || arguments.length < 2) return;

    final deviceNo = arguments[0] as String?;
    final newInfo = arguments[1] as Map<String, dynamic>?;

    if (deviceNo != null && newInfo != null) {
      _deviceUpdateController.add(
        DeviceUpdateEvent(deviceNo: deviceNo, data: newInfo),
      );
    }
  }

  /// 处理日志推送
  /// 对应 Vue 中的 logger 事件处理
  void _handleLogPush(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) return;

    final logData = arguments[0] as Map<String, dynamic>?;
    if (logData != null) {
      _logController.add(
        LogEvent(
          logLevel: logData['logLevel'] as int? ?? 2,
          message: logData['message'] as String? ?? '',
          categoryName: logData['categoryName'] as String? ?? '系统',
        ),
      );
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _hubConnection?.stop();
    _isConnected = false;
    _isConnecting = false;
    _currentConnectionState = HubConnectionState.Disconnected;  // 🎯 同步更新
    _connectionStateController.add(_currentConnectionState);
  }

  /// 手动重连
  /// 用户可以主动触发重连
  Future<void> reconnect() async {
    print('手动触发重连...');
    await disconnect();
    _reconnectCount = 0;
    _reconnectCountController.add(_reconnectCount);
    await Future.delayed(const Duration(milliseconds: 500));
    await connect();
  }

  /// 释放资源
  void dispose() {
    _hubConnection?.stop();
    _connectionStateController.close();
    _reconnectCountController.close();
    _deviceUpdateController.close();
    _logController.close();
  }
}

/// 设备更新事件
class DeviceUpdateEvent {
  final String deviceNo;
  final Map<String, dynamic> data;

  DeviceUpdateEvent({
    required this.deviceNo,
    required this.data,
  });
}

/// 日志事件
/// 对应 Vue 中的 logger 事件数据结构
class LogEvent {
  /// 日志级别: 2=info, 3=warning, 4=error
  final int logLevel;

  /// 日志消息内容（服务器推送的原始消息）
  final String message;

  /// 日志分类（如 'WCS.Connection', 'WMS.System' 等）
  final String categoryName;

  LogEvent({
    required this.logLevel,
    required this.message,
    required this.categoryName,
  });
}