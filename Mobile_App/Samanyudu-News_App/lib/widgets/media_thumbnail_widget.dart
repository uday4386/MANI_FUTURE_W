import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:video_player/video_player.dart';

class MediaThumbnailWidget extends StatelessWidget {
  final Map<String, dynamic> item;
  final double height;
  final double width;
  final BoxFit fit;

  const MediaThumbnailWidget({
    super.key,
    required this.item,
    required this.height,
    this.width = double.infinity,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    bool hasLive = item['live_link'] != null && item['live_link'].toString().trim().isNotEmpty;
    bool hasVideo = item['video_url'] != null && item['video_url'].toString().trim().isNotEmpty;
    bool hasImage = item['image_url'] != null && item['image_url'].toString().trim().isNotEmpty;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallbackColor = isDark ? Colors.white10 : Colors.black12;
    final iconColor = isDark ? Colors.white24 : Colors.black38;

    Widget backgroundWidget;

    // 1. YouTube Thumbnail
    if (hasLive) {
      final String linkStr = item['live_link'].toString().trim();
      final videoId = YoutubePlayerController.convertUrlToId(
        linkStr.startsWith('http') ? linkStr : 'https://$linkStr',
      );
      if (videoId != null && videoId.isNotEmpty) {
        backgroundWidget = Image.network(
          'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (c, e, s) => Container(
            width: width,
            height: height,
            color: fallbackColor,
            child: Icon(Icons.live_tv, color: iconColor),
          ),
        );
      } else {
        backgroundWidget = Container(color: fallbackColor, width: width, height: height, child: Icon(Icons.live_tv, color: iconColor));
      }
    }
    // 2. Explicit Image
    else if (hasImage) {
      backgroundWidget = Image.network(
        ApiService.normalizeUrl(item['image_url']),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (c, e, s) {
          // If the image fails to load, and it has a video, fallback to rendering the video directly
          if (hasVideo) {
            return _UploadedVideoThumbnail(
              videoUrl: item['video_url'].toString(),
              width: width,
              height: height,
              fit: fit,
            );
          }
          return Container(
            width: width,
            height: height,
            color: fallbackColor,
            child: Icon(Icons.broken_image, color: iconColor),
          );
        },
      );
    }
    // 3. Raw Video (Attempt to play and grab first frame)
    else if (hasVideo) {
      return _UploadedVideoThumbnail(
        videoUrl: item['video_url'].toString(),
        width: width,
        height: height,
        fit: fit,
      );
    }
    // 4. Default Fallback
    else {
      return Container(
        width: width,
        height: height,
        color: fallbackColor,
        child: Icon(Icons.article, color: iconColor, size: 30),
      );
    }

    // Wrap background with play button overlay if it is a video/live stream
    if (hasLive || hasVideo) {
      return Stack(
        alignment: Alignment.center,
        fit: StackFit.passthrough,
        children: [
          backgroundWidget,
          Center(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasLive ? Icons.play_circle_fill : Icons.play_arrow,
                color: hasLive ? Colors.red : Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      );
    }

    return backgroundWidget;
  }
}

class _UploadedVideoThumbnail extends StatefulWidget {
  final String videoUrl;
  final double height;
  final double width;
  final BoxFit fit;

  const _UploadedVideoThumbnail({
    required this.videoUrl,
    required this.height,
    required this.width,
    required this.fit,
  });

  @override
  State<_UploadedVideoThumbnail> createState() =>
      _UploadedVideoThumbnailState();
}

class _UploadedVideoThumbnailState extends State<_UploadedVideoThumbnail> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(covariant _UploadedVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _initializeController();
    }
  }

  void _initializeController() {
    final normalizedUrl = ApiService.normalizeUrl(widget.videoUrl);
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(normalizedUrl),
    );
    _controller = controller;
    _initializeFuture = controller
        .initialize()
        .then((_) async {
          await controller.setVolume(0);
          await controller.pause();
          await controller.seekTo(Duration.zero);
          if (mounted) setState(() {});
        })
        .catchError((_) {
          _hasError = true;
          if (mounted) setState(() {});
        });
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    _initializeFuture = null;
    controller?.dispose();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || _controller == null || _initializeFuture == null) {
      return _buildFallback();
    }

    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.error == null &&
            _controller!.value.isInitialized) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: [
                ClipRect(
                  child: FittedBox(
                    fit: widget.fit,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
                Container(color: Colors.black26),
                Center(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return _buildFallback(isLoading: true);
      },
    );
  }

  Widget _buildFallback({bool isLoading = false}) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Faint background icon to signify video
          Icon(
            isLoading ? Icons.hourglass_bottom : Icons.music_video,
            color: Colors.white10,
            size: 80,
          ),
          // Red circular play button just like Live TV videos
          Container(
            decoration: const BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(2),
            child: Icon(
              isLoading ? Icons.hourglass_bottom : Icons.play_circle_fill,
              color: isLoading ? Colors.white54 : Colors.red,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }
}
