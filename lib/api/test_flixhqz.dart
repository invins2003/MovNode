import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

void main() async {
  print('--- TESTING FLIXHQZ.COM EXTRACTION (SERVER 1 ONLY) ---');
  
  final title = 'The Matrix';
  final baseUrl = 'https://flixhqz.com';
  final ajaxUrl = 'https://flixhqz.com/ajax';
  final userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
  
  final decoderUrls = [
    'https://dec.eatmynerds.live',
    'https://rabbit-stream.vercel.app/api',
  ];

  try {
    // 1. Search
    print('[STEP 1] Searching for "$title"...');
    final searchUrl = '$baseUrl/search/?q=${Uri.encodeComponent(title)}';
    final searchRes = await http.get(Uri.parse(searchUrl), headers: {
      'User-Agent': userAgent,
      'Referer': baseUrl,
    });
    
    if (searchRes.statusCode != 200) {
      print('❌ Search failed with status ${searchRes.statusCode}');
      return;
    }

    final document = parse(searchRes.body);
    final results = document.querySelectorAll('div.flw-item, div.film_list-wrap div.flw-item, div.film-poster');
    print('DEBUG: Found ${results.length} result candidates.');
    
    if (results.isEmpty) {
      print('❌ No search results found in HTML');
      return;
    }
    
    final firstResult = results.first;
    
    final link = firstResult.querySelector('h2.film-name a');
    var matchedUrl = link?.attributes['href'];
    if (matchedUrl != null && !matchedUrl.startsWith('http')) {
      matchedUrl = baseUrl + (matchedUrl.startsWith('/') ? matchedUrl : '/$matchedUrl');
    }
    
    if (matchedUrl == null) {
      print('❌ Could not extract matched URL');
      return;
    }
    print('✅ Matched URL: $matchedUrl');

    // 2. Extract ID
    final pathParts = Uri.parse(matchedUrl).pathSegments.where((s) => s.isNotEmpty).toList();
    String? mediaId;
    if (pathParts.isNotEmpty) {
      final lastPart = pathParts.last;
      final idMatch = RegExp(r'-(\d+)$').firstMatch(lastPart);
      mediaId = idMatch?.group(1) ?? (RegExp(r'^\d+$').hasMatch(lastPart) ? lastPart : null);
    }
    
    if (mediaId == null) {
      print('❌ Could not extract Media ID');
      return;
    }
    print('✅ Media ID: $mediaId');

    // 3. Get Episode/Movie ID for Servers
    // For movies, we usually check /ajax/movie/episodes/[id]
    print('[STEP 2] Fetching movie episodes/servers info...');
    final movieEpRes = await http.get(Uri.parse('$ajaxUrl/movie/episodes/$mediaId'), headers: {'User-Agent': userAgent});
    final movieEpDoc = parse(movieEpRes.body);
    final firstEp = movieEpDoc.querySelector('.nav-item a, a.eps-item');
    final targetId = firstEp?.attributes['data-id'] ?? firstEp?.attributes['data-linkid'] ?? mediaId;
    print('✅ Target Episode/Movie ID: $targetId');

    // 4. Get Servers
    print('[STEP 3] Fetching server list...');
    final serversRes = await http.get(Uri.parse('$ajaxUrl/episode/servers/$targetId'), headers: {'User-Agent': userAgent});
    final serversDoc = parse(serversRes.body);
    final servers = serversDoc.querySelectorAll('.nav-item a');
    
    if (servers.isEmpty) {
      print('❌ No servers found');
      return;
    }
    
    final server = servers.first;
    final serverId = server.attributes['data-id'];
    final serverName = server.text.trim();
    print('✅ Found Server 1: $serverName (ID: $serverId)');

    if (serverId == null) return;

    // 5. Get Sources
    print('[STEP 4] Fetching sources for Server 1...');
    final sourcesRes = await http.get(Uri.parse('$ajaxUrl/episode/sources/$serverId'), headers: {'User-Agent': userAgent});
    final sourcesData = json.decode(sourcesRes.body);
    final embedLink = sourcesData['link']?.toString();
    
    if (embedLink == null) {
      print('❌ Could not extract embed link');
      return;
    }
    print('✅ Embed Link: $embedLink');

    // 6. Decrypt
    print('[STEP 5] Attempting decryption...');
    bool decrypted = false;
    for (var decoderUrl in decoderUrls) {
      try {
        print('... Trying decoder: $decoderUrl');
        final decRes = await http.get(
          Uri.parse('$decoderUrl/?url=${Uri.encodeComponent(embedLink)}'),
          headers: {'User-Agent': 'curl/8.16.0'},
        ).timeout(const Duration(seconds: 10));

        if (decRes.statusCode == 200) {
          final data = json.decode(decRes.body);
          final videoUrl = (data['sources'] as List?)?.first['file']?.toString();
          if (videoUrl != null) {
            print('🎉 SUCCESS! Extracted Video URL: $videoUrl');
            decrypted = true;
            break;
          }
        }
      } catch (e) {
        print('⚠️ Decoder failed: $e');
      }
    }

    if (!decrypted) {
      print('❌ All decoders failed to extract video URL');
    }

  } catch (e) {
    print('❌ CRITICAL ERROR: $e');
  }
}
