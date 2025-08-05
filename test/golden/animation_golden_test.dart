import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import '../golden_test_configuration.dart';

/// Golden tests for animations
/// Captures key frames of animations to ensure smooth transitions
void main() {
  configureGoldenTests();

  group('Animation Golden Tests', () {
    testGoldens('Page transition animation frames', (tester) async {
      final controller = PageController();

      await tester.pumpWidgetBuilder(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: PageView(
                controller: controller,
                children: [
                  ColoredBox(
                    color: Colors.blue.shade100,
                    child: const Center(
                      child: Text(
                        'Page 1',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  ColoredBox(
                    color: Colors.green.shade100,
                    child: const Center(
                      child: Text(
                        'Page 2',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Capture initial state
      await screenMatchesGolden(tester, 'page_transition_0_start');

      // Start animation
      controller.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      // Capture at 25%
      await tester.pump(const Duration(milliseconds: 75));
      await screenMatchesGolden(tester, 'page_transition_1_quarter');

      // Capture at 50%
      await tester.pump(const Duration(milliseconds: 75));
      await screenMatchesGolden(tester, 'page_transition_2_half');

      // Capture at 75%
      await tester.pump(const Duration(milliseconds: 75));
      await screenMatchesGolden(tester, 'page_transition_3_three_quarters');

      // Capture at completion
      await tester.pump(const Duration(milliseconds: 75));
      await screenMatchesGolden(tester, 'page_transition_4_complete');
    });

    testGoldens('Fade transition animation', (tester) async {
      final animationController = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: tester,
      );

      await tester.pumpWidgetBuilder(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FadeTransition(
                opacity: animationController,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text(
                      'Fading In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Capture frames at different opacity levels
      final frames = [0.0, 0.25, 0.5, 0.75, 1.0];

      for (int i = 0; i < frames.length; i++) {
        animationController.value = frames[i];
        await tester.pump();
        await screenMatchesGolden(
          tester,
          'fade_transition_${i}_${(frames[i] * 100).toInt()}percent',
        );
      }

      animationController.dispose();
    });

    testGoldens('Scale transition animation', (tester) async {
      final animationController = AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: tester,
      );

      final scaleAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animationController,
        curve: Curves.elasticOut,
      ));

      await tester.pumpWidgetBuilder(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ScaleTransition(
                scale: scaleAnimation,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.restaurant_menu,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Capture elastic animation frames
      final times = [0, 100, 200, 300, 400];

      for (int i = 0; i < times.length; i++) {
        animationController.value = times[i] / 400;
        await tester.pump();
        await screenMatchesGolden(
          tester,
          'scale_transition_elastic_${i}_${times[i]}ms',
        );
      }

      animationController.dispose();
    });

    testGoldens('Slide transition animation', (tester) async {
      final animationController = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: tester,
      );

      final slideAnimation = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animationController,
        curve: Curves.easeOutCubic,
      ));

      await tester.pumpWidgetBuilder(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SlideTransition(
                position: slideAnimation,
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    'Sliding in from right',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Capture slide animation frames
      final positions = [0.0, 0.25, 0.5, 0.75, 1.0];

      for (int i = 0; i < positions.length; i++) {
        animationController.value = positions[i];
        await tester.pump();
        await screenMatchesGolden(
          tester,
          'slide_transition_${i}_${(positions[i] * 100).toInt()}percent',
        );
      }

      animationController.dispose();
    });

    testGoldens('Hero animation frames', (tester) async {
      const heroTag = 'recipe-hero';

      await tester.pumpWidgetBuilder(
        const MaterialApp(
          home: _HeroAnimationExample(heroTag: heroTag),
        ),
      );

      // Initial state
      await screenMatchesGolden(tester, 'hero_animation_0_start');

      // Tap to trigger hero animation
      await tester.tap(find.byKey(const Key('hero-trigger')));

      // Capture hero animation frames
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 50));
      await screenMatchesGolden(tester, 'hero_animation_1_early');

      await tester.pump(const Duration(milliseconds: 100));
      await screenMatchesGolden(tester, 'hero_animation_2_middle');

      await tester.pump(const Duration(milliseconds: 100));
      await screenMatchesGolden(tester, 'hero_animation_3_late');

      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'hero_animation_4_complete');
    });

    testGoldens('AnimatedContainer property changes', (tester) async {
      bool expanded = false;

      await tester.pumpWidgetBuilder(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: expanded ? 300 : 150,
                        height: expanded ? 200 : 150,
                        decoration: BoxDecoration(
                          color: expanded ? Colors.blue : Colors.red,
                          borderRadius:
                              BorderRadius.circular(expanded ? 30 : 10),
                        ),
                        child: Center(
                          child: Text(
                            expanded ? 'Expanded' : 'Collapsed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            expanded = !expanded;
                          });
                        },
                        child: const Text('Toggle'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initial state
      await screenMatchesGolden(tester, 'animated_container_0_collapsed');

      // Trigger animation
      await tester.tap(find.text('Toggle'));

      // Capture intermediate frames
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 75));
      await screenMatchesGolden(tester, 'animated_container_1_expanding');

      await tester.pump(const Duration(milliseconds: 75));
      await screenMatchesGolden(tester, 'animated_container_2_halfway');

      await tester.pump(const Duration(milliseconds: 75));
      await screenMatchesGolden(tester, 'animated_container_3_nearly_done');

      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'animated_container_4_expanded');
    });

    testGoldens('Staggered animation sequence', (tester) async {
      await tester.pumpWidgetBuilder(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: _StaggeredAnimationExample(),
            ),
          ),
        ),
      );

      // Let the staggered animation play out
      await screenMatchesGolden(tester, 'staggered_animation_0_start');

      await tester.pump(const Duration(milliseconds: 100));
      await screenMatchesGolden(tester, 'staggered_animation_1_first_item');

      await tester.pump(const Duration(milliseconds: 100));
      await screenMatchesGolden(tester, 'staggered_animation_2_second_item');

      await tester.pump(const Duration(milliseconds: 100));
      await screenMatchesGolden(tester, 'staggered_animation_3_third_item');

      await tester.pump(const Duration(milliseconds: 100));
      await screenMatchesGolden(tester, 'staggered_animation_4_all_items');
    });

    testGoldens('Loading shimmer animation', (tester) async {
      await tester.pumpWidgetBuilder(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _ShimmerLoading(width: double.infinity, height: 200),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      _ShimmerLoading(width: 60, height: 60, isCircle: true),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ShimmerLoading(width: 150, height: 20),
                            SizedBox(height: 8),
                            _ShimmerLoading(width: 100, height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Capture shimmer at different positions
      for (int i = 0; i < 5; i++) {
        await tester.pump(Duration(milliseconds: i * 200));
        await screenMatchesGolden(
          tester,
          'shimmer_loading_${i}_${i * 200}ms',
        );
      }
    });

    testGoldens('Rotation animation', (tester) async {
      final animationController = AnimationController(
        duration: const Duration(seconds: 1),
        vsync: tester,
      );

      await tester.pumpWidgetBuilder(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RotationTransition(
                turns: animationController,
                child: Container(
                  width: 100,
                  height: 100,
                  color: Colors.teal,
                  child: const Icon(
                    Icons.refresh,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Capture rotation at different angles
      final rotations = [0.0, 0.25, 0.5, 0.75, 1.0];

      for (int i = 0; i < rotations.length; i++) {
        animationController.value = rotations[i];
        await tester.pump();
        await screenMatchesGolden(
          tester,
          'rotation_animation_${i}_${(rotations[i] * 360).toInt()}deg',
        );
      }

      animationController.dispose();
    });

    testGoldens('Custom painter animation', (tester) async {
      final animationController = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: tester,
      );

      await tester.pumpWidgetBuilder(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedBuilder(
                animation: animationController,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(300, 300),
                    painter: _CircularProgressPainter(
                      progress: animationController.value,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Capture custom painter animation frames
      final progressValues = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];

      for (int i = 0; i < progressValues.length; i++) {
        animationController.value = progressValues[i];
        await tester.pump();
        await screenMatchesGolden(
          tester,
          'custom_painter_progress_${i}_${(progressValues[i] * 100).toInt()}percent',
        );
      }

      animationController.dispose();
    });
  });
}

// Helper widgets for animation testing

class _HeroAnimationExample extends StatelessWidget {
  final String heroTag;

  const _HeroAnimationExample({required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: GestureDetector(
          key: const Key('hero-trigger'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _HeroDetailPage(heroTag: heroTag),
              ),
            );
          },
          child: Hero(
            tag: heroTag,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.restaurant,
                size: 50,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroDetailPage extends StatelessWidget {
  final String heroTag;

  const _HeroDetailPage({required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recipe Details')),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.restaurant,
              size: 150,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _StaggeredAnimationExample extends StatefulWidget {
  @override
  State<_StaggeredAnimationExample> createState() =>
      _StaggeredAnimationExampleState();
}

class _StaggeredAnimationExampleState extends State<_StaggeredAnimationExample>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(
      4,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutBack,
      );
    }).toList();

    // Start animations with stagger
    _startStaggeredAnimation();
  }

  Future<void> _startStaggeredAnimation() async {
    for (int i = 0; i < _controllers.length; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      _controllers[i].forward();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        4,
        (index) => ScaleTransition(
          scale: _animations[index],
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.primaries[index * 4],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final bool isCircle;

  const _ShimmerLoading({
    required this.width,
    required this.height,
    this.isCircle = false,
  });

  @override
  State<_ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<_ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.isCircle ? null : BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2 * _shimmerController.value, 0),
              end: Alignment(-0.5 + 2 * _shimmerController.value, 0),
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;

  _CircularProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Background circle
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * 3.14159 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      sweepAngle,
      false,
      progressPaint,
    );

    // Center text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${(progress * 100).toInt()}%',
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
