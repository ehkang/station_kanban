import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/dual_station_provider.dart';
import '../widget/header_bar.dart';
import '../widget/star_background.dart';
import '../widget/station_panel.dart';

/// 双站台看板页面
/// 对应 Vue 项目中的 DualStationView.vue
/// 左右分屏显示 Tran3002 和 Tran3003
class DualStationPage extends ConsumerWidget {
  const DualStationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(dualStationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e27), // 深蓝色背景
      body: Stack(
        children: [
          // 星空背景
          const StarBackground(),

          // 主内容区域
          SafeArea(
            child: Column(
              children: [
                // 顶部标题栏（双站台模式）
                const HeaderBar(isDualStation: true),

                // 双站台主体容器
                Expanded(
                  child: Row(
                    children: [
                      // 左侧：站台 3002
                      Expanded(
                        child: StationPanel(
                          stationId: 'Tran3002',
                          containerCode: provider.container3002,
                          goods: provider.goods3002,
                        ),
                      ),

                      // 分隔线
                      Container(
                        width: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.cyan.withOpacity(0.0),
                              Colors.cyan.withOpacity(0.5),
                              Colors.cyan.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),

                      // 右侧：站台 3003
                      Expanded(
                        child: StationPanel(
                          stationId: 'Tran3003',
                          containerCode: provider.container3003,
                          goods: provider.goods3003,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
