import 'package:flutter/material.dart';
import '../api/tmdb_client.dart';
import 'details_screen.dart';
import '../ui/cyber_theme.dart';

class HomeScreenMobile extends StatefulWidget {
  const HomeScreenMobile({Key? key}) : super(key: key);

  @override
  State<HomeScreenMobile> createState() => _HomeScreenMobileState();
}

class _HomeScreenMobileState extends State<HomeScreenMobile> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = true;

  Map<String, List<Map<String, dynamic>>> _categories = {};

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final type = _currentIndex == 1 ? 'movie' : (_currentIndex == 2 ? 'tv' : null);

    final results = await Future.wait([
      TmdbClient.getTrending(),
      TmdbClient.getNetflixSeries(),
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

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberTheme.matrixBlack,
      body: _currentIndex == 3 ? _buildSearchPage() : _buildHomePage(),
      bottomNavigationBar: Theme(
        data: ThemeData(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              _isSearching = (index == 3);
              _isLoading = true;
            });
            _loadDashboard();
          },
          backgroundColor: CyberTheme.matrixBlack,
          selectedItemColor: CyberTheme.hackerGreen,
          unselectedItemColor: Colors.white38,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: CyberTheme.monoText(size: 10, weight: FontWeight.bold),
          unselectedLabelStyle: CyberTheme.monoText(size: 10),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'HOME'),
            BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'MOVIES'),
            BottomNavigationBarItem(icon: Icon(Icons.tv), label: 'TV SHOWS'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'SEARCH'),
            BottomNavigationBarItem(icon: Icon(Icons.video_library), label: 'LIBRARY'),
          ],
        ),
      ),
    );
  }

  Widget _buildHomePage() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: CyberTheme.matrixBlack.withOpacity(0.8),
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Image.asset('assets/logo.png'),
          ),
          title: Text("MOVNODE", style: CyberTheme.headerText(size: 18, color: CyberTheme.hackerGreen)),
        ),
        if (_isLoading)
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
    );
  }

  Widget _buildSearchPage() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: CyberTheme.matrixBlack,
          title: Container(
            height: 45,
            decoration: CyberTheme.glassBox(),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: CyberTheme.monoText(color: CyberTheme.hackerGreen),
              onChanged: (_) => _performSearch(),
              decoration: InputDecoration(
                hintText: "> SEARCH_SYSTEM...",
                hintStyle: CyberTheme.monoText(color: CyberTheme.hackerGreen.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.terminal, color: CyberTheme.hackerGreen, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              ),
            ),
          ),
        ),
        if (_isSearching)
          _buildSearchResults()
        else
          const SliverFillRemaining(
            child: Center(child: Icon(Icons.search, size: 100, color: Colors.white10)),
          ),
      ],
    );
  }

  Widget _buildHero() {
    if (_categories['Trending Now'] == null || _categories['Trending Now']!.isEmpty) return const SizedBox();
    final featured = _categories['Trending Now']![0];

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsScreen(item: featured))),
      child: Container(
        height: 450,
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
              (featured['poster'] != null && featured['poster'].toString().startsWith('http'))
                  ? featured['poster']
                  : 'https://via.placeholder.com/500x750?text=No+Image',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                CyberTheme.matrixBlack.withOpacity(0.8),
                CyberTheme.matrixBlack,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                featured['title'].toUpperCase(),
                style: CyberTheme.headerText(size: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeroButton("PLAY", Icons.play_arrow, CyberTheme.hackerGreen, true, featured),
                  const SizedBox(width: 20),
                  _buildHeroButton("INFO", Icons.info_outline, Colors.white, false, featured),
                ],
              ),
              const SizedBox(height: 30),
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
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
      ),
    );
  }

  Widget _buildCategoryRow(String title, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 15, top: 25, bottom: 10),
          child: Text(title.toUpperCase(), style: CyberTheme.headerText(size: 16, color: CyberTheme.hackerGreen)),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsScreen(item: item))),
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: CyberTheme.hackerGreen.withOpacity(0.1)),
                    image: DecorationImage(
                      image: NetworkImage(
                        (item['poster'] != null && item['poster'].toString().startsWith('http'))
                            ? item['poster']
                            : 'https://via.placeholder.com/200x300?text=No+Image',
                      ),
                      fit: BoxFit.cover,
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
      padding: const EdgeInsets.all(15),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.7,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = _searchResults[index];
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsScreen(item: item))),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: CyberTheme.hackerGreen.withOpacity(0.2)),
                  image: DecorationImage(
                    image: NetworkImage(
                      (item['poster'] != null && item['poster'].toString().startsWith('http'))
                          ? item['poster']
                          : 'https://via.placeholder.com/200x300?text=No+Image',
                    ),
                    fit: BoxFit.cover,
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
