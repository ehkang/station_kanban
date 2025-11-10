import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_cef/webview_cef.dart';
import 'package:dio/dio.dart';
import '../utils/webview_3d_html.dart';

/// 自动旋转的3D模型查看器
///
/// 使用 webview_cef（CEF）渲染 STL 模型
/// 支持：Windows / Linux / macOS
class Rotating3DViewer extends StatefulWidget {
  final String stlUrl;
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
  late WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    // 创建 WebView controller
    _controller = WebviewManager().createWebView(
      loading: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );

    if (widget.initDelay > 0) {
      Future.delayed(Duration(milliseconds: widget.initDelay), _init);
    } else {
      _init();
    }
  }

  Future<void> _init() async {
    try {
      // 生成 HTML
      final html = WebView3DHTML.generate();
      final dataUrl = 'data:text/html;base64,${base64Encode(utf8.encode(html))}';

      // 初始化 WebView
      await _controller.initialize(dataUrl);

      // 等待页面加载
      await Future.delayed(const Duration(milliseconds: 1000));

      // 加载 STL
      await _loadSTL();
    } catch (e) {
      print('❌ 初始化失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _loadSTL() async {
    try {
      print('📥 下载STL: ${widget.stlUrl}');

      final dio = Dio();
      final response = await dio.get<List<int>>(
        widget.stlUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('STL为空');
      }

      print('✅ 下载: ${response.data!.length}字节');

      final base64STL = base64Encode(response.data!);

      // 执行 JavaScript
      await _controller.executeJavaScript('''
        window.postMessage({
          type: 'loadSTL',
          base64: '$base64STL'
        }, '*');
      ''');

      print('✅ 加载完成');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ 加载失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ValueListenableBuilder<bool>(
          valueListenable: _controller,
          builder: (context, initialized, child) {
            if (!initialized) {
              // WebView 未初始化
              return Container(
                color: Colors.cyan.withOpacity(0.05),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            return Stack(
              children: [
                // WebView
                _controller.webviewWidget,

                // 加载中遮罩
                if (_isLoading)
                  Container(
                    color: Colors.cyan.withOpacity(0.05),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),

                // 错误遮罩
                if (_hasError)
                  Container(
                    color: Colors.cyan.withOpacity(0.05),
                    child: Center(
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.red.withOpacity(0.6),
                        size: 48,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
