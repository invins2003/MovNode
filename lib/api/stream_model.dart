class SubtitleSource {
  final String url;
  final String label;
  final String? language;

  SubtitleSource({
    required this.url, 
    required this.label, 
    this.language
  });
}

class VideasyStream {
  final String name;
  final String title;
  final String url;
  final String quality;
  final String provider;
  final Map<String, String>? headers;
  final List<SubtitleSource>? subtitles;

  VideasyStream({
    required this.name,
    required this.title,
    required this.url,
    required this.quality,
    required this.provider,
    this.headers,
    this.subtitles,
  });
}
