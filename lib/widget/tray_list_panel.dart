import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/dashboard_provider.dart';
import '../model/container.dart' as model;

/// 托盘列表面板
/// 对应 Vue 项目中的左侧托盘列表
class TrayListPanel extends ConsumerStatefulWidget {
  const TrayListPanel({super.key});

  @override
  ConsumerState<TrayListPanel> createState() => _TrayListPanelState();
}

class _TrayListPanelState extends ConsumerState<TrayListPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    // 闪烁动画控制器
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(dashboardProvider);
    final trays = provider.traysWithDevices;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f3a).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // 面板标题
          _buildPanelHeader(trays.length),

          const Divider(
            color: Colors.cyan,
            height: 1,
            thickness: 0.5,
          ),

          // 托盘列表
          Expanded(
            child: trays.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: trays.length,
                    itemBuilder: (context, index) {
                      return _buildTrayItem(trays[index], index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 面板标题
  Widget _buildPanelHeader(int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2,
            color: Colors.cyan,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            '托盘列表',
            style: TextStyle(
              color: Colors.cyan,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.cyan.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.cyan,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 托盘项
  Widget _buildTrayItem(model.ContainerModel tray, int index) {
    return AnimatedBuilder(
      animation: _blinkController,
      builder: (context, child) {
        final isEven = index % 2 == 0;
        final opacity = isEven
            ? 0.7 + (_blinkController.value * 0.3)
            : 1.0 - (_blinkController.value * 0.2);

        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2a3f5f).withOpacity(0.8),
              const Color(0xFF1a2f4f).withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.cyan.withOpacity(0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyan.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 托盘编码
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tray.containerCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 设备信息
            if (tray.deviceCode != null) ...[
              _buildInfoRow(
                Icons.devices,
                '设备',
                tray.deviceCode!,
              ),
            ],

            // 地址信息
            if (tray.address != null) ...[
              const SizedBox(height: 4),
              _buildInfoRow(
                Icons.location_on,
                '位置',
                tray.address!,
              ),
            ],

            // 任务信息
            if (tray.taskCode != null) ...[
              const SizedBox(height: 4),
              _buildInfoRow(
                Icons.assignment,
                '任务',
                tray.taskCode!,
              ),
            ],

            // 货物数量
            if (tray.goodsList.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory,
                      color: Colors.orange,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '货物: ${tray.goodsList.length}',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 信息行
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.cyan.withOpacity(0.7),
          size: 14,
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.cyan.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            color: Colors.cyan.withOpacity(0.3),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无托盘数据',
            style: TextStyle(
              color: Colors.cyan.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}