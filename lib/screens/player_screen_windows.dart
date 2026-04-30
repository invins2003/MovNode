import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:http/http.dart' as http;
import '../api/stream_model.dart';
import '../ui/cyber_theme.dart';

class PlayerScreenWindows extends StatefulWidget {
  final String itemTitle;
  final List<VideasyStream> streams;
  final int initialStreamIndex;
  final String? tmdbId;
  final bool isTv;
  final int? season;
  final int? episode;

  const PlayerScreenWindows({
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
  State<PlayerScreenWindows> createState() => _PlayerScreenWindowsState();
}

class _PlayerScreenWindowsState extends State<PlayerScreenWindows> {
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
    print('DEBUG: PlayerScreenWindows playing: ${stream.url}');
    
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

    // Open the video stream
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
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handlePlaybackError() async {
    if (_currentIndex < widget.streams.length - 1) {
      print('DEBUG: Playback failed, trying next stream...');
      if (mounted) {
        setState(() {
          _currentIndex++;
          _isLoading = true;
        });
        // Show a small notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("SOURCE FAILED. SWITCHING TO ${widget.streams[_currentIndex].name}...", style: CyberTheme.monoText(size: 12)),
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
            content: Text("ALL SOURCES FAILED. PLEASE TRY ANOTHER SERVER.", style: CyberTheme.monoText(size: 12)),
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
        if (isFullscreen(context)) exitFullscreen(context);
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
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            backgroundColor: Colors.black26,
            shadows: [
              Shadow(offset: Offset(1, 1), blurRadius: 2.0, color: Colors.black),
            ],
          ),
          textAlign: TextAlign.center,
          padding: const EdgeInsets.all(40),
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
                  MaterialVideoControls(state),
                  _buildDesktopHeader(builderContext),
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

  Widget _buildDesktopHeader(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 20),
            Text(
              widget.itemTitle.toUpperCase(),
              style: CyberTheme.headerText(size: 20, color: Colors.white),
            ),
            const Spacer(),
            _buildHeaderAction(Icons.dns, "SOURCES", _showSources),
            const SizedBox(width: 20),
            _buildHeaderAction(Icons.subtitles, "SUBTITLES", () => _showTracks('subtitle')),
            const SizedBox(width: 20),
            _buildHeaderAction(Icons.audiotrack, "AUDIO", () => _showTracks('audio')),
            const SizedBox(width: 20),
            _buildHeaderAction(Icons.fullscreen, "FULLSCREEN (F)", () {
               if (isFullscreen(context)) exitFullscreen(context); else enterFullscreen(context);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: CyberTheme.hackerGreen, size: 20),
          const SizedBox(height: 4),
          Text(label, style: CyberTheme.monoText(size: 9, color: Colors.white70)),
        ],
      ),
    );
  }

  void _showSources() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CyberTheme.matrixBlack,
        title: Text("SELECT SOURCE", style: CyberTheme.headerText(size: 18, color: CyberTheme.hackerGreen)),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.streams.length,
            itemBuilder: (context, index) {
              final stream = widget.streams[index];
              return ListTile(
                selected: _currentIndex == index,
                selectedTileColor: CyberTheme.hackerGreen.withOpacity(0.1),
                title: Text(stream.name.toUpperCase(), style: CyberTheme.monoText(color: Colors.white)),
                subtitle: Text("${stream.quality} | ${stream.provider}", style: CyberTheme.monoText(color: Colors.white38, size: 10)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = index);
                  _playCurrentStream();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showTracks(String type) {
    final nativeTracks = type == 'audio' ? player.state.tracks.audio : player.state.tracks.subtitle;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CyberTheme.matrixBlack,
        title: Text("${type.toUpperCase()} TRACKS", style: CyberTheme.headerText(size: 18, color: CyberTheme.hackerGreen)),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (type == 'subtitle' && _externalSubtitles.isNotEmpty) ...[
                  Text("EXTERNAL SOURCES", style: CyberTheme.monoText(size: 10, color: CyberTheme.hackerGreen)),
                  const Divider(color: Colors.white10),
                  ..._externalSubtitles.map((sub) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.language, color: CyberTheme.hackerGreen, size: 14),
                    title: Text(sub.label.toUpperCase(), style: CyberTheme.monoText(color: Colors.white, size: 12)),
                    onTap: () {
                      print('DEBUG: Selecting external subtitle: ${sub.url}');
                      player.setSubtitleTrack(SubtitleTrack.uri(sub.url));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("LOADING ${sub.label} SUBTITLES...", style: CyberTheme.monoText()),
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
                    padding: const EdgeInsets.all(20),
                    child: Center(child: Text("NO ${type.toUpperCase()} TRACKS AVAILABLE", style: CyberTheme.monoText(color: Colors.white54))),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: nativeTracks.length,
                    itemBuilder: (context, index) {
                      final track = nativeTracks[index];
                      return ListTile(
                        dense: true,
                        title: Text(track.title ?? track.language ?? "Track ${index + 1}", style: CyberTheme.monoText(color: Colors.white)),
                        onTap: () {
                          if (type == 'audio') player.setAudioTrack(track as AudioTrack); else player.setSubtitleTrack(track as SubtitleTrack);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
