import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';

/// SignalR WebSocket 服务
/// 对应 Vue 项目中的 SignalR 连接逻辑
class SignalRService {
  HubConnection? _hubConnection;
  final String _hubUrl = 'http://10.20.88.14:8009/hubs/wcsHub';

  /// 连接状态流
  final _connectionStateController = StreamController<HubConnectionState>.broadcast();
  Stream<HubConnectionState> get connectionState => _connectionStateController.stream;

  /// 设备数据更新流
  final _deviceUpdateController = StreamController<DeviceUpdateEvent>.broadcast();
  Stream<DeviceUpdateEvent> get deviceUpdates => _deviceUpdateController.stream;

  /// 日志推送流
  final _logController = StreamController<LogEvent>.broadcast();
  Stream<LogEvent> get logs => _logController.stream;

  /// 初始化 SignalR 连接
  Future<void> connect() async {
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
      _connectionStateController.add(HubConnectionState.Disconnected);
    });

    _hubConnection?.onreconnecting(({error}) {
      print('SignalR 重连中...');
      _connectionStateController.add(HubConnectionState.Reconnecting);
    });

    _hubConnection?.onreconnected(({connectionId}) {
      print('SignalR 重连成功: $connectionId');
      _connectionStateController.add(HubConnectionState.Connected);
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
      print('SignalR 连接成功');
      _connectionStateController.add(HubConnectionState.Connected);
    } catch (e) {
      print('SignalR 连接失败: $e');
      _connectionStateController.add(HubConnectionState.Disconnected);
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
    _connectionStateController.add(HubConnectionState.Disconnected);
  }

  /// 释放资源
  void dispose() {
    _hubConnection?.stop();
    _connectionStateController.close();
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