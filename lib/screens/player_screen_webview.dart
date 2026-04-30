import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../ui/cyber_theme.dart';

/// Embed URL builder for rivestream.org
///
///   Standard   : https://rivestream.org/embed?type=...&id=...
///   Torrent    : https://rivestream.org/embed/torrent?type=...&id=...
///   Aggregator : https://rivestream.org/embed/agg?type=...&id=...
class _RiveSource {
  final String id;
  final String label;
  final IconData icon;
  final String path; // '/embed', '/embed/torrent', '/embed/agg'

  const _RiveSource({
    required this.id,
    required this.label,
    required this.icon,
    required this.path,
  });
}

const _sources = [
  _RiveSource(id: 'standard',   label: 'Standard',   icon: Icons.play_circle_fill,  path: '/embed'),
  _RiveSource(id: 'torrent',    label: 'Torrent',    icon: Icons.download_for_offline, path: '/embed/torrent'),
  _RiveSource(id: 'aggregator', label: 'Aggregator', icon: Icons.device_hub,         path: '/embed/agg'),
];

// ─── Widget ──────────────────────────────────────────────────────────────────

class PlayerScreenWebView extends StatefulWidget {
  final String itemTitle;
  final String tmdbId;
  final bool   isTv;
  final int?   season;
  final int?   episode;

  const PlayerScreenWebView({
    super.key,
    required this.itemTitle,
    required this.tmdbId,
    this.isTv    = false,
    this.season,
    this.episode,
  });

  @override
  State<PlayerScreenWebView> createState() => _PlayerScreenWebViewState();
}

class _PlayerScreenWebViewState extends State<PlayerScreenWebView> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  int  _sourceIndex = 0;   // which of the 3 sources is active
  bool _controlsVisible = true;

  // ─── URL builder ─────────────────────────────────────────────────────────

  String _buildUrl(int sourceIdx) {
    final src  = _sources[sourceIdx];
    final type = widget.isTv ? 'tv' : 'movie';
    final base = 'https://rivestream.org${src.path}?type=$type&id=${widget.tmdbId}';
    if (widget.isTv) {
      final s = widget.season  ?? 1;
      final e = widget.episode ?? 1;
      return '$base&season=$s&episode=$e';
    }
    return base;
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  void _switchSource(int idx) {
    if (idx == _sourceIndex) return;
    setState(() {
      _sourceIndex = idx;
      _isLoading   = true;
    });
    _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(_buildUrl(idx))),
    );
  }

  void _reload() {
    setState(() => _isLoading = true);
    _webViewController?.reload();
  }

  void _toggleControls() => setState(() => _controlsVisible = !_controlsVisible);

  // ─── Dialogs ─────────────────────────────────────────────────────────────

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Lock to landscape when video is playing
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        // Restore portrait on exit
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: GestureDetector(
            onTap: _toggleControls,
            child: Stack(
              children: [
                // ── WebView ──────────────────────────────────────────────
                InAppWebView(
                  initialUserScripts: UnmodifiableListView([
                    UserScript(
                      source: '''
                        window.__DISABLE_DEVTOOL__ = { isSuspend: true };
                        window.DISABLE_DEVTOOL = { isSuspend: true };
                        const _noop = () => {};
                        console.clear = _noop;
                        console.log = _noop;
                        console.info = _noop;
                        console.warn = _noop;
                        console.error = _noop;
                      ''',
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                    UserScript(
                      source: '''
                        // Safe click simulation: We click the center to start the player's native UI 
                        // and hide the poster overlay. Popups are blocked so this won't crash.
                        const tryPlay = setInterval(() => {
                           const el = document.elementFromPoint(window.innerWidth / 2, window.innerHeight / 2);
                           if (el) {
                               const ev = new MouseEvent('click', { view: window, bubbles: true, cancelable: true });
                               el.dispatchEvent(ev);
                           }
                           
                           const video = document.querySelector('video');
                           if (video && !video.paused) {
                               clearInterval(tryPlay);
                           }
                        }, 500);
                        setTimeout(() => clearInterval(tryPlay), 15000); // stop trying after 15s
                      ''',
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
                      forMainFrameOnly: false,
                    ),
                  ]),
                  initialUrlRequest: URLRequest(
                    url: WebUri(_buildUrl(_sourceIndex)),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    supportMultipleWindows: true, // Set to true so we can intercept and block popups
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    allowsAirPlayForMediaPlayback: true,
                    useWideViewPort: true,
                    loadWithOverviewMode: true,
                    supportZoom: false,
                    iframeAllow: "autoplay; fullscreen",
                    iframeAllowFullscreen: true,
                    userAgent:
                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                        'AppleWebKit/537.36 (KHTML, like Gecko) '
                        'Chrome/124.0.0.0 Safari/537.36',
                  ),
                  onWebViewCreated: (ctrl) => _webViewController = ctrl,
                  onCreateWindow: (controller, createWindowAction) async {
                    // This is the magic ad blocker! 
                    // By returning true, we tell the WebView we "handled" the new window request,
                    // but we do nothing, effectively discarding the ad popup.
                    return true;
                  },
                  onLoadStart: (_, __) =>
                      setState(() => _isLoading = true),
                  onLoadStop: (_, __) =>
                      setState(() => _isLoading = false),
                  onReceivedError: (_, __, ___) =>
                      setState(() => _isLoading = false),
                ),

                // ── Loading indicator ─────────────────────────────────────
                if (_isLoading)
                  Container(
                    color: Colors.black87,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: CyberTheme.hackerGreen,
                            strokeWidth: 2,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'LOADING ${_sources[_sourceIndex].label.toUpperCase()} SOURCE...',
                            style: CyberTheme.monoText(
                              color: CyberTheme.hackerGreen,
                              size: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Top controls overlay ──────────────────────────────────
                if (_controlsVisible) _buildTopBar(),

                // ── Bottom source tabs ────────────────────────────────────
                if (_controlsVisible) _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final epInfo = widget.isTv
        ? ' · S${widget.season ?? 1}:E${widget.episode ?? 1}'
        : '';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.85),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              // Back
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Back',
                onPressed: () {
                  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                  Navigator.pop(context);
                },
              ),

              const SizedBox(width: 8),

              // Title + episode info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.itemTitle.toUpperCase(),
                      style: CyberTheme.headerText(size: 14, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (epInfo.isNotEmpty)
                      Text(
                        'SEASON ${widget.season ?? 1}  ·  EPISODE ${widget.episode ?? 1}',
                        style: CyberTheme.monoText(size: 10, color: Colors.white54),
                      ),
                  ],
                ),
              ),

              // Active source chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: CyberTheme.hackerGreen.withOpacity(0.15),
                  border: Border.all(color: CyberTheme.hackerGreen.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_sources[_sourceIndex].icon,
                        color: CyberTheme.hackerGreen, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _sources[_sourceIndex].label.toUpperCase(),
                      style: CyberTheme.monoText(
                          color: CyberTheme.hackerGreen, size: 11),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Reload
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                tooltip: 'Reload',
                onPressed: _reload,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.85),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _sources.asMap().entries.map((entry) {
              final idx    = entry.key;
              final src    = entry.value;
              final active = _sourceIndex == idx;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () => _switchSource(idx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? CyberTheme.hackerGreen.withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      border: Border.all(
                        color: active
                            ? CyberTheme.hackerGreen
                            : Colors.white24,
                        width: active ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: CyberTheme.hackerGreen.withOpacity(0.25),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          src.icon,
                          size: 14,
                          color: active
                              ? CyberTheme.hackerGreen
                              : Colors.white54,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          src.label.toUpperCase(),
                          style: CyberTheme.monoText(
                            size: 11,
                            color: active
                                ? CyberTheme.hackerGreen
                                : Colors.white54,
                            weight: active
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
