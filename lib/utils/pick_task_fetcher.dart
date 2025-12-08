import 'package:dio/dio.dart';

/// 拣货任务数据获取工具
/// 用于从WMS API获取容器的拣货任务信息
class PickTaskFetcher {
  /// 获取指定容器的拣货任务
  ///
  /// 参数:
  /// - [dio]: Dio 实例
  /// - [containerCode]: 容器编码
  ///
  /// 返回:
  /// - Map<String, int>: goodsNo -> pickQuantity
  /// - 只包含 pickQuantity > 0 的任务
  /// - 如果 API 调用失败，返回空 Map（不抛出异常）
  static Future<Map<String, int>> fetchPickTasks(
    Dio dio,
    String containerCode,
  ) async {
    if (containerCode.isEmpty || containerCode == '0') {
      return {};
    }

    try {
      // WMS 拣货任务 API
      final url =
          'https://aio.wxnanxing.com/api/wms/StockOutOrder/PickTask?containerCode=$containerCode';

      final response = await dio.get(url);

      // 解析结果
      if (response.data != null && response.data['errCode'] == 0) {
        final taskList = response.data['data'] as List?;

        if (taskList != null && taskList.isNotEmpty) {
          final Map<String, int> result = {};

          for (var task in taskList) {
            final goodsNo = task['goodsNo']?.toString();
            final pickQuantity = _parseToInt(task['pickQuantity']);

            // 🎯 只记录有效的拣货任务（数量 > 0）
            if (goodsNo != null &&
                goodsNo.isNotEmpty &&
                pickQuantity != null &&
                pickQuantity > 0) {
              // 如果同一个货物有多个拣货任务，累加数量
              result[goodsNo] = (result[goodsNo] ?? 0) + pickQuantity;
            }
          }

          return result;
        }
      } else {
        // API 返回业务错误
        print(
            '拣货任务API返回错误: ${response.data?['errMsg'] ?? 'Unknown error'}');
      }

      return {};
    } catch (e) {
      // 网络错误或解析错误，返回空 Map（降级处理）
      print('获取拣货任务失败: $e');
      return {};
    }
  }

  /// 安全解析 int 类型
  static int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
