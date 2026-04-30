import 'dart:convert';
import 'package:http/http.dart' as http;
import 'stream_model.dart';

/// RiveStream client — uses the rivestream.org public API.
///
/// Endpoint formats (from https://rivestream.org/embed/docs):
///   Standard   : /api/backendfetch?requestID=[movie|tv]VideoProvider&id=...
///   Torrent     : /api/backendfetch?requestID=[movie|tv]TorrentProvider&id=...
///   Aggregator  : /api/backendfetch?requestID=[movie|tv]AggregatorProvider&id=...
///
/// All three tiers are fetched concurrently for maximum speed.
class RiveClient {
  static const String _baseUrl = 'https://backend.rivestream.org';
  static const String _origin  = 'https://rivestream.org';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Safari/537.36';

  // ─── API tier definitions ─────────────────────────────────────────────────

  static const _tiers = [
    _Tier(
      id: 'standard',
      label: 'Rive',
      movieRequestId: 'movieVideoProvider',
      tvRequestId: 'tvVideoProvider',
    ),
    _Tier(
      id: 'torrent',
      label: 'Rive Torrent',
      movieRequestId: 'movieTorrentProvider',
      tvRequestId: 'tvTorrentProvider',
    ),
    _Tier(
      id: 'aggregator',
      label: 'Rive Agg',
      movieRequestId: 'movieAggregatorProvider',
      tvRequestId: 'tvAggregatorProvider',
    ),
  ];

  // ─── Servers per tier ─────────────────────────────────────────────────────

  static const _standardServers = [
    'flowcast', 'asiacloud', 'humpy', 'primevids',
    'shadow', 'hindicast', 'animez', 'aqua',
    'yggdrasil', 'putafilme', 'ophim',
  ];

  static const _torrentServers = [
    'torrent', 'webtorrent', 'magnet',
  ];

  static const _aggregatorServers = [
    'agg', 'aggregator', 'multi',
  ];

  static Map<String, List<String>> get _tierServers => {
    'standard'   : _standardServers,
    'torrent'    : _torrentServers,
    'aggregator' : _aggregatorServers,
  };

  // ─── Public API ───────────────────────────────────────────────────────────

  static Future<List<VideasyStream>> getStreams({
    required String tmdbId,
    required String title,
    required String mediaType,
    int? seasonNum,
    int? episodeNum,
  }) async {
    if (tmdbId.isEmpty) {
      print('DEBUG: RiveClient — TMDB ID is required');
      return [];
    }

    final isTv = mediaType.toLowerCase() == 'tv' ||
                 mediaType.toLowerCase() == 'series';

    print('DEBUG: RiveClient fetching streams for "$title" '
        '(TMDB: $tmdbId, type: ${isTv ? "tv" : "movie"})');

    // Fire all tiers concurrently
    final tierFutures = _tiers.map(
      (tier) => _fetchTier(
        tier: tier,
        tmdbId: tmdbId,
        title: title,
        isTv: isTv,
        season: seasonNum,
        episode: episodeNum,
      ),
    );

    final results = await Future.wait(tierFutures);
    final streams = results.expand((s) => s).toList();

    // Sort: prefer streams that already went through a CDN/proxy
    streams.sort((a, b) {
      final aScore = _score(a.url);
      final bScore = _score(b.url);
      return bScore.compareTo(aScore);
    });

    print('DEBUG: RiveClient found ${streams.length} total streams');
    return streams;
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  static Future<List<VideasyStream>> _fetchTier({
    required _Tier tier,
    required String tmdbId,
    required String title,
    required bool isTv,
    int? season,
    int? episode,
  }) async {
    final requestId = isTv ? tier.tvRequestId : tier.movieRequestId;
    final servers   = _tierServers[tier.id] ?? [];
    final streams   = <VideasyStream>[];

    final base = isTv
        ? '$_baseUrl/api/backendfetch'
            '?requestID=$requestId'
            '&id=$tmdbId'
            '&season=${season ?? 1}'
            '&episode=${episode ?? 1}'
            '&service='
        : '$_baseUrl/api/backendfetch'
            '?requestID=$requestId'
            '&id=$tmdbId'
            '&service=';

    final futures = servers.map((server) async {
      final url = '$base$server';
      try {
        final res = await http
            .get(Uri.parse(url), headers: _headers)
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          _parseSources(data, streams, tier, server, title);
        }
      } catch (_) {
        // timeout / network error — silently ignore per-server failures
      }
    });

    await Future.wait(futures);

    // If no servers returned data, try a generic serverless endpoint
    if (streams.isEmpty) {
      await _tryGenericEndpoint(
        base: '$_baseUrl/api/backendfetch'
            '?requestID=$requestId'
            '&id=$tmdbId'
            '${isTv ? "&season=${season ?? 1}&episode=${episode ?? 1}" : ""}',
        tier: tier,
        title: title,
        streams: streams,
      );
    }

    return streams;
  }

  static Future<void> _tryGenericEndpoint({
    required String base,
    required _Tier tier,
    required String title,
    required List<VideasyStream> streams,
  }) async {
    try {
      final res = await http
          .get(Uri.parse(base), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _parseSources(data, streams, tier, tier.id, title);
      }
    } catch (_) {}
  }

  static void _parseSources(
    dynamic data,
    List<VideasyStream> streams,
    _Tier tier,
    String server,
    String title,
  ) {
    if (data == null) return;

    // Normalise: API might return { data: { sources: [...] } } or { sources: [...] }
    final payload = data['data'] ?? data;
    final sourcesList = payload['sources'];
    if (sourcesList == null || sourcesList is! List) return;

    // Collect captions/subtitles
    final subtitles = <SubtitleSource>[];
    final captions  = payload['captions'] ?? payload['subtitles'];
    if (captions is List) {
      for (final cap in captions) {
        final capUrl = cap['file']?.toString() ?? cap['url']?.toString();
        if (capUrl != null && capUrl.isNotEmpty) {
          subtitles.add(SubtitleSource(
            url: capUrl,
            label: cap['label']?.toString() ??
                   cap['language']?.toString() ?? 'English',
          ));
        }
      }
    }

    for (final src in sourcesList) {
      final srcUrl = src['url']?.toString() ?? '';
      if (srcUrl.isEmpty) continue;

      final quality     = src['quality']?.toString() ?? 'Auto';
      final serverLabel = src['source']?.toString() ?? server;
      final name        = '${tier.label} ($serverLabel) · $quality';

      // Direct stream
      streams.add(VideasyStream(
        name: name,
        title: title,
        url: srcUrl,
        quality: quality,
        provider: 'rive_${tier.id}',
        subtitles: subtitles,
        headers: _headers,
      ));

      // If the URL looks IP-locked, also add a proxy-wrapped fallback
      final ipPattern = RegExp(r':\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:');
      if (ipPattern.hasMatch(srcUrl)) {
        final encoded = Uri.encodeComponent(srcUrl);
        final encodedHeaders = Uri.encodeComponent(
          '{"Referer":"$_origin/","Origin":"$_origin"}',
        );
        streams.add(VideasyStream(
          name: '$name [Proxy]',
          title: title,
          url:
              'https://proxy.valhallastream.dpdns.org/proxy'
              '?url=$encoded&headers=$encodedHeaders',
          quality: quality,
          provider: 'rive_${tier.id}_proxy',
          subtitles: subtitles,
          headers: {'User-Agent': _userAgent},
        ));
      }
    }
  }

  static int _score(String url) {
    if (url.contains('workers.dev'))  return 3;
    if (url.contains('cloudflare'))   return 2;
    if (url.contains('proxy'))        return 1;
    return 0;
  }

  static Map<String, String> get _headers => {
    'User-Agent' : _userAgent,
    'Referer'    : '$_origin/',
    'Origin'     : _origin,
  };
}

// ─── Internal value type ─────────────────────────────────────────────────────

class _Tier {
  final String id;
  final String label;
  final String movieRequestId;
  final String tvRequestId;

  const _Tier({
    required this.id,
    required this.label,
    required this.movieRequestId,
    required this.tvRequestId,
  });
}
