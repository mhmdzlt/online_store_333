import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraImageSearchScreen extends StatefulWidget {
  const CameraImageSearchScreen({super.key});

  static Future<XFile?> open(BuildContext context) {
    return Navigator.of(context).push<XFile?>(
      MaterialPageRoute(builder: (_) => const CameraImageSearchScreen()),
    );
  }

  @override
  State<CameraImageSearchScreen> createState() =>
      _CameraImageSearchScreenState();
}

class _CameraImageSearchScreenState extends State<CameraImageSearchScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  List<CameraDescription> _cameras = const [];
  CameraController? _controller;

  bool _initializing = true;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initCamera());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera([CameraDescription? preferred]) async {
    setState(() => _initializing = true);

    try {
      final cameras = await availableCameras();
      if (!mounted) return;

      _cameras = cameras;

      final selected = preferred ?? _pickDefaultCamera(cameras);
      if (selected == null) {
        setState(() => _initializing = false);
        return;
      }

      await _controller?.dispose();

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _controller = controller;
      await controller.initialize();

      if (!mounted) return;
      setState(() => _initializing = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _initializing = false);
    }
  }

  CameraDescription? _pickDefaultCamera(List<CameraDescription> cameras) {
    if (cameras.isEmpty) return null;

    final back =
        cameras.where((c) => c.lensDirection == CameraLensDirection.back);
    if (back.isNotEmpty) return back.first;

    return cameras.first;
  }

  Future<void> _switchCamera() async {
    final controller = _controller;
    if (controller == null || _cameras.length < 2) return;

    final current = controller.description;
    final idx = _cameras.indexWhere(
      (c) => c.name == current.name && c.lensDirection == current.lensDirection,
    );

    final nextIndex = idx == -1 ? 0 : (idx + 1) % _cameras.length;
    await _initCamera(_cameras[nextIndex]);
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_capturing) return;

    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop<XFile>(file);
    } catch (_) {
      if (!mounted) return;
      setState(() => _capturing = false);
    }
  }

  Future<void> _pickFromAlbum() async {
    if (_capturing) return;

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    Navigator.of(context).pop<XFile>(picked);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildPreview(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    color: Colors.white,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _switchCamera,
                    icon: const Icon(Icons.cameraswitch_outlined),
                    color: Colors.white,
                  ),
                  IconButton(
                    onPressed: null,
                    icon: const Icon(Icons.help_outline),
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Text(
                    'Take a photo to search items',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        const Spacer(),
                        _CaptureButton(
                          isBusy: _capturing,
                          onPressed: _takePicture,
                        ),
                        const SizedBox(width: 16),
                        _RoundIconLabelButton(
                          icon: Icons.history,
                          label: 'History',
                          onPressed: null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: InkWell(
                      onTap: _pickFromAlbum,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Pick from album',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.keyboard_arrow_up,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_initializing) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Camera unavailable',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return CameraPreview(controller);
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.isBusy,
    required this.onPressed,
  });

  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Capture',
      child: InkResponse(
        onTap: isBusy ? null : onPressed,
        radius: 44,
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 4,
            ),
          ),
          child: Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: isBusy
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.black,
                      size: 26,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconLabelButton extends StatelessWidget {
  const _RoundIconLabelButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.6 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkResponse(
            onTap: onPressed,
            radius: 28,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                color: Colors.black38,
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
