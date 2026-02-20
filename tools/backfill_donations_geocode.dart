// Backfill donations latitude/longitude using Nominatim.
//
// Required env vars:
// - SUPABASE_URL (e.g. https://xyz.supabase.co)
// - SUPABASE_SERVICE_KEY (service role key for updates)
// Optional:
// - BACKFILL_LIMIT (max rows to process)
//
// Run:
//   dart run tools/backfill_donations_geocode.dart
//
// Notes:
// - Nominatim rate limits apply; this script delays between requests.
// - Verify a few rows before running on large datasets.

import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final supabaseKey = Platform.environment['SUPABASE_SERVICE_KEY'];
  final limit =
      int.tryParse(Platform.environment['BACKFILL_LIMIT'] ?? '0') ?? 0;

  if (supabaseUrl == null || supabaseKey == null) {
    stderr.writeln('Missing SUPABASE_URL or SUPABASE_SERVICE_KEY.');
    exitCode = 2;
    return;
  }

  final client = HttpClient();
  final rows = await _fetchMissingCoords(
    client,
    supabaseUrl,
    supabaseKey,
  );

  if (rows.isEmpty) {
    stdout.writeln('No rows to backfill.');
    return;
  }

  final toProcess = limit > 0 ? rows.take(limit) : rows;
  var processed = 0;

  for (final row in toProcess) {
    final id = row['id']?.toString();
    final city = row['city']?.toString() ?? '';
    final area = row['area']?.toString() ?? '';

    if (id == null || id.isEmpty || city.trim().isEmpty) {
      continue;
    }

    final query =
        [area, city, 'Iraq'].where((part) => part.trim().isNotEmpty).join(', ');

    final coords = await _geocode(client, query);
    if (coords == null) {
      stdout.writeln('No coordinates for $id ($query)');
      continue;
    }

    final updated = await _updateDonationCoords(
      client,
      supabaseUrl,
      supabaseKey,
      id,
      coords.$1,
      coords.$2,
    );

    if (updated) {
      processed++;
      stdout.writeln('Updated $id -> ${coords.$1}, ${coords.$2}');
    }

    await Future.delayed(const Duration(milliseconds: 1100));
  }

  stdout.writeln('Backfill completed. Updated: $processed');
  client.close();
}

Future<List<Map<String, dynamic>>> _fetchMissingCoords(
  HttpClient client,
  String supabaseUrl,
  String supabaseKey,
) async {
  final uri = Uri.parse(
    '$supabaseUrl/rest/v1/donations'
    '?select=id,city,area&or=(latitude.is.null,longitude.is.null)',
  );

  final request = await client.getUrl(uri);
  request.headers
    ..set('apikey', supabaseKey)
    ..set('Authorization', 'Bearer $supabaseKey')
    ..set('Accept', 'application/json');

  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode >= 400) {
    stderr.writeln('Fetch failed: ${response.statusCode} $body');
    return [];
  }

  final data = jsonDecode(body);
  if (data is! List) return [];
  return data.cast<Map<String, dynamic>>();
}

Future<(double, double)?> _geocode(HttpClient client, String query) async {
  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': query,
    'format': 'json',
    'limit': '1',
  });

  final request = await client.getUrl(uri);
  request.headers.set(
    'User-Agent',
    'online_store_333_backfill/1.0 (admin@example.com)',
  );

  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode >= 400) {
    stderr.writeln('Geocode failed: ${response.statusCode} $body');
    return null;
  }

  final data = jsonDecode(body);
  if (data is! List || data.isEmpty) return null;
  final item = data.first;
  final lat = double.tryParse(item['lat']?.toString() ?? '');
  final lon = double.tryParse(item['lon']?.toString() ?? '');
  if (lat == null || lon == null) return null;
  return (lat, lon);
}

Future<bool> _updateDonationCoords(
  HttpClient client,
  String supabaseUrl,
  String supabaseKey,
  String id,
  double latitude,
  double longitude,
) async {
  final uri = Uri.parse('$supabaseUrl/rest/v1/donations?id=eq.$id');
  final request = await client.patchUrl(uri);
  request.headers
    ..set('apikey', supabaseKey)
    ..set('Authorization', 'Bearer $supabaseKey')
    ..set('Content-Type', 'application/json')
    ..set('Prefer', 'return=minimal');

  request.write(jsonEncode({
    'latitude': latitude,
    'longitude': longitude,
  }));

  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode >= 400) {
    stderr.writeln('Update failed: ${response.statusCode} $body');
    return false;
  }
  return true;
}
