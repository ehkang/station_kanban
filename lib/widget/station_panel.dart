import 'package:flutter/material.dart';
import '../model/goods.dart';
import 'cube_3d_viewer.dart';

/// 单个站台面板
/// 用于双站台看板的左右两侧
/// 对应 Vue 项目中的 StationPanel.vue
class StationPanel extends StatelessWidget {
  final String stationId;
  final String containerCode;
  final List<Goods> goods;

  const StationPanel({
    super.key,
    required this.stationId,
    required this.containerCode,
    required this.goods,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0a0e27).withOpacity(0.3),
            const Color(0xFF1a1f3a).withOpacity(0.2),
          ],
        ),
      ),
      child: Column(
        children: [
          // 站台标题
          _buildStationHeader(),

          // 货物网格
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildGoodsGrid(),
            ),
          ),
        ],
      ),
    );
  }

  /// 站台标题
  Widget _buildStationHeader() {
    // 提取站台编号（如 Tran3002 -> 3002）
    final stationNumber = stationId.replaceFirst('Tran', '');

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1a1f3a).withOpacity(0.6),
            const Color(0xFF0a0e27).withOpacity(0.4),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.cyan.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Stack(
        children: [
          // 左侧：站台图标和标题
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Row(
              children: [
                // 站台图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.cyan.withOpacity(0.5),
                        Colors.blue.withOpacity(0.3),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 12),

                // 站台标题
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFF00d4ff),
                      Color(0xFF0099ff),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    '站台 $stationNumber',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 中间：容器编码（居中显示）
          if (containerCode.isNotEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.withOpacity(0.3),
                      Colors.deepOrange.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.6),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '容器: $containerCode',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 货物网格（5x2）
  Widget _buildGoodsGrid() {
    final displayGoods = goods.take(10).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
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
                      child: index < displayGoods.length
                          ? _buildGoodsCard(displayGoods[index], index, containerCode)
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
                      child: index < displayGoods.length
                          ? _buildGoodsCard(displayGoods[index], index, containerCode)
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
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Padding(
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

                // 中间：3D模型展示区域
                Expanded(
                  child: Center(
                    child: Cube3DViewer(
                      key: ValueKey('$containerCode-${goods.goodsCode}'),
                      stlUrl: 'https://aio.wxnanxing.com/api/Tech/Pdm/GetConvertFile?GoodsNo=${goods.goodsCode}',
                      initDelay: index * 200,
                    ),
                  ),
                ),

                // 底部：文字信息
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

                    // 数量信息
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
