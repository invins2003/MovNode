import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'stream_model.dart';
import 'flixhq_client.dart';
import 'rive_client.dart';
import 'moviesapi_client.dart';
import 'vidsrc_client.dart';

class ScraperEngine {
  static final Map<String, String> _cookieCache = {};

  static Future<List<VideasyStream>> fetchAllStreams({
    required String tmdbId,
    required String title,
    required String year,
    required String mediaType,
    int? season,
    int? episode,
  }) async {
    // Tier 1: RiveStream — 3 API tiers (standard + torrent + aggregator), all concurrent
    print('DEBUG: ScraperEngine fetching streams from RiveStream (3 tiers) for $title');
    var streams = await RiveClient.getStreams(
      tmdbId: tmdbId,
      title: title,
      mediaType: mediaType,
      seasonNum: season,
      episodeNum: episode,
    );

    // Tier 2: MoviesApi — reliable fallback using 8man decrypt
    if (streams.isEmpty) {
      print('DEBUG: RiveStream failed, trying MoviesApi...');
      streams = await MoviesApiClient.getStreams(
        tmdbId: tmdbId,
        title: title,
        mediaType: mediaType,
        seasonNum: season,
        episodeNum: episode,
      );
    }

    // Tier 3: FlixHQz — headless scraper, slower
    if (streams.isEmpty) {
      print('DEBUG: MoviesApi failed, trying FlixHQz...');
      streams = await FlixHQClient.getStreams(
        title: title,
        mediaType: mediaType,
        seasonNum: season,
        episodeNum: episode,
      );
    }

    // Tier 4: VidSrc — public embed fallback
    if (streams.isEmpty) {
      print('DEBUG: FlixHQz failed, trying VidSrc...');
      streams = await VidSrcClient.getStreams(
        tmdbId: tmdbId,
        title: title,
        mediaType: mediaType,
        seasonNum: season,
        episodeNum: episode,
      );
    }

    if (streams.isEmpty) {
      print('DEBUG: ALL providers failed for "$title"');
    } else {
      print('DEBUG: Found ${streams.length} streams total');
    }

    return streams;
  }

  static Future<String> fetchRenderedHtml(String url, {int waitSeconds = 5}) async {
    final completer = Completer<String>();
    HeadlessInAppWebView? webView;
    try {
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          allowsInlineMediaPlayback: true,
        ),
        onLoadStop: (controller, finalUrl) async {
          // Wait for AJAX content to render and handle Cloudflare
          for (int i = 0; i < waitSeconds; i++) {
             final title = await controller.getTitle();
             if (title != null && (title.contains('Cloudflare') || title.contains('Just a moment'))) {
                await controller.evaluateJavascript(source: "const c = document.querySelector('input[type=\"checkbox\"]'); if(c) c.click();");
             }
             
             // Check if search results have loaded
             final hasResults = await controller.evaluateJavascript(source: "document.querySelectorAll('.flw-item').length > 0");
             if (hasResults == true) break;
             
             await Future.delayed(const Duration(seconds: 1));
          }
          final html = await controller.getHtml();
          if (!completer.isCompleted) completer.complete(html ?? '');
        },
      );
      await webView.run();
      return await completer.future.timeout(Duration(seconds: waitSeconds + 15), onTimeout: () => '');
    } catch (e) {
      print('DEBUG: fetchRenderedHtml failed: $e');
      return '';
    } finally {
      if (webView != null) {
        Future.delayed(const Duration(milliseconds: 500), () async {
          try { await webView?.dispose(); } catch (_) {}
        });
      }
    }
  }

  static Future<String?> extractM3u8Native(String url, {int timeoutSeconds = 15}) async {
    final completer = Completer<String?>();
    HeadlessInAppWebView? webView;
    try {
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          useShouldInterceptAjaxRequest: true,
          useShouldInterceptFetchRequest: true,
        ),
        onLoadStart: (controller, url) {
          print('DEBUG: extractM3u8Native started loading: $url');
        },
        shouldInterceptAjaxRequest: (controller, ajaxRequest) async {
          final reqUrl = ajaxRequest.url?.toString() ?? '';
          if (reqUrl.contains('.m3u8') && !completer.isCompleted) {
            print('🎉 SUCCESS: Intercepted AJAX m3u8: $reqUrl');
            completer.complete(reqUrl);
          }
          return null;
        },
        shouldInterceptFetchRequest: (controller, fetchRequest) async {
          final reqUrl = fetchRequest.url?.toString() ?? '';
          if (reqUrl.contains('.m3u8') && !completer.isCompleted) {
            print('🎉 SUCCESS: Intercepted FETCH m3u8: $reqUrl');
            completer.complete(reqUrl);
          }
          return null;
        },
        onLoadResource: (controller, resource) {
           final reqUrl = resource.url?.toString() ?? '';
           if (reqUrl.contains('.m3u8') && !completer.isCompleted) {
             print('🎉 SUCCESS: Intercepted Resource m3u8: $reqUrl');
             completer.complete(reqUrl);
           }
        },
        onLoadStop: (controller, finalUrl) async {
           // Wait and try to extract from video tag or click play
           await Future.delayed(const Duration(seconds: 3));
           if (!completer.isCompleted) {
             try {
               await controller.evaluateJavascript(source: "const btn = document.querySelector('.play-btn, .play, button'); if (btn) btn.click();");
               await Future.delayed(const Duration(seconds: 2));
               final videoSrc = await controller.evaluateJavascript(source: "document.querySelector('video')?.src || '';");
               if (videoSrc != null && videoSrc.toString().contains('.m3u8') && !completer.isCompleted) {
                   completer.complete(videoSrc.toString());
               }
             } catch (e) {}
           }
        }
      );
      await webView.run();
      final result = await completer.future.timeout(Duration(seconds: timeoutSeconds), onTimeout: () {
        if (!completer.isCompleted) completer.complete(null);
        return null;
      });
      return result;
    } catch (e) {
      print('DEBUG: extractM3u8Native failed: $e');
      if (!completer.isCompleted) completer.complete(null);
      return null;
    } finally {
      if (webView != null) {
        Future.delayed(const Duration(milliseconds: 500), () async {
          try { await webView?.dispose(); } catch (_) {}
        });
      }
    }
  }

  static Future<http.Response> fetchWithBypass(String url, {Map<String, String>? headers}) async {
    final domain = Uri.parse(url).host;
    try {
      final cookies = _cookieCache[domain];
      final reqHeaders = Map<String, String>.from(headers ?? {});
      if (cookies != null) reqHeaders['Cookie'] = cookies;

      final response = await http.get(Uri.parse(url), headers: reqHeaders).timeout(const Duration(seconds: 10));
      final isChallenge = response.body.contains('cf-challenge-running') || response.body.contains('Just a moment...');
      if (response.statusCode == 200 && !isChallenge) return response;
    } catch (_) {}

    final bypassData = await getBypassCookies(url);
    final reqHeaders = Map<String, String>.from(headers ?? {});
    if (bypassData['cookies'] != null) {
      reqHeaders['Cookie'] = bypassData['cookies']!;
      _cookieCache[domain] = bypassData['cookies']!;
    }
    return await http.get(Uri.parse(bypassData['finalUrl'] ?? url), headers: reqHeaders).timeout(const Duration(seconds: 15));
  }

  static Future<Map<String, String>> getBypassCookies(String url) async {
    final completer = Completer<Map<String, String>>();
    HeadlessInAppWebView? webView;
    try {
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        onLoadStop: (controller, finalUrl) async {
          try {
            for (int i = 0; i < 10; i++) {
              await Future.delayed(const Duration(seconds: 2));
              if (completer.isCompleted) return;
              final title = await controller.getTitle();
              if (title != null && (title.contains('Cloudflare') || title.contains('Just a moment'))) {
                await controller.evaluateJavascript(source: "const c = document.querySelector('input[type=\"checkbox\"]'); if(c) c.click();");
              } else { break; }
            }
            final cookies = await CookieManager.instance().getCookies(url: finalUrl!);
            completer.complete({'cookies': cookies.map((c) => '${c.name}=${c.value}').join('; '), 'finalUrl': finalUrl.toString()});
          } catch (e) {
            print('DEBUG: Bypass cookies callback failed: $e');
            if (!completer.isCompleted) completer.complete({});
          }
        },
      );
      await webView.run();
      final result = await completer.future.timeout(const Duration(seconds: 30), onTimeout: () => {});
      return result;
    } catch (e) {
      print('DEBUG: getBypassCookies failed: $e');
      return {};
    } finally {
      if (webView != null) {
        Future.delayed(const Duration(milliseconds: 500), () async {
          try { await webView?.dispose(); } catch (_) {}
        });
      }
    }
  }
}
