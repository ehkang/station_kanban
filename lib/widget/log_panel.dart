import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/dashboard_provider.dart';

/// 日志面板
/// 对应 Vue 项目中的右侧日志显示区域
class LogPanel extends ConsumerStatefulWidget {
  const LogPanel({super.key});

  @override
  ConsumerState<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends ConsumerState<LogPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(dashboardProvider);
    final logs = provider.logs;

    // 当有新日志时，自动滚动到顶部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

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
          _buildPanelHeader(logs.length),

          const Divider(
            color: Colors.cyan,
            height: 1,
            thickness: 0.5,
          ),

          // 日志列表
          Expanded(
            child: logs.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      return _buildLogItem(logs[index], index);
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
            Icons.assignment,
            color: Colors.cyan,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            '系统日志',
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

  /// 日志项
  Widget _buildLogItem(String log, int index) {
    // 解析日志（格式：[时间] 消息）
    final match = RegExp(r'\[(.*?)\](.*)').firstMatch(log);
    final time = match?.group(1) ?? '';
    final message = match?.group(2)?.trim() ?? log;

    // 根据消息内容确定颜色
    Color messageColor = Colors.white70;
    IconData icon = Icons.info_outline;
    Color iconColor = Colors.cyan;

    if (message.contains('错误') || message.contains('失败')) {
      messageColor = Colors.red.shade300;
      icon = Icons.error_outline;
      iconColor = Colors.red;
    } else if (message.contains('警告')) {
      messageColor = Colors.orange.shade300;
      icon = Icons.warning_amber_outlined;
      iconColor = Colors.orange;
    } else if (message.contains('成功') || message.contains('已连接')) {
      messageColor = Colors.green.shade300;
      icon = Icons.check_circle_outline;
      iconColor = Colors.green;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(20 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF2a3f5f).withOpacity(0.4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: iconColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图标
            Icon(
              icon,
              color: iconColor.withOpacity(0.8),
              size: 16,
            ),

            const SizedBox(width: 8),

            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 时间戳
                  if (time.isNotEmpty) ...[
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.cyan.withOpacity(0.6),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // 消息内容
                  Text(
                    message,
                    style: TextStyle(
                      color: messageColor,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            color: Colors.cyan.withOpacity(0.3),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无日志',
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