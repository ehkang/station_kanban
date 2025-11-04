/// 托盘/容器模型
/// 对应 Vue 项目中的 Container 接口
/// 注意：货物数据不存储在容器中，而是单独通过API获取
class ContainerModel {
  /// 托盘编码
  final String containerCode;

  /// 容器类型编码
  final String? containerTypeCode;

  /// 容器类型名称
  final String? containerTypeName;

  /// 所在设备编码
  final String? deviceCode;

  /// 所在地址
  final String? address;

  /// 目标地址
  final String? destAddress;

  /// 源地址
  final String? sourceAddress;

  /// 任务编码
  final String? taskCode;

  /// 状态
  final int? status;

  /// 创建时间
  final DateTime? createTime;

  /// 更新时间
  final DateTime? updateTime;

  ContainerModel({
    required this.containerCode,
    this.containerTypeCode,
    this.containerTypeName,
    this.deviceCode,
    this.address,
    this.destAddress,
    this.sourceAddress,
    this.taskCode,
    this.status,
    this.createTime,
    this.updateTime,
  });

  factory ContainerModel.fromJson(Map<String, dynamic> json) {
    return ContainerModel(
      containerCode: json['containerCode'] as String,
      containerTypeCode: json['containerTypeCode'] as String?,
      containerTypeName: json['containerTypeName'] as String?,
      deviceCode: json['deviceCode'] as String?,
      address: json['address'] as String?,
      destAddress: json['destAddress'] as String?,
      sourceAddress: json['sourceAddress'] as String?,
      taskCode: json['taskCode'] as String?,
      status: json['status'] as int?,
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
      'containerCode': containerCode,
      'containerTypeCode': containerTypeCode,
      'containerTypeName': containerTypeName,
      'deviceCode': deviceCode,
      'address': address,
      'destAddress': destAddress,
      'sourceAddress': sourceAddress,
      'taskCode': taskCode,
      'status': status,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
    };
  }
}