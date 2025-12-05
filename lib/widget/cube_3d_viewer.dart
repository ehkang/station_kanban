import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';
import 'package:dio/dio.dart';
import '../utils/stl_to_obj_converter.dart';
import '../utils/error_logger.dart';

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
  DateTime _lastUpdateTime = DateTime.now();

  @override
  void initState() {
    super.initState();

    // 旋转动画控制器（12秒一圈，但限制为 25fps 以提升性能）
    _animationController = AnimationController(
      duration: const Duration(seconds: 12),  // 6秒 → 12秒（速度降低一半）
      vsync: this,
    )
      ..addListener(() {
        if (_object != null && _scene != null) {
          // 限制帧率为 25fps（每 40ms 更新一次）
          final now = DateTime.now();
          final elapsed = now.difference(_lastUpdateTime).inMilliseconds;

          if (elapsed >= 40) {  // 40ms = 1000ms / 25fps
            _lastUpdateTime = now;

            // 方案1：倾斜 + Y轴旋转（能看到立体全貌）
            _object!.rotation.x = 25; // 向前倾斜25度（显示顶部）
            _object!.rotation.z = 15; // 侧倾15度（增加动态感）
            _object!.rotation.y = _animationController.value * 360; // 绕Y轴旋转

            _object!.updateTransform();
            _scene!.update();
          }
        }
      })
      ..repeat();

    if (widget.initDelay > 0) {
      Future.delayed(Duration(milliseconds: widget.initDelay), _init);
    } else {
      _init();
    }
  }

  @override
  void didUpdateWidget(Cube3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果 URL 变化了，重新加载模型（共存亡原则）
    if (oldWidget.stlUrl != widget.stlUrl) {
      // 清空旧数据，重置状态
      setState(() {
        _object = null;
        _scene = null;
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      // 重新加载
      if (widget.initDelay > 0) {
        Future.delayed(Duration(milliseconds: widget.initDelay), _init);
      } else {
        _init();
      }
    }
  }

  Future<void> _init() async {
    final logger = ErrorLogger();
    DioException? dioError;

    try {
      // 1. 下载 STL 文件
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ));

      final response = await dio.get<List<int>>(
        widget.stlUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      // 检查 HTTP 状态码
      if (response.statusCode != 200) {
        await logger.logNetworkError(
          url: widget.stlUrl,
          errorMessage: 'HTTP 状态码异常',
          statusCode: response.statusCode,
          responseData: {
            'statusMessage': response.statusMessage ?? '未知',
          },
        );
        throw Exception('HTTP ${response.statusCode}: ${response.statusMessage}');
      }

      // 检查响应数据
      if (response.data == null || response.data!.isEmpty) {
        await logger.logNetworkError(
          url: widget.stlUrl,
          errorMessage: 'STL 文件为空 (0 bytes)',
          statusCode: response.statusCode,
        );
        throw Exception('STL 文件为空');
      }

      final stlBytes = Uint8List.fromList(response.data!);
      final fileSizeKB = (stlBytes.length / 1024).toStringAsFixed(2);

      // 2. 转换 STL → OBJ
      final objString = StlToObjConverter.convert(stlBytes, optimize: true);

      // 3. 解析 OBJ 为 Mesh
      final mesh = _parseObjToMesh(objString);

      // 验证网格数据
      if (mesh.vertices.isEmpty) {
        await logger.log3DModelError(
          modelUrl: widget.stlUrl,
          errorMessage: '3D 模型解析失败：顶点数量为 0',
          additionalInfo: {
            'fileSize': '$fileSizeKB KB',
            'meshVertices': mesh.vertices.length,
            'meshIndices': mesh.indices.length,
          },
        );
        throw Exception('3D 模型解析失败：顶点数量为 0');
      }

      // 4. 创建 Object 和 Scene（等待 onSceneCreated 回调）
      if (mounted) {
        setState(() {
          _object = Object(
            mesh: mesh,
            backfaceCulling: false,
            lighting: true, // 启用光照
          );
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      dioError = e;

      // 详细记录网络错误
      await logger.logNetworkError(
        url: widget.stlUrl,
        errorMessage: _getDioErrorMessage(e),
        statusCode: e.response?.statusCode,
        responseData: {
          'type': e.type.toString(),
          'message': e.message ?? '未知',
          'error': e.error?.toString() ?? '未知',
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = _getDioErrorMessage(e);
        });
      }
    } catch (e, stackTrace) {
      // 记录详细错误信息到日志文件
      await logger.log3DModelError(
        modelUrl: widget.stlUrl,
        errorMessage: e.toString(),
        stackTrace: stackTrace,
        additionalInfo: {
          'platform': Platform.operatingSystem,
          'platformVersion': Platform.operatingSystemVersion,
          'isDioError': dioError != null,
          'errorType': e.runtimeType.toString(),
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// 获取 Dio 错误的友好消息
  String _getDioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.sendTimeout:
        return '发送超时';
      case DioExceptionType.receiveTimeout:
        return '接收超时';
      case DioExceptionType.badResponse:
        return 'HTTP ${e.response?.statusCode}: ${e.response?.statusMessage ?? "服务器响应错误"}';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络设置';
      case DioExceptionType.badCertificate:
        return 'SSL 证书验证失败';
      case DioExceptionType.unknown:
      default:
        return '未知网络错误: ${e.message ?? "无详细信息"}';
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

    // 设置光照（增强亮度）- 更亮的白光
    scene.light.position.setFrom(Vector3(10, 10, 10));
    scene.light.setColor(
      const Color(0xFFFFFFFF),  // 纯白光
      0.4,   // ambient: 40% 环境光（提高整体亮度）
      1.0,   // diffuse: 100% 漫反射光（最强）
      0.9,   // specular: 90% 高光（强金属反射）
    );

    // 添加对象到场景
    if (_object != null) {
      // 浅色不锈钢材质：银白色金属质感
      // Vector3(R, G, B) 范围 0.0-1.0
      _object!.mesh.material.ambient = Vector3.all(0.7);   // 高亮度环境光（70% 银白色）
      _object!.mesh.material.diffuse = Vector3.all(0.95);  // 高亮度漫反射（95% 银白色）
      _object!.mesh.material.specular = Vector3.all(1.0);  // 纯白高光（金属质感）
      _object!.mesh.material.shininess = 80.0;             // 高光泽度（不锈钢效果）

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
    // 包装抗锯齿容器以改善边缘质量
    return RepaintBoundary(
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_hasError) {
      // 友好提示：没有模型，不显示错误详情
      return Container(
        color: Colors.cyan.withOpacity(0.05),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                color: Colors.cyan.withOpacity(0.3),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                '暂无模型',
                style: TextStyle(
                  color: Colors.cyan.withOpacity(0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
