import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('--- STARTING PROPER TEST FOR FLIXHQ ---');
  
  const title = 'John Wick';
  const query = 'john-wick';
  const baseUrl = 'https://flixhq.to';
  const ajaxUrl = 'https://flixhq.to/ajax';
  const decoderUrl = 'https://dec.eatmynerds.live';
  const userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

  try {
    // 1. Test Search
    print('\n[STEP 1] Testing Search...');
    final searchRes = await http.get(Uri.parse('$baseUrl/search/$query'), headers: {'User-Agent': userAgent});
    if (searchRes.statusCode == 200 && searchRes.body.contains('flw-item')) {
      print('✅ Search Success: Found results for "$title"');
    } else {
      print('❌ Search Failed: Status ${searchRes.statusCode}');
      return;
    }

    // 2. Test Media ID (Hardcoded for testing if needed, or extracted)
    // For "John Wick (2014)", the ID is usually 17921 or similar
    // Let's try to extract it from the first search result in a real scenario
    final mediaId = '17921'; 
    print('\n[STEP 2] Using Media ID: $mediaId');

    // 3. Test Servers AJAX
    print('\n[STEP 3] Testing Servers AJAX...');
    // We need an episode ID. For movies, it's often the mediaId itself or from /movie/episodes/
    final serversRes = await http.get(Uri.parse('$ajaxUrl/episode/servers/$mediaId'), headers: {'User-Agent': userAgent});
    if (serversRes.statusCode == 200 && serversRes.body.contains('data-id')) {
      print('✅ Servers AJAX Success: Found server list');
    } else {
      print('❌ Servers AJAX Failed: Status ${serversRes.statusCode}');
      // Try movie episodes list first
      final movieEpRes = await http.get(Uri.parse('$ajaxUrl/movie/episodes/$mediaId'), headers: {'User-Agent': userAgent});
      print('DEBUG: Movie Episodes Response contains data-id: ${movieEpRes.body.contains('data-id')}');
    }

    // 4. Test Decoder with a known UpCloud/VidCloud link
    // Example link structure: https://flixhq.to/ajax/episode/sources/12345
    print('\n[STEP 4] Testing External Decoder...');
    const testEmbed = 'https://rabbitstream.net/embed-4/6Ju6uHLnJuJD?z='; // Example RabbitStream link
    final decRes = await http.get(
      Uri.parse('$decoderUrl/?url=${Uri.encodeComponent(testEmbed)}'),
      headers: {'User-Agent': 'curl/8.16.0'},
    ).timeout(const Duration(seconds: 15));

    if (decRes.statusCode == 200) {
      final data = json.decode(decRes.body);
      if (data['sources'] != null && (data['sources'] as List).isNotEmpty) {
        print('✅ Decoder Success: Found stream URL -> ${data['sources'][0]['file']}');
      } else {
        print('❌ Decoder Failed: No sources in JSON');
      }
    } else {
      print('❌ Decoder Failed: Status ${decRes.statusCode}');
    }

    print('\n--- TEST COMPLETE ---');
  } catch (e) {
    print('❌ CRITICAL ERROR DURING TEST: $e');
  }
}
