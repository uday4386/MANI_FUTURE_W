import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';

class AdDialogWidget extends StatefulWidget {
  final Map<String, dynamic> ad;

  const AdDialogWidget({super.key, required this.ad});

  @override
  State<AdDialogWidget> createState() => _AdDialogWidgetState();
}

class _AdDialogWidgetState extends State<AdDialogWidget> {
  VideoPlayerController? _videoController;
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();
    final url = widget.ad['media_url'] as String?;
    if (url != null && (url.toLowerCase().endsWith('.mp4') || url.toLowerCase().endsWith('.webm') || url.toLowerCase().endsWith('.ogg'))) {
      _isVideo = true;
      final normalizedUrl = ApiService.normalizeUrl(url);
      _videoController = VideoPlayerController.networkUrl(Uri.parse(normalizedUrl))
        ..initialize().then((_) {
          _videoController!.setLooping(true);
          _videoController!.play();
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _handleTap() async {
    final clickUrl = widget.ad['click_url'] as String?;
    if (clickUrl != null && clickUrl.isNotEmpty) {
      final uri = Uri.parse(clickUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
    // Optionally close the ad after clicking
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mediaUrl = ApiService.normalizeUrl(widget.ad['media_url'] as String?);
    if (mediaUrl == null) return const SizedBox.shrink();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          GestureDetector(
            onTap: _handleTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.black,
                constraints: const BoxConstraints(
                  maxHeight: 500,
                  maxWidth: 400,
                ),
                child: _isVideo && _videoController != null
                    ? _videoController!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                        : const Center(child: CircularProgressIndicator(color: Colors.amber))
                    : Image.network(
                        mediaUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 50)),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator(color: Colors.amber));
                        },
                      ),
              ),
            ),
          ),
          // Close button
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          // "ADVERTISEMENT" badge
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'AD',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
