import 'dart:convert';
import 'package:http/http.dart' as http;
import 'stream_model.dart';

/// MoviesApi provider - uses the 8man.me decrypt API exactly as vega-providers does
class MoviesApiClient {
  static const _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  static const _baseUrl = 'https://moviesapi.club';
  static const _decryptEndpoint = 'https://ext.8man.me/api/decrypt';
  static const _decryptPassphrase = '=JV[t}{trEV=Ilh5';

  static Future<List<VideasyStream>> getStreams({
    required String tmdbId,
    required String title,
    required String mediaType,
    int? seasonNum,
    int? episodeNum,
  }) async {
    final streams = <VideasyStream>[];
    final isTv = mediaType.toLowerCase() == 'tv' || mediaType.toLowerCase() == 'series';

    try {
      final embedUrl = isTv
          ? '$_baseUrl/tv/$tmdbId-${seasonNum ?? 1}-${episodeNum ?? 1}'
          : '$_baseUrl/movie/$tmdbId';

      print('DEBUG: MoviesApi fetching: $embedUrl');

      final res = await http.get(Uri.parse(embedUrl), headers: {
        'User-Agent': _userAgent,
        'Referer': '$_baseUrl/',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return streams;

      // Extract the encrypted data blob from the HTML
      final encryptedMatch = RegExp(r'Encrypted\s*=\s*"([^"]+)"').firstMatch(res.body)
        ?? RegExp(r"Encrypted\s*=\s*'([^']+)'").firstMatch(res.body);
      
      if (encryptedMatch == null) {
        print('DEBUG: MoviesApi: no encrypted data found in page');
        return streams;
      }

      final encrypted = encryptedMatch.group(1)!;
      print('DEBUG: MoviesApi decrypting ${encrypted.length} chars');

      // Decrypt via 8man.me API
      final decryptRes = await http.post(
        Uri.parse('$_decryptEndpoint?passphrase=${Uri.encodeComponent(_decryptPassphrase)}'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': _userAgent,
          'Referer': '$_baseUrl/',
        },
        body: encrypted,
      ).timeout(const Duration(seconds: 10));

      if (decryptRes.statusCode != 200) {
        print('DEBUG: MoviesApi decrypt failed: ${decryptRes.statusCode}');
        return streams;
      }

      final data = json.decode(decryptRes.body);
      final sources = data['sources'] as List?;
      final tracks = data['tracks'] as List?;

      if (sources == null || sources.isEmpty) return streams;

      // Parse subtitles
      final subtitles = <SubtitleSource>[];
      if (tracks != null) {
        for (final t in tracks) {
          if (t['kind'] == 'captions' || t['kind'] == 'subtitles') {
            final url = t['file']?.toString() ?? t['url']?.toString();
            if (url != null) {
              subtitles.add(SubtitleSource(url: url, label: t['label'] ?? 'English'));
            }
          }
        }
      }

      for (final source in sources) {
        final url = source['file']?.toString() ?? source['url']?.toString();
        if (url != null) {
          streams.add(VideasyStream(
            name: 'MoviesAPI (${source['label'] ?? 'Auto'})',
            title: title,
            url: url,
            quality: source['label']?.toString() ?? 'Auto',
            provider: 'moviesapi',
            subtitles: subtitles,
            headers: {
              'User-Agent': _userAgent,
              'Referer': '$_baseUrl/',
              'Origin': _baseUrl,
            },
          ));
          print('DEBUG: MoviesApi found: $url');
        }
      }
    } catch (e) {
      print('DEBUG: MoviesApi failed: $e');
    }

    return streams;
  }
}
