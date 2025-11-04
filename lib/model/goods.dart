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
    this.remark,
    this.createTime,
    this.updateTime,
  });

  factory Goods.fromJson(Map<String, dynamic> json) {
    return Goods(
      goodsCode: json['goodsCode'] as String,
      goodsName: json['goodsName'] as String?,
      goodsTypeCode: json['goodsTypeCode'] as String?,
      goodsTypeName: json['goodsTypeName'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      batchNo: json['batchNo'] as String?,
      slotX: json['slotX'] as int?,
      slotY: json['slotY'] as int?,
      status: json['status'] as int?,
      imageUrl: json['imageUrl'] as String?,
      remark: json['remark'] as String?,
      createTime: json['createTime'] != null
          ? DateTime.parse(json['createTime'] as String)
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.parse(json['updateTime'] as String)
          : null,
    );
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
