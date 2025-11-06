import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/dashboard_provider.dart';
import '../model/goods.dart';

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
              child: _buildGoodsGrid(displayGoods),
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
  Widget _buildGoodsGrid(List<Goods> goods) {
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
                          ? _buildGoodsCard(goods[index], index)
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
                          ? _buildGoodsCard(goods[index], index)
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
  Widget _buildGoodsCard(Goods goods, int index) {
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2a4f7f).withOpacity(0.9),
              const Color(0xFF1a3f6f).withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.blue.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 4),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.cyan.withOpacity(0.2),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // 背景渐变
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topLeft,
                    radius: 1.5,
                    colors: [
                      Colors.blue.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // 内容
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 货物编码
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

                    const Spacer(),

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
              ),

              // 右上角装饰
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Colors.cyan.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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