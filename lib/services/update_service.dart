import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const String kCurrentVersion = 'v0.4.0-alpha';

const String _repoOwner = 'laskinss27-cmyk';
const String _repoName = 'diary-app';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String notes;
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.notes,
  });
}

class UpdateService {
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$_repoOwner/$_repoName/releases',
            ),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final releases = jsonDecode(response.body) as List;
      if (releases.isEmpty) return null;

      final latest = releases[0] as Map<String, dynamic>;
      final latestTag = latest['tag_name'] as String? ?? '';

      if (latestTag.isEmpty || latestTag == kCurrentVersion) return null;

      String downloadUrl = '';
      final assets = latest['assets'] as List? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String? ?? '';
          break;
        }
      }

      if (downloadUrl.isEmpty) {
        downloadUrl = latest['html_url'] as String? ?? '';
      }

      return UpdateInfo(
        version: latestTag,
        downloadUrl: downloadUrl,
        notes: latest['body'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> openDownload(String url) async {
    if (url.isEmpty) return;
    try {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }
}
