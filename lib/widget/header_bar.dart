import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../provider/dashboard_provider.dart';

/// 顶部标题栏
/// 对应 Vue 项目中的 header 部分
/// 支持单站台和双站台模式
class HeaderBar extends ConsumerWidget {
  final bool isDualStation;

  const HeaderBar({
    super.key,
    this.isDualStation = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🎯 总是从 DashboardProvider 读取连接状态（单一数据源）
    // DashboardProvider 不是 autoDispose，永远存活，状态永远正确
    final connectionState = ref.watch(
      dashboardProvider.select((p) => p.connectionState)
    );

    final reconnectCount = ref.watch(
      dashboardProvider.select((p) => p.reconnectCount)
    );

    return Container(
      height: 70,  // 🎨 黄金比例优化：80→70
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1a1f3a).withOpacity(0.9),
            const Color(0xFF0a0e27).withOpacity(0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Stack(
          children: [
            // 左侧图标
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Row(
                children: [
                  Container(
                    width: 48,  // 🎨 黄金比例优化：50→48
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.cyan.withOpacity(0.6),
                          Colors.blue.withOpacity(0.4),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.warehouse,
                      color: Colors.white,
                      size: 26,  // 🎨 黄金比例优化：28→26
                    ),
                  ),
                ],
              ),
            ),

            // 居中标题文字（渐变效果）
            Center(
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFF00d4ff),
                    Color(0xFF0099ff),
                  ],
                ).createShader(bounds),
                child: Text(
                  isDualStation
                      ? '双站台看板 (3002 | 3003)'
                      : '${ref.watch(dashboardProvider.select((p) => p.stationNumber))}站台看板',
                  style: const TextStyle(
                    fontSize: 36,  // 🎨 黄金比例优化：32→36 (h1级别)
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),

            // 右侧状态区域
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Row(
                children: [
                  // 站台选择器（只在单站台模式显示，或双站台模式也显示用于切换）
                  _buildStationSelector(context, ref),

                  const SizedBox(width: 20),

                  // 连接状态指示器
                  _buildConnectionStatus(connectionState, reconnectCount, ref),

                  const SizedBox(width: 20),

                  // 当前时间
                  _buildCurrentTime(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 站台选择器
  /// 对应 Vue 中的 station-switcher
  Widget _buildStationSelector(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(dashboardProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 站台图标
          Icon(
            Icons.location_on,
            color: Colors.cyan,
            size: 18,
          ),
          const SizedBox(width: 8),

          // "站台"标签
          Text(
            '站台',
            style: TextStyle(
              color: Colors.cyan.shade200,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),

          // 下拉选择框
          DropdownButton<String>(
            value: provider.selectedStation,
            dropdownColor: const Color(0xFF1a1f3a),
            style: TextStyle(
              color: Colors.cyan.shade100,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            underline: Container(), // 移除下划线
            icon: Icon(
              Icons.arrow_drop_down,
              color: Colors.cyan,
              size: 20,
            ),
            items: DashboardProvider.availableStations.map((station) {
              return DropdownMenuItem<String>(
                value: station,
                child: Text(station),
              );
            }).toList(),
            onChanged: (String? newStation) {
              if (newStation != null) {
                provider.changeStation(newStation);
              }
            },
          ),
        ],
      ),
    );
  }

  /// 连接状态指示器
  /// 支持 3 种状态：已连接（绿色）、重连中（橙色）、未连接（红色）
  Widget _buildConnectionStatus(
      HubConnectionState connectionState, int reconnectCount, WidgetRef ref) {

    // 根据连接状态确定颜色和文本
    Color statusColor;
    String statusText;
    bool hasGlow;

    switch (connectionState) {
      case HubConnectionState.Connected:
        statusColor = Colors.green;
        statusText = '已连接';
        hasGlow = true;
        break;
      case HubConnectionState.Reconnecting:
        statusColor = Colors.orange;
        statusText = reconnectCount > 0 ? '重连中 ($reconnectCount)' : '重连中';
        hasGlow = true;
        break;
      default:
        statusColor = Colors.red;
        statusText = '未连接';
        hasGlow = false;
    }

    return GestureDetector(
      onTap: () {
        // 只有在未连接或重连失败时才允许手动重连
        // 🎯 总是调用 DashboardProvider 的重连方法（单一数据源）
        if (connectionState != HubConnectionState.Connected) {
          ref.read(dashboardProvider).manualReconnect();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: statusColor.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 状态指示灯（带动画）
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              builder: (context, value, child) {
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    boxShadow: hasGlow
                        ? [
                            BoxShadow(
                              color: statusColor.withOpacity(value * 0.8),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            // 重连中时显示loading动画
            if (connectionState == HubConnectionState.Reconnecting) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 当前时间显示
  Widget _buildCurrentTime() {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final timeStr =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        final dateStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              timeStr,
              style: const TextStyle(
                color: Colors.cyan,
                fontSize: 28,  // 🎨 黄金比例优化：24→28
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              dateStr,
              style: TextStyle(
                color: Colors.cyan.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        );
      },
    );
  }
}