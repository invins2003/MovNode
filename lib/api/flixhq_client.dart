import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'stream_model.dart';
import 'scraper_engine.dart';

class FlixHQClient {
  static const String _baseUrl = 'https://flixhqz.com';
  static const String _ajaxUrl = 'https://flixhqz.com/ajax';
  static const List<String> _decoderUrls = [
    'https://dec.eatmynerds.live',
    'https://rabbit-stream.vercel.app/api',
    'https://consumet-api.herokuapp.com/movies/flixhq/watch', // Note: Consumet uses a different structure, handled below
  ];
  static const String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static Future<Map<String, dynamic>?> _extractFromEmbed(String embedUrl) async {
    try {
      final uri = Uri.parse(embedUrl);
      final embedHost = '${uri.scheme}://${uri.host}';
      
      final response = await http.get(uri, headers: {
        'Referer': _baseUrl,
        'User-Agent': _userAgent,
      });

      if (response.statusCode != 200) return null;

      final html = response.body;
      
      // Pattern 1: 48-character alphanumeric string
      // Pattern 2: Three 16-character alphanumeric strings
      final nonceRegex48 = RegExp(r'\b[a-zA-Z0-9]{48}\b');
      final nonceRegex16 = RegExp(r'\b([a-zA-Z0-9]{16})\b.*?\b([a-zA-Z0-9]{16})\b.*?\b([a-zA-Z0-9]{16})\b');

      String? nonce;
      final match48 = nonceRegex48.firstMatch(html);
      if (match48 != null) {
        nonce = match48.group(0);
      } else {
        final match16 = nonceRegex16.firstMatch(html);
        if (match16 != null) {
          nonce = '${match16.group(1)}${match16.group(2)}${match16.group(3)}';
        }
      }

      if (nonce == null) return null;

      final fileId = uri.pathSegments.last.split('?').first;
      // Try standard RabbitStream/UpCloud API paths
      final apiPaths = ['/embed-1/v3/e-1/getSources', '/ajax/getSources', '/v2/getSources'];
      
      for (var path in apiPaths) {
        final apiUrl = '$embedHost$path?id=$fileId&_k=$nonce';
        final apiRes = await http.get(Uri.parse(apiUrl), headers: {
          'Referer': '$embedHost/',
          'X-Requested-With': 'XMLHttpRequest',
          'User-Agent': _userAgent,
        });

        if (apiRes.statusCode == 200) {
          final data = json.decode(apiRes.body);
          if (data['sources'] != null) return data;
        }
      }
    } catch (e) {
      print('DEBUG: Direct extraction failed: $e');
    }
    return null;
  }

  static Future<List<VideasyStream>> getStreams({
    required String title,
    required String mediaType,
    int? seasonNum,
    int? episodeNum,
  }) async {
    final streams = <VideasyStream>[];

    try {
      print('DEBUG: FlixHQz extraction started for: $title');
      
      // 1. Search (Use rendered HTML because results are loaded via AJAX)
      final searchUrl = '$_baseUrl/search/?q=${Uri.encodeComponent(title)}';
      final searchHtml = await ScraperEngine.fetchRenderedHtml(searchUrl, waitSeconds: 15);
      
      if (searchHtml.isEmpty) return streams;
      
      final document = parse(searchHtml);
      final results = document.querySelectorAll('div.flw-item');
      
      String? matchedUrl;
      for (var result in results) {
        final link = result.querySelector('h2.film-name a');
        final resultTitle = link?.attributes['title']?.toLowerCase() ?? link?.text.trim().toLowerCase() ?? '';
        final resultType = result.querySelector('span.fdi-type')?.text.trim().toLowerCase() ?? '';
        
        bool typeMatch = (mediaType == 'movie' && (resultType == 'movie')) || 
                        (mediaType == 'tv' && (resultType == 'tv' || resultType == 'series'));

        if (resultTitle.contains(title.toLowerCase()) && typeMatch) {
          matchedUrl = link?.attributes['href'];
          if (matchedUrl != null && !matchedUrl.startsWith('http')) matchedUrl = _baseUrl + (matchedUrl.startsWith('/') ? matchedUrl : '/$matchedUrl');
          break;
        }
      }
      
      if (matchedUrl == null && results.isNotEmpty) {
        final firstLink = results.first.querySelector('a.film-poster-ahref')?.attributes['href'] ?? 
                          results.first.querySelector('div.film-poster a')?.attributes['href'];
        if (firstLink != null) matchedUrl = firstLink.startsWith('http') ? firstLink : _baseUrl + (firstLink.startsWith('/') ? firstLink : '/$firstLink');
      }
      
      if (matchedUrl == null) return streams;
      print('DEBUG: Matched URL: $matchedUrl');

      // 2. Extract ID from URL (Format: /movie/slug-id/ or /tv/slug-id/)
      final pathParts = Uri.parse(matchedUrl).pathSegments.where((s) => s.isNotEmpty).toList();
      String? mediaId;
      
      if (pathParts.isNotEmpty) {
        final lastPart = pathParts.last;
        final idMatch = RegExp(r'-(\d+)$').firstMatch(lastPart);
        if (idMatch != null) {
          mediaId = idMatch.group(1);
        } else if (RegExp(r'^\d+$').hasMatch(lastPart)) {
          mediaId = lastPart;
        }
      }
      
      if (mediaId == null || mediaId.isEmpty) {
        // Fallback to HTML data-id if URL parsing fails
        final detailRes = await ScraperEngine.fetchWithBypass(matchedUrl, headers: {'User-Agent': _userAgent});
        final detailDoc = parse(detailRes.body);
        mediaId = detailDoc.querySelector('#watch-block')?.attributes['data-id'] ??
                  detailDoc.querySelector('div.detail_page-watch')?.attributes['data-id'] ??
                  detailDoc.querySelector('#movie_id')?.attributes['value'];
      }
      
      if (mediaId == null) return streams;
      print('DEBUG: FlixHQz Media ID: $mediaId');

      String targetEpisodeId = mediaId;

      if (mediaType == 'tv') {
        // 3. Get Seasons
        final seasonsRes = await ScraperEngine.fetchWithBypass('$_ajaxUrl/season/list/$mediaId', headers: {'User-Agent': _userAgent});
        final seasonsDoc = parse(seasonsRes.body);
        final seasons = seasonsDoc.querySelectorAll('.dropdown-item');
        
        String? targetSeasonId;
        for (var s in seasons) {
          final sName = s.text.toLowerCase();
          if (sName.contains('season ${(seasonNum ?? 1)}')) {
            targetSeasonId = s.attributes['data-id'];
            break;
          }
        }
        targetSeasonId ??= seasons.isNotEmpty ? seasons.first.attributes['data-id'] : null;
        if (targetSeasonId == null) return streams;

        // 4. Get Episodes
        final episodesRes = await ScraperEngine.fetchWithBypass('$_ajaxUrl/v2/episode/servers/$targetSeasonId', headers: {'User-Agent': _userAgent});
        final episodesDoc = parse(episodesRes.body);
        final episodes = episodesDoc.querySelectorAll('.nav-item a, a.eps-item');
        
        for (var e in episodes) {
          final eName = e.attributes['title'] ?? e.text.trim();
          if (eName.toLowerCase().contains('episode ${(episodeNum ?? 1)}')) {
            targetEpisodeId = e.attributes['data-id'] ?? e.attributes['data-linkid'] ?? '';
            break;
          }
        }
      } else {
        // For movies on flixhqz, the ID for sources is often the mediaId or from /ajax/movie/episodes/
        final movieEpisodesRes = await ScraperEngine.fetchWithBypass('$_ajaxUrl/movie/episodes/$mediaId', headers: {'User-Agent': _userAgent});
        final movieEpDoc = parse(movieEpisodesRes.body);
        final firstEp = movieEpDoc.querySelector('.nav-item a, a.eps-item');
        if (firstEp != null) {
          targetEpisodeId = firstEp.attributes['data-id'] ?? firstEp.attributes['data-linkid'] ?? mediaId;
        }
      }

      print('DEBUG: FlixHQz Target ID: $targetEpisodeId');

      // 5. Get Servers (Using /ajax/movie/episodes/)
      final serversRes = await ScraperEngine.fetchWithBypass('$_ajaxUrl/movie/episodes/$mediaId', headers: {'User-Agent': _userAgent});
      final serversDoc = parse(serversRes.body);
      final servers = serversDoc.querySelectorAll('.nav-item a, #content-episodes a.server');
      
      if (servers.isNotEmpty) {
        for (var server in servers) {
        final serverId = server.attributes['data-linkid'] ?? server.attributes['data-id'];
        final serverName = server.text.trim();
        
        if (serverId != null) {
          // 6. Get Sources (Using /ajax/movie/get_sources/ for movies)
          final sourcesRes = await ScraperEngine.fetchWithBypass('$_ajaxUrl/movie/get_sources/$serverId', headers: {'User-Agent': _userAgent});
          final sourcesData = json.decode(sourcesRes.body);
          final embedLink = sourcesData['link']?.toString();
          
          if (embedLink != null) {
            // 7. Decrypt (First try direct extraction from flixhq-api, then fallback to external decoders)
            bool decrypted = false;
            
            // A. Direct Extraction (Pure Scraping)
            final directData = await _extractFromEmbed(embedLink);
            if (directData != null && directData['sources'] != null) {
              final sourcesList = directData['sources'] as List;
              final tracks = directData['tracks'] as List?;
              String? videoUrl;
              for (var s in sourcesList) {
                if (s['file'] != null && s['file'].toString().contains('.m3u8')) {
                  videoUrl = s['file'];
                  break;
                }
              }
              videoUrl ??= sourcesList.first['file']?.toString();

              if (videoUrl != null) {
                final subtitleList = <SubtitleSource>[];
                if (tracks != null) {
                  for (var t in tracks) {
                    if (t['kind'] == 'captions' || t['kind'] == 'subtitles') {
                      subtitleList.add(SubtitleSource(
                        url: t['file'],
                        label: t['label'] ?? 'English',
                      ));
                    }
                  }
                }

                streams.add(VideasyStream(
                  name: 'FlixHQz ($serverName) [Direct]',
                  title: title,
                  url: videoUrl,
                  quality: 'HD',
                  provider: 'flixhqz',
                  subtitles: subtitleList,
                  headers: {
                    'User-Agent': _userAgent,
                    'Referer': _baseUrl,
                  },
                ));
                decrypted = true;
                print('DEBUG: FlixHQz Direct extraction succeeded');
              }
            }

            // B. Headless Native Extraction (Fallback)
            if (!decrypted) {
              print('DEBUG: FlixHQz Attempting Headless Native Extraction for $embedLink');
              final nativeUrl = await ScraperEngine.extractM3u8Native(embedLink);
              if (nativeUrl != null && nativeUrl.isNotEmpty) {
                streams.add(VideasyStream(
                  name: 'FlixHQz ($serverName) [Native]',
                  title: title,
                  url: nativeUrl,
                  quality: 'HD',
                  provider: 'flixhqz',
                  subtitles: [], 
                  headers: {
                    'User-Agent': _userAgent,
                    'Referer': _baseUrl,
                  },
                ));
                decrypted = true;
                print('DEBUG: FlixHQz Native extraction succeeded');
              }
            }

            // C. External Decoders (Last Resort)
            if (!decrypted) {
              for (var decoderUrl in _decoderUrls) {
                try {
                  print('DEBUG: FlixHQz Attempting fallback decryption with: $decoderUrl');
                  final decryptRes = await http.get(
                    Uri.parse('$decoderUrl/?url=${Uri.encodeComponent(embedLink)}'),
                    headers: {'User-Agent': 'curl/8.16.0'},
                  ).timeout(const Duration(seconds: 10));

                  if (decryptRes.statusCode == 200) {
                    final data = json.decode(decryptRes.body);
                    final sourcesList = data['sources'] as List?;
                    final tracks = data['tracks'] as List?;

                    String? videoUrl;
                    if (sourcesList != null && sourcesList.isNotEmpty) {
                      for (var s in sourcesList) {
                        if (s['file'] != null && s['file'].toString().contains('.m3u8')) {
                          videoUrl = s['file'];
                          break;
                        }
                      }
                      videoUrl ??= sourcesList.first['file']?.toString();
                    }

                    if (videoUrl != null) {
                      final subtitleList = <SubtitleSource>[];
                      if (tracks != null) {
                        for (var t in tracks) {
                          if (t['kind'] == 'captions' || t['kind'] == 'subtitles') {
                            subtitleList.add(SubtitleSource(
                              url: t['file'],
                              label: t['label'] ?? 'English',
                            ));
                          }
                        }
                      }

                      streams.add(VideasyStream(
                        name: 'FlixHQz ($serverName) [API]',
                        title: title,
                        url: videoUrl,
                        quality: 'HD',
                        provider: 'flixhqz',
                        subtitles: subtitleList,
                        headers: {
                          'User-Agent': _userAgent,
                          'Referer': _baseUrl,
                        },
                      ));
                      decrypted = true;
                      break;
                    }
                  }
                } catch (e) {
                  print('DEBUG: Decoder $decoderUrl failed: $e');
                }
              }
            }
            if (decrypted) break; // Break out of servers loop if we found a stream
          }
        }
      }
      }
    } catch (e) {
      print('DEBUG: FlixHQz extraction failed: $e');
    }
    
    return streams;
  }
}
