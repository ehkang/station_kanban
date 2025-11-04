import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/dashboard_provider.dart';

/// 顶部标题栏
/// 对应 Vue 项目中的 header 部分
class HeaderBar extends ConsumerWidget {
  const HeaderBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(dashboardProvider);
    final isConnected = provider.isConnected;

    return Container(
      height: 80,
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
                    width: 50,
                    height: 50,
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
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),

            // 居中标题文字（渐变效果）- 显示站台编号
            Center(
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFF00d4ff),
                    Color(0xFF0099ff),
                  ],
                ).createShader(bounds),
                child: Text(
                  '${provider.stationNumber}站台看板',
                  style: const TextStyle(
                    fontSize: 32,
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
                  // 站台选择器
                  _buildStationSelector(context, ref, provider),

                  const SizedBox(width: 20),

                  // 连接状态指示器
                  _buildConnectionStatus(isConnected),

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
  Widget _buildStationSelector(
      BuildContext context, WidgetRef ref, DashboardProvider provider) {
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
  Widget _buildConnectionStatus(bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected
              ? Colors.green.withOpacity(0.5)
              : Colors.red.withOpacity(0.5),
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
                  color: isConnected ? Colors.green : Colors.red,
                  boxShadow: isConnected
                      ? [
                          BoxShadow(
                            color: Colors.green.withOpacity(value * 0.8),
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
            isConnected ? '已连接' : '未连接',
            style: TextStyle(
              color: isConnected ? Colors.green : Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
                fontSize: 24,
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