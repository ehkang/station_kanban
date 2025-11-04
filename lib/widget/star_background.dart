import 'dart:math';
import 'package:flutter/material.dart';

/// 星空背景动画
/// 对应 Vue 项目中的背景效果
class StarBackground extends StatefulWidget {
  const StarBackground({super.key});

  @override
  State<StarBackground> createState() => _StarBackgroundState();
}

class _StarBackgroundState extends State<StarBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Star> _stars = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // 生成 100 个星星
    for (int i = 0; i < 100; i++) {
      _stars.add(Star(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 2 + 1,
        speed: _random.nextDouble() * 0.5 + 0.2,
        opacity: _random.nextDouble() * 0.5 + 0.3,
      ));
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: StarPainter(_stars, _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

/// 星星数据
class Star {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

/// 星空绘制器
class StarPainter extends CustomPainter {
  final List<Star> stars;
  final double progress;

  StarPainter(this.stars, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final star in stars) {
      // 计算星星闪烁效果
      final twinkle = sin(progress * 2 * pi * star.speed);
      final currentOpacity = star.opacity + (twinkle * 0.3);

      paint.color = Colors.white.withOpacity(currentOpacity.clamp(0.0, 1.0));

      // 绘制星星
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );

      // 绘制星星光晕
      if (star.size > 1.5) {
        paint.color =
            Colors.cyan.withOpacity((currentOpacity * 0.3).clamp(0.0, 1.0));
        canvas.drawCircle(
          Offset(star.x * size.width, star.y * size.height),
          star.size * 1.5,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(StarPainter oldDelegate) => true;
}