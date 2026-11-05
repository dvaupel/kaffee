/// Update-Prüfung gegen die GitHub-Releases und Installation der neuen APK.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

const releasesRepo = 'dvaupel/kaffee';

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.notes,
    required this.size,
  });

  final String version;
  final String apkUrl;
  final String notes;
  final int size;
}

/// "v1.2.3" oder "1.2.3+4" -> [1, 2, 3]; ungültig -> null.
List<int>? parseVersion(String v) {
  final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)').firstMatch(v.trim());
  if (m == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
}

bool isNewerVersion(String remote, String local) {
  final r = parseVersion(remote), l = parseVersion(local);
  if (r == null || l == null) return false;
  for (var i = 0; i < 3; i++) {
    if (r[i] != l[i]) return r[i] > l[i];
  }
  return false;
}

/// Gibt `null` zurück, wenn die App aktuell ist. Wirft bei Netzwerkfehlern.
Future<UpdateInfo?> checkForUpdate() async {
  final info = await PackageInfo.fromPlatform();
  final res = await http.get(
    Uri.https('api.github.com', '/repos/$releasesRepo/releases/latest'),
    headers: {'Accept': 'application/vnd.github+json'},
  ).timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) {
    throw HttpException('GitHub antwortet mit ${res.statusCode}');
  }
  final j = jsonDecode(res.body) as Map<String, dynamic>;
  final tag = j['tag_name'] as String? ?? '';
  if (!isNewerVersion(tag, info.version)) return null;
  final assets = (j['assets'] as List? ?? []).cast<Map<String, dynamic>>();
  final apk = assets.where((a) => (a['name'] as String).endsWith('.apk'));
  if (apk.isEmpty) return null;
  final a = apk.first;
  return UpdateInfo(
    version: tag.replaceFirst('v', ''),
    apkUrl: a['browser_download_url'] as String,
    notes: (j['body'] as String? ?? '').trim(),
    size: (a['size'] as num?)?.toInt() ?? 0,
  );
}

Future<String> currentVersion() async =>
    (await PackageInfo.fromPlatform()).version;

/// Lädt die APK in den Cache und öffnet den Android-Installer.
/// [onProgress] liefert 0..1 (oder null, wenn die Größe unbekannt ist).
Future<void> downloadAndInstall(
  UpdateInfo u, {
  required void Function(double? progress) onProgress,
}) async {
  final client = http.Client();
  try {
    final res = await client.send(http.Request('GET', Uri.parse(u.apkUrl)));
    if (res.statusCode != 200) {
      throw HttpException('Download fehlgeschlagen (${res.statusCode})');
    }
    final total = res.contentLength ?? u.size;
    final file = File('${Directory.systemTemp.path}/kaffee-${u.version}.apk');
    final sink = file.openWrite();
    var got = 0;
    await for (final chunk in res.stream) {
      sink.add(chunk);
      got += chunk.length;
      onProgress(total > 0 ? got / total : null);
    }
    await sink.close();
    final r = await OpenFilex.open(file.path,
        type: 'application/vnd.android.package-archive');
    if (r.type != ResultType.done) {
      throw Exception(r.message);
    }
  } finally {
    client.close();
  }
}
