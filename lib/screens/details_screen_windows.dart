import 'dart:ui';
import 'package:flutter/material.dart';
import '../api/tmdb_client.dart';
import '../ui/cyber_theme.dart';
import 'player_screen_webview.dart';

class DetailsScreenWindows extends StatefulWidget {
  final Map<String, dynamic> item;

  const DetailsScreenWindows({super.key, required this.item});

  @override
  State<DetailsScreenWindows> createState() => _DetailsScreenWindowsState();
}

class _DetailsScreenWindowsState extends State<DetailsScreenWindows> {
  bool _isLoading = true;
  bool _isLoadingEpisodes = false;
  List<Map<String, dynamic>> _seasons  = [];
  List<Map<String, dynamic>> _episodes = [];
  int _selectedSeason = 1;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (widget.item['type'] == 'TV Series') {
      final seasons = await TmdbClient.getTVDetails(widget.item['id']);
      if (mounted) {
        setState(() {
          _seasons = seasons;
          _selectedSeason = seasons.isNotEmpty ? seasons.first['number'] : 1;
        });
        await _loadEpisodes(_selectedSeason);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadEpisodes(int season) async {
    setState(() => _isLoadingEpisodes = true);
    final episodes = await TmdbClient.getEpisodes(widget.item['id'], season);
    if (mounted) {
      setState(() {
        _episodes = episodes;
        _isLoadingEpisodes = false;
      });
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  void _openPlayer({int? season, int? episode}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreenWebView(
          itemTitle: widget.item['title'],
          tmdbId: widget.item['id'].toString(),
          isTv: widget.item['type'] == 'TV Series',
          season: season ?? _selectedSeason,
          episode: episode,
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberTheme.matrixBlack,
      body: Stack(
        children: [
          // Blurred backdrop
          Positioned.fill(
            child: Image.network(
              widget.item['backdrop'] ?? widget.item['poster'] ?? '',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: CyberTheme.matrixBlack),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                  color: CyberTheme.matrixBlack.withOpacity(0.85)),
            ),
          ),

          // Content
          Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Poster
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 20),
                      child: Container(
                        width: 300,
                        height: 450,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5),
                          ],
                          image: DecorationImage(
                            image: NetworkImage(
                                widget.item['poster'] ?? ''),
                            fit: BoxFit.cover,
                            onError: (_, __) {},
                          ),
                        ),
                      ),
                    ),

                    // Info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(
                            right: 60, top: 20),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.item['title'].toUpperCase(),
                                style: CyberTheme.headerText(size: 48),
                              ),
                              const SizedBox(height: 10),
                              _buildMetadata(),
                              const SizedBox(height: 30),
                              Text(
                                widget.item['overview'] ?? '',
                                style: CyberTheme.monoText(
                                    size: 16, color: Colors.white70),
                              ),
                              const SizedBox(height: 40),
                              Row(
                                children: [
                                  _buildPlayButton(),
                                ],
                              ),
                              const SizedBox(height: 40),
                              if (widget.item['type'] == 'TV Series')
                                _buildTVSection(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata() {
    return Row(
      children: [
        Text(
          widget.item['releaseDate']?.split('-')[0] ?? '',
          style: CyberTheme.monoText(color: Colors.white54),
        ),
        const SizedBox(width: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white54),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('HD',
              style: CyberTheme.monoText(
                  color: CyberTheme.hackerGreen,
                  weight: FontWeight.bold)),
        ),
        const SizedBox(width: 20),
        const Icon(Icons.star, color: CyberTheme.hackerGreen, size: 20),
        const SizedBox(width: 5),
        Text(
          widget.item['vote_average']?.toString() ?? '0.0',
          style: CyberTheme.monoText(color: CyberTheme.hackerGreen),
        ),
      ],
    );
  }

  Widget _buildPlayButton() {
    return ElevatedButton.icon(
      onPressed: () => _openPlayer(
        season: widget.item['type'] == 'TV Series' ? 1 : null,
        episode: widget.item['type'] == 'TV Series' ? 1 : null,
      ),
      icon: const Icon(Icons.play_arrow, color: Colors.black),
      label: Text(
        'PLAY NOW',
        style: CyberTheme.monoText(
            color: Colors.black, weight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: CyberTheme.hackerGreen,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      ),
    );
  }

  Widget _buildTVSection() {
    if (_isLoading) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('EPISODES',
                style: CyberTheme.headerText(
                    size: 24, color: CyberTheme.hackerGreen)),
            const SizedBox(width: 30),
            DropdownButton<int>(
              value: _selectedSeason,
              dropdownColor: CyberTheme.matrixDarkGray,
              style: CyberTheme.monoText(color: CyberTheme.hackerGreen),
              underline: Container(height: 1, color: CyberTheme.hackerGreen),
              items: _seasons
                  .map((s) => DropdownMenuItem(
                        value: s['number'] as int,
                        child: Text('SEASON ${s['number']}'),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedSeason = val);
                  _loadEpisodes(val);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_isLoadingEpisodes)
          const Center(
              child: CircularProgressIndicator(
                  color: CyberTheme.hackerGreen))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 250,
              childAspectRatio: 2.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _episodes.length,
            itemBuilder: (context, index) {
              final ep = _episodes[index];
              return InkWell(
                onTap: () => _openPlayer(
                    season: _selectedSeason,
                    episode: ep['number']),
                child: Container(
                  decoration: CyberTheme.glassBox(),
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_outline,
                          color: CyberTheme.hackerGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ep['title'],
                          style: CyberTheme.monoText(size: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
