import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';  // 🎨 用于平滑着色的法向量归一化

/// STL 转 OBJ 转换器
///
/// 支持 Binary STL 和 ASCII STL 格式
/// 将 STL 三角形网格转换为 OBJ 格式供 flutter_cube 使用
class StlToObjConverter {
  /// 将 STL 字节数据转换为 OBJ 字符串
  ///
  /// [stlBytes] STL 文件的字节数据
  /// [optimize] 是否优化（去重顶点）
  /// 返回 OBJ 格式字符串
  static String convert(Uint8List stlBytes, {bool optimize = true}) {
    // 判断是 Binary STL 还是 ASCII STL
    if (_isBinaryStl(stlBytes)) {
      return _convertBinaryStl(stlBytes, optimize: optimize);
    } else {
      return _convertAsciiStl(stlBytes, optimize: optimize);
    }
  }

  /// 判断是否为 Binary STL
  ///
  /// 更可靠的判断方法：
  /// 1. 检查文件大小是否符合 Binary STL 格式（80 + 4 + n*50）
  /// 2. Binary STL 即使头部有 "solid" 也要正确识别
  static bool _isBinaryStl(Uint8List bytes) {
    if (bytes.length < 84) {
      // 文件太小，无法是 Binary STL
      return false;
    }

    // 读取三角形数量（字节 80-83，小端序）
    final buffer = ByteData.sublistView(bytes);
    final triangleCount = buffer.getUint32(80, Endian.little);

    // Binary STL 的期望大小：80(头) + 4(数量) + triangleCount * 50(每个三角形)
    final expectedSize = 80 + 4 + triangleCount * 50;

    // 如果文件大小完全匹配，肯定是 Binary STL
    if (bytes.length == expectedSize) {
      return true;
    }

    // 如果大小不匹配，再检查是否以 "solid" 开头（可能是 ASCII）
    try {
      final header = utf8.decode(bytes.sublist(0, 5), allowMalformed: false);
      if (header.toLowerCase() == 'solid') {
        // 可能是 ASCII STL，但要确认不是误判
        // Binary STL 也可能在头部包含 "solid"
        // 所以如果大小匹配度很高，仍然认为是 Binary
        if ((bytes.length - expectedSize).abs() < 100) {
          return true; // 差异很小，认为是 Binary
        }
        return false; // ASCII STL
      }
    } catch (e) {
      // 解码失败，肯定是 Binary
      return true;
    }

    // 默认认为是 Binary
    return true;
  }

  /// 转换 Binary STL
  static String _convertBinaryStl(Uint8List bytes, {required bool optimize}) {
    final buffer = ByteData.sublistView(bytes);

    // 跳过 80 字节头部
    // 读取三角形数量（4字节，小端序）
    final triangleCount = buffer.getUint32(80, Endian.little);

    final vertices = <_Vertex>[];
    final normals = <_Vector3>[];
    final faces = <_Face>[];

    int offset = 84; // 头部(80) + 三角形数量(4)

    // 🔍 诊断统计
    int validCount = 0;
    int degenerateCount = 0;
    int zeroNormalCount = 0;
    int nanCount = 0;

    for (int i = 0; i < triangleCount; i++) {
      // 法向量 (3 * 4 bytes)
      final nx = buffer.getFloat32(offset, Endian.little);
      final ny = buffer.getFloat32(offset + 4, Endian.little);
      final nz = buffer.getFloat32(offset + 8, Endian.little);
      offset += 12;

      // 3个顶点 (3 * 3 * 4 bytes)
      final v1 = _Vertex(
        buffer.getFloat32(offset, Endian.little),
        buffer.getFloat32(offset + 4, Endian.little),
        buffer.getFloat32(offset + 8, Endian.little),
      );
      offset += 12;

      final v2 = _Vertex(
        buffer.getFloat32(offset, Endian.little),
        buffer.getFloat32(offset + 4, Endian.little),
        buffer.getFloat32(offset + 8, Endian.little),
      );
      offset += 12;

      final v3 = _Vertex(
        buffer.getFloat32(offset, Endian.little),
        buffer.getFloat32(offset + 4, Endian.little),
        buffer.getFloat32(offset + 8, Endian.little),
      );
      offset += 12;

      // 属性字节计数 (2 bytes)
      offset += 2;

      // 🔍 验证：检查NaN和Infinity
      if (_hasInvalidNumber(v1) || _hasInvalidNumber(v2) || _hasInvalidNumber(v3)) {
        nanCount++;
        continue; // 跳过包含无效数值的三角形
      }

      // 🔍 验证：检查零法向量
      if (nx == 0 && ny == 0 && nz == 0) {
        zeroNormalCount++;
        // 零法向量可能是有效的（让渲染器自动计算），所以不跳过
      }

      // 🔍 验证：检查退化三角形（顶点重合或共线）
      if (_isDegenerate(v1, v2, v3)) {
        degenerateCount++;
        continue; // 跳过退化三角形
      }

      // 添加到列表
      validCount++;
      final vertexBaseIndex = vertices.length;
      vertices.addAll([v1, v2, v3]);
      normals.add(_Vector3(nx, ny, nz));

      // 面索引（从1开始）
      final baseIndex = vertexBaseIndex + 1;
      faces.add(_Face(baseIndex, baseIndex + 1, baseIndex + 2, normals.length - 1));
    }

    // 🔍 输出诊断日志
    print('📊 [STL Binary] 三角形统计:');
    print('   总数: $triangleCount');
    print('   ✅ 有效: $validCount');
    print('   ⚠️  退化: $degenerateCount (顶点重合/共线)');
    print('   ⚠️  零法向量: $zeroNormalCount');
    print('   ❌ 无效数值: $nanCount (NaN/Infinity)');
    if (validCount < triangleCount) {
      print('   ⚠️  警告: 丢失了 ${triangleCount - validCount} 个三角形');
    }

    return _generateObjString(vertices, normals, faces, optimize: optimize);
  }

  /// 转换 ASCII STL
  static String _convertAsciiStl(Uint8List bytes, {required bool optimize}) {
    final text = utf8.decode(bytes);
    final lines = text.split('\n');

    final vertices = <_Vertex>[];
    final normals = <_Vector3>[];
    final faces = <_Face>[];

    _Vector3? currentNormal;
    final triangleVertices = <_Vertex>[];
    int triangleCount = 0;

    // 🔍 诊断统计
    int validCount = 0;
    int degenerateCount = 0;
    int incompleteCount = 0;
    int parseErrorCount = 0;
    int zeroNormalCount = 0;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('facet normal')) {
        // 解析法向量
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 5) {
          try {
            currentNormal = _Vector3(
              double.parse(parts[2]),
              double.parse(parts[3]),
              double.parse(parts[4]),
            );

            // 🔍 检查零法向量
            if (currentNormal.x == 0 && currentNormal.y == 0 && currentNormal.z == 0) {
              zeroNormalCount++;
            }
          } catch (e) {
            parseErrorCount++;
            currentNormal = null;
          }
        }
      } else if (trimmed.startsWith('vertex')) {
        // 解析顶点
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          try {
            final vertex = _Vertex(
              double.parse(parts[1]),
              double.parse(parts[2]),
              double.parse(parts[3]),
            );

            // 🔍 检查无效数值
            if (!_hasInvalidNumber(vertex)) {
              triangleVertices.add(vertex);
            } else {
              parseErrorCount++;
            }
          } catch (e) {
            parseErrorCount++;
          }
        }
      } else if (trimmed.startsWith('endfacet')) {
        triangleCount++;

        // 三角形完成
        if (triangleVertices.length == 3 && currentNormal != null) {
          final v1 = triangleVertices[0];
          final v2 = triangleVertices[1];
          final v3 = triangleVertices[2];

          // 🔍 检查退化三角形
          if (_isDegenerate(v1, v2, v3)) {
            degenerateCount++;
          } else {
            validCount++;
            final vertexBaseIndex = vertices.length;
            vertices.addAll(triangleVertices);
            normals.add(currentNormal);

            final baseIndex = vertexBaseIndex + 1;
            faces.add(_Face(baseIndex, baseIndex + 1, baseIndex + 2, normals.length - 1));
          }
        } else {
          // 三角形不完整（顶点数!=3或法向量缺失）
          incompleteCount++;
        }

        triangleVertices.clear();
        currentNormal = null;
      }
    }

    // 🔍 输出诊断日志
    print('📊 [STL ASCII] 三角形统计:');
    print('   总数: $triangleCount');
    print('   ✅ 有效: $validCount');
    print('   ⚠️  退化: $degenerateCount (顶点重合/共线)');
    print('   ⚠️  不完整: $incompleteCount (顶点数!=3或缺法向量)');
    print('   ⚠️  零法向量: $zeroNormalCount');
    print('   ❌ 解析错误: $parseErrorCount');
    if (validCount < triangleCount) {
      print('   ⚠️  警告: 丢失了 ${triangleCount - validCount} 个三角形');
    }

    return _generateObjString(vertices, normals, faces, optimize: optimize);
  }

  /// 生成 OBJ 格式字符串（强制使用平滑着色）
  static String _generateObjString(
    List<_Vertex> vertices,
    List<_Vector3> normals,
    List<_Face> faces, {
    required bool optimize,
  }) {
    final obj = StringBuffer();
    obj.writeln('# Converted from STL by flutter_cube');
    obj.writeln('# Vertices: ${vertices.length}');
    obj.writeln('# Faces: ${faces.length}');
    obj.writeln();

    if (optimize) {
      // 优化：去重顶点
      final uniqueVertices = <_Vertex>[];
      final vertexMap = <String, int>{};
      final newFaces = <_Face>[];

      for (final face in faces) {
        final v1 = vertices[face.v1 - 1];
        final v2 = vertices[face.v2 - 1];
        final v3 = vertices[face.v3 - 1];

        final i1 = _getOrAddVertex(v1, uniqueVertices, vertexMap);
        final i2 = _getOrAddVertex(v2, uniqueVertices, vertexMap);
        final i3 = _getOrAddVertex(v3, uniqueVertices, vertexMap);

        newFaces.add(_Face(i1, i2, i3, face.normalIndex));
      }

      // 写入顶点
      for (final v in uniqueVertices) {
        obj.writeln('v ${v.x.toStringAsFixed(6)} ${v.y.toStringAsFixed(6)} ${v.z.toStringAsFixed(6)}');
      }

      // 🎨 计算并写入顶点平滑法向量（强制平滑着色）
      obj.writeln();
      final vertexNormals = _calculateVertexNormals(uniqueVertices.length, newFaces, normals);

      for (final n in vertexNormals) {
        obj.writeln('vn ${n.x.toStringAsFixed(6)} ${n.y.toStringAsFixed(6)} ${n.z.toStringAsFixed(6)}');
      }

      // 写入面（每个顶点使用自己的法向量索引）
      obj.writeln();
      for (final face in newFaces) {
        obj.writeln('f ${face.v1}//${face.v1} ${face.v2}//${face.v2} ${face.v3}//${face.v3}');
      }
    } else {
      // 不优化：直接输出
      for (final v in vertices) {
        obj.writeln('v ${v.x.toStringAsFixed(6)} ${v.y.toStringAsFixed(6)} ${v.z.toStringAsFixed(6)}');
      }

      obj.writeln();
      for (final n in normals) {
        obj.writeln('vn ${n.x.toStringAsFixed(6)} ${n.y.toStringAsFixed(6)} ${n.z.toStringAsFixed(6)}');
      }

      obj.writeln();
      for (final face in faces) {
        final normalIndex = face.normalIndex + 1;
        obj.writeln('f ${face.v1}//${normalIndex} ${face.v2}//${normalIndex} ${face.v3}//${normalIndex}');
      }
    }

    return obj.toString();
  }

  /// 获取或添加顶点（去重）
  static int _getOrAddVertex(
    _Vertex vertex,
    List<_Vertex> uniqueVertices,
    Map<String, int> vertexMap,
  ) {
    // 🔧 提高精度到7位小数以匹配float32精度，减少误合并
    final key = '${vertex.x.toStringAsFixed(7)}_${vertex.y.toStringAsFixed(7)}_${vertex.z.toStringAsFixed(7)}';

    if (vertexMap.containsKey(key)) {
      return vertexMap[key]!;
    } else {
      uniqueVertices.add(vertex);
      final index = uniqueVertices.length;
      vertexMap[key] = index;
      return index;
    }
  }

  /// 🎨 计算顶点平滑法向量（Smooth Shading）
  ///
  /// 对于每个顶点，计算所有关联三角形法向量的平均值
  /// 这样可以消除三角网格的明暗分界线，实现平滑的光照效果
  ///
  /// [vertexCount] 顶点数量
  /// [faces] 面列表
  /// [faceNormals] 面法向量列表
  /// 返回每个顶点的平滑法向量
  static List<_Vector3> _calculateVertexNormals(
    int vertexCount,
    List<_Face> faces,
    List<_Vector3> faceNormals,
  ) {
    // 为每个顶点收集所有关联的三角形法向量
    final vertexNormalLists = List<List<_Vector3>>.generate(
      vertexCount,
      (_) => [],
    );

    // 遍历所有三角形，将法向量添加到顶点列表中
    for (final face in faces) {
      final normal = faceNormals[face.normalIndex];

      // 顶点索引从1开始，列表索引从0开始
      vertexNormalLists[face.v1 - 1].add(normal);
      vertexNormalLists[face.v2 - 1].add(normal);
      vertexNormalLists[face.v3 - 1].add(normal);
    }

    // 计算每个顶点的平均法向量并归一化
    final smoothNormals = <_Vector3>[];

    for (final normalList in vertexNormalLists) {
      if (normalList.isEmpty) {
        // 没有关联法向量，使用默认值（指向Z轴）
        smoothNormals.add(_Vector3(0, 0, 1));
        continue;
      }

      // 计算平均值
      double sumX = 0, sumY = 0, sumZ = 0;
      for (final n in normalList) {
        sumX += n.x;
        sumY += n.y;
        sumZ += n.z;
      }

      // 归一化（单位化）
      final length = sqrt(sumX * sumX + sumY * sumY + sumZ * sumZ);
      if (length > 0.0001) {
        smoothNormals.add(_Vector3(
          sumX / length,
          sumY / length,
          sumZ / length,
        ));
      } else {
        // 法向量过小（几乎为零），使用默认值
        smoothNormals.add(_Vector3(0, 0, 1));
      }
    }

    return smoothNormals;
  }
}

/// 顶点
class _Vertex {
  final double x, y, z;
  _Vertex(this.x, this.y, this.z);
}

/// 向量
class _Vector3 {
  final double x, y, z;
  _Vector3(this.x, this.y, this.z);
}

/// 面（三角形）
class _Face {
  final int v1, v2, v3; // 顶点索引（从1开始）
  final int normalIndex; // 法向量索引（从0开始）
  _Face(this.v1, this.v2, this.v3, this.normalIndex);
}

/// 🔍 检查顶点是否包含无效数值（NaN或Infinity）
bool _hasInvalidNumber(_Vertex v) {
  return v.x.isNaN || v.x.isInfinite ||
         v.y.isNaN || v.y.isInfinite ||
         v.z.isNaN || v.z.isInfinite;
}

/// 🔍 检查三角形是否退化（顶点重合或共线）
bool _isDegenerate(_Vertex v1, _Vertex v2, _Vertex v3) {
  const tolerance = 1e-7; // 容差

  // 检查顶点是否重合
  final d12 = _distance(v1, v2);
  final d23 = _distance(v2, v3);
  final d31 = _distance(v3, v1);

  if (d12 < tolerance || d23 < tolerance || d31 < tolerance) {
    return true; // 至少有两个顶点重合
  }

  // 检查三个顶点是否共线（叉积长度接近0）
  // 向量 v1→v2 和 v1→v3 的叉积
  final edge1X = v2.x - v1.x;
  final edge1Y = v2.y - v1.y;
  final edge1Z = v2.z - v1.z;

  final edge2X = v3.x - v1.x;
  final edge2Y = v3.y - v1.y;
  final edge2Z = v3.z - v1.z;

  // 叉积: edge1 × edge2
  final crossX = edge1Y * edge2Z - edge1Z * edge2Y;
  final crossY = edge1Z * edge2X - edge1X * edge2Z;
  final crossZ = edge1X * edge2Y - edge1Y * edge2X;

  // 叉积的长度（三角形面积的2倍）
  final crossLength = sqrt(crossX * crossX + crossY * crossY + crossZ * crossZ);

  return crossLength < tolerance; // 面积接近0，三点共线
}

/// 🔍 计算两个顶点之间的距离
double _distance(_Vertex v1, _Vertex v2) {
  final dx = v1.x - v2.x;
  final dy = v1.y - v2.y;
  final dz = v1.z - v2.z;
  return sqrt(dx * dx + dy * dy + dz * dz);
}
