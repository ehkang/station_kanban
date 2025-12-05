import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'page/dashboard_page.dart';

/// 应用入口
/// 配置 1920x1080 全屏显示
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 配置开机自启动（仅 Windows 和 macOS）
  if (Platform.isWindows || Platform.isMacOS) {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    launchAtStartup.setup(
      appName: packageInfo.appName,
      appPath: Platform.resolvedExecutable,
      // Windows MSIX 打包时需要指定 packageName
      // packageName: 'com.yourcompany.wms_station_kanban',
    );

    // 启用自启动
    await launchAtStartup.enable();

    // 可选：检查是否已启用（调试用）
    // bool isEnabled = await launchAtStartup.isEnabled();
    // print('自启动状态: $isEnabled');
  }

  // ⚠️ 注意：不在这里初始化 WebviewManager
  // WebView CEF 会在第一次创建 WebViewController 时自动初始化
  // 提前初始化会导致创建额外的窗口和 OpenGL context 错误

  // 桌面平台窗口管理配置
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1920, 1080),
      minimumSize: Size(1280, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: '仓库管理系统看板',
      // Windows 真全屏关键配置（隐藏任务栏）
      fullScreen: true,    // 启用全屏模式
      alwaysOnTop: true,   // 窗口置顶（这是隐藏任务栏的关键）
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      // WindowOptions 中已设置 fullScreen，无需再次调用 setFullScreen
      // alwaysOnTop: true 确保窗口覆盖任务栏
    });
  }

  // 设置系统UI样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Color(0xFF0a0e27),
    ),
  );

  // 设置屏幕方向为横屏
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '仓库管理系统看板',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00d4ff),
        scaffoldBackgroundColor: const Color(0xFF0a0e27),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00d4ff),
          secondary: Color(0xFF0099ff),
          surface: Color(0xFF1a1f3a),
        ),
        fontFamily: 'sans-serif',
      ),
      home: const DashboardPage(),
    );
  }
}