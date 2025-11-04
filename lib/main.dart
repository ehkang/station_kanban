import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'page/dashboard_page.dart';

/// 应用入口
/// 配置 1920x1080 全屏显示
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      // 可选：全屏模式
      // await windowManager.setFullScreen(true);
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
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00d4ff),
          secondary: const Color(0xFF0099ff),
          surface: const Color(0xFF1a1f3a),
          background: const Color(0xFF0a0e27),
        ),
        fontFamily: 'sans-serif',
      ),
      home: const DashboardPage(),
    );
  }
}