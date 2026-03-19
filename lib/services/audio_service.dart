import 'package:http/http.dart' as http;

class AudioService {
  static Future<List<Map<String, String>>> getRecordings() async {
    final response = await http.get(
      Uri.parse("https://media.smartbilal.com/masjid/mzcentraldequelimane"),
    );

    if (response.statusCode != 200) return [];

    final html = response.body;

    final regex = RegExp(r'https://[^"]+\.mp3');
    final matches = regex.allMatches(html);

    List<Map<String, String>> audios = [];

    for (var m in matches) {
      final url = m.group(0)!;

      audios.add({
        "title": url.split("/").last,
        "url": url,
      });
    }

    return audios;
  }
}
