import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:http/http.dart' as http;
import '../api/stream_model.dart';
import '../ui/cyber_theme.dart';

class PlayerScreenMobile extends StatefulWidget {
  final String itemTitle;
  final List<VideasyStream> streams;
  final int initialStreamIndex;
  final String? tmdbId;
  final bool isTv;
  final int? season;
  final int? episode;

  const PlayerScreenMobile({
    super.key,
    required this.itemTitle,
    required this.streams,
    required this.initialStreamIndex,
    this.tmdbId,
    this.isTv = false,
    this.season,
    this.episode,
  });

  @override
  State<PlayerScreenMobile> createState() => _PlayerScreenMobileState();
}

class _PlayerScreenMobileState extends State<PlayerScreenMobile> {
  late final player = Player();
  late final controller = VideoController(player);
  final FocusNode _focusNode = FocusNode();
  
  bool _isLoading = true;
  late int _currentIndex;
  StreamSubscription? _errorSubscription;
  List<SubtitleSource> _externalSubtitles = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialStreamIndex;
    _focusNode.requestFocus();
    _fetchExtraSubtitles();
    _playCurrentStream();
  }

  Future<void> _fetchExtraSubtitles() async {
    // Aggregate all unique subtitles from ALL available streams (already fetched by scraper)
    final seen = <String>{};
    final all = <SubtitleSource>[];
    for (final stream in widget.streams) {
      if (stream.subtitles != null) {
        for (final sub in stream.subtitles!) {
          if (seen.add(sub.url)) all.add(sub);
        }
      }
    }
    print('DEBUG: Found ${all.length} subtitles from stream data');
    if (mounted && all.isNotEmpty) {
      setState(() => _externalSubtitles = all);
    }
  }

  Future<void> _playCurrentStream() async {
    setState(() => _isLoading = true);
    
    final stream = widget.streams[_currentIndex];
    print('DEBUG: PlayerScreen playing: ${stream.url}');
    
    await _errorSubscription?.cancel();
    _errorSubscription = player.stream.error.listen((error) {
      final errStr = error.toString();
      // CRITICAL: Ignore subtitle/caption load failures — they must NOT trigger stream fallback
      final isSubtitleError = errStr.contains('.srt') ||
          errStr.contains('.vtt') ||
          errStr.contains('subtitle') ||
          errStr.contains('captions') ||
          errStr.contains('Can not open external file');
      if (isSubtitleError) {
        print('DEBUG: Subtitle load failed (ignoring): $errStr');
        return;
      }
      print('DEBUG: MEDIA_KIT ERROR -> $errStr');
      _handlePlaybackError();
    });

    await player.open(Media(stream.url, httpHeaders: stream.headers));

    // Auto-select embedded English subtitle after video loads (subtitle errors are safe to ignore)
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      final subs = player.state.tracks.subtitle;
      for (var s in subs) {
        final title = s.title?.toLowerCase() ?? '';
        final lang = s.language?.toLowerCase() ?? '';
        if (title.contains('english') || lang.contains('en')) {
          player.setSubtitleTrack(s);
          break;
        }
      }
    });

    await player.play();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _switchStream(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
    _playCurrentStream();
  }

  void _showSourcesSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: CyberTheme.matrixBlack,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "AVAILABLE SOURCES",
                  style: CyberTheme.headerText(color: CyberTheme.hackerGreen, size: 18),
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.streams.length,
                  itemBuilder: (context, index) {
                    final stream = widget.streams[index];
                    final isSelected = _currentIndex == index;
                    return ListTile(
                      leading: Icon(Icons.dns, color: isSelected ? CyberTheme.hackerGreen : Colors.white54),
                      title: Text(
                        stream.name.toUpperCase(),
                        style: CyberTheme.monoText(
                          color: isSelected ? CyberTheme.hackerGreen : Colors.white,
                          size: 14,
                        ),
                      ),
                      subtitle: Text(
                        "QUALITY: ${stream.quality} | PROVIDER: ${stream.provider.toUpperCase()}",
                        style: CyberTheme.monoText(color: Colors.white38, size: 10),
                      ),
                      trailing: isSelected ? const Icon(Icons.check, color: CyberTheme.hackerGreen) : null,
                      onTap: () {
                        Navigator.pop(context);
                        _switchStream(index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTrackSelection(String type) {
    final nativeTracks = type == 'audio' ? player.state.tracks.audio : player.state.tracks.subtitle;
    final currentNative = type == 'audio' ? player.state.track.audio : player.state.track.subtitle;

    showModalBottomSheet(
      context: context,
      backgroundColor: CyberTheme.matrixBlack,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${type.toUpperCase()} TRACKS",
                style: CyberTheme.headerText(color: CyberTheme.hackerGreen, size: 18),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (type == 'subtitle' && _externalSubtitles.isNotEmpty) ...[
                        Text("EXTERNAL SOURCES", style: CyberTheme.monoText(size: 10, color: CyberTheme.hackerGreen)),
                        const Divider(color: Colors.white10),
                        ..._externalSubtitles.map((sub) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.language, color: CyberTheme.hackerGreen, size: 14),
                          title: Text(sub.label.toUpperCase(), style: CyberTheme.monoText(color: Colors.white, size: 12)),
                          onTap: () {
                            player.setSubtitleTrack(SubtitleTrack.uri(sub.url));
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("LOADING ${sub.label} SUBTITLES...", style: CyberTheme.monoText(size: 10)),
                                backgroundColor: CyberTheme.matrixDarkGray,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        )),
                        const SizedBox(height: 15),
                        Text("EMBEDDED TRACKS", style: CyberTheme.monoText(size: 10, color: CyberTheme.hackerGreen)),
                        const Divider(color: Colors.white10),
                      ],
                      if (nativeTracks.isEmpty && (type != 'subtitle' || _externalSubtitles.isEmpty))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text("NO ${type.toUpperCase()} TRACKS AVAILABLE", style: CyberTheme.monoText(color: Colors.white54, size: 12))),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: nativeTracks.length,
                          itemBuilder: (context, index) {
                            final track = nativeTracks[index];
                            final isSelected = track == currentNative;
                            return ListTile(
                              dense: true,
                              title: Text(
                                track.title ?? track.language ?? "Track ${index + 1}",
                                style: CyberTheme.monoText(color: isSelected ? CyberTheme.hackerGreen : Colors.white),
                              ),
                              trailing: isSelected ? const Icon(Icons.check, color: CyberTheme.hackerGreen) : null,
                              onTap: () {
                                if (type == 'audio') {
                                  player.setAudioTrack(track as AudioTrack);
                                } else {
                                  player.setSubtitleTrack(track as SubtitleTrack);
                                }
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handlePlaybackError() async {
    if (_currentIndex < widget.streams.length - 1) {
      print('DEBUG: Playback failed, trying next stream...');
      if (mounted) {
        setState(() {
          _currentIndex++;
          _isLoading = true;
        });
        // Show notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("SOURCE FAILED. TRYING NEXT...", style: CyberTheme.monoText(size: 12)),
            backgroundColor: Colors.redAccent.withOpacity(0.8),
            duration: const Duration(seconds: 2),
          ),
        );
        _playCurrentStream();
      }
    } else {
      print('DEBUG: All streams failed.');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("ALL SOURCES FAILED.", style: CyberTheme.monoText(size: 12)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleKeyEvent(KeyEvent event, BuildContext context) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        player.playOrPause();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        player.seek(player.state.position + const Duration(seconds: 10));
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        player.seek(player.state.position - const Duration(seconds: 10));
      } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
        if (isFullscreen(context)) {
          exitFullscreen(context);
        } else {
          enterFullscreen(context);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (isFullscreen(context)) {
          exitFullscreen(context);
        }
      }
    }
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    player.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Video(
        controller: controller,
        subtitleViewConfiguration: SubtitleViewConfiguration(
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            backgroundColor: Colors.black26,
            shadows: [
              Shadow(offset: Offset(1, 1), blurRadius: 2.0, color: Colors.black),
            ],
          ),
          textAlign: TextAlign.center,
          padding: const EdgeInsets.all(24),
        ),
        controls: (state) => Builder(
          builder: (builderContext) => KeyboardListener(
            focusNode: _focusNode,
            onKeyEvent: (event) => _handleKeyEvent(event, builderContext),
            child: Theme(
              data: ThemeData.dark().copyWith(
                primaryColor: CyberTheme.hackerGreen,
                colorScheme: const ColorScheme.dark(primary: CyberTheme.hackerGreen),
              ),
              child: Stack(
                children: [
                  GestureDetector(
                    onVerticalDragUpdate: (details) {
                      final delta = details.primaryDelta ?? 0;
                      if (details.localPosition.dx < MediaQuery.of(context).size.width / 2) {
                        // Left side: Brightness
                      } else {
                        // Right side: Volume
                        final current = player.state.volume;
                        final next = (current - delta / 2).clamp(0.0, 100.0);
                        player.setVolume(next);
                      }
                    },
                    child: MaterialVideoControls(state),
                  ),
                  // Top Overlays
                  _buildTopOverlays(builderContext),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: CyberTheme.hackerGreen)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopOverlays(BuildContext context) {
    return Stack(
      children: [
        // Top Left Close Button & Title
        Positioned(
          top: 40,
          left: 20,
          child: Row(
            children: [
              _buildPlayerAction(Icons.arrow_back, () => Navigator.pop(context)),
              const SizedBox(width: 15),
              Text(
                widget.itemTitle,
                style: CyberTheme.monoText(color: Colors.white, size: 16, weight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Top Right Overlays (Sources, Subtitles, Audio, Speed)
        Positioned(
          top: 40,
          right: 20,
          child: Row(
            children: [
              _buildPlayerAction(Icons.dns, _showSourcesSelection),
              const SizedBox(width: 15),
              _buildPlayerAction(Icons.subtitles, () => _showTrackSelection('subtitle')),
              const SizedBox(width: 15),
              _buildPlayerAction(Icons.audiotrack, () => _showTrackSelection('audio')),
              const SizedBox(width: 15),
              _buildPlayerAction(Icons.speed, () {
                final speeds = [0.5, 1.0, 1.25, 1.5, 2.0];
                final current = player.state.rate;
                final next = speeds[(speeds.indexOf(current) + 1) % speeds.length];
                player.setRate(next);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("SPEED SET TO ${next}X", style: CyberTheme.monoText()),
                    backgroundColor: CyberTheme.matrixDarkGray,
                    duration: const Duration(seconds: 1),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerAction(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: CyberTheme.hackerGreen.withOpacity(0.3)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onTap,
      ),
    );
  }
}
