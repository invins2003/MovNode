import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api/tmdb_client.dart';
import '../ui/cyber_theme.dart';
import 'player_screen_webview.dart';

class DetailsScreenMobile extends StatefulWidget {
  final Map<String, dynamic> item;

  const DetailsScreenMobile({super.key, required this.item});

  @override
  State<DetailsScreenMobile> createState() => _DetailsScreenMobileState();
}

class _DetailsScreenMobileState extends State<DetailsScreenMobile> {
  bool _isLoading = true;
  bool _isLoadingEpisodes = false;
  List<Map<String, dynamic>> _seasons = [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberTheme.matrixBlack,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(CyberTheme.hackerGreen),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetadata(CyberTheme.hackerGreen),
                  const SizedBox(height: 20),
                  _buildActionButtons(CyberTheme.hackerGreen),
                  const SizedBox(height: 20),
                  Text(
                    widget.item['overview'] ?? '',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 30),
                  if (widget.item['type'] == 'TV Series') _buildEpisodeSection(CyberTheme.hackerGreen),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(Color accent) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: CyberTheme.matrixBlack,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              (widget.item['backdrop'] != null && widget.item['backdrop'].toString().startsWith('http'))
                  ? widget.item['backdrop']
                  : (widget.item['poster'] != null && widget.item['poster'].toString().startsWith('http'))
                      ? widget.item['poster']
                      : 'https://via.placeholder.com/1280x720?text=No+Backdrop',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.black,
                child: const Center(child: Icon(Icons.movie, color: Colors.white24, size: 50)),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    CyberTheme.matrixBlack.withOpacity(0.5),
                    CyberTheme.matrixBlack,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadata(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.item['title'].toUpperCase(),
          style: CyberTheme.headerText(size: 24, color: Colors.white),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(widget.item['releaseDate']?.toString().split('-')[0] ?? 'N/A', style: CyberTheme.monoText(color: Colors.white54)),
            const SizedBox(width: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text("18+", style: CyberTheme.monoText(color: Colors.white54, size: 10)),
            ),
            const SizedBox(width: 15),
            Text("HD", style: CyberTheme.monoText(color: accent, weight: FontWeight.bold)),
            const SizedBox(width: 15),
            Icon(Icons.star, color: accent, size: 16),
            const SizedBox(width: 5),
            Text(widget.item['vote_average']?.toString() ?? '0.0', style: CyberTheme.monoText(color: accent)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(Color accent) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              if (widget.item['type'] == 'Movie') {
                _openPlayer();
              } else {
                _openPlayer(season: 1, episode: 1);
              }
            },
            icon: const Icon(Icons.play_arrow, color: Colors.black),
            label: Text("PLAY", style: CyberTheme.monoText(weight: FontWeight.bold, color: Colors.black)),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download, color: Colors.white),
            label: Text("DOWNLOAD", style: CyberTheme.monoText(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeSection(Color accent) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("EPISODES", style: CyberTheme.headerText(color: accent, size: 16)),
            DropdownButton<int>(
              value: _selectedSeason,
              dropdownColor: CyberTheme.matrixDarkGray,
              style: CyberTheme.monoText(color: accent),
              underline: Container(height: 1, color: accent),
              items: _seasons.map((s) => DropdownMenuItem(
                value: s['number'] as int,
                child: Text("SEASON ${s['number']}"),
              )).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedSeason = val);
                  _loadEpisodes(val);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 15),
        if (_isLoadingEpisodes)
          const Center(child: CircularProgressIndicator())
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _episodes.length,
            itemBuilder: (context, index) {
              final ep = _episodes[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(ep['title'], style: CyberTheme.monoText(color: Colors.white)),
                trailing: IconButton(
                  icon: Icon(Icons.play_circle_outline, color: accent),
                  onPressed: () => _openPlayer(season: _selectedSeason, episode: ep['number']),
                ),
              );
            },
          ),
      ],
    );
  }
}
