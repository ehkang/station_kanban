import 'dart:typed_data';
import 'dart:convert';

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

    print('📦 Binary STL: $triangleCount 个三角形');

    final vertices = <_Vertex>[];
    final normals = <_Vector3>[];
    final faces = <_Face>[];

    int offset = 84; // 头部(80) + 三角形数量(4)

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

      // 添加到列表
      vertices.addAll([v1, v2, v3]);
      normals.add(_Vector3(nx, ny, nz));

      // 面索引（从1开始）
      final baseIndex = i * 3 + 1;
      faces.add(_Face(baseIndex, baseIndex + 1, baseIndex + 2, i));
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

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('facet normal')) {
        // 解析法向量
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 5) {
          currentNormal = _Vector3(
            double.parse(parts[2]),
            double.parse(parts[3]),
            double.parse(parts[4]),
          );
        }
      } else if (trimmed.startsWith('vertex')) {
        // 解析顶点
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          triangleVertices.add(_Vertex(
            double.parse(parts[1]),
            double.parse(parts[2]),
            double.parse(parts[3]),
          ));
        }
      } else if (trimmed.startsWith('endfacet')) {
        // 三角形完成
        if (triangleVertices.length == 3 && currentNormal != null) {
          vertices.addAll(triangleVertices);
          normals.add(currentNormal);

          final baseIndex = triangleCount * 3 + 1;
          faces.add(_Face(baseIndex, baseIndex + 1, baseIndex + 2, triangleCount));

          triangleCount++;
          triangleVertices.clear();
        }
      }
    }

    print('📦 ASCII STL: $triangleCount 个三角形');

    return _generateObjString(vertices, normals, faces, optimize: optimize);
  }

  /// 生成 OBJ 格式字符串
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

      print('✅ 优化: ${vertices.length} → ${uniqueVertices.length} 顶点');

      // 写入顶点
      for (final v in uniqueVertices) {
        obj.writeln('v ${v.x.toStringAsFixed(6)} ${v.y.toStringAsFixed(6)} ${v.z.toStringAsFixed(6)}');
      }

      // 写入法向量
      obj.writeln();
      for (final n in normals) {
        obj.writeln('vn ${n.x.toStringAsFixed(6)} ${n.y.toStringAsFixed(6)} ${n.z.toStringAsFixed(6)}');
      }

      // 写入面
      obj.writeln();
      for (final face in newFaces) {
        final normalIndex = face.normalIndex + 1;
        obj.writeln('f ${face.v1}//${normalIndex} ${face.v2}//${normalIndex} ${face.v3}//${normalIndex}');
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
    final key = '${vertex.x.toStringAsFixed(6)}_${vertex.y.toStringAsFixed(6)}_${vertex.z.toStringAsFixed(6)}';

    if (vertexMap.containsKey(key)) {
      return vertexMap[key]!;
    } else {
      uniqueVertices.add(vertex);
      final index = uniqueVertices.length;
      vertexMap[key] = index;
      return index;
    }
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
