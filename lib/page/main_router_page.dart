import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/dashboard_provider.dart';
import 'dashboard_page.dart';
import 'dual_station_page.dart';

/// 主路由页面
/// 根据选择的站台决定显示单站台看板还是双站台看板
/// - Tran3002 或 Tran3003 -> 显示双站台看板
/// - 其他站台 -> 显示单站台看板
class MainRouterPage extends ConsumerWidget {
  const MainRouterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedStation = ref.watch(
      dashboardProvider.select((p) => p.selectedStation),
    );

    // 判断是否应该显示双站台模式
    final showDualStation = selectedStation == 'Tran3002' || selectedStation == 'Tran3003';

    // 根据选择的站台返回对应的页面
    return showDualStation ? const DualStationPage() : const DashboardPage();
  }
}
