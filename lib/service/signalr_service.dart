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