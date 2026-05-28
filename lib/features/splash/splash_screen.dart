import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  Timer? _fallbackTimer;
  bool _ready = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goNext());
      return;
    }
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    final controller = VideoPlayerController.asset('assets/videos/splash.mp4');
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);
      controller.addListener(_handleVideoProgress);
      if (mounted) setState(() => _ready = true);
      await controller.play();
      _fallbackTimer = Timer(const Duration(seconds: 5), _goNext);
    } catch (_) {
      _fallbackTimer = Timer(const Duration(milliseconds: 900), _goNext);
    }
  }

  void _handleVideoProgress() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.position >= controller.value.duration) {
      _goNext();
    }
  }

  void _goNext() {
    if (!mounted || _navigated) return;
    _navigated = true;
    context.go('/home');
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller?.removeListener(_handleVideoProgress);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: const Color(0xFF061A36),
      body: Center(
        child: _ready && controller != null
            ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              )
            : const Icon(
                Icons.sports_soccer,
                size: 72,
                color: Color(0xFF63E8FF),
              ),
      ),
    );
  }
}
