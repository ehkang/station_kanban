import '../model/goods.dart';

/// 列表差异更新工具
/// 用于智能更新货物列表，避免不必要的 UI 重建和闪烁
class ListDiffUpdater {
  /// 智能更新货物列表
  ///
  /// 返回值：true 表示有更新，false 表示无变化
  ///
  /// 策略：
  /// 1. 数据完全相同 → 不更新，返回 false
  /// 2. 长度相同但内容不同 → 逐项替换
  /// 3. 长度不同 → 智能增删改
  static bool updateGoodsList(List<Goods> targetList, List<Goods> newGoods) {
    // 场景 1：数据完全相同 → 不更新，避免闪烁
    if (_isListEqual(targetList, newGoods)) {
      return false; // 🎯 关键：避免无意义的更新
    }

    // 场景 2：长度相同 → 逐项检查和替换
    if (targetList.length == newGoods.length) {
      return _updateSameLengthList(targetList, newGoods);
    }

    // 场景 3：长度不同 → 智能增删改（保留 Widget 状态）
    return _updateDifferentLengthList(targetList, newGoods);
  }

  /// 比较两个列表是否完全相等
  /// 考虑顺序和内容
  static bool _isListEqual(List<Goods> list1, List<Goods> list2) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      if (!list1[i].isEqualTo(list2[i])) {
        return false;
      }
    }

    return true;
  }

  /// 更新长度相同的列表
  /// 策略：逐项比较，只替换变化的项
  static bool _updateSameLengthList(List<Goods> targetList, List<Goods> newGoods) {
    bool hasChanges = false;

    for (int i = 0; i < targetList.length; i++) {
      // 场景 2.1：goodsCode 相同，但其他字段变化（如数量）
      if (targetList[i].goodsCode == newGoods[i].goodsCode) {
        if (!targetList[i].isEqualTo(newGoods[i])) {
          targetList[i] = newGoods[i]; // 🎯 只替换变化的项
          hasChanges = true;
        }
      }
      // 场景 2.2：位置上的货物完全不同（顺序变化 + 内容变化）
      else {
        targetList[i] = newGoods[i];
        hasChanges = true;
      }
    }

    return hasChanges;
  }

  /// 更新长度不同的列表
  /// 策略：基于 goodsCode 匹配，最大程度复用现有 Goods 对象
  /// 🎯 关键：避免使用 clear()，改用逐项替换和增删，减少闪烁
  static bool _updateDifferentLengthList(List<Goods> targetList, List<Goods> newGoods) {
    // 构建旧数据的 Map（goodsCode -> Goods）
    final oldMap = <String, Goods>{};
    for (var goods in targetList) {
      oldMap[goods.goodsCode] = goods;
    }

    // 步骤 1：先调整列表长度
    if (newGoods.length > targetList.length) {
      // 需要扩容：添加占位符
      final placeholdersNeeded = newGoods.length - targetList.length;
      for (int i = 0; i < placeholdersNeeded; i++) {
        targetList.add(newGoods[targetList.length]); // 临时添加
      }
    } else if (newGoods.length < targetList.length) {
      // 需要缩容：从尾部删除
      targetList.removeRange(newGoods.length, targetList.length);
    }

    // 步骤 2：逐项替换，尽可能复用旧对象
    for (int i = 0; i < newGoods.length; i++) {
      final newItem = newGoods[i];
      final oldGoods = oldMap[newItem.goodsCode];

      if (oldGoods != null && oldGoods.isEqualTo(newItem)) {
        // 内容相同：复用旧对象（🎯 关键：保持对象引用不变）
        targetList[i] = oldGoods;
      } else {
        // 内容变化或新货物：使用新对象
        targetList[i] = newItem;
      }
    }

    return true; // 长度不同，一定有变化
  }
}
