import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/dashboard_provider.dart';
import '../widget/header_bar.dart';
import '../widget/goods_grid_panel.dart';
import '../widget/star_background.dart';

/// Dashboard 主界面
/// 对应 Vue 项目中的 Dashboard.vue
/// 针对 1920x1080 分辨率优化
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(dashboardProvider);

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
                // 顶部标题栏
                const HeaderBar(),

                // 主体内容区域 - 只显示货物网格
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: const GoodsGridPanel(),
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
