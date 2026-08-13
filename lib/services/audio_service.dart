import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class Recording {
  final String title;
  final String url;
  final int durationMin;
  final DateTime? startAt;

  Recording({
    required this.title,
    required this.url,
    required this.durationMin,
    this.startAt,
  });
}

class RecordingsPage {
  final List<Recording> items;
  final String? nextPageUrl;

  RecordingsPage(this.items, this.nextPageUrl);
}

class AudioService {
  static const _recordingsUrl =
      "https://media.smartbilal.com/masjid/mzcentraldequelimane/recordings";

  // A página é uma app Inertia.js: os dados vêm num atributo
  // data-page="{...json...}" com aspas em &quot; e barras escapadas.
  static Future<RecordingsPage> fetchRecordings({String? pageUrl}) async {
    final response = await http.get(
      Uri.parse(pageUrl ?? _recordingsUrl),
      headers: {"User-Agent": "Mozilla/5.0"},
    );

    if (response.statusCode != 200) return RecordingsPage([], null);

    final html = response.body;
    const marker = 'data-page="';
    final start = html.indexOf(marker);
    if (start == -1) return RecordingsPage([], null);

    final contentStart = start + marker.length;
    final end = html.indexOf('"></div>', contentStart);
    if (end == -1) return RecordingsPage([], null);

    final raw = _unescapeHtml(html.substring(contentStart, end));

    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return RecordingsPage([], null);
    }

    final recordings = data['props']?['recordings'] as Map<String, dynamic>?;
    final list = (recordings?['data'] as List?) ?? [];

    final itens = list
        .map((item) {
          final map = item as Map<String, dynamic>;
          return Recording(
            title: map['title']?.toString() ?? '',
            url: map['media_url']?.toString() ?? '',
            durationMin: (map['duration'] as num?)?.toInt() ?? 0,
            startAt: DateTime.tryParse(map['start_at']?.toString() ?? ''),
          );
        })
        .where((r) => r.url.isNotEmpty)
        .toList();

    String? nextUrl;
    for (final link in (recordings?['links'] as List?) ?? []) {
      if (link['label']?.toString() == 'Next' && link['url'] != null) {
        nextUrl = link['url'].toString();
      }
    }

    return RecordingsPage(itens, nextUrl);
  }

  static String _unescapeHtml(String s) {
    return s
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
  }

  static Future<Directory> _recordingsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/gravacoes');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> localFile(String url) async {
    final dir = await _recordingsDir();
    return File('${dir.path}/${url.split('/').last}');
  }

  static Future<bool> isDownloaded(String url) async {
    return (await localFile(url)).exists();
  }

  static Future<File> download(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final file = await localFile(url);
    final client = http.Client();

    try {
      final response = await client.send(http.Request('GET', Uri.parse(url)));

      final total = response.contentLength ?? 0;
      int recebido = 0;
      final sink = file.openWrite();

      await response.stream.map((chunk) {
        recebido += chunk.length;
        if (total > 0) onProgress?.call(recebido / total);
        return chunk;
      }).pipe(sink);
    } finally {
      client.close();
    }

    return file;
  }

  static Future<void> deleteDownload(String url) async {
    final file = await localFile(url);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
