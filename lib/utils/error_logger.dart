import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

/// 错误日志记录器
///
/// 将错误信息详细记录到 error.log 文件中
/// 日志位置：程序可执行文件所在目录
/// - Windows: {程序目录}\error.log
/// - Linux: {程序目录}/error.log
class ErrorLogger {
  static final ErrorLogger _instance = ErrorLogger._internal();
  factory ErrorLogger() => _instance;
  ErrorLogger._internal();

  static const String _logFileName = 'error.log';
  static const int _maxLogSize = 5 * 1024 * 1024; // 5MB

  File? _logFile;
  bool _initialized = false;

  /// 初始化日志文件
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 获取可执行文件所在目录
      final executablePath = Platform.resolvedExecutable;
      final executableDir = path.dirname(executablePath);
      _logFile = File(path.join(executableDir, _logFileName));

      // 如果日志文件过大，进行轮转（重命名旧文件）
      if (await _logFile!.exists()) {
        final fileSize = await _logFile!.length();
        if (fileSize > _maxLogSize) {
          await _rotateLog();
        }
      }

      _initialized = true;

      // 写入启动日志
      await _writeLog('='.padRight(80, '='));
      await _writeLog('应用启动 - ${DateTime.now()}');
      await _writeLog('平台: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
      await _writeLog('Dart 版本: ${Platform.version}');
      await _writeLog('日志文件: ${_logFile!.path}');
      await _writeLog('='.padRight(80, '='));
    } catch (e) {
      print('❌ 错误日志初始化失败: $e');
    }
  }

  /// 记录 3D 模型加载错误
  Future<void> log3DModelError({
    required String modelUrl,
    required String errorMessage,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalInfo,
  }) async {
    await _ensureInitialized();

    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final buffer = StringBuffer();

    buffer.writeln();
    buffer.writeln('━'.padRight(80, '━'));
    buffer.writeln('🔴 3D 模型加载错误');
    buffer.writeln('时间: $timestamp');
    buffer.writeln('模型URL: $modelUrl');
    buffer.writeln('错误信息: $errorMessage');

    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      buffer.writeln('附加信息:');
      additionalInfo.forEach((key, value) {
        buffer.writeln('  - $key: $value');
      });
    }

    if (stackTrace != null) {
      buffer.writeln('堆栈跟踪:');
      buffer.writeln(stackTrace.toString());
    }

    buffer.writeln('━'.padRight(80, '━'));

    await _writeLog(buffer.toString());
  }

  /// 记录网络请求错误
  Future<void> logNetworkError({
    required String url,
    required String errorMessage,
    int? statusCode,
    Map<String, dynamic>? responseData,
  }) async {
    await _ensureInitialized();

    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final buffer = StringBuffer();

    buffer.writeln();
    buffer.writeln('━'.padRight(80, '━'));
    buffer.writeln('🌐 网络请求错误');
    buffer.writeln('时间: $timestamp');
    buffer.writeln('URL: $url');
    buffer.writeln('状态码: ${statusCode ?? '未知'}');
    buffer.writeln('错误信息: $errorMessage');

    if (responseData != null && responseData.isNotEmpty) {
      buffer.writeln('响应数据:');
      responseData.forEach((key, value) {
        buffer.writeln('  - $key: $value');
      });
    }

    buffer.writeln('━'.padRight(80, '━'));

    await _writeLog(buffer.toString());
  }

  /// 记录 OpenGL 兼容性错误
  Future<void> logOpenGLError({
    required String errorMessage,
    Map<String, dynamic>? systemInfo,
  }) async {
    await _ensureInitialized();

    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final buffer = StringBuffer();

    buffer.writeln();
    buffer.writeln('━'.padRight(80, '━'));
    buffer.writeln('🎮 OpenGL 渲染错误');
    buffer.writeln('时间: $timestamp');
    buffer.writeln('错误信息: $errorMessage');

    if (systemInfo != null && systemInfo.isNotEmpty) {
      buffer.writeln('系统信息:');
      systemInfo.forEach((key, value) {
        buffer.writeln('  - $key: $value');
      });
    }

    buffer.writeln('━'.padRight(80, '━'));

    await _writeLog(buffer.toString());
  }

  /// 记录通用错误
  Future<void> logError({
    required String category,
    required String message,
    StackTrace? stackTrace,
    Map<String, dynamic>? details,
  }) async {
    await _ensureInitialized();

    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final buffer = StringBuffer();

    buffer.writeln();
    buffer.writeln('━'.padRight(80, '━'));
    buffer.writeln('❌ 错误 [$category]');
    buffer.writeln('时间: $timestamp');
    buffer.writeln('信息: $message');

    if (details != null && details.isNotEmpty) {
      buffer.writeln('详细信息:');
      details.forEach((key, value) {
        buffer.writeln('  - $key: $value');
      });
    }

    if (stackTrace != null) {
      buffer.writeln('堆栈跟踪:');
      buffer.writeln(stackTrace.toString());
    }

    buffer.writeln('━'.padRight(80, '━'));

    await _writeLog(buffer.toString());
  }

  /// 写入日志
  Future<void> _writeLog(String message) async {
    if (_logFile == null) return;

    try {
      await _logFile!.writeAsString(
        message + '\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      print('❌ 写入日志失败: $e');
    }
  }

  /// 确保已初始化
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// 日志轮转（重命名旧文件）
  Future<void> _rotateLog() async {
    if (_logFile == null) return;

    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupPath = _logFile!.path.replaceAll('.log', '_$timestamp.log');
      await _logFile!.rename(backupPath);

      // 创建新的空日志文件
      _logFile = File(_logFile!.path);
    } catch (e) {
      print('❌ 日志轮转失败: $e');
    }
  }

  /// 获取日志文件路径（用于调试）
  String? get logFilePath => _logFile?.path;

  /// 清空日志文件
  Future<void> clearLog() async {
    await _ensureInitialized();

    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('');
        await _writeLog('日志已清空 - ${DateTime.now()}');
      }
    } catch (e) {
      print('❌ 清空日志失败: $e');
    }
  }
}
