import 'dart:convert';
import 'package:http/http.dart' as http;
import 'stream_model.dart';

/// Subtitle service based on vega-providers/autoEmbed approach.
/// Subtitles are fetched directly from RiveStream's backendfetch API.
/// This mirrors how vega-providers handles it.
class SubtitleService {
  static const _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// Generates the secret key exactly as vega-providers autoEmbed does
  static String _generateSecretKey(String id) {
    const c = [
      "4Z7lUo", "gwIVSMD", "PLmz2elE2v", "Z4OFV0", "SZ6RZq6Zc",
      "zhJEFYxrz8", "FOm7b0", "axHS3q4KDq", "o9zuXQ", "4Aebt",
      "wgjjWwKKx", "rY4VIxqSN", "kfjbnSo", "2DyrFA1M", "YUixDM9B",
      "JQvgEj0", "mcuFx6JIek", "eoTKe26gL", "qaI9EVO1rB", "0xl33btZL",
      "1fszuAU", "a7jnHzst6P", "wQuJkX", "cBNhTJlEOf", "KNcFWhDvgT",
      "XipDGjST", "PCZJlbHoyt", "2AYnMZkqd", "HIpJh", "KH0C3iztrG",
      "W81hjts92", "rJhAT", "NON7LKoMQ", "NMdY3nsKzI", "t4En5v",
      "Qq5cOQ9H", "Y9nwrp", "VX5FYVfsf", "cE5SJG", "x1vj1",
      "HegbLe", "zJ3nmt4OA", "gt7rxW57dq", "clIE9b", "jyJ9g",
      "B5jXjMCSx", "cOzZBZTV", "FTXGy", "Dfh1q1", "ny9jqZ2POI",
      "X2NnMn", "MBtoyD", "qz4Ilys7wB", "68lbOMye", "3YUJnmxp",
      "1fv5Imona", "PlfvvXD7mA", "ZarKfHCaPR", "owORnX", "dQP1YU",
      "dVdkx", "qgiK0E", "cx9wQ", "5F9bGa", "7UjkKrp",
      "Yvhrj", "wYXez5Dg3", "pG4GMU", "MwMAu", "rFRD5wlM",
    ];
    try {
      final r = id;
      final num = int.tryParse(id);
      String t;
      int n;

      if (num == null) {
        final sum = r.codeUnits.fold(0, (a, b) => a + b);
        t = c[sum % c.length];
        n = ((sum % r.length) / 2).floor();
      } else {
        t = c[num % c.length];
        n = ((num % r.length) / 2).floor();
      }
      final i = r.substring(0, n) + t + r.substring(n);
      // Simplified hash (dart doesn't have btoa, we use base64)
      return base64Encode(utf8.encode(i.hashCode.toRadixString(16).padLeft(8, '0')));
    } catch (e) {
      return 'topSecret';
    }
  }

  /// Fetches subtitles from RiveStream directly (same as our scraper, but isolated for subtitle-only use)
  static Future<List<SubtitleSource>> getExternalSubtitles(
    String tmdbId, {
    bool isTv = false,
    int? season,
    int? episode,
  }) async {
    const baseUrl = 'https://rivestream.live';
    final allSubs = <SubtitleSource>[];

    final secret = _generateSecretKey(tmdbId);
    final route = isTv
        ? '/api/backendfetch?requestID=tvVideoProvider&id=$tmdbId&season=$season&episode=$episode&secretKey=$secret&service='
        : '/api/backendfetch?requestID=movieVideoProvider&id=$tmdbId&secretKey=$secret&service=';

    // Try the first server that returns captions
    const servers = ['flowcast', 'asiacloud', 'shadow', 'aqua'];
    for (final server in servers) {
      try {
        final res = await http.get(
          Uri.parse('$baseUrl$route$server'),
          headers: {
            'User-Agent': _userAgent,
            'Referer': '$baseUrl/',
          },
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final captions = data?['data']?['captions'] as List?;
          if (captions != null && captions.isNotEmpty) {
            for (final cap in captions) {
              if (cap['url'] != null) {
                allSubs.add(SubtitleSource(
                  url: cap['url'].toString(),
                  label: cap['label']?.toString() ?? 'English',
                  language: cap['label']?.toString().toLowerCase().contains('english') == true ? 'en' : null,
                ));
              }
            }
            print('DEBUG: SubtitleService found ${allSubs.length} subs from server: $server');
            break; // Stop once we found subs
          }
        }
      } catch (e) {
        print('DEBUG: SubtitleService error ($server): $e');
      }
    }

    return allSubs;
  }
}
