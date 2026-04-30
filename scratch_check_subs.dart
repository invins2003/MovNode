import 'package:media_kit/media_kit.dart';

void main() {
  final track = SubtitleTrack.data('WEBVTT\n\n1\n00:00:00.000 --> 00:00:05.000\nHello World');
  print(track.title);
}
