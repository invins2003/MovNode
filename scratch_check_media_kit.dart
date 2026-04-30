import 'package:media_kit/media_kit.dart';

void main() {
  final track = SubtitleTrack('id', 'title', 'lang');
  print(track.id);
  print(track.title);
  print(track.language);
  // print(track.uri); // Check if this exists
}
