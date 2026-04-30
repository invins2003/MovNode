import 'rive_client.dart';

void main() async {
  print('Testing RiveClient with TMDB ID 673 (Harry Potter 3)...');
  
  final streams = await RiveClient.getStreams(
    tmdbId: '673',
    title: 'Harry Potter 3',
    mediaType: 'movie'
  );

  print('\n=== RESULTS ===');
  if (streams.isEmpty) {
    print('No streams found!');
  } else {
    print('Found ${streams.length} streams:');
    for (var stream in streams) {
      print('- ${stream.name}: ${stream.url.substring(0, stream.url.length > 50 ? 50 : stream.url.length)}...');
    }
  }
}
