import 'dart:convert';
import 'package:http/http.dart' as http;

class TmdbClient {
  static const String _apiKey = 'd131017ccc6e5462a81c9304d21476de';
  static const List<String> _baseUrls = [
    'https://api.tmdb.org/3',
    'https://api.themoviedb.org/3',
  ];
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  static Future<http.Response> _getWithFallback(String endpoint) async {
    http.Response? lastResponse;
    for (String baseUrl in _baseUrls) {
      try {
        final url = '$baseUrl$endpoint';
        print('DEBUG: Sending HTTP GET to $url');
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          return response;
        }
        lastResponse = response;
      } catch (e) {
        print('DEBUG: Request to $baseUrl failed: $e');
      }
    }
    if (lastResponse != null) return lastResponse;
    throw Exception('All TMDB proxies failed. Network blocked.');
  }

  /// Search TMDB for movies and TV shows using JSON API
  static Future<List<Map<String, dynamic>>> search(String query) async {
    return _fetchList('/search/multi?api_key=$_apiKey&query=${Uri.encodeComponent(query)}');
  }

  /// Get trending content
  static Future<List<Map<String, dynamic>>> getTrending() async {
    return _fetchList('/trending/all/day?api_key=$_apiKey');
  }

  /// Get popular movies
  static Future<List<Map<String, dynamic>>> getPopularMovies() async {
    return _fetchList('/movie/popular?api_key=$_apiKey');
  }

  /// Get popular TV shows
  static Future<List<Map<String, dynamic>>> getPopularTVShows() async {
    return _fetchList('/tv/popular?api_key=$_apiKey');
  }

  /// Get Netflix Originals
  static Future<List<Map<String, dynamic>>> getNetflixSeries() async {
    return _fetchList('/discover/tv?api_key=$_apiKey&with_networks=213&sort_by=popularity.desc');
  }

  /// Get Amazon Prime Originals
  static Future<List<Map<String, dynamic>>> getAmazonSeries() async {
    return _fetchList('/discover/tv?api_key=$_apiKey&with_networks=1024&sort_by=popularity.desc');
  }

  /// Get Apple TV+ Originals
  static Future<List<Map<String, dynamic>>> getAppleSeries() async {
    return _fetchList('/discover/tv?api_key=$_apiKey&with_networks=2552&sort_by=popularity.desc');
  }

  /// Get Disney+ Originals
  static Future<List<Map<String, dynamic>>> getDisneySeries() async {
    return _fetchList('/discover/tv?api_key=$_apiKey&with_networks=2739&sort_by=popularity.desc');
  }

  /// Helper to fetch and format a list of items
  static Future<List<Map<String, dynamic>>> _fetchList(String endpoint) async {
    try {
      final response = await _getWithFallback(endpoint);
      if (response.statusCode != 200) return [];
      
      final data = json.decode(response.body);
      final results = <Map<String, dynamic>>[];

      for (var item in data['results'] ?? []) {
        final mediaType = item['media_type'] ?? (endpoint.contains('/movie/') ? 'movie' : (endpoint.contains('/tv/') ? 'tv' : null));
        if (mediaType != 'movie' && mediaType != 'tv') continue;

        final title = item['title'] ?? item['name'] ?? 'Unknown';
        final type = mediaType == 'movie' ? 'Movie' : 'TV Series';
        final releaseDate = item['release_date'] ?? item['first_air_date'] ?? 'N/A';
        final posterPath = item['poster_path'] != null ? '$_imageBaseUrl${item['poster_path']}' : null;
        final backdropPath = item['backdrop_path'] != null ? '$_imageBaseUrl${item['backdrop_path']}' : null;

        results.add({
          'title': title,
          'type': type,
          'id': item['id'].toString(),
          'releaseDate': releaseDate,
          'poster': posterPath,
          'backdrop': backdropPath,
          'overview': item['overview'] ?? '',
          'vote_average': item['vote_average']?.toString() ?? '0.0',
        });
      }
      return results;
    } catch (e) {
      print('Fetch list failed: $e');
      return [];
    }
  }

  /// Get seasons for a TV Show using JSON API
  static Future<List<Map<String, dynamic>>> getTVDetails(String id) async {

    try {
      final response = await _getWithFallback('/tv/$id?api_key=$_apiKey');

      if (response.statusCode != 200) {
        print('Fetch seasons failed with status: ${response.statusCode}');
        return [{'title': 'Season 1', 'number': 1}];
      }

      final data = json.decode(response.body);
      final seasons = <Map<String, dynamic>>[];

      for (var season in data['seasons'] ?? []) {
        // Skip season 0 (Usually Specials) unless needed
        if (season['season_number'] == 0) continue;
        
        seasons.add({
          'title': season['name'] ?? 'Season ${season['season_number']}',
          'number': season['season_number']
        });
      }

      if (seasons.isEmpty) {
        seasons.add({'title': 'Season 1', 'number': 1});
      }
      return seasons;
    } catch (e) {
      print('Fetch seasons failed: $e');
      return [{'title': 'Season 1', 'number': 1}];
    }
  }

  /// Get episodes for a specific season using JSON API
  static Future<List<Map<String, dynamic>>> getEpisodes(String tvId, int seasonNum) async {
    try {
      final response = await _getWithFallback('/tv/$tvId/season/$seasonNum?api_key=$_apiKey');

      if (response.statusCode != 200) {
        print('Fetch episodes failed with status: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);
      final episodes = <Map<String, dynamic>>[];

      for (var episode in data['episodes'] ?? []) {
        episodes.add({
          'title': 'Episode ${episode['episode_number']}: ${episode['name']}',
          'number': episode['episode_number']
        });
      }

      return episodes;
    } catch (e) {
      print('Fetch episodes failed: $e');
      return [];
    }
  }

  /// Get possible embed links
  static Map<String, String> getEmbedLink(String type, String id, {int season = 1, int episode = 1}) {
    final isMovie = type.toLowerCase() == 'movie';
    return {
      'vidsrc': isMovie 
        ? 'https://vidsrc.to/embed/movie/$id' 
        : 'https://vidsrc.to/embed/tv/$id/$season/$episode',
      'vidsrc_xyz': isMovie 
        ? 'https://vidsrc.xyz/embed/movie?tmdb=$id' 
        : 'https://vidsrc.xyz/embed/tv?tmdb=$id&season=$season&episode=$episode',
      'multiembed': isMovie 
        ? 'https://multiembed.mov/directstream.php?video_id=$id&tmdb=1' 
        : 'https://multiembed.mov/directstream.php?video_id=$id&tmdb=1&s=$season&e=$episode',
      'vsembed': isMovie
        ? 'https://vsembed.su/embed/movie/$id'
        : 'https://vsembed.su/embed/tv/$id/$season-$episode'
    };
  }
}
