import 'package:http/http.dart' as http;
import 'stream_model.dart';

/// VidSrc provider - uses the public vidsrc embed API
class VidSrcClient {
  static const _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static Future<List<VideasyStream>> getStreams({
    required String tmdbId,
    required String title,
    required String mediaType,
    int? seasonNum,
    int? episodeNum,
  }) async {
    final streams = <VideasyStream>[];
    final isTv = mediaType.toLowerCase() == 'tv' || mediaType.toLowerCase() == 'series';

    final domains = [
      'https://vidsrc.me',
      'https://vidsrc.to',
      'https://vidsrc.xyz',
    ];

    final path = isTv
        ? '/embed/tv/$tmdbId/${seasonNum ?? 1}/${episodeNum ?? 1}'
        : '/embed/movie/$tmdbId';

    for (final domain in domains) {
      try {
        print('DEBUG: VidSrc trying $domain$path');
        final res = await http.get(
          Uri.parse('$domain$path'),
          headers: {
            'User-Agent': _userAgent,
            'Referer': '$domain/',
          },
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final body = res.body;

          // Look for m3u8 URL in the response
          final m3u8Match = RegExp(r'https?://\S+\.m3u8\S*').firstMatch(body);
          if (m3u8Match != null) {
            final url = m3u8Match.group(0)!;
            streams.add(VideasyStream(
              name: 'VidSrc (${domain.replaceAll('https://', '')})',
              title: title,
              url: url,
              quality: 'Auto',
              provider: 'vidsrc',
              headers: {
                'User-Agent': _userAgent,
                'Referer': '$domain/',
                'Origin': domain,
              },
            ));
            print('DEBUG: VidSrc found m3u8: $url');
            break;
          }

          // Look for mp4 URL
          final mp4Match = RegExp(r'https?://\S+\.mp4\S*').firstMatch(body);
          if (mp4Match != null) {
            final url = mp4Match.group(0)!;
            streams.add(VideasyStream(
              name: 'VidSrc (${domain.replaceAll('https://', '')})',
              title: title,
              url: url,
              quality: 'Auto',
              provider: 'vidsrc',
              headers: {
                'User-Agent': _userAgent,
                'Referer': '$domain/',
              },
            ));
            print('DEBUG: VidSrc found mp4: $url');
            break;
          }
        }
      } catch (e) {
        print('DEBUG: VidSrc $domain failed: $e');
      }
    }

    return streams;
  }
}
