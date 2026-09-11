// Seeds Firestore from the bundled radars.json.
//
//   flutter run -t tool/seed_firestore.dart
//
// Requires Firebase to be configured for the platform you run it on
// (`flutterfire configure`). Writes all 88 documents into `radars/` plus
// `app_config/settings` in a single batch, so a re-run is idempotent.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:radarme/config/constants.dart';
import 'package:radarme/config/theme.dart';
import 'package:radarme/models/radar.dart';
import 'package:radarme/services/firestore_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? initError;
  try {
    await Firebase.initializeApp();
  } catch (error) {
    initError = error.toString();
  }

  runApp(_SeedApp(initError: initError));
}

class _SeedApp extends StatelessWidget {
  const _SeedApp({this.initError});

  final String? initError;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'RadarME — seed',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: _SeedScreen(initError: initError),
      );
}

class _SeedScreen extends StatefulWidget {
  const _SeedScreen({this.initError});

  final String? initError;

  @override
  State<_SeedScreen> createState() => _SeedScreenState();
}

class _SeedScreenState extends State<_SeedScreen> {
  final List<String> _log = <String>[];
  bool _running = false;

  void _append(String line) => setState(() => _log.add(line));

  Future<void> _seed() async {
    setState(() {
      _running = true;
      _log.clear();
    });

    try {
      _append('Čitanje ${AppConstants.localRadarsAsset}…');
      final List<Radar> radars = Radar.decodeList(
        await rootBundle.loadString(AppConstants.localRadarsAsset),
      );
      _append('Učitano ${radars.length} lokacija.');

      final int corridors = radars
          .where((Radar r) => r.type == RadarType.averageSpeedControlA)
          .length;
      _append('Zona prosječne brzine: $corridors');

      _append('Upis u Firestore…');
      final int written =
          await FirestoreService(enabled: true).seed(radars);
      _append('Gotovo — $written dokumenata u "radars" '
          '+ app_config/settings.');
    } catch (error) {
      _append('GREŠKA: $error');
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? error = widget.initError;

    return Scaffold(
      appBar: AppBar(title: const Text('Firestore seeding')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Firebase nije inicijalizovan.\nPokrenite '
                    '`flutterfire configure` pa probajte ponovo.\n\n$error',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _running || error != null ? null : _seed,
              icon: _running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_running ? 'Upis u toku…' : 'Pokreni seeding'),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: AppRadii.cardRadius,
                ),
                child: ListView.builder(
                  itemCount: _log.length,
                  itemBuilder: (BuildContext context, int index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _log[index],
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
