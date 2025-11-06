/// 货物模型
class Goods {
  /// 货物编码
  final String goodsCode;

  /// 货物名称
  final String? goodsName;

  /// 货物类型编码
  final String? goodsTypeCode;

  /// 货物类型名称
  final String? goodsTypeName;

  /// 数量
  final double? quantity;

  /// 单位
  final String? unit;

  /// 批次号
  final String? batchNo;

  /// 槽位X
  final int? slotX;

  /// 槽位Y
  final int? slotY;

  /// 状态
  final int? status;

  /// 图片URL
  final String? imageUrl;

  /// 3D模型文件URL（OBJ格式）
  final String? modelFileUrl;

  /// 备注
  final String? remark;

  /// 创建时间
  final DateTime? createTime;

  /// 更新时间
  final DateTime? updateTime;

  Goods({
    required this.goodsCode,
    this.goodsName,
    this.goodsTypeCode,
    this.goodsTypeName,
    this.quantity,
    this.unit,
    this.batchNo,
    this.slotX,
    this.slotY,
    this.status,
    this.imageUrl,
    this.modelFileUrl,
    this.remark,
    this.createTime,
    this.updateTime,
  });

  factory Goods.fromJson(Map<String, dynamic> json) {
    return Goods(
      // 兼容 Vue API: goodsNo 和 goodsCode 都支持
      goodsCode: (json['goodsNo'] ?? json['goodsCode'])?.toString() ?? '',
      goodsName: json['goodsName']?.toString(),
      goodsTypeCode: json['goodsTypeCode']?.toString(),
      goodsTypeName: json['goodsTypeName']?.toString(),
      // 安全转换数量
      quantity: _parseToDouble(json['quantity']),
      unit: json['unit']?.toString() ?? '件',
      batchNo: json['batchNo']?.toString(),
      slotX: _parseToInt(json['slotX']),
      slotY: _parseToInt(json['slotY']),
      status: _parseToInt(json['status']),
      imageUrl: json['imageUrl']?.toString(),
      modelFileUrl: json['modelFileUrl']?.toString(),
      remark: json['remark']?.toString(),
      createTime: json['createTime'] != null
          ? DateTime.tryParse(json['createTime'].toString())
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.tryParse(json['updateTime'].toString())
          : null,
    );
  }

  /// 安全解析 double 类型
  static double? _parseToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// 安全解析 int 类型
  static int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'goodsCode': goodsCode,
      'goodsName': goodsName,
      'goodsTypeCode': goodsTypeCode,
      'goodsTypeName': goodsTypeName,
      'quantity': quantity,
      'unit': unit,
      'batchNo': batchNo,
      'slotX': slotX,
      'slotY': slotY,
      'status': status,
      'imageUrl': imageUrl,
      'remark': remark,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
    };
  }
}
