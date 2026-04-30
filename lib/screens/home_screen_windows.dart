import 'package:flutter/material.dart';
import '../api/tmdb_client.dart';
import 'details_screen.dart';
import '../ui/cyber_theme.dart';

class HomeScreenWindows extends StatefulWidget {
  const HomeScreenWindows({Key? key}) : super(key: key);

  @override
  State<HomeScreenWindows> createState() => _HomeScreenWindowsState();
}

class _HomeScreenWindowsState extends State<HomeScreenWindows> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = true;

  int _selectedIndex = 0;
  final List<String> _navItems = ['Home', 'Movies', 'TV Shows', 'Search'];

  Map<String, List<Map<String, dynamic>>> _categories = {};

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final type = _selectedIndex == 1 ? 'movie' : (_selectedIndex == 2 ? 'tv' : null);
    
    final results = await Future.wait([
      TmdbClient.getTrending(),
      TmdbClient.getNetflixSeries(), // Note: TMDB Client might need update to filter these by type if needed
      TmdbClient.getAmazonSeries(),
      TmdbClient.getAppleSeries(),
      TmdbClient.getDisneySeries(),
      TmdbClient.getPopularMovies(),
    ]);

    if (mounted) {
      setState(() {
        _categories = {
          'Trending Now': type == null ? results[0] : results[0].where((item) => item['type'] == (type == 'movie' ? 'Movie' : 'TV Series')).toList(),
          'Netflix Originals': type == 'movie' ? [] : results[1],
          'Amazon Prime': type == 'movie' ? [] : results[2],
          'Apple TV+': type == 'movie' ? [] : results[3],
          'Disney+': type == 'movie' ? [] : results[4],
          'Popular Movies': type == 'tv' ? [] : results[5],
        };
        _isLoading = false;
      });
    }
  }

  void _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _isSearching = false);
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoading = true;
    });

    final results = await TmdbClient.search(query);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberTheme.matrixBlack,
      body: Row(
        children: [
          // Sidebar Navigation
          Container(
            width: 250,
            color: CyberTheme.matrixDarkGray,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  child: Row(
                    children: [
                      Image.asset('assets/logo.png', height: 40),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          "MOVNODE",
                          style: CyberTheme.headerText(size: 20, color: CyberTheme.hackerGreen),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                ...List.generate(_navItems.length, (index) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
                    selected: _selectedIndex == index,
                    selectedTileColor: CyberTheme.hackerGreen.withOpacity(0.1),
                    title: Text(
                      _navItems[index],
                      style: CyberTheme.monoText(
                        color: _selectedIndex == index ? CyberTheme.hackerGreen : Colors.white70,
                        size: 16,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                        _isSearching = (index == 3);
                        _isLoading = true;
                      });
                      _loadDashboard();
                    },
                  );
                }),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Text(
                    "v2.0.0-cyber",
                    style: CyberTheme.monoText(color: Colors.white38, size: 12),
                  ),
                ),
              ],
            ),
          ),

          // Main Content Area
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Top Bar
                SliverAppBar(
                  floating: true,
                  backgroundColor: CyberTheme.matrixBlack,
                  elevation: 0,
                  toolbarHeight: 80,
                  title: Row(
                    children: [
                      if (_isSearching || _selectedIndex == 3)
                        Expanded(
                          child: Container(
                            height: 45,
                            margin: const EdgeInsets.only(right: 20),
                            decoration: CyberTheme.glassBox(),
                            child: TextField(
                              controller: _searchController,
                              style: CyberTheme.monoText(color: CyberTheme.hackerGreen),
                              onSubmitted: (_) => _performSearch(),
                              decoration: InputDecoration(
                                hintText: "> SEARCH_SYSTEM...",
                                hintStyle: CyberTheme.monoText(color: CyberTheme.hackerGreen.withOpacity(0.5)),
                                prefixIcon: const Icon(Icons.terminal, color: CyberTheme.hackerGreen, size: 20),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: Text(
                            _navItems[_selectedIndex].toUpperCase(),
                            style: CyberTheme.headerText(size: 24, color: Colors.white),
                          ),
                        ),
                      // Buttons removed as requested
                    ],
                  ),
                ),

                if (_isSearching || _selectedIndex == 3)
                  _buildSearchResults()
                else if (_isLoading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: CyberTheme.hackerGreen)),
                  )
                else
                  SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHero(),
                      ..._categories.entries.map((entry) => _buildCategoryRow(entry.key, entry.value)).toList(),
                      const SizedBox(height: 50),
                    ]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    if (_categories['Trending Now'] == null || _categories['Trending Now']!.isEmpty) return const SizedBox();
    final featured = _categories['Trending Now']![0];

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsScreen(item: featured))),
      child: Container(
        height: 500,
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: NetworkImage(
              (featured['backdrop'] != null && featured['backdrop'].toString().startsWith('http'))
                  ? featured['backdrop']
                  : 'https://via.placeholder.com/1920x1080?text=No+Image',
            ),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                CyberTheme.matrixBlack.withOpacity(0.9),
                CyberTheme.matrixBlack.withOpacity(0.4),
                Colors.transparent,
              ],
            ),
          ),
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                featured['title'].toUpperCase(),
                style: CyberTheme.headerText(size: 42),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 500,
                child: Text(
                  featured['overview'] ?? '',
                  style: CyberTheme.monoText(color: Colors.white70, size: 14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  _buildHeroButton("PLAY", Icons.play_arrow, CyberTheme.hackerGreen, true, featured),
                  const SizedBox(width: 20),
                  _buildHeroButton("INFO", Icons.info_outline, Colors.white, false, featured),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroButton(String label, IconData icon, Color color, bool filled, Map<String, dynamic> item) {
    return ElevatedButton.icon(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsScreen(item: item))),
      icon: Icon(icon, color: filled ? Colors.black : color),
      label: Text(label, style: CyberTheme.monoText(color: filled ? Colors.black : color, weight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: filled ? color : Colors.transparent,
        side: filled ? BorderSide.none : BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      ),
    );
  }

  Widget _buildCategoryRow(String title, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 30, bottom: 15),
          child: Text(title.toUpperCase(), style: CyberTheme.headerText(size: 20, color: CyberTheme.hackerGreen)),
        ),
        SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsScreen(item: item))),
                    child: Container(
                      width: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: CyberTheme.hackerGreen.withOpacity(0.2)),
                        image: DecorationImage(
                          image: NetworkImage(
                            (item['poster'] != null && item['poster'].toString().startsWith('http'))
                                ? item['poster']
                                : 'https://via.placeholder.com/300x450?text=No+Image',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.65,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = _searchResults[index];
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsScreen(item: item))),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CyberTheme.hackerGreen.withOpacity(0.3)),
                    image: DecorationImage(
                      image: NetworkImage(
                        (item['poster'] != null && item['poster'].toString().startsWith('http'))
                            ? item['poster']
                            : 'https://via.placeholder.com/300x450?text=No+Image',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            );
          },
          childCount: _searchResults.length,
        ),
      ),
    );
  }
}
