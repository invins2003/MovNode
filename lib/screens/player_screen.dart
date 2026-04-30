import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../api/stream_model.dart';
import 'player_screen_mobile.dart';
import 'player_screen_windows.dart';

class PlayerScreen extends StatelessWidget {
  final String itemTitle;
  final List<VideasyStream> streams;
  final int initialStreamIndex;
  final String? tmdbId;
  final bool isTv;
  final int? season;
  final int? episode;

  const PlayerScreen({
    Key? key,
    required this.itemTitle,
    required this.streams,
    required this.initialStreamIndex,
    this.tmdbId,
    this.isTv = false,
    this.season,
    this.episode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (isDesktop && constraints.maxWidth > 800) {
          return PlayerScreenWindows(
            itemTitle: itemTitle,
            streams: streams,
            initialStreamIndex: initialStreamIndex,
            tmdbId: tmdbId,
            isTv: isTv,
            season: season,
            episode: episode,
          );
        } else {
          return PlayerScreenMobile(
            itemTitle: itemTitle,
            streams: streams,
            initialStreamIndex: initialStreamIndex,
            tmdbId: tmdbId,
            isTv: isTv,
            season: season,
            episode: episode,
          );
        }
      },
    );
  }
}
