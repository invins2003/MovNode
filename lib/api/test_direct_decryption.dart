import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('--- TESTING DIRECT DECRYPTION (NONCE EXTRACTION) ---');
  
  // Example embed link from flixhqz.com
  final embedUrl = 'https://ployan.live/get/83579481a8cc35d8-818c617e1f9a911e86e72277-1e30ee9ad6d0073aad90707a87ffc6987968b64750003dbc8f80b8b4ce4c3406f499d4';
  final userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

  try {
    print('[STEP 1] Fetching embed HTML...');
    final response = await http.get(Uri.parse(embedUrl), headers: {
      'User-Agent': userAgent,
      'Referer': 'https://flixhqz.com/',
    });

    if (response.statusCode != 200) {
      print('❌ Failed to fetch embed HTML: ${response.statusCode}');
      return;
    }

    final html = response.body;
    print('DEBUG: HTML length: ${html.length}');

    // [STEP 2] Extract Nonce (The "staticsenju/flixhq-api" way)
    // Pattern 1: 48-character alphanumeric string
    // Pattern 2: Three 16-character alphanumeric strings
    final nonceRegex48 = RegExp(r'\b[a-zA-Z0-9]{48}\b');
    final nonceRegex16 = RegExp(r'\b([a-zA-Z0-9]{16})\b.*?\b([a-zA-Z0-9]{16})\b.*?\b([a-zA-Z0-9]{16})\b');

    String? nonce;
    final match48 = nonceRegex48.firstMatch(html);
    if (match48 != null) {
      nonce = match48.group(0);
      print('✅ Found 48-char nonce: $nonce');
    } else {
      final match16 = nonceRegex16.firstMatch(html);
      if (match16 != null) {
        nonce = '${match16.group(1)}${match16.group(2)}${match16.group(3)}';
        print('✅ Found combined 16-char nonce: $nonce');
      }
    }

    if (nonce == null) {
      print('❌ Nonce not found in HTML');
      // Show snippet of HTML to see if we can find something else
      print('DEBUG: HTML Snippet: ${html.length > 500 ? html.substring(0, 500) : html}');
      return;
    }

    // [STEP 3] Call getSources
    final uri = Uri.parse(embedUrl);
    final embedHost = '${uri.scheme}://${uri.host}';
    final fileId = uri.pathSegments.last;
    
    // The repo uses /embed-1/v3/e-1/getSources
    // We need to check if ployan.live uses the same path
    final apiPaths = [
      '/embed-1/v3/e-1/getSources',
      '/ajax/getSources',
      '/v2/getSources',
    ];

    for (var path in apiPaths) {
      final apiUrl = '$embedHost$path?id=$fileId&_k=$nonce';
      print('[STEP 3] Trying API call: $apiUrl');
      
      final apiRes = await http.get(Uri.parse(apiUrl), headers: {
        'Referer': '$embedHost/',
        'X-Requested-With': 'XMLHttpRequest',
        'User-Agent': userAgent,
      });

      print('DEBUG: Status: ${apiRes.statusCode}');
      if (apiRes.statusCode == 200) {
        try {
          final data = json.decode(apiRes.body);
          if (data['sources'] != null) {
            print('🎉 SUCCESS! Found sources: ${data['sources']}');
            return;
          }
        } catch (e) {
          print('DEBUG: Failed to parse JSON: $e');
        }
      }
    }

    print('❌ All API paths failed');

  } catch (e) {
    print('❌ ERROR: $e');
  }
}
