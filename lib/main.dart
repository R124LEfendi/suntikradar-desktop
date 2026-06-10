import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:auto_updater/auto_updater.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // URL Appcast XML (dapat disesuaikan atau diambil dari .env)
  final String feedURL = dotenv.env['APP_UPDATE_URL'] ?? 'https://api.suntikradar.com/updates/appcast.xml';
  
  try {
    await autoUpdater.setFeedURL(feedURL);
    await autoUpdater.checkForUpdates(inBackground: true);
  } catch (e) {
    debugPrint('AutoUpdater initialization failed: $e');
  }

  runApp(const ProviderScope(child: AdminConsoleApp()));
}
