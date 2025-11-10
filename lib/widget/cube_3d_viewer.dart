import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';
import 'package:dio/dio.dart';
import '../utils/stl_to_obj_converter.dart';

/// 基于 flutter_cube 的 3D 模型查看器
///
/// 特点：
/// - 轻量级：内存占用 50-100 MB（vs CEF 200-500 MB）
/// - 原生渲染：基于 OpenGL，无需 WebView
/// - 自动旋转：Y 轴旋转动画
/// - STL 支持：自动转换 STL → OBJ → Mesh
class Cube3DViewer extends StatefulWidget {
  final String stlUrl;
  final int initDelay;

  const Cube3DViewer({
    super.key,
    required this.stlUrl,
    this.initDelay = 0,
  });

  @override
  State<Cube3DViewer> createState() => _Cube3DViewerState();
}

class _Cube3DViewerState extends State<Cube3DViewer>
    with SingleTickerProviderStateMixin {
  Scene? _scene;
  Object? _object;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    // 旋转动画控制器（6秒一圈）
    _animationController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )
      ..addListener(() {
        if (_object != null && _scene != null) {
          // 方案1：倾斜 + Y轴旋转（能看到立体全貌）
          _object!.rotation.x = 25; // 向前倾斜25度（显示顶部）
          _object!.rotation.z = 15; // 侧倾15度（增加动态感）
          _object!.rotation.y = _animationController.value * 360; // 绕Y轴旋转

          _object!.updateTransform();
          _scene!.update();
        }
      })
      ..repeat();

    if (widget.initDelay > 0) {
      Future.delayed(Duration(milliseconds: widget.initDelay), _init);
    } else {
      _init();
    }
  }

  Future<void> _init() async {
    try {
      // 1. 下载 STL 文件
      print('📥 下载 STL: ${widget.stlUrl}');
      final dio = Dio();
      final response = await dio.get<List<int>>(
        widget.stlUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('STL 文件为空');
      }

      final stlBytes = Uint8List.fromList(response.data!);
      print('✅ 下载完成: ${stlBytes.length} 字节');

      // 2. 转换 STL → OBJ
      print('🔄 转换 STL → OBJ...');
      final objString = StlToObjConverter.convert(stlBytes, optimize: true);
      print('✅ 转换完成: ${objString.length} 字符');

      // 3. 解析 OBJ 为 Mesh
      final mesh = _parseObjToMesh(objString);
      print('✅ Mesh 创建: ${mesh.vertices.length} 顶点, ${mesh.indices.length} 三角形');

      // 4. 创建 Object 和 Scene（等待 onSceneCreated 回调）
      if (mounted) {
        setState(() {
          _object = Object(
            mesh: mesh,
            backfaceCulling: false,
            lighting: true,
          );
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ 加载失败: $e');
      print(stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// 解析 OBJ 字符串为 Mesh
  Mesh _parseObjToMesh(String objString) {
    final vertices = <Vector3>[];
    final normals = <Vector3>[];
    final indices = <Polygon>[];

    final lines = objString.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final parts = trimmed.split(RegExp(r'\s+'));

      if (parts[0] == 'v') {
        // 顶点
        vertices.add(Vector3(
          double.parse(parts[1]),
          double.parse(parts[2]),
          double.parse(parts[3]),
        ));
      } else if (parts[0] == 'vn') {
        // 法向量
        normals.add(Vector3(
          double.parse(parts[1]),
          double.parse(parts[2]),
          double.parse(parts[3]),
        ));
      } else if (parts[0] == 'f') {
        // 面（三角形）
        // 格式: f v1//vn1 v2//vn2 v3//vn3
        final v1 = _parseFaceVertex(parts[1]);
        final v2 = _parseFaceVertex(parts[2]);
        final v3 = _parseFaceVertex(parts[3]);

        indices.add(Polygon(v1, v2, v3));
      }
    }

    // 自动缩放和居中
    if (vertices.isNotEmpty) {
      _normalizeVertices(vertices);
    }

    return Mesh(
      vertices: vertices,
      indices: indices,
    );
  }

  /// 解析面顶点索引（格式: v//vn）
  int _parseFaceVertex(String faceVertex) {
    // OBJ 索引从 1 开始，Mesh 索引从 0 开始
    final parts = faceVertex.split('//');
    return int.parse(parts[0]) - 1;
  }

  /// 归一化顶点（居中并缩放到合适大小）
  void _normalizeVertices(List<Vector3> vertices) {
    if (vertices.isEmpty) return;

    // 计算边界
    double minX = vertices[0].x, minY = vertices[0].y, minZ = vertices[0].z;
    double maxX = vertices[0].x, maxY = vertices[0].y, maxZ = vertices[0].z;

    for (final v in vertices) {
      if (v.x < minX) minX = v.x;
      if (v.y < minY) minY = v.y;
      if (v.z < minZ) minZ = v.z;
      if (v.x > maxX) maxX = v.x;
      if (v.y > maxY) maxY = v.y;
      if (v.z > maxZ) maxZ = v.z;
    }

    // 计算中心和尺寸
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    final centerZ = (minZ + maxZ) / 2;
    final sizeX = maxX - minX;
    final sizeY = maxY - minY;
    final sizeZ = maxZ - minZ;
    final maxSize = [sizeX, sizeY, sizeZ].reduce((a, b) => a > b ? a : b);

    // 目标尺寸
    final targetSize = 5.0;
    final scale = targetSize / maxSize;

    print('📐 模型尺寸: ${sizeX.toStringAsFixed(2)} x ${sizeY.toStringAsFixed(2)} x ${sizeZ.toStringAsFixed(2)}');
    print('🔍 缩放比例: ${scale.toStringAsFixed(4)}');

    // 平移到中心并缩放
    for (final v in vertices) {
      v.x = (v.x - centerX) * scale;
      v.y = (v.y - centerY) * scale;
      v.z = (v.z - centerZ) * scale;
    }
  }

  void _onSceneCreated(Scene scene) {
    _scene = scene;

    // 设置相机
    scene.camera.position.z = 10;

    // 添加对象到场景
    if (_object != null) {
      scene.world.add(_object!);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_hasError) {
      return Container(
        color: Colors.cyan.withOpacity(0.05),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.withOpacity(0.6),
                size: 48,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red.withOpacity(0.6),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_isLoading || _object == null) {
      return Container(
        color: Colors.cyan.withOpacity(0.05),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // 渲染 3D 模型
    return Cube(
      onSceneCreated: _onSceneCreated,
      interactive: false, // 禁用手势交互（看板模式）
    );
  }
}
