/// 设备模型 - 对应 Vue 项目中的 Device 接口
class Device {
  /// 设备编号
  final String deviceCode;

  /// 显示编号
  final String? displayCode;

  /// 设备名称
  final String? deviceName;

  /// 设备类型编码
  final String? deviceTypeCode;

  /// 设备类型名称
  final String? deviceTypeName;

  /// 工作状态 (0: 空闲, 1: 工作中)
  final int? workStatus;

  /// 地址
  final String? address;

  /// 托盘编码
  final String? palletCode;

  /// 任务编码
  final String? taskCode;

  /// 源地址
  final String? sourceAddress;

  /// 目标地址
  final String? destAddress;

  /// X方向槽位数
  final int? slotsXCount;

  /// Y方向槽位数
  final int? slotsYCount;

  /// 行
  final int? row;

  /// 列
  final int? column;

  /// 子设备列表
  final List<Device> children;

  Device({
    required this.deviceCode,
    this.displayCode,
    this.deviceName,
    this.deviceTypeCode,
    this.deviceTypeName,
    this.workStatus,
    this.address,
    this.palletCode,
    this.taskCode,
    this.sourceAddress,
    this.destAddress,
    this.slotsXCount,
    this.slotsYCount,
    this.row,
    this.column,
    this.children = const [],
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      // deviceCode 可能是 int 或 String，统一转为 String
      deviceCode: json['deviceCode']?.toString() ?? '',
      displayCode: json['displayCode']?.toString(),
      deviceName: json['deviceName']?.toString(),
      deviceTypeCode: json['deviceTypeCode']?.toString(),
      deviceTypeName: json['deviceTypeName']?.toString(),
      // workStatus 可能是 String 或 int，转为 int
      workStatus: _parseToInt(json['workStatus']),
      address: json['address']?.toString(),
      // palletCode 可能是 int 或 String，统一转为 String
      // 这是关键字段！SignalR 推送的数据中 palletCode 可能是 number
      palletCode: json['palletCode']?.toString(),
      taskCode: json['taskCode']?.toString(),
      sourceAddress: json['sourceAddress']?.toString(),
      destAddress: json['destAddress']?.toString(),
      // 数值字段的安全转换
      slotsXCount: _parseToInt(json['slotsXCount']),
      slotsYCount: _parseToInt(json['slotsYCount']),
      row: _parseToInt(json['row']),
      column: _parseToInt(json['column']),
      // children 可能叫 childrenDevice（对应 Vue 中的 childrenDevice）
      children: _parseChildren(json),
    );
  }

  /// 安全解析 int 类型
  static int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is double) return value.toInt();
    return null;
  }

  /// 解析子设备列表（兼容 children 和 childrenDevice）
  static List<Device> _parseChildren(Map<String, dynamic> json) {
    // 尝试从 children 字段获取
    var childrenData = json['children'] as List<dynamic>?;

    // 如果 children 不存在，尝试从 childrenDevice 获取（对应 Vue 中的字段名）
    if (childrenData == null || childrenData.isEmpty) {
      childrenData = json['childrenDevice'] as List<dynamic>?;
    }

    if (childrenData == null) return [];

    return childrenData
        .map((e) => Device.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceCode': deviceCode,
      'displayCode': displayCode,
      'deviceName': deviceName,
      'deviceTypeCode': deviceTypeCode,
      'deviceTypeName': deviceTypeName,
      'workStatus': workStatus,
      'address': address,
      'palletCode': palletCode,
      'taskCode': taskCode,
      'sourceAddress': sourceAddress,
      'destAddress': destAddress,
      'slotsXCount': slotsXCount,
      'slotsYCount': slotsYCount,
      'row': row,
      'column': column,
      'children': children.map((e) => e.toJson()).toList(),
    };
  }
}
