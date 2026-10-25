import 'dart:convert';

import 'package:http/http.dart' as http;

class ImportResult {
  final List<String> names = [];
  final List<String> notes = [];
  String? listName;
}

const _userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

final _urlRe = RegExp(r'''https?://[^\s<>"']+''');
final _coordRe = RegExp(r'^-?\d+\.\d+,\s*-?\d+\.\d+$');

String _clean(String s) {
  var t = s.replaceAll('+', ' ');
  try {
    t = Uri.decodeComponent(t);
  } catch (_) {
    // Already decoded.
  }
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _label(String n) => _coordRe.hasMatch(n) ? 'Pinned spot ($n)' : n;

/// Place names that can be read straight from a full Google Maps URL:
/// directions (every stop), a single place, a search, or ?q= / waypoints.
List<String> namesFromMapsUrl(String raw) {
  final out = <String>[];
  final u = Uri.tryParse(raw);
  if (u == null || !u.host.contains('google.')) return out;

  final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
  final i = segs.indexOf('maps');
  final rest = i >= 0 ? segs.sublist(i + 1) : segs;

  if (rest.isNotEmpty && rest[0] == 'dir') {
    for (final seg in rest.skip(1)) {
      if (seg.startsWith('@') || seg.startsWith('data=') || seg == 'am=t') {
        break;
      }
      final n = _clean(seg);
      if (n.isNotEmpty) out.add(n);
    }
  } else if (rest.length > 1 &&
      (rest[0] == 'place' || rest[0] == 'search') &&
      !rest[1].startsWith('@')) {
    final n = _clean(rest[1]);
    if (n.isNotEmpty) out.add(n);
  }

  if (out.isEmpty) {
    final q = u.queryParameters['q'] ??
        u.queryParameters['query'] ??
        u.queryParameters['destination'];
    if (q != null && q.trim().isNotEmpty) out.add(_clean(q));
  }
  final wps = u.queryParameters['waypoints'];
  if (wps != null) {
    for (final w in wps.split('|')) {
      final n = _clean(w);
      if (n.isNotEmpty) out.add(n);
    }
  }
  return out.map(_label).toList();
}

/// The id of a saved list, if this URL points at one.
String? listIdFrom(String url) {
  var s = url;
  try {
    s = Uri.decodeFull(url);
  } catch (_) {}
  final m = RegExp(r'!11m\d+!2s([A-Za-z0-9_\-]+)').firstMatch(s) ??
      RegExp(r'/placelists/list/([A-Za-z0-9_\-]+)').firstMatch(s);
  return m?.group(1);
}

/// Follows a maps.app.goo.gl short link to the full Google Maps address.
Future<String?> resolveShortLink(String url) async {
  final client = http.Client();
  try {
    var cur = Uri.parse(url);
    for (var hop = 0; hop < 8; hop++) {
      final req = http.Request('GET', cur)
        ..followRedirects = false
        ..headers['User-Agent'] = _userAgent;
      final res = await client.send(req).timeout(const Duration(seconds: 12));
      final loc = res.headers['location'];
      if (res.statusCode >= 300 && res.statusCode < 400 && loc != null) {
        await res.stream.drain<void>();
        cur = cur.resolve(loc);
        continue;
      }
      // Some short links answer with a page instead of a redirect.
      if (cur.host.contains('goo.gl')) {
        final body = await res.stream.bytesToString();
        final m = RegExp(r'''https://(?:www\.)?google\.[a-z.]+/maps[^"'\s<>\\]+''')
            .firstMatch(body.replaceAll(r'\u003d', '=').replaceAll(r'\u0026', '&').replaceAll('&amp;', '&'));
        if (m != null) return m.group(0);
      } else {
        await res.stream.drain<void>();
      }
      break;
    }
    return cur.toString();
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// Reads the places in a shared Google Maps list.
///
/// Google has no public API for this. It uses the same address the Maps
/// website loads lists from, so it only works for lists with link sharing on,
/// and may stop working if Google changes it. Takeout import is the fallback.
Future<bool> fetchSavedList(String id, ImportResult r) async {
  final uri = Uri.parse(
      'https://www.google.com/maps/preview/entitylist/getlist?authuser=0&hl=en&gl=in'
      '&pb=!1m4!1s$id!2e1!3m1!1e1!2e2!3e2!4i500!16b1');
  try {
    final res = await http
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return false;
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    final start = body.indexOf('[');
    if (start < 0) return false;
    final data = jsonDecode(body.substring(start));
    final root = (data is List && data.isNotEmpty && data[0] is List)
        ? data[0] as List
        : null;
    if (root == null) return false;
    if (root.length > 4 &&
        root[4] is String &&
        (root[4] as String).trim().isNotEmpty) {
      r.listName = (root[4] as String).trim();
    }
    final items = root.length > 8 && root[8] is List ? root[8] as List : const [];
    var found = 0;
    for (final it in items) {
      if (it is List && it.length > 2 && it[2] is String) {
        final name = (it[2] as String).trim();
        if (name.isNotEmpty) {
          r.names.add(name);
          found++;
        }
      }
    }
    return found > 0;
  } catch (_) {
    return false;
  }
}

/// Handles anything pasted or shared into the app: links, place names, or the
/// "Place name + short link" text Google Maps sends when you share.
Future<ImportResult> importText(String text) async {
  final r = ImportResult();
  final urls = _urlRe.allMatches(text).map((m) => m.group(0)!).toList();
  final plain = text
      .replaceAll(_urlRe, '\n')
      .split(RegExp(r'[\n;]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  if (urls.isEmpty) {
    r.names.addAll(plain);
    return r;
  }

  var sawList = false;
  for (final url in urls) {
    var full = url;
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.contains('goo.gl')) {
      final resolved = await resolveShortLink(url);
      if (resolved == null) {
        r.notes.add('Couldn’t open the link. Check your internet connection.');
        continue;
      }
      full = resolved;
    } else if (!host.contains('google.')) {
      r.notes.add('$host isn’t a Google Maps link.');
      continue;
    }

    final id = listIdFrom(full);
    if (id != null) {
      sawList = true;
      final ok = await fetchSavedList(id, r);
      if (!ok) {
        r.notes.add('Couldn’t read that saved list. Turn on link sharing for '
            'it in Google Maps, or import it from Google Takeout.');
      }
      continue;
    }
    r.names.addAll(namesFromMapsUrl(full));
  }

  if (r.names.isEmpty && !sawList) {
    // Google Maps shares a single place as "Place name\nhttps://maps.app.goo.gl/…".
    final boiler = RegExp(r'check out|google maps|shared a list',
        caseSensitive: false);
    r.names.addAll(plain.where((s) => s.length <= 90 && !boiler.hasMatch(s)));
  }
  if (r.names.isEmpty && r.notes.isEmpty) {
    r.notes.add('No place names found in that link.');
  }
  return r;
}

/* ---------- Google Takeout files ---------- */

List<List<String>> parseCsv(String input) {
  final text = input.replaceFirst('﻿', '');
  final rows = <List<String>>[];
  var row = <String>[];
  final f = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          f.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        f.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(f.toString());
      f.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(f.toString());
      f.clear();
      rows.add(row);
      row = <String>[];
    } else {
      f.write(c);
    }
  }
  if (f.isNotEmpty || row.isNotEmpty) {
    row.add(f.toString());
    rows.add(row);
  }
  return rows.where((r) => r.any((x) => x.trim().isNotEmpty)).toList();
}

String _nameFromUrl(String? u) {
  if (u == null || u.isEmpty) return '';
  final n = namesFromMapsUrl(u);
  return n.isEmpty ? '' : n.first;
}

/// Reads a list exported by Google Takeout: a .csv per saved list, or
/// "Saved Places.json" for starred places.
List<String> namesFromFile(String text, String filename) {
  final out = <String>[];
  final looksJson = RegExp(r'\.(geo)?json$', caseSensitive: false).hasMatch(filename) ||
      RegExp(r'^\s*[\[{]').hasMatch(text);

  if (looksJson) {
    dynamic data;
    try {
      data = jsonDecode(text);
    } catch (_) {
      return out;
    }
    final items = data is Map && data['features'] is List
        ? data['features'] as List
        : (data is List ? data : const []);
    for (final it in items) {
      if (it is! Map) continue;
      final p = it['properties'] is Map ? it['properties'] as Map : it;
      final loc = p['location'] is Map ? p['location'] as Map : const {};
      final candidates = [
        p['Title'], p['title'], p['name'], loc['name'], loc['Name'],
        loc['Business Name'],
      ];
      final direct = candidates.firstWhere(
          (x) => x is String && x.trim().isNotEmpty,
          orElse: () => null);
      final urlVal = p['Google Maps URL'] ?? p['google_maps_url'] ?? p['url'];
      final name = direct is String
          ? direct
          : _nameFromUrl(urlVal is String ? urlVal : null);
      if (name.trim().isNotEmpty) out.add(name.trim());
    }
    return out;
  }

  final rows = parseCsv(text);
  if (rows.isEmpty) return out;
  final head = rows.first.map((h) => h.trim().toLowerCase()).toList();
  var ti = head.indexWhere((h) => h == 'title' || h == 'name');
  final ui = head.indexWhere((h) => h == 'url' || h.contains('url'));
  final hasHeader = ti >= 0 || ui >= 0;
  final body = hasHeader ? rows.skip(1) : rows;
  if (!hasHeader) ti = 0;
  for (final r in body) {
    var n = (ti >= 0 && ti < r.length) ? r[ti].trim() : '';
    if (n.isEmpty && ui >= 0 && ui < r.length) n = _nameFromUrl(r[ui]);
    if (n.isNotEmpty) out.add(n);
  }
  return out;
}
