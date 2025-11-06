import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:dio/dio.dart';
import '../utils/webview_3d_html.dart';

/// 自动旋转的3D模型查看器
///
/// 特点：
/// - 使用WebView + Three.js渲染STL模型（仅 Windows）
/// - 自动Y轴旋转（6秒一圈）
/// - 异步加载，不阻塞主界面
/// - Dart代理下载STL文件（解决CORS问题）
/// - 支持降级显示（加载失败显示默认图标）
/// - 跨平台兼容（非 Windows 平台显示占位符）
class Rotating3DViewer extends StatefulWidget {
  /// STL文件URL
  final String stlUrl;

  /// 延迟初始化时间（毫秒）
  /// 用于优化性能，避免10个WebView同时初始化
  final int initDelay;

  const Rotating3DViewer({
    super.key,
    required this.stlUrl,
    this.initDelay = 0,
  });

  @override
  State<Rotating3DViewer> createState() => _Rotating3DViewerState();
}

class _Rotating3DViewerState extends State<Rotating3DViewer> {
  WebviewController? _controller;

  // 状态管理
  bool _isInitializing = false;
  bool _isReady = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // 仅在 Windows 平台初始化 WebView
    if (!kIsWeb && !Platform.isWindows) {
      return;
    }

    // 延迟初始化（性能优化）
    if (widget.initDelay > 0) {
      Future.delayed(Duration(milliseconds: widget.initDelay), () {
        if (mounted) {
          _initWebView();
        }
      });
    } else {
      _initWebView();
    }
  }

  @override
  void dispose() {
    // 仅在 Windows 平台且 controller 已创建时释放资源
    _controller?.dispose();
    super.dispose();
  }

  /// 初始化WebView
  Future<void> _initWebView() async {
    if (_isInitializing) return;

    setState(() {
      _isInitializing = true;
      _hasError = false;
    });

    try {
      // 1. 创建并初始化WebView控制器
      _controller = WebviewController();
      await _controller!.initialize();

      // 2. 加载HTML模板
      final html = WebView3DHTML.generate();
      await _controller!.loadStringContent(html);

      // 等待HTML加载完成
      await Future.delayed(const Duration(milliseconds: 500));

      // 3. 下载STL文件并转换为Base64
      await _downloadAndLoadSTL();

      setState(() {
        _isReady = true;
      });

      print('WebView 3D初始化成功: ${widget.stlUrl}');
    } catch (e) {
      print('WebView 3D初始化失败: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  /// 下载STL文件并传递给WebView
  ///
  /// 这个方法解决了CORS跨域问题：
  /// 1. 使用Dart的Dio下载STL文件（没有浏览器CORS限制）
  /// 2. 转换为Base64字符串
  /// 3. 通过executeScript传递给WebView
  /// 4. WebView中的JS将Base64解码为Blob
  Future<void> _downloadAndLoadSTL() async {
    try {
      print('开始下载STL文件: ${widget.stlUrl}');

      // 下载STL文件（二进制数据）
      final dio = Dio();
      final response = await dio.get<List<int>>(
        widget.stlUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Accept': 'application/octet-stream, */*',
          },
        ),
      );

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('STL文件下载失败：数据为空');
      }

      print('STL文件下载成功，大小: ${response.data!.length} 字节');

      // 转换为Base64
      final base64STL = base64Encode(response.data!);

      print('Base64编码完成，长度: ${base64STL.length}');

      // 传递给WebView
      // 注意：需要转义引号，避免JS语法错误
      final escapedBase64 = base64STL.replaceAll("'", "\\'");

      await _controller?.executeScript('''
        window.postMessage({
          type: 'loadSTL',
          base64: '$escapedBase64'
        }, '*');
      ''');

      print('STL数据已传递给WebView');
    } catch (e) {
      print('STL下载或加载失败: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 平台检测：仅在 Windows 上启用 WebView
    if (!kIsWeb && !Platform.isWindows) {
      return _buildPlatformNotSupported();
    }

    // 错误状态：显示默认图标
    if (_hasError) {
      return _buildFallbackIcon();
    }

    // 加载中状态
    if (_isInitializing || !_isReady) {
      return _buildLoadingIndicator();
    }

    // 正常状态：显示WebView
    if (_controller == null) {
      return _buildFallbackIcon();
    }

    return SizedBox(
      width: 160,
      height: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Webview(
          _controller!,
          permissionRequested: (url, kind, isUserInitiated) =>
              WebviewPermissionDecision.allow,
        ),
      ),
    );
  }

  /// 加载中指示器
  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.cyan.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '加载3D模型...',
              style: TextStyle(
                color: Colors.cyan.withOpacity(0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 降级显示：默认图标
  Widget _buildFallbackIcon() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.view_in_ar,
              color: Colors.cyan.withOpacity(0.3),
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              '加载失败',
              style: TextStyle(
                color: Colors.red.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 4),
              // 显示详细错误信息（用于调试）
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  _getShortErrorMessage(),
                  style: TextStyle(
                    color: Colors.orange.withOpacity(0.7),
                    fontSize: 8,
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

  /// 获取简短的错误信息
  String _getShortErrorMessage() {
    if (_errorMessage == null) return '';

    // 提取关键错误信息
    if (_errorMessage!.contains('WebView2')) {
      return 'WebView2未安装';
    } else if (_errorMessage!.contains('network') || _errorMessage!.contains('dio')) {
      return '网络错误';
    } else if (_errorMessage!.contains('timeout')) {
      return '下载超时';
    } else if (_errorMessage!.contains('STL')) {
      return 'STL加载失败';
    } else {
      // 返回前50个字符
      return _errorMessage!.length > 50
          ? '${_errorMessage!.substring(0, 50)}...'
          : _errorMessage!;
    }
  }

  /// 平台不支持提示
  Widget _buildPlatformNotSupported() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.withOpacity(0.1),
              Colors.cyan.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.cyan.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.view_in_ar_outlined,
                color: Colors.cyan.withOpacity(0.6),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                '3D 模型预览',
                style: TextStyle(
                  color: Colors.cyan.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Windows 平台可用',
                  style: TextStyle(
                    color: Colors.cyan.withOpacity(0.5),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}