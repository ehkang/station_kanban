/// 基于黄金比例的设计系统
///
/// 黄金比例 φ ≈ 1.618
/// 应用场景：字体级数、间距系统、组件尺寸
///
/// 参考资料：
/// - Golden Ratio in Design: https://www.canva.com/learn/golden-ratio/
/// - Typography Scale: https://type-scale.com/
class DesignTokens {
  // ========================================
  // 黄金比例常数
  // ========================================

  /// 黄金比例 φ (phi)
  static const double phi = 1.618;

  // ========================================
  // 字体级数系统
  // ========================================
  // 基准：14px
  // 比例：每级约为 φ 倍关系

  /// h1 - 大标题（HeaderBar主标题）
  /// 36px = 14 × φ × φ ≈ 36.6
  static const double fontH1 = 36.0;

  /// h2 - 中标题
  /// 22px = 14 × φ ≈ 22.7
  static const double fontH2 = 22.0;

  /// h3 - 小标题（Panel标题、重要文字）
  /// 16px = 基准 + 2
  static const double fontH3 = 16.0;

  /// body - 正文（标签、正文）
  /// 14px - 基准字号
  static const double fontBody = 14.0;

  /// small - 辅助信息
  /// 12px ≈ 14 / φ ≈ 8.7，调整到12
  static const double fontSmall = 12.0;

  /// tiny - 最小文字（编号、次要信息）
  /// 10px
  static const double fontTiny = 10.0;

  // ========================================
  // 间距系统
  // ========================================
  // 基准：8px
  // 比例：每级约为 φ 倍关系

  /// 基准间距
  static const double spaceBase = 8.0;

  /// XS - 最小间距
  /// 5px ≈ 8 / φ ≈ 4.9
  static const double spaceXS = 5.0;

  /// SM - 小间距（元素内部）
  /// 8px
  static const double spaceSM = 8.0;

  /// MD - 中等间距（相关元素之间）
  /// 13px ≈ 8 × φ ≈ 12.9
  static const double spaceMD = 13.0;

  /// LG - 大间距（区块之间）
  /// 21px ≈ 13 × φ ≈ 21.0
  static const double spaceLG = 21.0;

  /// XL - 超大间距（主要区块）
  /// 34px ≈ 21 × φ ≈ 34.0
  static const double spaceXL = 34.0;

  // ========================================
  // 组件高度
  // ========================================

  /// HeaderBar 高度（顶部标题栏）
  /// 70px - 遵循黄金比例优化
  static const double headerHeight = 70.0;

  /// Panel Header 高度（面板标题）
  /// 60px - 与HeaderBar形成层次关系
  static const double panelHeaderHeight = 60.0;

  // ========================================
  // 图标尺寸
  // ========================================

  /// XL - 超大图标
  /// 48px ≈ headerHeight / φ ≈ 43.3
  static const double iconXL = 48.0;

  /// LG - 大图标
  /// 32px
  static const double iconLG = 32.0;

  /// MD - 中等图标
  /// 24px
  static const double iconMD = 24.0;

  /// SM - 小图标
  /// 16px
  static const double iconSM = 16.0;

  /// XS - 最小图标
  /// 12px
  static const double iconXS = 12.0;

  // ========================================
  // 圆角半径
  // ========================================

  /// SM - 小圆角
  static const double radiusSM = 8.0;

  /// MD - 中圆角
  static const double radiusMD = 12.0;

  /// LG - 大圆角
  static const double radiusLG = 20.0;

  // ========================================
  // 边框宽度
  // ========================================

  /// 细边框
  static const double borderThin = 1.0;

  /// 标准边框
  static const double borderStandard = 1.5;

  /// 粗边框
  static const double borderThick = 2.0;

  // ========================================
  // 阴影参数
  // ========================================

  /// 轻微阴影模糊半径
  static const double shadowBlurSM = 8.0;

  /// 标准阴影模糊半径
  static const double shadowBlurMD = 12.0;

  /// 强阴影模糊半径
  static const double shadowBlurLG = 20.0;
}
