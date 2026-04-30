import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const tmdbId = '221851'; // Marry My Husband
  const url = 'https://vidsrc.me/api/subtitles?tmdb=$tmdbId';
  
  print('Testing Subtitle API: $url');
  
  try {
    final response = await http.get(Uri.parse(url), headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://vidsrc.me/',
    });

    print('Status Code: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Found ${data.length} subtitles');
      if (data.isNotEmpty) {
        print('First Subtitle: ${data[0]['label']} -> ${data[0]['file']}');
      }
    } else {
      print('Error Body: ${response.body}');
    }
  } catch (e) {
    print('Connection Error: $e');
  }
}
