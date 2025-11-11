import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/dashboard_provider.dart';
import '../model/goods.dart';
import 'cube_3d_viewer.dart';

/// 货物网格面板
/// 对应 Vue 项目中的中间货物展示区域
/// 显示 5x2 的货物网格
class GoodsGridPanel extends ConsumerWidget {
  const GoodsGridPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(dashboardProvider);

    // 直接从 provider 获取当前站台的货物数据
    // 对应 Vue 版本中的 localGoods
    final currentGoods = provider.currentGoods;
    final currentContainer = provider.currentContainer;

    // 最多显示 10 个货物（5x2 网格）
    final displayGoods = currentGoods.take(10).toList();

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
          _buildPanelHeader(displayGoods.length, currentContainer),

          const Divider(
            color: Colors.cyan,
            height: 1,
            thickness: 0.5,
          ),

          // 货物网格
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildGoodsGrid(displayGoods, currentContainer),
            ),
          ),
        ],
      ),
    );
  }

  /// 面板标题
  Widget _buildPanelHeader(int count, String containerCode) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 80, // 给 Stack 一个固定高度，增加以容纳容器编码显示
      child: Stack(
        children: [
          // 左侧：货物展示标签
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Row(
              children: [
                Icon(
                  Icons.grid_view,
                  color: Colors.cyan,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  '货物展示',
                  style: TextStyle(
                    color: Colors.cyan,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 中心：容器编码
          if (containerCode.isNotEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.withOpacity(0.3),
                      Colors.deepOrange.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.6),
                    width: 2,
                  ),
                ),
                child: Text(
                  '容器: $containerCode',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

          // 右侧：货物数量统计
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Row(
              children: [
                Text(
                  '5 × 2',
                  style: TextStyle(
                    color: Colors.cyan.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count / 10',
                    style: const TextStyle(
                      color: Colors.cyan,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 5x2 货物网格
  Widget _buildGoodsGrid(List<Goods> goods, String containerCode) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - 32) / 5; // 5 列
        final cellHeight = (constraints.maxHeight - 8) / 2; // 2 行

        return Column(
          children: [
            // 第一行
            Expanded(
              child: Row(
                children: List.generate(5, (col) {
                  final index = col;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: index < goods.length
                          ? _buildGoodsCard(goods[index], index, containerCode)
                          : _buildEmptyCard(index),
                    ),
                  );
                }),
              ),
            ),

            // 第二行
            Expanded(
              child: Row(
                children: List.generate(5, (col) {
                  final index = col + 5;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: index < goods.length
                          ? _buildGoodsCard(goods[index], index, containerCode)
                          : _buildEmptyCard(index),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 货物卡片
  Widget _buildGoodsCard(Goods goods, int index, String containerCode) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          // 透明背景 - 使用父容器背景色
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.cyan.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyan.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.blue.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // 内容
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 顶部：编号标签
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '# ${index + 1}',
                            style: const TextStyle(
                              color: Colors.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.inventory_2,
                          color: Colors.cyan.withOpacity(0.7),
                          size: 20,
                        ),
                      ],
                    ),

                    // 中间：3D模型展示区域（用Expanded让它占据剩余空间）
                    Expanded(
                      child: Center(
                        child: _build3DModelOrIcon(goods, index, containerCode),
                      ),
                    ),

                    // 底部：文字信息（固定在底部）
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 货物名称
                        Text(
                          goods.goodsName ?? goods.goodsCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 6),

                        // 货物编码
                        Text(
                          goods.goodsCode,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 10),

                        // 数量信息 - 更醒目的显示
                        if (goods.quantity != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.withOpacity(0.4),
                                  Colors.green.withOpacity(0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.8),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.analytics_outlined,
                                  color: Colors.greenAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${goods.quantity} ${goods.unit ?? ''}',
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 3D模型或默认图标
  ///
  /// 策略：
  /// - 使用基础URL + 料号拼接获取STL文件
  /// - 测试模式：使用写死的料号（testGoodsNo）
  /// - 生产模式：使用实际料号（goods.goodsCode）
  ///
  /// 性能优化：
  /// - 各货物错开加载（index * 200ms），避免同时下载STL文件
  Widget _build3DModelOrIcon(Goods goods, int index, String containerCode) {
    // 🔧 测试模式：控制是否写死料号
    const bool enableTestMode = false;
    const String testGoodsNo = '35101.00787';

    // 3D模型API基础URL
    const String baseUrl = 'https://aio.wxnanxing.com/api/Tech/Pdm/GetConvertFile?GoodsNo=';

    // 确定料号
    final goodsNo = enableTestMode ? testGoodsNo : goods.goodsCode;

    // 拼接完整URL
    final stlUrl = '$baseUrl$goodsNo';

    // 计算延迟时间（避免同时下载，错开加载）
    final initDelay = index * 200;

    // 使用 容器编码+料号 作为 Key，确保切换容器时强制重建
    // 这样即使料号相同，只要容器变了，3D Viewer 也会重新创建
    return Cube3DViewer(
      key: ValueKey('$containerCode-$goodsNo'),
      stlUrl: stlUrl,
      initDelay: initDelay,
    );
  }

  /// 空卡片
  Widget _buildEmptyCard(int index) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1a2f4f).withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_box_outlined,
              color: Colors.cyan.withOpacity(0.2),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              '${index + 1}',
              style: TextStyle(
                color: Colors.cyan.withOpacity(0.2),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}